#!/usr/bin/env bash
# mermaid-from-graph.sh — emit Mermaid diagrams from the knowledge graph.
#
# Backed by the codebase-memory-mcp engine. Diagrams:
#   module-deps : real file/module dependency graph (IMPORTS edges) as a flowchart.
#                 This is the auto-derived dependency diagram for architecture.md
#                 §9 (graph-tooling-v2 Phase 4) — it replaces the prior co-change
#                 proxy with actual import edges.
#   co-change   : file co-change coupling (FILE_CHANGES_WITH edges) — the hidden,
#                 git-history dependency proxy (the prior module-deps behavior,
#                 still available explicitly).
#   proto-map   : detected service routes (Route nodes) as a flowchart.
#
# When the engine is unavailable, emits an empty diagram stub and exits 2 so
# consuming skills can degrade gracefully.
#
# Usage:
#   scripts/tools/mermaid-from-graph.sh [--repo DIR] [--diagram module-deps|co-change|proto-map]
#
# Exit codes: 0 OK, 1 invocation error, 2 graph engine/data unavailable.
set -euo pipefail

# shellcheck source=_graph_queries.sh
source "$(dirname "${BASH_SOURCE[0]}")/_graph_queries.sh"

REPO="."
DIAGRAM="module-deps"

usage() {
    cat <<'EOF'
mermaid-from-graph.sh — emit Mermaid diagrams from the knowledge graph.

Usage:
  scripts/tools/mermaid-from-graph.sh [--repo DIR] [--diagram module-deps|co-change|proto-map]

Flags:
  --repo DIR      Repository root (default: cwd).
  --diagram NAME  module-deps (default, IMPORTS edges), co-change
                  (FILE_CHANGES_WITH coupling), or proto-map (routes).
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

# module-deps: real IMPORTS edges (the auto-derived dependency graph). Self-imports
# (src == dst) are dropped so the diagram is a true cross-file graph. Capped at 40
# edges for readability.
render_module_deps() {
    local res; res="$(gq_run "$PROJECT" "$(gq_q_imports)" || echo '{}')"
    local edges; edges="$(echo "${res:-{\}}" | jq -r '
        [ (.rows // [])[] | {s:(.[0]|tostring), d:(.[1]|tostring)}
          | select(.s != "" and .d != "" and .s != .d) ]
        | unique | .[0:40][] | "    \"" + .s + "\" --> \"" + .d + "\""' 2>/dev/null || true)"
    if [[ -z "$edges" ]]; then return 1; fi
    printf '```mermaid\nflowchart LR\n%s\n```\n' "$edges"
}

# co-change: FILE_CHANGES_WITH coupling (the prior module-deps proxy).
render_co_change() {
    local res; res="$(gq_run "$PROJECT" "$(gq_q_co_change)" || echo '{}')"
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
    co-change)   render_co_change || stub ;;
    proto-map)   render_proto_map || stub ;;
    *) echo "Unknown --diagram '$DIAGRAM' (expected module-deps|co-change|proto-map)" >&2; exit 1 ;;
esac
