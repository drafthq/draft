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

# --- Happy path via mock engine (engine-only: schema.yaml gate marker, no graph data) ---
if command -v jq >/dev/null 2>&1; then
    MOCK="$(make_mock_memory_engine "$FIXTURE/mockbin")"
    # Seed a stale fat-snapshot to prove re-index prunes it.
    mkdir -p "$FIXTURE/graph/okf"
    : > "$FIXTURE/graph/architecture.json"
    : > "$FIXTURE/graph/hotspots.jsonl"
    : > "$FIXTURE/graph/module-deps.mermaid"
    : > "$FIXTURE/graph/proto-map.mermaid"
    : > "$FIXTURE/graph/okf/index.md"
    set +e
    DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --repo "$FIXTURE" --out "$FIXTURE/graph" >/dev/null 2>&1
    rc=$?
    set -e
    assert "Index → exit 0" "$([[ "$rc" == "0" ]] && echo true || echo false)"
    assert "schema.yaml written" "$([[ -f "$FIXTURE/graph/schema.yaml" ]] && echo true || echo false)"
    assert "schema.yaml names the engine" \
        "$(grep -q 'engine: codebase-memory-mcp' "$FIXTURE/graph/schema.yaml" && echo true || echo false)"
    assert "schema.yaml is engine-live (carries no graph data)" \
        "$(grep -q 'access: engine-live' "$FIXTURE/graph/schema.yaml" && echo true || echo false)"
    assert "schema.yaml records index provenance counts" \
        "$(grep -q 'indexed_nodes:' "$FIXTURE/graph/schema.yaml" && echo true || echo false)"
    # Engine-only: NO committed graph data is written, and stale fat-snapshot artifacts are pruned.
    assert "no architecture.json" "$([[ ! -f "$FIXTURE/graph/architecture.json" ]] && echo true || echo false)"
    assert "no hotspots.jsonl" "$([[ ! -f "$FIXTURE/graph/hotspots.jsonl" ]] && echo true || echo false)"
    assert "no *.mermaid" "$([[ ! -f "$FIXTURE/graph/module-deps.mermaid" && ! -f "$FIXTURE/graph/proto-map.mermaid" ]] && echo true || echo false)"
    assert "no okf/ bundle" "$([[ ! -d "$FIXTURE/graph/okf" ]] && echo true || echo false)"
    assert "draft/graph holds only schema.yaml" \
        "$([[ "$(find "$FIXTURE/graph" -type f | wc -l | tr -d ' ')" == "1" ]] && echo true || echo false)"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
