#!/usr/bin/env bash
# Test suite for scripts/tools/verify-graph-binary.sh (codebase-memory-mcp engine resolver)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/verify-graph-binary.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== verify-graph-binary.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# --- Test 1: engine disabled → exit 2, JSON reports unavailable ---
set +e
out="$(DRAFT_MEMORY_DISABLE=1 "$TOOL" --repo "$FIXTURE" --json 2>/dev/null)"
rc=$?
set -e
assert "Missing engine → exit 2" "$([[ "$rc" == "2" ]] && echo true || echo false)"
assert "JSON reports unavailable" "$(echo "$out" | grep -q '"status":"unavailable"' && echo true || echo false)"

# --- Test 2: engine present (mock) → exit 0, status ok ---
MOCK="$(make_mock_memory_engine "$FIXTURE/mockbin")"
set +e
out="$(DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --repo "$FIXTURE" --json 2>/dev/null)"
rc=$?
set -e
assert "Engine present → exit 0" "$([[ "$rc" == "0" ]] && echo true || echo false)"
assert "JSON reports status ok" "$(echo "$out" | grep -q '"status":"ok"' && echo true || echo false)"
assert "JSON reports engine_bin" "$(echo "$out" | grep -q '"engine_bin"' && echo true || echo false)"

# --- Test 3: usage report side-effect written in draft/ context ---
mkdir -p "$FIXTURE/draft"
DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --repo "$FIXTURE" --json >/dev/null 2>&1 || true
if [[ -f "$FIXTURE/draft/.graph-binary-report.json" ]]; then
    assert "Usage report JSON written" "true"
    assert "Report contains engine_bin" "$(grep -q '"engine_bin"' "$FIXTURE/draft/.graph-binary-report.json" && echo true || echo false)"
else
    assert "Usage report JSON written" "false"
fi

# --- Test 4: --strict with engine present → exit 0 ---
set +e
DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --repo "$FIXTURE" --strict --json >/dev/null 2>&1
rc=$?
set -e
assert "Strict + engine present → exit 0" "$([[ "$rc" == "0" ]] && echo true || echo false)"

# --- Test 5: --strict, engine disabled → exit 2 ---
set +e
DRAFT_MEMORY_DISABLE=1 "$TOOL" --repo "$FIXTURE" --strict --json >/dev/null 2>&1
rc=$?
set -e
assert "Strict + no engine → exit 2" "$([[ "$rc" == "2" ]] && echo true || echo false)"

# --- Test 6: version drift from the pinned engine is reported, not silent ---
# The wrappers are verified against DEFAULT_VERSION; any other engine (e.g. a
# global one on PATH, which outranks the managed install) may speak a different
# dialect or CLI.
PINNED="$(sed -n 's/^DEFAULT_VERSION="v\{0,1\}\([^"]*\)".*/\1/p' "$ROOT_DIR/scripts/fetch-memory-engine.sh")"
out="$(DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --repo "$FIXTURE" --json 2>"$FIXTURE/drift.err")" || true
assert "JSON reports the engine and pinned versions" \
    "$(echo "$out" | jq -e --arg p "$PINNED" '.version == "0.0.0-mock" and .pinned_version == $p' >/dev/null 2>&1 && echo true || echo false)"
assert "Off-pin engine warns on stderr" \
    "$(grep -q "differs from the pinned $PINNED" "$FIXTURE/drift.err" && echo true || echo false)"
PINMOCK="$FIXTURE/pinbin/codebase-memory-mcp"
mkdir -p "$FIXTURE/pinbin"
printf '#!/usr/bin/env bash\necho "codebase-memory-mcp %s"\n' "$PINNED" > "$PINMOCK"
chmod +x "$PINMOCK"
DRAFT_MEMORY_BIN="$PINMOCK" "$TOOL" --repo "$FIXTURE" --json >/dev/null 2>"$FIXTURE/pin.err" || true
assert "On-pin engine does not warn" \
    "$([[ ! -s "$FIXTURE/pin.err" ]] && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
