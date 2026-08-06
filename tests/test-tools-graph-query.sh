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

# --- Read query whose string literal merely contains a write-verb word is NOT rejected ---
# The guard rejection happens before the engine is ever contacted, so these
# only need to clear the write-verb check — they run against a fixture repo
# with no graph engine present and are expected to hit "unavailable" (exit 2),
# never the write-verb rejection (exit 1).
# Cypher quotes strings with ' or " and identifiers with `; the engine accepts
# all three, so all three must clear the guard.
for word in set create delete merge remove drop detach; do
    set +e
    out="$("$TOOL" --repo "$FIXTURE" --cypher "MATCH (f {name:'$word'}) RETURN f.qualified_name AS q LIMIT 5" 2>&1)"
    rc=$?
    set -e
    assert "Single-quoted literal containing '$word' → not a write-verb rejection" \
        "$([[ "$rc" != "1" ]] && echo true || echo false)"

    set +e
    out="$("$TOOL" --repo "$FIXTURE" --cypher "MATCH (f {name:\"$word\"}) RETURN f.qualified_name AS q LIMIT 5" 2>&1)"
    rc=$?
    set -e
    assert "Double-quoted literal containing '$word' → not a write-verb rejection" \
        "$([[ "$rc" != "1" ]] && echo true || echo false)"

    set +e
    out="$("$TOOL" --repo "$FIXTURE" --cypher "MATCH (f {name:\`$word\`}) RETURN f.qualified_name AS q LIMIT 5" 2>&1)"
    rc=$?
    set -e
    assert "Backtick-quoted identifier containing '$word' → not a write-verb rejection" \
        "$([[ "$rc" != "1" ]] && echo true || echo false)"
done

# --- Escaped quote inside a string literal must not be read as closing it early ---
set +e
out="$("$TOOL" --repo "$FIXTURE" --cypher "MATCH (f {name:'o\\'brien CREATE'}) RETURN f.qualified_name AS q LIMIT 5" 2>&1)"
rc=$?
set -e
assert "Escaped quote in literal containing 'CREATE' → not a write-verb rejection" \
    "$([[ "$rc" != "1" ]] && echo true || echo false)"

# --- An unterminated span of ANY quote kind fails closed, never falls open ---
set +e
"$TOOL" --repo "$FIXTURE" --cypher "MATCH (f {name:'unterminated) RETURN f LIMIT 5" >/dev/null 2>&1; rc=$?
set -e
assert "Unterminated single-quoted literal → exit 1 (fail closed)" "$([[ "$rc" == "1" ]] && echo true || echo false)"

set +e
"$TOOL" --repo "$FIXTURE" --cypher 'MATCH (f {name:"unterminated) RETURN f LIMIT 5' >/dev/null 2>&1; rc=$?
set -e
assert "Unterminated double-quoted literal → exit 1 (fail closed)" "$([[ "$rc" == "1" ]] && echo true || echo false)"

set +e
"$TOOL" --repo "$FIXTURE" --cypher 'MATCH (f {name:`unterminated) RETURN f LIMIT 5' >/dev/null 2>&1; rc=$?
set -e
assert "Unterminated backtick identifier → exit 1 (fail closed)" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --- A write verb hiding after a closed span of any quote kind is still caught ---
set +e
"$TOOL" --repo "$FIXTURE" --cypher 'MATCH (f {name:"o\"brien"}) CREATE (x) RETURN f' >/dev/null 2>&1; rc=$?
set -e
assert "Write verb after a double-quoted span → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

set +e
"$TOOL" --repo "$FIXTURE" --cypher 'MATCH (f:`Weird Label`) DETACH DELETE f' >/dev/null 2>&1; rc=$?
set -e
assert "Write verb after a backtick-quoted span → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

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
