#!/usr/bin/env bash
# graph-risk.sh — pre-computed risk hotspots from the knowledge graph node props.
#
# graph-tooling-v2 Phase 3. The engine already computes per-symbol risk flags
# (unguarded_recursion, recursion_in_loop, alloc_in_loop, linear_scan_in_loop)
# during indexing. This wrapper surfaces them so bughunt / deep-review consume the
# engine's findings instead of re-deriving them by hand.
#
# Usage:
#   scripts/tools/graph-risk.sh --repo DIR [--min-complexity N]
#
# Output: JSON {risky:[{symbol, file, complexity, flags:[...]}], total,
#               truncated, source}. --min-complexity keeps only flagged symbols
#               whose complexity >= N (filtered client-side; the engine dialect
#               has no >= operator).
#
# Exit codes: 0 OK, 1 invocation error, 2 graph engine unavailable.
set -euo pipefail

# shellcheck source=_graph_queries.sh
source "$(dirname "${BASH_SOURCE[0]}")/_graph_queries.sh"

REPO="."
MIN_COMPLEXITY=0

usage() {
    cat <<'EOF'
graph-risk.sh — pre-computed risk hotspots (recursion / in-loop allocations).

Usage:
  scripts/tools/graph-risk.sh --repo DIR [--min-complexity N]

Flags:
  --repo DIR           Repository root (default: cwd).
  --min-complexity N   Keep only flagged symbols with complexity >= N (default 0).
  --help               Show this help.

Output: JSON {risky:[{symbol, file, complexity, flags}], total, truncated,
source}. Exit 2 when engine unavailable.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) REPO="$2"; shift 2;;
        --min-complexity) MIN_COMPLEXITY="$2"; shift 2;;
        --help|-h) usage; exit 0;;
        *) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
    esac
done

[[ -d "$REPO" ]] || { echo "ERROR: --repo '$REPO' is not a directory" >&2; exit 1; }
[[ "$MIN_COMPLEXITY" =~ ^[0-9]+$ ]] || { echo "ERROR: --min-complexity must be a non-negative integer" >&2; exit 1; }

REPO_ABS="$(cd "$REPO" && pwd)"
SELF_REPO="$(cd "$(dirname "$0")/../.." && pwd)"

unavailable() { echo '{"risky":[],"total":0,"source":"unavailable"}'; exit 2; }

find_memory_bin "$REPO_ABS" "$SELF_REPO" || unavailable
command -v jq >/dev/null 2>&1 || unavailable

PROJECT="$(memory_ensure_index "$REPO_ABS" || true)"
[[ -n "$PROJECT" ]] || unavailable

RES="$(gq_run "$PROJECT" "$(gq_q_risk)" || true)"
[[ -n "$RES" ]] || unavailable

# Columns: symbol, file, complexity, unguarded_recursion, alloc_in_loop,
# recursion_in_loop, linear_scan_in_loop. complexity arrives as a string.
echo "$RES" | jq --argjson minc "$MIN_COMPLEXITY" '
    [ (.rows // [])[]
      | {symbol:.[0], file:.[1], complexity:((.[2] // "0") | tonumber? // 0),
         flags: ( [ (if (.[3]|tostring) == "true" then "unguarded_recursion" else empty end),
                    (if (.[4]|tostring) == "true" then "alloc_in_loop" else empty end),
                    (if (.[5]|tostring) == "true" then "recursion_in_loop" else empty end),
                    (if (.[6]|tostring) == "true" then "linear_scan_in_loop" else empty end) ] )}
      | select(.complexity >= $minc) ] as $r
    | {risky: $r, total: ($r | length),
       truncated: (((.rows // []) | length) >= 200),
       source:"memory-graph"}'
