#!/usr/bin/env bash
# Test suite for scripts/tools/cycle-detect.sh (codebase-memory-mcp engine)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/cycle-detect.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== cycle-detect.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# --- Fallback: engine disabled ---
set +e
out="$(DRAFT_MEMORY_DISABLE=1 "$TOOL" --repo "$FIXTURE")"
rc=$?
set -e
assert "Exit 2 when engine unavailable" "$([[ "$rc" == "2" ]] && echo true || echo false)"
if command -v jq >/dev/null 2>&1; then
    if echo "$out" | jq -e '.cycles == [] and .source == "unavailable"' >/dev/null 2>&1; then
        assert "Fallback emits {cycles:[], source:unavailable}" "true"
    else
        assert "Fallback emits {cycles:[], source:unavailable}" "false"
    fi

    # --- Happy path via mock engine (query_graph returns one cycle row) ---
    MOCK="$(make_mock_memory_engine "$FIXTURE/mockbin")"
    out2="$(DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --repo "$FIXTURE")"
    if echo "$out2" | jq -e '.source == "memory-graph" and (.cycles | length >= 1)' >/dev/null 2>&1; then
        assert "Mock engine yields cycles (source=memory-graph)" "true"
    else
        assert "Mock engine yields cycles (source=memory-graph)" "false"
    fi
    if echo "$out2" | jq -e '.truncated | type == "boolean"' >/dev/null 2>&1; then
        assert "Cycles output carries a boolean truncated flag" "true"
    else
        assert "Cycles output carries a boolean truncated flag" "false"
    fi
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
