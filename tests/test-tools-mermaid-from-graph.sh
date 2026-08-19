#!/usr/bin/env bash
# Test suite for scripts/tools/mermaid-from-graph.sh (codebase-memory-mcp engine)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/mermaid-from-graph.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== mermaid-from-graph.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# --- Fallback: engine disabled → empty stub, exit 2 ---
set +e
out="$(DRAFT_MEMORY_DISABLE=1 "$TOOL" --repo "$FIXTURE")"
rc=$?
set -e
assert "Fallback exit is 2" "$([[ "$rc" == "2" ]] && echo true || echo false)"
if echo "$out" | grep -q '```mermaid'; then
    assert "Fallback emits a mermaid fenced block" "true"
else
    assert "Fallback emits a mermaid fenced block" "false"
fi
if echo "$out" | grep -q 'graph data unavailable'; then
    assert "Fallback includes disclaimer comment" "true"
else
    assert "Fallback includes disclaimer comment" "false"
fi

# --- Happy path via mock engine ---
if command -v jq >/dev/null 2>&1; then
    MOCK="$(make_mock_memory_engine "$FIXTURE/mockbin")"
    md="$(DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --repo "$FIXTURE" --diagram module-deps)"
    if echo "$md" | grep -q 'flowchart LR' && echo "$md" | grep -q -- '-->'; then
        assert "module-deps renders a flowchart with edges" "true"
    else
        assert "module-deps renders a flowchart with edges" "false"
    fi
    pm="$(DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --repo "$FIXTURE" --diagram proto-map)"
    if echo "$pm" | grep -q '/health'; then
        assert "proto-map renders detected routes" "true"
    else
        assert "proto-map renders detected routes" "false"
    fi

    # --- Engine reachable, but the graph query itself fails ---
    # A failed query is not an empty graph. Engine 0.10.x returns a human-readable
    # summary instead of JSON, which is exactly this shape.
    BROKEN="$FIXTURE/brokenbin/codebase-memory-mcp"
    mkdir -p "$FIXTURE/brokenbin"
    cat > "$BROKEN" <<'BROKENMOCK'
#!/usr/bin/env bash
if [[ "$1" == "--version" ]]; then echo "codebase-memory-mcp 0.0.0-mock"; exit 0; fi
[[ "$1" == "cli" ]] || { echo '{}'; exit 0; }
case "$2" in
  list_projects)    echo '{"projects":[]}' ;;
  index_repository) echo '{"project":"mock","status":"indexed"}' ;;
  get_architecture) echo '{"hotspots":[{"name":"foo","qualified_name":"mock.foo","fan_in":5}],"routes":[]}' ;;
  query_graph)      echo "rows: 0  (cols: a b)" ;;   # not JSON
  *)                echo '{}' ;;
esac
exit 0
BROKENMOCK
    chmod +x "$BROKEN"

    set +e
    bad="$(DRAFT_MEMORY_BIN="$BROKEN" "$TOOL" --repo "$FIXTURE" --diagram module-deps 2>/dev/null)"
    set -e
    assert "A failed query says the graph is unavailable, not that it is empty" \
        "$(echo "$bad" | grep -q 'graph data unavailable' && echo true || echo false)"
    assert "A failed query is not reported as 'no edges'" \
        "$(echo "$bad" | grep -q 'no edges' && echo false || echo true)"

    # --- Query succeeds, graph genuinely holds no edges of this kind ---
    # This is the case the old code could not express: it swallowed a failed
    # query into an empty row set, so "your repo has no cross-file imports" and
    # "the engine is broken" both printed "graph not built".
    EMPTY="$FIXTURE/emptybin/codebase-memory-mcp"
    mkdir -p "$FIXTURE/emptybin"
    cat > "$EMPTY" <<'EMPTYMOCK'
#!/usr/bin/env bash
if [[ "$1" == "--version" ]]; then echo "codebase-memory-mcp 0.0.0-mock"; exit 0; fi
[[ "$1" == "cli" ]] || { echo '{}'; exit 0; }
case "$2" in
  list_projects)    echo '{"projects":[]}' ;;
  index_repository) echo '{"project":"mock","status":"indexed"}' ;;
  query_graph)      echo '{"columns":["a","b"],"rows":[],"total":0}' ;;   # valid, empty
  *)                echo '{}' ;;
esac
exit 0
EMPTYMOCK
    chmod +x "$EMPTY"

    set +e
    none="$(DRAFT_MEMORY_BIN="$EMPTY" "$TOOL" --repo "$FIXTURE" --diagram module-deps 2>/dev/null)"
    set -e
    assert "An empty-but-valid result says the graph has no such edges" \
        "$(echo "$none" | grep -q 'no edges' && echo true || echo false)"
    assert "An empty-but-valid result does not claim the graph was never built" \
        "$(echo "$none" | grep -q 'graph not built' && echo false || echo true)"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
