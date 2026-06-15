#!/usr/bin/env bash
# Test suite for scripts/tools/graph-snippet.sh (get_code_snippet wrapper)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/graph-snippet.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== graph-snippet.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# --- Invocation error: missing --qualified ---
set +e
"$TOOL" --repo "$FIXTURE" >/dev/null 2>&1; rc=$?
set -e
assert "Missing --qualified → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --- Fallback: engine disabled ---
set +e
out="$(DRAFT_MEMORY_DISABLE=1 "$TOOL" --repo "$FIXTURE" --qualified pkg.foo)"
rc=$?
set -e
assert "Exit 2 when engine unavailable" "$([[ "$rc" == "2" ]] && echo true || echo false)"
if command -v jq >/dev/null 2>&1; then
    assert "Fallback emits source:unavailable" \
        "$(echo "$out" | jq -e '.source == "unavailable" and .status == "unavailable"' >/dev/null 2>&1 && echo true || echo false)"

    # --- Happy path via mock engine ---
    MOCK="$(make_mock_memory_engine "$FIXTURE/mockbin")"
    out2="$(DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --repo "$FIXTURE" --qualified mock.foo)"
    assert "Mock yields status ok with code + counts" \
        "$(echo "$out2" | jq -e '.status == "ok" and (.code | length >= 1) and .callers == 2 and .source == "memory-graph"' >/dev/null 2>&1 && echo true || echo false)"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
