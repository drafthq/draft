#!/usr/bin/env bash
# Test suite for scripts/tools/graph-search.sh (search_graph wrapper)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/graph-search.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== graph-search.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# --- Invocation error: missing --query ---
set +e
"$TOOL" --repo "$FIXTURE" >/dev/null 2>&1; rc=$?
set -e
assert "Missing --query → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --- Invocation error: non-numeric --limit ---
set +e
"$TOOL" --repo "$FIXTURE" --query x --limit abc >/dev/null 2>&1; rc=$?
set -e
assert "Non-numeric --limit → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --- Fallback: engine disabled ---
set +e
out="$(DRAFT_MEMORY_DISABLE=1 "$TOOL" --repo "$FIXTURE" --query 'auth flow')"
rc=$?
set -e
assert "Exit 2 when engine unavailable" "$([[ "$rc" == "2" ]] && echo true || echo false)"
if command -v jq >/dev/null 2>&1; then
    assert "Fallback emits results:[] source:unavailable" \
        "$(echo "$out" | jq -e '.results == [] and .source == "unavailable"' >/dev/null 2>&1 && echo true || echo false)"

    # --- Happy path via mock engine ---
    MOCK="$(make_mock_memory_engine "$FIXTURE/mockbin")"
    out2="$(DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --repo "$FIXTURE" --query 'auth flow' --limit 3)"
    assert "Mock yields ranked results (source=memory-graph)" \
        "$(echo "$out2" | jq -e '.source == "memory-graph" and (.results | length >= 1) and (.results[0].qualified_name == "mock.foo")' >/dev/null 2>&1 && echo true || echo false)"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
