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

# shellcheck source=_graph_queries.sh
source "$(dirname "${BASH_SOURCE[0]}")/_graph_queries.sh"

REPO="."

usage() {
    cat <<'EOF'
cycle-detect.sh — call-cycle detection from the knowledge graph.

Usage:
  scripts/tools/cycle-detect.sh [--repo DIR]

Flags:
  --repo DIR  Repository root (default: cwd).
  --help      Show this help.

Output: JSON {cycles:[[a,b],[a,b,c]], truncated, source}. `truncated` is true
when either cycle query hit its LIMIT (results are a sample, not exhaustive).
Fallback when the engine is unavailable: {"cycles":[],"source":"unavailable"},
exit 2.
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

# 2- and 3-node CALLS cycles. Cypher lives in _graph_queries.sh (label-agnostic;
# the Phase 0 fix — code units are mostly :Method, and CALLS only connects
# callables). LIMIT 100 caps each, so results are a sample, not exhaustive.
R2="$(gq_run "$PROJECT" "$(gq_q_cycles2)" || echo '{}')"
R3="$(gq_run "$PROJECT" "$(gq_q_cycles3)" || echo '{}')"

# Guard against empty/non-JSON engine output so --argjson never aborts the script.
echo "$R2" | jq -e . >/dev/null 2>&1 || R2='{}'
echo "$R3" | jq -e . >/dev/null 2>&1 || R3='{}'

jq -n --argjson r2 "$R2" --argjson r3 "$R3" '
    ( ((($r2.rows) // []) | length) >= 100
      or ((($r3.rows) // []) | length) >= 100 ) as $trunc
    | {
        cycles: (((($r2.rows) // []) + (($r3.rows) // []))),
        truncated: $trunc,
        source: "memory-graph"
      }'
