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
        --repo) REPO="${2:?--repo requires a value}"; shift 2;;
        --help|-h) usage; exit 0;;
        *) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
    esac
done

if [[ ! -d "$REPO" ]]; then
    echo "ERROR: --repo '$REPO' is not a directory" >&2
    exit 1
fi

unavailable() { echo '{"cycles":[],"source":"unavailable"}'; exit 2; }

graph_bootstrap "$REPO" || unavailable

# 2- and 3-node CALLS cycles. Cypher lives in _graph_queries.sh (label-agnostic;
# the Phase 0 fix — code units are mostly :Method, and CALLS only connects
# callables). LIMIT 100 caps each, so results are a sample, not exhaustive.
#
# A failed query is not an empty result. Substituting `{}` and carrying on
# reported `source:"memory-graph"` with zero cycles — a clean bill of health
# derived from a query that never ran, which is exactly the true-negative
# confusion Guardrail 4 exists to prevent, and the one failure mode a caller
# cannot detect. Both queries must land for the sample to mean anything, so
# either failure routes to `unavailable`. gq_run only ever echoes validated
# JSON, so nothing downstream needs a second shape guard.
R2="$(gq_run "$PROJECT" "$(gq_q_cycles2)")" || unavailable
R3="$(gq_run "$PROJECT" "$(gq_q_cycles3)")" || unavailable

# Self-loops and duplicate orderings are filtered here rather than in Cypher:
# the engine rejects `a.x < b.x`, which is what the query used to rely on.
# A 2-cycle comes back twice (A,B and B,A), hence the doubled LIMIT upstream.
jq -n --argjson r2 "$R2" --argjson r3 "$R3" '
    ( ((($r2.rows) // []) | length) >= 200
      or ((($r3.rows) // []) | length) >= 100 ) as $trunc
    | ( ($r2.rows // []) | map(select(.[0] != .[1])) | unique_by(sort) ) as $two
    | {
        cycles: ($two + ($r3.rows // [])),
        truncated: $trunc,
        source: "memory-graph"
      }'
