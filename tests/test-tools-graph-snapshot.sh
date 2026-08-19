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

    # An ALREADY-INDEXED repo must still be re-indexed. memory_ensure_index only
    # calls index_repository when the project is absent, so this tool used to write
    # a gate marker with a fresh generated_at over a frozen index — deleted symbols
    # stayed resolvable and new ones never appeared, silently.
    REIDX_DIR="$(mktemp -d)"
    CALLS="$REIDX_DIR/calls.log"
    REIDX_MOCK="$REIDX_DIR/codebase-memory-mcp"
    cat > "$REIDX_MOCK" <<'MOCK'
#!/usr/bin/env bash
# Mock whose list_projects already knows this repo, so the "absent" branch of
# memory_ensure_index cannot fire. Records every cli tool it is asked for.
if [[ "$1" == "--version" ]]; then echo "codebase-memory-mcp 0.0.0-mock"; exit 0; fi
[[ "$1" == "cli" ]] || { echo '{}'; exit 0; }
echo "$2" >> "$CALLS_LOG"
case "$2" in
  list_projects)    printf '{"projects":[{"name":"already","root_path":"%s"}]}\n' "$REPO_UNDER_TEST" ;;
  index_repository) echo '{"project":"already","status":"indexed","nodes":9,"edges":9}' ;;
  index_status)     echo '{"project":"already","nodes":9,"edges":9,"status":"ready"}' ;;
  detect_changes)   echo '{"changed_files":["a.sh"],"changed_count":1,"impacted_symbols":[]}' ;;
  *) echo '{}' ;;
esac
exit 0
MOCK
    chmod +x "$REIDX_MOCK"
    REIDX_REPO="$REIDX_DIR/repo"
    mkdir -p "$REIDX_REPO"
    set +e
    CALLS_LOG="$CALLS" REPO_UNDER_TEST="$REIDX_REPO" DRAFT_MEMORY_BIN="$REIDX_MOCK" \
        "$TOOL" --repo "$REIDX_REPO" --out "$REIDX_REPO/graph" >/dev/null 2>&1
    reidx_rc=$?
    set -e
    assert "already-indexed repo → exit 0" \
        "$([[ "$reidx_rc" == "0" ]] && echo true || echo false)"
    assert "already-indexed repo is re-indexed (index_repository invoked)" \
        "$(grep -qx 'index_repository' "$CALLS" && echo true || echo false)"
    rm -rf "$REIDX_DIR"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
