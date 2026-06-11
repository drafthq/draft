#!/usr/bin/env bash
# mermaid-from-graph.sh — emit Mermaid diagrams from the knowledge graph.
#
# Backed by the codebase-memory-mcp engine. Two diagrams:
#   module-deps : file co-change coupling (FILE_CHANGES_WITH edges) as a flowchart.
#   proto-map   : detected service routes (Route nodes) as a flowchart.
#
# When the engine is unavailable, emits an empty diagram stub and exits 2 so
# consuming skills can degrade gracefully.
#
# Usage:
#   scripts/tools/mermaid-from-graph.sh [--repo DIR] [--diagram module-deps|proto-map]
#
# Exit codes: 0 OK, 1 invocation error, 2 graph engine/data unavailable.
set -euo pipefail

# shellcheck source=_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

REPO="."
DIAGRAM="module-deps"

usage() {
    cat <<'EOF'
mermaid-from-graph.sh — emit Mermaid diagrams from the knowledge graph.

Usage:
  scripts/tools/mermaid-from-graph.sh [--repo DIR] [--diagram module-deps|proto-map]

Flags:
  --repo DIR      Repository root (default: cwd).
  --diagram NAME  module-deps (default) or proto-map.
  --help          Show this help.

Exit 0 with diagram output, exit 2 with an empty stub when the engine is unavailable.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) REPO="$2"; shift 2;;
        --diagram) DIAGRAM="$2"; shift 2;;
        --help|-h) usage; exit 0;;
        *) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
    esac
done

if [[ ! -d "$REPO" ]]; then
    echo "ERROR: --repo '$REPO' is not a directory" >&2
    exit 1
fi

REPO_ABS="$(cd "$REPO" && pwd)"
SELF_REPO="$(cd "$(dirname "$0")/../.." && pwd)"

stub() {
    cat <<'EOF'
```mermaid
%% graph data unavailable — index the repo with the graph engine first
flowchart LR
    empty["graph not built"]
```
EOF
    exit 2
}

find_memory_bin "$REPO_ABS" "$SELF_REPO" || stub
command -v jq >/dev/null 2>&1 || stub

PROJECT="$(memory_ensure_index "$REPO_ABS" || true)"
[[ -n "$PROJECT" ]] || stub

render_module_deps() {
    local q="MATCH (a:File)-[r:FILE_CHANGES_WITH]->(b:File) RETURN a.name AS src, b.name AS dst, r.coupling_score AS score ORDER BY r.coupling_score DESC LIMIT 40"
    local res; res="$(memory_cli query_graph "{\"project\":\"$PROJECT\",\"query\":\"$q\"}" || echo '{}')"
    local edges; edges="$(echo "${res:-{\}}" | jq -r '(.rows // [])[] | "    \"" + (.[0]|tostring) + "\" --> \"" + (.[1]|tostring) + "\""' 2>/dev/null || true)"
    if [[ -z "$edges" ]]; then return 1; fi
    printf '```mermaid\nflowchart LR\n%s\n```\n' "$edges"
}

render_proto_map() {
    local res; res="$(memory_cli get_architecture "{\"project\":\"$PROJECT\",\"aspects\":[\"routes\"]}" || echo '{}')"
    local edges; edges="$(echo "${res:-{\}}" | jq -r '(.routes // [])[] | "    \"" + ((.method // "")|tostring) + " " + ((.path // "")|tostring) + "\" --> \"" + ((.handler // "?")|tostring) + "\""' 2>/dev/null || true)"
    if [[ -z "$edges" ]]; then return 1; fi
    printf '```mermaid\nflowchart LR\n%s\n```\n' "$edges"
}

case "$DIAGRAM" in
    module-deps) render_module_deps || stub ;;
    proto-map)   render_proto_map || stub ;;
    *) echo "Unknown --diagram '$DIAGRAM' (expected module-deps|proto-map)" >&2; exit 1 ;;
esac
