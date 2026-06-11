#!/usr/bin/env bash
# Test suite for scripts/tools/graph-snapshot.sh (codebase-memory-mcp engine)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/graph-snapshot.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== graph-snapshot.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# --- Fallback: engine disabled → exit 2, no snapshot ---
set +e
DRAFT_MEMORY_DISABLE=1 "$TOOL" --repo "$FIXTURE" --out "$FIXTURE/graph" >/dev/null 2>&1
rc=$?
set -e
assert "Exit 2 when engine unavailable" "$([[ "$rc" == "2" ]] && echo true || echo false)"
assert "No snapshot dir written on fallback" "$([[ ! -f "$FIXTURE/graph/schema.yaml" ]] && echo true || echo false)"

# --- Happy path via mock engine ---
if command -v jq >/dev/null 2>&1; then
    MOCK="$(make_mock_memory_engine "$FIXTURE/mockbin")"
    set +e
    DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --repo "$FIXTURE" --out "$FIXTURE/graph" >/dev/null 2>&1
    rc=$?
    set -e
    assert "Snapshot build → exit 0" "$([[ "$rc" == "0" ]] && echo true || echo false)"
    assert "schema.yaml written" "$([[ -f "$FIXTURE/graph/schema.yaml" ]] && echo true || echo false)"
    assert "architecture.json written" "$([[ -f "$FIXTURE/graph/architecture.json" ]] && echo true || echo false)"
    assert "hotspots.jsonl written" "$([[ -f "$FIXTURE/graph/hotspots.jsonl" ]] && echo true || echo false)"
    assert "schema.yaml names the engine" \
        "$(grep -q 'engine: codebase-memory-mcp' "$FIXTURE/graph/schema.yaml" && echo true || echo false)"
    assert "hotspots.jsonl is one JSON object per line" \
        "$(head -1 "$FIXTURE/graph/hotspots.jsonl" | jq -e '.id and .fanIn' >/dev/null 2>&1 && echo true || echo false)"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
