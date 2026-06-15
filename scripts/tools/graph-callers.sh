#!/usr/bin/env bash
# graph-callers.sh — enumerate callers of a function, from the knowledge graph.
#
# Replaces `graph --query --symbol <name> --mode callers`. Backed by the
# codebase-memory-mcp engine. All Cypher lives in _graph_queries.sh (single
# source of query truth); this entrypoint only parses args and shapes JSON.
#
# Usage:
#   scripts/tools/graph-callers.sh --repo DIR --symbol NAME
#                                  [--transitive[=N]] [--prod-only] [--qualified]
#
# Output: JSON {symbol, callers:[{name,file[,hop]}], status, source}.
#   source = "memory-graph" | "unavailable"
#   status = "ok" | "no-edges" | "no-match" | "unavailable"
#            (fail-loud: distinguishes node-not-found from node-has-no-callers
#             from engine-unavailable — never a bare [] that reads as a true
#             negative).
#
# Exit codes: 0 OK, 1 invocation error, 2 graph engine unavailable.
set -euo pipefail

# shellcheck source=_graph_queries.sh
source "$(dirname "${BASH_SOURCE[0]}")/_graph_queries.sh"

REPO="."
SYMBOL=""
TRANSITIVE=0
DEPTH=3
PROD_ONLY=0
QUALIFIED=0

usage() {
    cat <<'EOF'
graph-callers.sh — callers of a function from the knowledge graph.

Usage:
  scripts/tools/graph-callers.sh --repo DIR --symbol NAME [options]

Flags:
  --repo DIR      Repository root (default: cwd).
  --symbol NAME   Function name to find callers of (required).
  --transitive[=N] Transitive (upstream) callers via the trace_path expander,
                  depth N (default 3). Adds a `hop` field per caller.
  --prod-only     Best-effort exclude test/mock callers (is_test=false AND not
                  under tests/). is_test is partial in the engine, so this is a
                  heuristic, not a guarantee. Ignored with --transitive.
  --qualified     Match SYMBOL against qualified_name instead of name (use to
                  disambiguate same-named nodes). Ignored with --transitive.
  --help          Show this help.

Output: JSON {symbol, callers, status, source}. Exit 2 when engine unavailable.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) REPO="$2"; shift 2;;
        --symbol) SYMBOL="$2"; shift 2;;
        --transitive) TRANSITIVE=1; shift;;
        --transitive=*) TRANSITIVE=1; DEPTH="${1#*=}"; shift;;
        --prod-only) PROD_ONLY=1; shift;;
        --qualified) QUALIFIED=1; shift;;
        --help|-h) usage; exit 0;;
        *) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
    esac
done

[[ -d "$REPO" ]] || { echo "ERROR: --repo '$REPO' is not a directory" >&2; exit 1; }
[[ -n "$SYMBOL" ]] || { echo "ERROR: --symbol is required" >&2; usage >&2; exit 1; }
[[ "$DEPTH" =~ ^[0-9]+$ ]] || { echo "ERROR: --transitive depth must be a non-negative integer" >&2; exit 1; }

REPO_ABS="$(cd "$REPO" && pwd)"
SELF_REPO="$(cd "$(dirname "$0")/../.." && pwd)"

unavailable() {
    jq -n --arg s "$SYMBOL" '{symbol:$s, callers:[], status:"unavailable", source:"unavailable"}' 2>/dev/null \
        || echo '{"callers":[],"status":"unavailable","source":"unavailable"}'
    exit 2
}

find_memory_bin "$REPO_ABS" "$SELF_REPO" || unavailable
command -v jq >/dev/null 2>&1 || unavailable

PROJECT="$(memory_ensure_index "$REPO_ABS" || true)"
[[ -n "$PROJECT" ]] || unavailable

SYM_ESC="$(gq_escape "$SYMBOL")"

if [[ "$TRANSITIVE" -eq 1 ]]; then
    # Transitive upstream callers via the trace_path depth-bounded expander.
    # direction:"both" is the reliable form; we read its .callers array.
    PAYLOAD="$(jq -n --arg p "$PROJECT" --arg f "$SYMBOL" --argjson d "$DEPTH" \
        '{project:$p, function_name:$f, depth:$d, direction:"both"}')"
    RES="$(memory_cli trace_path "$PAYLOAD" 2>/dev/null || true)"
    echo "$RES" | jq -e . >/dev/null 2>&1 || unavailable
    N="$(echo "$RES" | jq -r '(.callers // []) | length' 2>/dev/null || echo 0)"
    if [[ "$N" -gt 0 ]]; then STATUS="ok"; else
        EX="$(gq_run "$PROJECT" "$(gq_q_exists "$SYM_ESC")" || true)"
        if [[ -n "$EX" && "$(gq_rows_len "$EX")" -gt 0 ]]; then STATUS="no-edges"; else STATUS="no-match"; fi
    fi
    echo "$RES" | jq --arg s "$SYMBOL" --arg st "$STATUS" '
        {symbol:$s,
         callers: [ (.callers // [])[] | {name:.name, file:(.qualified_name // ""), hop:(.hop // 1)} ],
         status:$st, source:"memory-graph"}'
    exit 0
fi

# Direct (single-hop) callers. Pick the builder by mode.
if [[ "$QUALIFIED" -eq 1 ]]; then
    Q="$(gq_q_callers_qualified "$SYM_ESC")"
elif [[ "$PROD_ONLY" -eq 1 ]]; then
    Q="$(gq_q_callers_prod "$SYM_ESC")"
else
    Q="$(gq_q_callers "$SYM_ESC")"
fi

RES="$(gq_run "$PROJECT" "$Q" || true)"
[[ -n "$RES" ]] || unavailable

STATUS="$(gq_symbol_status "$PROJECT" "$SYM_ESC" "$RES")"

echo "$RES" | jq --arg s "$SYMBOL" --arg st "$STATUS" '
    {symbol:$s,
     callers: [ (.rows // [])[] | {name:.[0], file:.[1]} ],
     status:$st, source:"memory-graph"}'
