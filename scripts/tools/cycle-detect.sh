#!/usr/bin/env bash
# cycle-detect.sh — emit call cycles from the knowledge graph.
#
# Backed by the codebase-memory-mcp engine. Uses bounded, fixed-length CALLS
# patterns via openCypher (this engine's dialect handles explicit patterns
# reliably but not variable-length/aggregate queries). Detects 2- and 3-node
# call cycles, which surface mutual recursion and tight coupling.
#
# Usage:
#   scripts/tools/cycle-detect.sh [--repo DIR]
#
# Output: JSON {cycles:[[a,b],[a,b,c], ...], source}.
#   source = "memory-graph" | "unavailable"
#
# Exit codes: 0 OK, 1 invocation error, 2 graph engine/data unavailable.
set -euo pipefail

# shellcheck source=_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

REPO="."

usage() {
    cat <<'EOF'
cycle-detect.sh — call-cycle detection from the knowledge graph.

Usage:
  scripts/tools/cycle-detect.sh [--repo DIR]

Flags:
  --repo DIR  Repository root (default: cwd).
  --help      Show this help.

Output: JSON {cycles:[[a,b],[a,b,c]], source}. Fallback when the engine is
unavailable: {"cycles":[],"source":"unavailable"}, exit 2.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) REPO="$2"; shift 2;;
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

unavailable() { echo '{"cycles":[],"source":"unavailable"}'; exit 2; }

find_memory_bin "$REPO_ABS" "$SELF_REPO" || unavailable
command -v jq >/dev/null 2>&1 || unavailable

PROJECT="$(memory_ensure_index "$REPO_ABS" || true)"
[[ -n "$PROJECT" ]] || unavailable

# 2-cycles: a -> b -> a (dedup with a.qualified_name < b.qualified_name).
Q2="MATCH (a:Function)-[:CALLS]->(b:Function)-[:CALLS]->(a) WHERE a.qualified_name < b.qualified_name RETURN a.qualified_name AS a, b.qualified_name AS b LIMIT 100"
# 3-cycles: a -> b -> c -> a.
Q3="MATCH (a:Function)-[:CALLS]->(b:Function)-[:CALLS]->(c:Function)-[:CALLS]->(a) RETURN a.qualified_name AS a, b.qualified_name AS b, c.qualified_name AS c LIMIT 100"

R2="$(memory_cli query_graph "{\"project\":\"$PROJECT\",\"query\":\"$Q2\"}" || echo '{}')"
R3="$(memory_cli query_graph "{\"project\":\"$PROJECT\",\"query\":\"$Q3\"}" || echo '{}')"

jq -n --argjson r2 "${R2:-{\}}" --argjson r3 "${R3:-{\}}" '
    {
      cycles: (((($r2.rows) // []) + (($r3.rows) // []))),
      source: "memory-graph"
    }'
