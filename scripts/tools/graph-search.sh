#!/usr/bin/env bash
# graph-search.sh — semantic / ranked symbol search over the knowledge graph.
#
# Wraps the engine's search_graph (graph-tooling-v2 Phase 3): "find code about X"
# returns vector/text-ranked symbols, not a literal grep. Use when the user names
# an intent or concept rather than an exact symbol.
#
# Usage:
#   scripts/tools/graph-search.sh --repo DIR --query "order submission to broker" [--limit N]
#
# Output: JSON {query, results:[{name, qualified_name, label, file, start_line,
#               end_line, rank}], total, source}.
#
# Exit codes: 0 OK, 1 invocation error, 2 graph engine unavailable.
set -euo pipefail

# shellcheck source=_graph_queries.sh
source "$(dirname "${BASH_SOURCE[0]}")/_graph_queries.sh"

REPO="."
QUERY=""
LIMIT=10

usage() {
    cat <<'EOF'
graph-search.sh — semantic / ranked symbol search.

Usage:
  scripts/tools/graph-search.sh --repo DIR --query "STR" [--limit N]

Flags:
  --repo DIR   Repository root (default: cwd).
  --query STR  Natural-language or keyword query (required).
  --limit N    Max results (default: 10).
  --help       Show this help.

Output: JSON {query, results, total, source}. Exit 2 when engine unavailable.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) REPO="$2"; shift 2;;
        --query) QUERY="$2"; shift 2;;
        --limit) LIMIT="$2"; shift 2;;
        --help|-h) usage; exit 0;;
        *) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
    esac
done

[[ -d "$REPO" ]] || { echo "ERROR: --repo '$REPO' is not a directory" >&2; exit 1; }
[[ -n "$QUERY" ]] || { echo "ERROR: --query is required" >&2; usage >&2; exit 1; }
[[ "$LIMIT" =~ ^[0-9]+$ ]] || { echo "ERROR: --limit must be a non-negative integer" >&2; exit 1; }

REPO_ABS="$(cd "$REPO" && pwd)"
SELF_REPO="$(cd "$(dirname "$0")/../.." && pwd)"

unavailable() {
    jq -n --arg q "$QUERY" '{query:$q, results:[], source:"unavailable"}' 2>/dev/null \
        || echo '{"results":[],"source":"unavailable"}'
    exit 2
}

find_memory_bin "$REPO_ABS" "$SELF_REPO" || unavailable
command -v jq >/dev/null 2>&1 || unavailable

PROJECT="$(memory_ensure_index "$REPO_ABS" || true)"
[[ -n "$PROJECT" ]] || unavailable

ARGS="$(jq -n --arg p "$PROJECT" --arg q "$QUERY" --argjson n "$LIMIT" \
    '{project:$p, query:$q, limit:$n}')"
RES="$(memory_cli search_graph "$ARGS" 2>/dev/null || true)"
[[ -n "$RES" ]] || unavailable
echo "$RES" | jq -e . >/dev/null 2>&1 || unavailable

echo "$RES" | jq --arg q "$QUERY" '
    {query:$q,
     results: [ (.results // .matches // [])[]
                | {name:(.name // ""), qualified_name:(.qualified_name // ""),
                   label:(.label // ""), file:(.file_path // .file // ""),
                   start_line:(.start_line // null), end_line:(.end_line // null),
                   rank:(.rank // .score // null)} ],
     total: ((.results // .matches // []) | length),
     source:"memory-graph"}'
