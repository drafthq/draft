#!/usr/bin/env bash
# hotspot-rank.sh — complexity-weighted hotspot ranking from the knowledge graph.
#
# Backed by the codebase-memory-mcp engine. Fan-in alone is skewed by
# name-collision generics (e.g. a logger `info` with fan_in 1022 but complexity 0),
# so graph-tooling-v2 Phase 4 blends the engine's pre-computed complexity and
# cognitive scores into the rank: score = fanIn + complexity + cognitive. Entry
# points are annotated. fan_in still comes from the engine's server-computed
# hotspot ranking; the per-symbol complexity/cognitive/is_entry_point come from a
# node-property query and are merged in.
#
# Usage:
#   scripts/tools/hotspot-rank.sh [--repo DIR] [--top N]
#
# Output: JSON {hotspots:[{id, name, fanIn, complexity, cognitive, score,
#               isEntryPoint}], source}.
#   source = "memory-graph" | "unavailable"
#
# Exit codes: 0 OK, 1 invocation error, 2 graph engine/data unavailable.
set -euo pipefail

# shellcheck source=_graph_queries.sh
source "$(dirname "${BASH_SOURCE[0]}")/_graph_queries.sh"

REPO="."
TOP=0

usage() {
    cat <<'EOF'
hotspot-rank.sh — complexity-weighted hotspot ranking from the knowledge graph.

Usage:
  scripts/tools/hotspot-rank.sh [--repo DIR] [--top N]

Flags:
  --repo DIR  Repository root (default: cwd).
  --top N     Keep only top N hotspots (default: 0 = all).
  --help      Show this help.

Output: JSON {hotspots:[{id, name, fanIn, complexity, cognitive, score,
isEntryPoint}], source}. Ranked by score = fanIn + complexity + cognitive.

Exit 0 with results, exit 2 with {"hotspots":[],"source":"unavailable"} when the
graph engine is unavailable.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) REPO="${2:?--repo requires a value}"; shift 2;;
        --top) TOP="${2:?--top requires a value}"; shift 2;;
        --help|-h) usage; exit 0;;
        *) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
    esac
done

[[ "$TOP" =~ ^[0-9]+$ ]] || { echo "ERROR: --top must be a non-negative integer" >&2; exit 1; }

if [[ ! -d "$REPO" ]]; then
    echo "ERROR: --repo '$REPO' is not a directory" >&2
    exit 1
fi

unavailable() { echo '{"hotspots":[],"source":"unavailable"}'; exit 2; }

graph_bootstrap "$REPO" || unavailable

ARCH_JSON="$(memory_cli get_architecture \
    "$(jq -n --arg p "$PROJECT" '{project:$p, aspects:["hotspots"]}')" || true)"
[[ -n "$ARCH_JSON" ]] || unavailable
echo "$ARCH_JSON" | jq -e . >/dev/null 2>&1 || unavailable

# Pre-computed complexity/cognitive/is_entry_point per symbol (merged onto fan-in).
#
# The hotspots themselves come from get_architecture above, which is fail-loud,
# so a failure here costs enrichment rather than the whole result — worth keeping
# the ranking for. But it must not pass silently: substituting an empty row set
# gave every symbol complexity 0 and cognitive 0, folded those zeros into `score`,
# and still reported source:"memory-graph", so a fan-in-only ranking was
# indistinguishable from a fully measured one. Record the outcome instead, and
# omit the fields rather than emitting measurements that were never taken.
if PROPS_JSON="$(gq_run "$PROJECT" "$(gq_q_node_props)")"; then
    ENRICHMENT="ok"
else
    PROPS_JSON='{"rows":[]}'
    ENRICHMENT="unavailable"
fi

# Merge via temp files (the props row set can exceed argv limits on large repos).
TMP_ARCH="$(mktemp)"; TMP_PROPS="$(mktemp)"
trap 'rm -f "$TMP_ARCH" "$TMP_PROPS"' EXIT
printf '%s' "$ARCH_JSON" > "$TMP_ARCH"
printf '%s' "$PROPS_JSON" > "$TMP_PROPS"

jq -n --slurpfile arch "$TMP_ARCH" --slurpfile props "$TMP_PROPS" --argjson top "$TOP" \
      --arg enrichment "$ENRICHMENT" '
    ((($props[0].rows) // []) | map(select(.[0] != null))) as $prows
    | (reduce $prows[] as $r ({};
          .[$r[0]] = {c:((($r[1]) // "0") | tonumber? // 0),
                      cog:((($r[2]) // "0") | tonumber? // 0),
                      ep:((($r[3]) | tostring) == "true")})) as $pmap
    | [ (($arch[0].hotspots) // [])[]
        | (.qualified_name) as $q
        | ($pmap[$q] // {c:0, cog:0, ep:false}) as $p
        | ({id:$q, name:.name, fanIn:(.fan_in // 0),
            score:((.fan_in // 0) + $p.c + $p.cog)}
           + (if $enrichment == "ok"
              then {complexity:$p.c, cognitive:$p.cog, isEntryPoint:$p.ep}
              else {} end)) ]
    | sort_by(-.score)
    | (if $top > 0 then .[0:$top] else . end) as $h
    | {hotspots:$h, enrichment:$enrichment, source:"memory-graph"}'
