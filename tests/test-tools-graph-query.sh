#!/usr/bin/env bash
# Test suite for scripts/tools/graph-query.sh (generic read-only passthrough)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/graph-query.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== graph-query.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# --- Invocation error: neither --cypher nor --tool ---
set +e
"$TOOL" --repo "$FIXTURE" >/dev/null 2>&1; rc=$?
set -e
assert "No mode → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --- Write verb rejected (before engine) ---
set +e
"$TOOL" --repo "$FIXTURE" --cypher 'CREATE (n) RETURN n' >/dev/null 2>&1; rc=$?
set -e
assert "Write verb (CREATE) → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

set +e
"$TOOL" --repo "$FIXTURE" --cypher 'MATCH (n) DETACH DELETE n' >/dev/null 2>&1; rc=$?
set -e
assert "Write verb (DELETE) → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --- Non-allowlisted tool rejected ---
set +e
"$TOOL" --repo "$FIXTURE" --tool delete_project --json '{}' >/dev/null 2>&1; rc=$?
set -e
assert "Destructive tool (delete_project) → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --- Fallback: engine disabled ---
set +e
out="$(DRAFT_MEMORY_DISABLE=1 "$TOOL" --repo "$FIXTURE" --cypher 'MATCH (n) RETURN n LIMIT 1')"
rc=$?
set -e
assert "Exit 2 when engine unavailable" "$([[ "$rc" == "2" ]] && echo true || echo false)"
if command -v jq >/dev/null 2>&1; then
    assert "Fallback emits source:unavailable" \
        "$(echo "$out" | jq -e '.source == "unavailable"' >/dev/null 2>&1 && echo true || echo false)"

    # --- Happy path via mock engine ---
    MOCK="$(make_mock_memory_engine "$FIXTURE/mockbin")"
    out2="$(DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --repo "$FIXTURE" --cypher 'MATCH (n) RETURN n LIMIT 1')"
    assert "Mock cypher returns rows" \
        "$(echo "$out2" | jq -e '(.rows | length) >= 1' >/dev/null 2>&1 && echo true || echo false)"

    out3="$(DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --repo "$FIXTURE" --tool get_graph_schema --json '{}')"
    assert "Mock tool passthrough returns engine JSON" \
        "$(echo "$out3" | jq -e '(.node_labels | length) >= 1' >/dev/null 2>&1 && echo true || echo false)"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
