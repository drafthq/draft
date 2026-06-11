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

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
