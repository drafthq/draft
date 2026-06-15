#!/usr/bin/env bash
# graph-hierarchy.sh — class inheritance from the knowledge graph (INHERITS edges).
#
# graph-tooling-v2 Phase 3. Answers base/derived relationships and the impact of a
# base-class change.
#   (default)        all INHERITS edges (child → parent).
#   --symbol NAME    bases of class NAME (what NAME inherits from).
#   --derived NAME   subclasses of class NAME (who inherits from NAME — the blast
#                    radius of changing NAME).
#
# Usage:
#   scripts/tools/graph-hierarchy.sh --repo DIR [--symbol NAME | --derived NAME]
#
# Output: JSON {edges:[{child,parent}], status, source}.
#
# Exit codes: 0 OK, 1 invocation error, 2 graph engine unavailable.
set -euo pipefail

# shellcheck source=_graph_queries.sh
source "$(dirname "${BASH_SOURCE[0]}")/_graph_queries.sh"

REPO="."
SYMBOL=""
DERIVED=""

usage() {
    cat <<'EOF'
graph-hierarchy.sh — class inheritance (INHERITS edges).

Usage:
  scripts/tools/graph-hierarchy.sh --repo DIR [--symbol NAME | --derived NAME]

Flags:
  --repo DIR      Repository root (default: cwd).
  --symbol NAME   Bases of class NAME (what it inherits from).
  --derived NAME  Subclasses of class NAME (impact of changing NAME).
  --help          Show this help.

Output: JSON {edges:[{child,parent}], status, source}. With no class filter,
emits the full hierarchy. Exit 2 when engine unavailable.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) REPO="$2"; shift 2;;
        --symbol) SYMBOL="$2"; shift 2;;
        --derived) DERIVED="$2"; shift 2;;
        --help|-h) usage; exit 0;;
        *) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
    esac
done

[[ -d "$REPO" ]] || { echo "ERROR: --repo '$REPO' is not a directory" >&2; exit 1; }
if [[ -n "$SYMBOL" && -n "$DERIVED" ]]; then
    echo "ERROR: use either --symbol or --derived, not both" >&2; exit 1
fi

REPO_ABS="$(cd "$REPO" && pwd)"
SELF_REPO="$(cd "$(dirname "$0")/../.." && pwd)"

unavailable() { echo '{"edges":[],"status":"unavailable","source":"unavailable"}'; exit 2; }

find_memory_bin "$REPO_ABS" "$SELF_REPO" || unavailable
command -v jq >/dev/null 2>&1 || unavailable

PROJECT="$(memory_ensure_index "$REPO_ABS" || true)"
[[ -n "$PROJECT" ]] || unavailable

if [[ -n "$SYMBOL" ]]; then
    SYM_ESC="$(gq_escape "$SYMBOL")"; Q="$(gq_q_inherits_sym "$SYM_ESC")"; PROBE="$SYM_ESC"
elif [[ -n "$DERIVED" ]]; then
    SYM_ESC="$(gq_escape "$DERIVED")"; Q="$(gq_q_derived_sym "$SYM_ESC")"; PROBE="$SYM_ESC"
else
    Q="$(gq_q_inherits)"; PROBE=""
fi

RES="$(gq_run "$PROJECT" "$Q" || true)"
[[ -n "$RES" ]] || unavailable

if [[ -n "$PROBE" ]]; then
    STATUS="$(gq_symbol_status "$PROJECT" "$PROBE" "$RES")"
else
    STATUS="ok"
fi

echo "$RES" | jq --arg st "$STATUS" '
    {edges: [ (.rows // [])[] | {child:.[0], parent:.[1]} ],
     status:$st, source:"memory-graph"}'
