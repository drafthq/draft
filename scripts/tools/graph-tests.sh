#!/usr/bin/env bash
# graph-tests.sh — test→symbol coverage from the knowledge graph (TESTS edges).
#
# graph-tooling-v2 Phase 3. Two modes:
#   --symbol NAME  tests that cover a symbol (who tests this?).
#   --untested     exported symbols with NO TESTS edge (what's untested?).
#
# The engine dialect has no anti-join (NOT EXISTS / NOT(pattern) are rejected), so
# --untested is computed as a set difference in jq: exported symbols minus the
# set of TESTS targets. Honest about partiality — TESTS coverage depends on the
# engine resolving test→symbol links, which varies by language/framework.
#
# Usage:
#   scripts/tools/graph-tests.sh --repo DIR --symbol NAME
#   scripts/tools/graph-tests.sh --repo DIR --untested
#
# Output (--symbol):   {symbol, tests:[{test,file}], status, source}
# Output (--untested): {untested:[{symbol,file}], total, truncated, source}
#
# Exit codes: 0 OK, 1 invocation error, 2 graph engine unavailable.
set -euo pipefail

# shellcheck source=_graph_queries.sh
source "$(dirname "${BASH_SOURCE[0]}")/_graph_queries.sh"

REPO="."
SYMBOL=""
UNTESTED=0

usage() {
    cat <<'EOF'
graph-tests.sh — test coverage edges from the knowledge graph.

Usage:
  scripts/tools/graph-tests.sh --repo DIR --symbol NAME
  scripts/tools/graph-tests.sh --repo DIR --untested

Flags:
  --repo DIR     Repository root (default: cwd).
  --symbol NAME  List tests covering this symbol.
  --untested     List exported symbols with no TESTS edge.
  --help         Show this help.

Output: --symbol → {symbol, tests, status, source}; --untested →
{untested, total, truncated, source}. Exit 2 when engine unavailable.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) REPO="$2"; shift 2;;
        --symbol) SYMBOL="$2"; shift 2;;
        --untested) UNTESTED=1; shift;;
        --help|-h) usage; exit 0;;
        *) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
    esac
done

[[ -d "$REPO" ]] || { echo "ERROR: --repo '$REPO' is not a directory" >&2; exit 1; }
[[ -n "$SYMBOL" || "$UNTESTED" -eq 1 ]] || { echo "ERROR: provide --symbol or --untested" >&2; usage >&2; exit 1; }

REPO_ABS="$(cd "$REPO" && pwd)"
SELF_REPO="$(cd "$(dirname "$0")/../.." && pwd)"

unavailable() {
    if [[ "$UNTESTED" -eq 1 ]]; then
        echo '{"untested":[],"total":0,"source":"unavailable"}'
    else
        jq -n --arg s "$SYMBOL" '{symbol:$s, tests:[], status:"unavailable", source:"unavailable"}' 2>/dev/null \
            || echo '{"tests":[],"status":"unavailable","source":"unavailable"}'
    fi
    exit 2
}

find_memory_bin "$REPO_ABS" "$SELF_REPO" || unavailable
command -v jq >/dev/null 2>&1 || unavailable

PROJECT="$(memory_ensure_index "$REPO_ABS" || true)"
[[ -n "$PROJECT" ]] || unavailable

if [[ "$UNTESTED" -eq 1 ]]; then
    EXP="$(gq_run "$PROJECT" "$(gq_q_exported)" || true)"
    [[ -n "$EXP" ]] || unavailable
    TST="$(gq_run "$PROJECT" "$(gq_q_tested_all)" || echo '{"rows":[]}')"
    echo "$TST" | jq -e . >/dev/null 2>&1 || TST='{"rows":[]}'
    # Pass results via temp files, not argv: the exported set can exceed the
    # ARG_MAX limit for --argjson on large repos.
    TMP_EXP="$(mktemp)"; TMP_TST="$(mktemp)"
    trap 'rm -f "$TMP_EXP" "$TMP_TST"' EXIT
    printf '%s' "$EXP" > "$TMP_EXP"
    printf '%s' "$TST" > "$TMP_TST"
    jq -n --slurpfile exp "$TMP_EXP" --slurpfile tst "$TMP_TST" '
        ($exp[0] // {}) as $e | ($tst[0] // {}) as $t
        | ((($t.rows) // []) | map(.[0])) as $tested
        | [ (($e.rows) // [])[]
            | select(((.[0]) as $q | $tested | index($q)) | not)
            | {symbol:.[0], file:.[1]} ] as $u
        | {untested: $u, total: ($u | length),
           truncated: (((($e.rows) // []) | length) >= 2000),
           source:"memory-graph"}'
    exit 0
fi

SYM_ESC="$(gq_escape "$SYMBOL")"
RES="$(gq_run "$PROJECT" "$(gq_q_tests "$SYM_ESC")" || true)"
[[ -n "$RES" ]] || unavailable
STATUS="$(gq_symbol_status "$PROJECT" "$SYM_ESC" "$RES")"

echo "$RES" | jq --arg s "$SYMBOL" --arg st "$STATUS" '
    {symbol:$s,
     tests: [ (.rows // [])[] | {test:.[0], file:.[1]} ],
     status:$st, source:"memory-graph"}'
