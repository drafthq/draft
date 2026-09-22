#!/usr/bin/env bash
# Real-engine smoke test for the graph wrappers.
#
# Every other graph suite runs against a mock engine, so the Cypher builders,
# the engine's JSON shapes, project resolution, and index freshness were never
# exercised for real — which is how a stale dialect list and double-counted
# cycles shipped. This suite drives the actual codebase-memory-mcp binary over a
# tiny Python fixture, in an isolated engine cache.
#
# Skips (exit 0) when no engine resolves. CI's engine-smoke job fetches the
# pinned engine and asserts it resolves first, so the skip cannot pass there.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOLS="$ROOT_DIR/scripts/tools"

source "$SCRIPT_DIR/test-helpers.sh"
# shellcheck source=../scripts/tools/_lib.sh
source "$TOOLS/_lib.sh"

echo "=== real-engine smoke tests ==="
echo ""

if ! find_memory_bin "" "$ROOT_DIR" || ! command -v jq >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1; then
    echo "SKIP: no codebase-memory-mcp engine (or jq/git) — run scripts/fetch-memory-engine.sh"
    finish_test "engine smoke"
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export CBM_CACHE_DIR="$WORK/engine-cache"
REPO="$WORK/repo"
mkdir -p "$REPO"
cat > "$REPO/lib.py" <<'PY'
def helper(x):
    return x + 1


def core(y):
    return helper(y) * 2
PY
cat > "$REPO/app.py" <<'PY'
from lib import core


def main():
    return core(3)
PY
cat > "$REPO/cyc.py" <<'PY'
def fa(n):
    return fb(n)


def fb(n):
    return fc(n)


def fc(n):
    return fa(n - 1) if n else 0
PY
git -C "$REPO" init -q
git -C "$REPO" add .
git -C "$REPO" -c user.email=t@t -c user.name=t commit -qm fixture

j() { echo "$1" | jq -e "$2" >/dev/null 2>&1 && echo true || echo false; }

out="$("$TOOLS/graph-callers.sh" --repo "$REPO" --symbol helper 2>/dev/null || true)"
assert "callers: helper is called by core in lib.py" \
    "$(j "$out" '.status == "ok" and any(.callers[]; .name == "core" and .file == "lib.py")')"

# Freshness: an uncommitted edit is visible to the next query, no snapshot re-run.
printf '\n\ndef newfn(z):\n    return helper(z)\n' >> "$REPO/lib.py"
out="$("$TOOLS/graph-callers.sh" --repo "$REPO" --symbol helper 2>/dev/null || true)"
assert "freshness: a caller added after the first index is found" \
    "$(j "$out" 'any(.callers[]; .name == "newfn")')"

out="$("$TOOLS/graph-impact.sh" --repo "$REPO" --file lib.py 2>/dev/null || true)"
assert "impact --file: app.py is downstream of lib.py" \
    "$(j "$out" '.status == "ok" and (.downstream_files | index("app.py")) != null')"
assert "impact --file: the target's own symbols are not listed" \
    "$(j "$out" 'all(.impacted[]; .file != "lib.py")')"
out="$("$TOOLS/graph-impact.sh" --repo "$REPO" --symbol core 2>/dev/null || true)"
assert "impact --symbol: main in app.py depends on core" \
    "$(j "$out" 'any(.impacted[]; .name == "main" and .file == "app.py")')"
out="$("$TOOLS/graph-impact.sh" --repo "$REPO" --file nope.py 2>/dev/null || true)"
assert "impact --file: an unknown path is no-match" "$(j "$out" '.status == "no-match"')"

out="$("$TOOLS/cycle-detect.sh" --repo "$REPO" 2>/dev/null || true)"
assert "cycles: the fa→fb→fc loop is reported exactly once" \
    "$(j "$out" '[.cycles[] | map(split(".")[-1])] == [["fa","fb","fc"]]')"

out="$("$TOOLS/hotspot-rank.sh" --repo "$REPO" 2>/dev/null || true)"
assert "hotspots: ranked from the live graph with enrichment" \
    "$(j "$out" '.source == "memory-graph" and .enrichment == "ok" and (.hotspots | length) > 0')"

out="$("$TOOLS/graph-query.sh" --repo "$REPO" --cypher "MATCH (f) WHERE f.name <> 'zzz' AND f.name = 'core' RETURN f.name LIMIT 5" 2>/dev/null || true)"
assert "dialect: <> against a literal parses and filters" "$(j "$out" '.rows == [["core"]]')"

# memory_cli directly: the wrappers discard engine stderr even under DRAFT_MEMORY_DEBUG.
err="$(DRAFT_MEMORY_DEBUG=1 memory_cli list_projects '{}' 2>&1 >/dev/null || true)"
assert "calling convention: the engine logs no deprecation warning" \
    "$([[ "$err" != *deprecated* ]] && echo true || echo false)"

"$TOOLS/graph-snapshot.sh" --repo "$REPO" >/dev/null 2>&1 || true
assert "snapshot: schema.yaml written with counts, no machine-specific fields" \
    "$(grep -q '^indexed_nodes: [1-9]' "$REPO/draft/graph/schema.yaml" 2>/dev/null \
        && ! grep -qE '^(project|generated_at):' "$REPO/draft/graph/schema.yaml" && echo true || echo false)"

verify_err="$("$TOOLS/verify-graph-binary.sh" --repo "$WORK" 2>&1 >/dev/null || true)"
assert "the resolved engine is the pinned version" \
    "$([[ "$verify_err" != *"differs from the pinned"* ]] && echo true || echo false)"

finish_test "engine smoke"
