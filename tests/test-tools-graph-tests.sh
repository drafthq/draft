#!/usr/bin/env bash
# Test suite for scripts/tools/graph-tests.sh (TESTS coverage / --untested)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/graph-tests.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== graph-tests.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# --- Invocation error: no mode ---
set +e
"$TOOL" --repo "$FIXTURE" >/dev/null 2>&1; rc=$?
set -e
assert "No --symbol/--untested → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --- Fallback: engine disabled (symbol mode) ---
set +e
out="$(DRAFT_MEMORY_DISABLE=1 "$TOOL" --repo "$FIXTURE" --symbol foo)"
rc=$?
set -e
assert "Exit 2 when engine unavailable" "$([[ "$rc" == "2" ]] && echo true || echo false)"
if command -v jq >/dev/null 2>&1; then
    assert "Fallback (symbol) emits tests:[] source:unavailable" \
        "$(echo "$out" | jq -e '.tests == [] and .source == "unavailable"' >/dev/null 2>&1 && echo true || echo false)"

    set +e
    outu="$(DRAFT_MEMORY_DISABLE=1 "$TOOL" --repo "$FIXTURE" --untested)"; rc=$?
    set -e
    assert "Exit 2 (untested) when engine unavailable" "$([[ "$rc" == "2" ]] && echo true || echo false)"
    assert "Fallback (untested) emits untested:[] source:unavailable" \
        "$(echo "$outu" | jq -e '.untested == [] and .source == "unavailable"' >/dev/null 2>&1 && echo true || echo false)"

    # --- Happy path via mock engine ---
    MOCK="$(make_mock_memory_engine "$FIXTURE/mockbin")"
    out2="$(DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --repo "$FIXTURE" --symbol foo)"
    assert "Mock --symbol yields tests + status (source=memory-graph)" \
        "$(echo "$out2" | jq -e '.source == "memory-graph" and (.tests | type == "array") and (.status | type == "string")' >/dev/null 2>&1 && echo true || echo false)"

    out3="$(DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --repo "$FIXTURE" --untested)"
    assert "Mock --untested yields untested array (source=memory-graph)" \
        "$(echo "$out3" | jq -e '.source == "memory-graph" and (.untested | type == "array") and (.total | type == "number")' >/dev/null 2>&1 && echo true || echo false)"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
