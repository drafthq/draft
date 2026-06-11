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
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
