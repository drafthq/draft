#!/usr/bin/env bash
# Test suite for scripts/tools/graph-arch.sh (codebase-memory-mcp engine)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/graph-arch.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== graph-arch.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# --- Invocation error: unknown flag ---
set +e
"$TOOL" --bogus >/dev/null 2>&1
rc=$?
set -e
assert "Unknown flag → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --- Fallback: engine disabled ---
set +e
out="$(DRAFT_MEMORY_DISABLE=1 "$TOOL" --repo "$FIXTURE")"
rc=$?
set -e
assert "Exit 2 when engine unavailable" "$([[ "$rc" == "2" ]] && echo true || echo false)"
if command -v jq >/dev/null 2>&1; then
    assert "Fallback emits {source:unavailable}" \
        "$(echo "$out" | jq -e '.source == "unavailable"' >/dev/null 2>&1 && echo true || echo false)"

    # --- Happy path via mock engine ---
    MOCK="$(make_mock_memory_engine "$FIXTURE/mockbin")"
    set +e
    out2="$(DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --repo "$FIXTURE")"
    rc=$?
    set -e
    assert "Mock engine → exit 0" "$([[ "$rc" == "0" ]] && echo true || echo false)"
    assert "Emits a valid architecture object (total_nodes present)" \
        "$(echo "$out2" | jq -e '.total_nodes != null' >/dev/null 2>&1 && echo true || echo false)"
    assert "Architecture object carries routes/hotspots" \
        "$(echo "$out2" | jq -e '(.routes | length >= 1) and (.hotspots | length >= 1)' >/dev/null 2>&1 && echo true || echo false)"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
