#!/usr/bin/env bash
# Test suite for scripts/tools/hotspot-rank.sh (codebase-memory-mcp engine)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/hotspot-rank.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== hotspot-rank.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# --- Fallback: engine disabled → exit 2 with {hotspots:[], source:unavailable} ---
set +e
out="$(DRAFT_MEMORY_DISABLE=1 "$TOOL" --repo "$FIXTURE")"
rc=$?
set -e
assert "Exit 2 when engine unavailable" "$([[ "$rc" == "2" ]] && echo true || echo false)"
if command -v jq >/dev/null 2>&1; then
    if echo "$out" | jq -e '.hotspots == [] and .source == "unavailable"' >/dev/null 2>&1; then
        assert "Emits {hotspots:[], source:unavailable} on fallback" "true"
    else
        assert "Emits {hotspots:[], source:unavailable} on fallback" "false"
    fi
fi

# --- Happy path via mock engine ---
if command -v jq >/dev/null 2>&1; then
    MOCK="$(make_mock_memory_engine "$FIXTURE/mockbin")"
    out2="$(DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --repo "$FIXTURE")"
    if echo "$out2" | jq -e '.source == "memory-graph" and (.hotspots | length == 2)' >/dev/null 2>&1; then
        assert "Mock engine yields ranked hotspots (source=memory-graph)" "true"
    else
        assert "Mock engine yields ranked hotspots (source=memory-graph)" "false"
    fi
    if echo "$out2" | jq -e '.hotspots[0] | (.id == "mock.foo" and .fanIn == 5)' >/dev/null 2>&1; then
        assert "Hotspot record shape {id, name, fanIn}" "true"
    else
        assert "Hotspot record shape {id, name, fanIn}" "false"
    fi
    top_out="$(DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --repo "$FIXTURE" --top 1)"
    count="$(echo "$top_out" | jq '.hotspots | length')"
    assert "--top 1 returns 1 entry" "$([[ "$count" == "1" ]] && echo true || echo false)"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
