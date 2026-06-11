#!/usr/bin/env bash
# graph-impact.sh — blast radius for a file or symbol, from the knowledge graph.
#
# Replaces `graph --query --file <path> --mode impact`. Backed by the
# codebase-memory-mcp engine: combines detect_changes (git-diff → impacted
# symbols, when querying the working tree) with trace_path callers for a named
# function (transitive upstream dependents).
#
# Usage:
#   scripts/tools/graph-impact.sh --repo DIR (--file PATH | --symbol NAME) [--depth N]
#
# Output: JSON {target, kind, impacted:[{name,file,hop}], source}.
#   source = "memory-graph" | "unavailable"
#
# Exit codes: 0 OK, 1 invocation error, 2 graph engine unavailable.
set -euo pipefail

# shellcheck source=_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

REPO="."
FILE=""
SYMBOL=""
DEPTH=3

usage() {
    cat <<'EOF'
graph-impact.sh — blast radius for a file or symbol.

Usage:
  scripts/tools/graph-impact.sh --repo DIR (--file PATH | --symbol NAME) [--depth N]

Flags:
  --repo DIR     Repository root (default: cwd).
  --file PATH    Size impact of a changed file (uses git working-tree diff).
  --symbol NAME  Transitive callers of a function (default depth 3).
  --depth N      Caller traversal depth for --symbol (default: 3).
  --help         Show this help.

Output: JSON {target, kind, impacted, source}. Exit 2 when engine unavailable.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) REPO="$2"; shift 2;;
        --file) FILE="$2"; shift 2;;
        --symbol) SYMBOL="$2"; shift 2;;
        --depth) DEPTH="$2"; shift 2;;
        --help|-h) usage; exit 0;;
        *) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
    esac
done

[[ -d "$REPO" ]] || { echo "ERROR: --repo '$REPO' is not a directory" >&2; exit 1; }
[[ -n "$FILE" || -n "$SYMBOL" ]] || { echo "ERROR: provide --file or --symbol" >&2; usage >&2; exit 1; }

REPO_ABS="$(cd "$REPO" && pwd)"
SELF_REPO="$(cd "$(dirname "$0")/../.." && pwd)"

unavailable() {
    local t="$1" k="$2"
    jq -n --arg t "$t" --arg k "$k" '{target:$t, kind:$k, impacted:[], source:"unavailable"}' 2>/dev/null \
        || echo '{"impacted":[],"source":"unavailable"}'
    exit 2
}

if [[ -n "$SYMBOL" ]]; then TARGET="$SYMBOL"; KIND="symbol"; else TARGET="$FILE"; KIND="file"; fi

find_memory_bin "$REPO_ABS" "$SELF_REPO" || unavailable "$TARGET" "$KIND"
command -v jq >/dev/null 2>&1 || unavailable "$TARGET" "$KIND"

PROJECT="$(memory_ensure_index "$REPO_ABS" || true)"
[[ -n "$PROJECT" ]] || unavailable "$TARGET" "$KIND"

if [[ -n "$SYMBOL" ]]; then
    # direction:"both" is the reliable form (the "callers" value returns empty in this engine);
    # we read the .callers array from it.
    RES="$(memory_cli trace_path "{\"project\":\"$PROJECT\",\"function_name\":\"$SYMBOL\",\"depth\":$DEPTH,\"direction\":\"both\"}" || echo '{}')"
    echo "${RES:-{\}}" | jq --arg t "$TARGET" '
        {target:$t, kind:"symbol",
         impacted: [ (.callers // [])[] | {name:.name, file:(.qualified_name // ""), hop:(.hop // 1)} ],
         source:"memory-graph"}'
else
    # File impact: detect_changes maps the working-tree diff to impacted symbols.
    RES="$(memory_cli detect_changes "{\"project\":\"$PROJECT\"}" || echo '{}')"
    echo "${RES:-{\}}" | jq --arg t "$TARGET" '
        {target:$t, kind:"file",
         impacted: [ (.impacted_symbols // [])[]
                     | select((.file // "") | endswith($t) or (. == $t))
                     | {name:.name, file:(.file // ""), hop:1} ],
         source:"memory-graph"}'
fi
