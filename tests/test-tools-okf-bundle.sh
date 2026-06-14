#!/usr/bin/env bash
# Test suite for scripts/tools/okf-bundle.sh (OKF root index for a draft/ bundle)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/okf-bundle.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== okf-bundle.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

D="$FIXTURE/draft"
mkdir -p "$D/tracks/T-001" "$D/graph/okf"
printf -- '---\ntype: Architecture\nproject: "demoproj"\n---\n\n# Arch\n' > "$D/architecture.md"
printf -- '---\ntype: ContextMap\nproject: "demoproj"\n---\n\n# Ctx\n' > "$D/.ai-context.md"
printf -- '---\ntype: Product\nproject: "demoproj"\n---\n\n# Product\n' > "$D/product.md"
printf -- '# Tracks\n' > "$D/tracks.md"
printf -- '---\nproject: "demoproj"\ntrack_id: "T-001"\n---\n\n# Spec\n' > "$D/tracks/T-001/spec.md"
printf '{"title":"Add login"}\n' > "$D/tracks/T-001/metadata.json"
printf -- '---\ntype: Repository\n---\n\n# graph\n' > "$D/graph/okf/index.md"

# --- Missing dir → exit 2 ---
set +e
"$TOOL" --dir "$FIXTURE/nope" >/dev/null 2>&1
rc=$?
set -e
assert "Exit 2 when bundle dir is absent" "$([[ "$rc" == "2" ]] && echo true || echo false)"

# --- Generate index ---
set +e
"$TOOL" --dir "$D" >/dev/null 2>&1
rc=$?
set -e
assert "Generate → exit 0" "$([[ "$rc" == "0" ]] && echo true || echo false)"
assert "index.md written" "$([[ -f "$D/index.md" ]] && echo true || echo false)"
assert "index.md declares OKF type: Repository" \
    "$(grep -q '^type: Repository' "$D/index.md" && echo true || echo false)"
assert "index.md derives project name" \
    "$(grep -q 'title: "demoproj"' "$D/index.md" && echo true || echo false)"
assert "links each present concept with its type" \
    "$(grep -q '\[Architecture\](architecture.md) — `Architecture`' "$D/index.md" \
        && grep -q '\[Product\](product.md) — `Product`' "$D/index.md" && echo true || echo false)"
assert "omits concepts not present (no workflow.md link)" \
    "$(grep -q 'workflow.md' "$D/index.md" && echo false || echo true)"
assert "links track via metadata title" \
    "$(grep -q '\[Add login\](tracks/T-001/spec.md)' "$D/index.md" && echo true || echo false)"
assert "links the graph sub-bundle" \
    "$(grep -q '\[Graph bundle\](graph/okf/index.md)' "$D/index.md" && echo true || echo false)"

# --- Conformance check: passes when all present concepts have type: ---
set +e
"$TOOL" --dir "$D" --check >/dev/null 2>&1
rc=$?
set -e
assert "--check passes when all concepts declare type" "$([[ "$rc" == "0" ]] && echo true || echo false)"

# --- Conformance check: fails when a concept lacks type: ---
printf -- '---\nproject: "demoproj"\n---\n\n# Tech (no type)\n' > "$D/tech-stack.md"
set +e
out="$("$TOOL" --dir "$D" --check 2>&1)"
rc=$?
set -e
assert "--check fails when a concept lacks type" "$([[ "$rc" == "1" ]] && echo true || echo false)"
assert "--check names the offending file" \
    "$(echo "$out" | grep -q 'tech-stack.md' && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
