#!/usr/bin/env bash
# Test suite for scripts/tools/graph-hierarchy.sh (INHERITS edges)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/graph-hierarchy.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== graph-hierarchy.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# --- Invocation error: both --symbol and --derived ---
set +e
"$TOOL" --repo "$FIXTURE" --symbol A --derived B >/dev/null 2>&1; rc=$?
set -e
assert "Both --symbol and --derived → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --- Fallback: engine disabled ---
set +e
out="$(DRAFT_MEMORY_DISABLE=1 "$TOOL" --repo "$FIXTURE")"
rc=$?
set -e
assert "Exit 2 when engine unavailable" "$([[ "$rc" == "2" ]] && echo true || echo false)"
if command -v jq >/dev/null 2>&1; then
    assert "Fallback emits edges:[] source:unavailable" \
        "$(echo "$out" | jq -e '.edges == [] and .source == "unavailable"' >/dev/null 2>&1 && echo true || echo false)"

    # --- Happy path via mock engine ---
    MOCK="$(make_mock_memory_engine "$FIXTURE/mockbin")"
    out2="$(DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --repo "$FIXTURE")"
    assert "Mock (all) yields edges (source=memory-graph)" \
        "$(echo "$out2" | jq -e '.source == "memory-graph" and (.edges | length >= 1) and (.edges[0] | has("child") and has("parent"))' >/dev/null 2>&1 && echo true || echo false)"

    out3="$(DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --repo "$FIXTURE" --derived Base)"
    assert "Mock --derived yields status field" \
        "$(echo "$out3" | jq -e '.status | type == "string"' >/dev/null 2>&1 && echo true || echo false)"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
