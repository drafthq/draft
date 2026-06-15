#!/usr/bin/env bash
# Test suite for scripts/tools/graph-risk.sh (pre-computed risk node props)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/graph-risk.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== graph-risk.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# --- Invocation error: non-numeric --min-complexity ---
set +e
"$TOOL" --repo "$FIXTURE" --min-complexity x >/dev/null 2>&1; rc=$?
set -e
assert "Non-numeric --min-complexity → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --- Fallback: engine disabled ---
set +e
out="$(DRAFT_MEMORY_DISABLE=1 "$TOOL" --repo "$FIXTURE")"
rc=$?
set -e
assert "Exit 2 when engine unavailable" "$([[ "$rc" == "2" ]] && echo true || echo false)"
if command -v jq >/dev/null 2>&1; then
    assert "Fallback emits risky:[] source:unavailable" \
        "$(echo "$out" | jq -e '.risky == [] and .source == "unavailable"' >/dev/null 2>&1 && echo true || echo false)"

    # --- Happy path via mock engine ---
    MOCK="$(make_mock_memory_engine "$FIXTURE/mockbin")"
    out2="$(DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --repo "$FIXTURE")"
    assert "Mock yields risky array with flags + total (source=memory-graph)" \
        "$(echo "$out2" | jq -e '.source == "memory-graph" and (.risky | type == "array") and (.total | type == "number") and (.risky[0] | has("flags"))' >/dev/null 2>&1 && echo true || echo false)"

    # --- --min-complexity filter accepts a numeric threshold ---
    out3="$(DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --repo "$FIXTURE" --min-complexity 999)"
    assert "High --min-complexity filters everything out" \
        "$(echo "$out3" | jq -e '.total == 0' >/dev/null 2>&1 && echo true || echo false)"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
