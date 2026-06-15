#!/usr/bin/env bash
# Test suite for scripts/tools/graph-errors.sh (RAISES/THROWS edges)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/graph-errors.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== graph-errors.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# --- Invocation error: no mode ---
set +e
"$TOOL" --repo "$FIXTURE" >/dev/null 2>&1; rc=$?
set -e
assert "No --symbol/--type → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --- Invocation error: both modes ---
set +e
"$TOOL" --repo "$FIXTURE" --symbol A --type B >/dev/null 2>&1; rc=$?
set -e
assert "Both --symbol and --type → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --- Fallback: engine disabled ---
set +e
out="$(DRAFT_MEMORY_DISABLE=1 "$TOOL" --repo "$FIXTURE" --symbol foo)"
rc=$?
set -e
assert "Exit 2 when engine unavailable" "$([[ "$rc" == "2" ]] && echo true || echo false)"
if command -v jq >/dev/null 2>&1; then
    assert "Fallback (symbol) emits raises:[] source:unavailable" \
        "$(echo "$out" | jq -e '.raises == [] and .source == "unavailable"' >/dev/null 2>&1 && echo true || echo false)"

    # --- Happy path via mock engine ---
    MOCK="$(make_mock_memory_engine "$FIXTURE/mockbin")"
    out2="$(DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --repo "$FIXTURE" --symbol foo)"
    assert "Mock --symbol yields raises array (source=memory-graph)" \
        "$(echo "$out2" | jq -e '.source == "memory-graph" and (.raises | type == "array")' >/dev/null 2>&1 && echo true || echo false)"

    out3="$(DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --repo "$FIXTURE" --type ValueError)"
    assert "Mock --type yields raisers array (source=memory-graph)" \
        "$(echo "$out3" | jq -e '.source == "memory-graph" and (.raisers | type == "array") and .type == "ValueError"' >/dev/null 2>&1 && echo true || echo false)"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
