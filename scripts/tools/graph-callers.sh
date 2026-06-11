#!/usr/bin/env bash
# graph-callers.sh — enumerate direct callers of a function, from the knowledge graph.
#
# Replaces `graph --query --symbol <name> --mode callers`. Backed by the
# codebase-memory-mcp engine via a single-hop CALLS openCypher pattern (the
# dialect handles fixed-length patterns reliably).
#
# Usage:
#   scripts/tools/graph-callers.sh --repo DIR --symbol NAME
#
# Output: JSON {symbol, callers:[{name,file}], source}.
#   source = "memory-graph" | "unavailable"
#
# Exit codes: 0 OK, 1 invocation error, 2 graph engine unavailable.
set -euo pipefail

# shellcheck source=_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

REPO="."
SYMBOL=""

usage() {
    cat <<'EOF'
graph-callers.sh — direct callers of a function.

Usage:
  scripts/tools/graph-callers.sh --repo DIR --symbol NAME

Flags:
  --repo DIR     Repository root (default: cwd).
  --symbol NAME  Function name to find callers of (required).
  --help         Show this help.

Output: JSON {symbol, callers, source}. Exit 2 when engine unavailable.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) REPO="$2"; shift 2;;
        --symbol) SYMBOL="$2"; shift 2;;
        --help|-h) usage; exit 0;;
        *) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
    esac
done

[[ -d "$REPO" ]] || { echo "ERROR: --repo '$REPO' is not a directory" >&2; exit 1; }
[[ -n "$SYMBOL" ]] || { echo "ERROR: --symbol is required" >&2; usage >&2; exit 1; }

REPO_ABS="$(cd "$REPO" && pwd)"
SELF_REPO="$(cd "$(dirname "$0")/../.." && pwd)"

unavailable() {
    jq -n --arg s "$SYMBOL" '{symbol:$s, callers:[], source:"unavailable"}' 2>/dev/null \
        || echo '{"callers":[],"source":"unavailable"}'
    exit 2
}

find_memory_bin "$REPO_ABS" "$SELF_REPO" || unavailable
command -v jq >/dev/null 2>&1 || unavailable

PROJECT="$(memory_ensure_index "$REPO_ABS" || true)"
[[ -n "$PROJECT" ]] || unavailable

# Escape single quotes in the symbol for the Cypher string literal.
SYM_ESC="${SYMBOL//\'/\\\'}"
Q="MATCH (c)-[:CALLS]->(f:Function {name:'$SYM_ESC'}) RETURN c.name AS caller, c.file_path AS file LIMIT 200"
RES="$(memory_cli query_graph "{\"project\":\"$PROJECT\",\"query\":\"$Q\"}" || echo '{}')"

echo "${RES:-{\}}" | jq --arg s "$SYMBOL" '
    {symbol:$s,
     callers: [ (.rows // [])[] | {name:.[0], file:.[1]} ],
     source:"memory-graph"}'
