#!/usr/bin/env bash
# graph-deps.sh — real file/module import graph from the knowledge graph (IMPORTS).
#
# graph-tooling-v2 Phase 3/4. The authoritative module-dependency graph, derived
# from actual IMPORTS edges — not the directory-stub `fan_in` heuristic. Feeds the
# architecture.md §9 dependency diagram (mermaid-from-graph.sh module-deps) and
# blast-radius reasoning.
#
# Self-imports (src == dst, an artifact of how some languages attribute a file's
# own symbols) are filtered out so the result is a true cross-file graph.
#
# Usage:
#   scripts/tools/graph-deps.sh --repo DIR [--file PATH]
#
# Output: JSON {imports:[{src,dst}], total, truncated, source}. With --file, only
# edges whose src ends with PATH are kept (a file's outgoing dependencies).
#
# Exit codes: 0 OK, 1 invocation error, 2 graph engine unavailable.
set -euo pipefail

# shellcheck source=_graph_queries.sh
source "$(dirname "${BASH_SOURCE[0]}")/_graph_queries.sh"

REPO="."
FILE=""

usage() {
    cat <<'EOF'
graph-deps.sh — real module/file import graph (IMPORTS edges).

Usage:
  scripts/tools/graph-deps.sh --repo DIR [--file PATH]

Flags:
  --repo DIR   Repository root (default: cwd).
  --file PATH  Keep only edges whose source file ends with PATH.
  --help       Show this help.

Output: JSON {imports:[{src,dst}], total, truncated, source}. Self-imports are
filtered. Exit 2 when engine unavailable.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) REPO="$2"; shift 2;;
        --file) FILE="$2"; shift 2;;
        --help|-h) usage; exit 0;;
        *) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
    esac
done

[[ -d "$REPO" ]] || { echo "ERROR: --repo '$REPO' is not a directory" >&2; exit 1; }

REPO_ABS="$(cd "$REPO" && pwd)"
SELF_REPO="$(cd "$(dirname "$0")/../.." && pwd)"

unavailable() { echo '{"imports":[],"total":0,"source":"unavailable"}'; exit 2; }

find_memory_bin "$REPO_ABS" "$SELF_REPO" || unavailable
command -v jq >/dev/null 2>&1 || unavailable

PROJECT="$(memory_ensure_index "$REPO_ABS" || true)"
[[ -n "$PROJECT" ]] || unavailable

RES="$(gq_run "$PROJECT" "$(gq_q_imports)" || true)"
[[ -n "$RES" ]] || unavailable

echo "$RES" | jq --arg f "$FILE" '
    [ (.rows // [])[]
      | {src:.[0], dst:.[1]}
      | select(.src != null and .dst != null and .src != .dst)
      | select($f == "" or (.src | endswith($f))) ] as $e
    | {imports: $e, total: ($e | length),
       truncated: (((.rows // []) | length) >= 1000),
       source:"memory-graph"}'
