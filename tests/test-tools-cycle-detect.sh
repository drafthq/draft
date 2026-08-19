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

    # --- Engine reachable, but the cycle query itself fails ---
    # The regression that matters: a query that never ran must not be reported as
    # "no cycles found". Engine 0.10.x returns a human-readable summary instead of
    # JSON, which is precisely this shape, and the old code turned it into a clean
    # bill of health.
    BROKEN="$FIXTURE/brokenbin/codebase-memory-mcp"
    mkdir -p "$FIXTURE/brokenbin"
    cat > "$BROKEN" <<'BROKENMOCK'
#!/usr/bin/env bash
if [[ "$1" == "--version" ]]; then echo "codebase-memory-mcp 0.0.0-mock"; exit 0; fi
[[ "$1" == "cli" ]] || { echo '{}'; exit 0; }
case "$2" in
  list_projects)    echo '{"projects":[]}' ;;
  index_repository) echo '{"project":"mock","status":"indexed"}' ;;
  query_graph)      echo "rows: 0  (cols: a b)" ;;   # not JSON — what 0.10.x emits
  *)                echo '{}' ;;
esac
exit 0
BROKENMOCK
    chmod +x "$BROKEN"

    set +e
    out3="$(DRAFT_MEMORY_BIN="$BROKEN" "$TOOL" --repo "$FIXTURE")"
    rc3=$?
    set -e
    assert "A failed cycle query exits 2, not 0" "$([[ "$rc3" == "2" ]] && echo true || echo false)"
    assert "A failed cycle query reports unavailable, never an empty clean result" \
        "$(echo "$out3" | jq -e '.source == "unavailable"' >/dev/null 2>&1 && echo true || echo false)"
    assert "A failed cycle query never claims source=memory-graph" \
        "$(echo "$out3" | jq -e '.source == "memory-graph"' >/dev/null 2>&1 && echo false || echo true)"
fi


echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
