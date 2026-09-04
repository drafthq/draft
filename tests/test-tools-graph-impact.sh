#!/usr/bin/env bash
# Test suite for scripts/tools/graph-impact.sh (codebase-memory-mcp engine)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/graph-impact.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== graph-impact.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# --- Invocation error: neither --file nor --symbol ---
set +e
"$TOOL" --repo "$FIXTURE" >/dev/null 2>&1
rc=$?
set -e
assert "Missing --file/--symbol → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --- Fallback: engine disabled ---
set +e
out="$(DRAFT_MEMORY_DISABLE=1 "$TOOL" --repo "$FIXTURE" --symbol foo)"
rc=$?
set -e
assert "Exit 2 when engine unavailable" "$([[ "$rc" == "2" ]] && echo true || echo false)"
if command -v jq >/dev/null 2>&1; then
    assert "Fallback emits {impacted:[], source:unavailable}" \
        "$(echo "$out" | jq -e '.impacted == [] and .source == "unavailable"' >/dev/null 2>&1 && echo true || echo false)"

    EMPTY="$FIXTURE/emptybin/codebase-memory-mcp"
    mkdir -p "$FIXTURE/emptybin"
    cat > "$EMPTY" <<'EMPTYMOCK'
#!/usr/bin/env bash
if [[ "$1" == "--version" ]]; then echo "codebase-memory-mcp 0.0.0-mock"; exit 0; fi
[[ "$1" == "cli" ]] || { echo '{}'; exit 0; }
case "$2" in
  list_projects)    echo '{"projects":[]}' ;;
  index_repository) echo '{"project":"mock","status":"indexed"}' ;;
  trace_path)       echo '{}' ;;
  detect_changes)   echo '{}' ;;
  *) echo '{}' ;;
esac
exit 0
EMPTYMOCK
    chmod +x "$EMPTY"
    set +e
    empty_out="$(DRAFT_MEMORY_BIN="$EMPTY" "$TOOL" --repo "$FIXTURE" --symbol foo)"
    empty_rc=$?
    set -e
    assert "Shapeless {} from trace_path exits 2" "$([[ "$empty_rc" == "2" ]] && echo true || echo false)"
    assert "Shapeless {} from trace_path is unavailable, not empty impact" \
        "$(echo "$empty_out" | jq -e '.source == "unavailable"' >/dev/null 2>&1 && echo true || echo false)"

    MOCK="$(make_mock_memory_engine "$FIXTURE/mockbin")"
    # --- Symbol impact (trace_path callers) ---
    sout="$(DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --repo "$FIXTURE" --symbol foo)"
    assert "Symbol impact yields callers (kind=symbol)" \
        "$(echo "$sout" | jq -e '.kind == "symbol" and (.impacted | length >= 1)' >/dev/null 2>&1 && echo true || echo false)"

    # --- File impact (detect_changes filtered to the file) ---
    fout="$(DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --repo "$FIXTURE" --file a.sh)"
    assert "File impact yields impacted symbols (kind=file)" \
        "$(echo "$fout" | jq -e '.kind == "file" and (.impacted | length >= 1)' >/dev/null 2>&1 && echo true || echo false)"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
