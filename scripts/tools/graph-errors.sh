#!/usr/bin/env bash
# graph-errors.sh — error-propagation paths from the knowledge graph (RAISES/THROWS).
#
# graph-tooling-v2 Phase 3. Two modes:
#   --symbol NAME  what error types NAME raises/throws.
#   --type NAME    who raises/throws error type NAME (fail-closed audits: confirm
#                  every site that can emit a given error).
#
# Usage:
#   scripts/tools/graph-errors.sh --repo DIR (--symbol NAME | --type NAME)
#
# Output (--symbol): {symbol, raises:[{error,qualified}], status, source}
# Output (--type):   {type, raisers:[{symbol,file}], status, source}
#
# Exit codes: 0 OK, 1 invocation error, 2 graph engine unavailable.
set -euo pipefail

# shellcheck source=_graph_queries.sh
source "$(dirname "${BASH_SOURCE[0]}")/_graph_queries.sh"

REPO="."
SYMBOL=""
TYPE=""

usage() {
    cat <<'EOF'
graph-errors.sh — error propagation (RAISES/THROWS edges).

Usage:
  scripts/tools/graph-errors.sh --repo DIR (--symbol NAME | --type NAME)

Flags:
  --repo DIR     Repository root (default: cwd).
  --symbol NAME  Error types raised/thrown by NAME.
  --type NAME    Symbols that raise/throw error type NAME.
  --help         Show this help.

Output: --symbol → {symbol, raises, status, source}; --type → {type, raisers,
status, source}. Exit 2 when engine unavailable.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) REPO="$2"; shift 2;;
        --symbol) SYMBOL="$2"; shift 2;;
        --type) TYPE="$2"; shift 2;;
        --help|-h) usage; exit 0;;
        *) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
    esac
done

[[ -d "$REPO" ]] || { echo "ERROR: --repo '$REPO' is not a directory" >&2; exit 1; }
if [[ -n "$SYMBOL" && -n "$TYPE" ]]; then
    echo "ERROR: use either --symbol or --type, not both" >&2; exit 1
fi
[[ -n "$SYMBOL" || -n "$TYPE" ]] || { echo "ERROR: provide --symbol or --type" >&2; usage >&2; exit 1; }

REPO_ABS="$(cd "$REPO" && pwd)"
SELF_REPO="$(cd "$(dirname "$0")/../.." && pwd)"

unavailable() {
    if [[ -n "$TYPE" ]]; then
        jq -n --arg t "$TYPE" '{type:$t, raisers:[], status:"unavailable", source:"unavailable"}' 2>/dev/null \
            || echo '{"raisers":[],"status":"unavailable","source":"unavailable"}'
    else
        jq -n --arg s "$SYMBOL" '{symbol:$s, raises:[], status:"unavailable", source:"unavailable"}' 2>/dev/null \
            || echo '{"raises":[],"status":"unavailable","source":"unavailable"}'
    fi
    exit 2
}

find_memory_bin "$REPO_ABS" "$SELF_REPO" || unavailable
command -v jq >/dev/null 2>&1 || unavailable

PROJECT="$(memory_ensure_index "$REPO_ABS" || true)"
[[ -n "$PROJECT" ]] || unavailable

if [[ -n "$TYPE" ]]; then
    SYM_ESC="$(gq_escape "$TYPE")"
    RES="$(gq_run "$PROJECT" "$(gq_q_raisers "$SYM_ESC")" || true)"
    [[ -n "$RES" ]] || unavailable
    STATUS="$(gq_symbol_status "$PROJECT" "$SYM_ESC" "$RES")"
    echo "$RES" | jq --arg t "$TYPE" --arg st "$STATUS" '
        {type:$t,
         raisers: [ (.rows // [])[] | {symbol:.[0], file:.[1]} ],
         status:$st, source:"memory-graph"}'
else
    SYM_ESC="$(gq_escape "$SYMBOL")"
    RES="$(gq_run "$PROJECT" "$(gq_q_raises "$SYM_ESC")" || true)"
    [[ -n "$RES" ]] || unavailable
    STATUS="$(gq_symbol_status "$PROJECT" "$SYM_ESC" "$RES")"
    echo "$RES" | jq --arg s "$SYMBOL" --arg st "$STATUS" '
        {symbol:$s,
         raises: [ (.rows // [])[] | {error:.[0], qualified:.[1]} ],
         status:$st, source:"memory-graph"}'
fi
