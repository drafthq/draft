#!/usr/bin/env bash
# Test suite for scripts/tools/graph-deps.sh (IMPORTS module graph)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/graph-deps.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== graph-deps.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# --- Invocation error: unknown flag ---
set +e
"$TOOL" --bogus >/dev/null 2>&1; rc=$?
set -e
assert "Unknown flag → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --- Fallback: engine disabled ---
set +e
out="$(DRAFT_MEMORY_DISABLE=1 "$TOOL" --repo "$FIXTURE")"
rc=$?
set -e
assert "Exit 2 when engine unavailable" "$([[ "$rc" == "2" ]] && echo true || echo false)"
if command -v jq >/dev/null 2>&1; then
    assert "Fallback emits imports:[] source:unavailable" \
        "$(echo "$out" | jq -e '.imports == [] and .source == "unavailable"' >/dev/null 2>&1 && echo true || echo false)"

    # --- Happy path via mock engine (mock.a -> mock.b, distinct → kept) ---
    MOCK="$(make_mock_memory_engine "$FIXTURE/mockbin")"
    out2="$(DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --repo "$FIXTURE")"
    assert "Mock yields import edges (source=memory-graph)" \
        "$(echo "$out2" | jq -e '.source == "memory-graph" and (.imports | length >= 1) and (.imports[0].src != .imports[0].dst)' >/dev/null 2>&1 && echo true || echo false)"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
