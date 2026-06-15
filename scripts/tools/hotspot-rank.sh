#!/usr/bin/env bash
# hotspot-rank.sh — emit complexity/fan-in-ranked symbols from the knowledge graph.
#
# Backed by the codebase-memory-mcp engine (get_architecture, server-computed
# hotspot ranking by fan-in). Indexes the repo on demand if needed.
#
# Usage:
#   scripts/tools/hotspot-rank.sh [--repo DIR] [--top N]
#
# Output: JSON {hotspots:[{id, name, fanIn}], source}.
#   source = "memory-graph" | "unavailable"
#
# Exit codes: 0 OK, 1 invocation error, 2 graph engine/data unavailable.
set -euo pipefail

# shellcheck source=_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

REPO="."
TOP=0

usage() {
    cat <<'EOF'
hotspot-rank.sh — fan-in-ranked symbols from the knowledge graph.

Usage:
  scripts/tools/hotspot-rank.sh [--repo DIR] [--top N]

Flags:
  --repo DIR  Repository root (default: cwd).
  --top N     Keep only top N hotspots (default: 0 = all).
  --help      Show this help.

Output: JSON {hotspots:[{id, name, fanIn}], source}.
  source = "memory-graph" | "unavailable"

Exit 0 with results, exit 2 with {"hotspots":[],"source":"unavailable"} when the
graph engine is unavailable.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) REPO="$2"; shift 2;;
        --top) TOP="$2"; shift 2;;
        --help|-h) usage; exit 0;;
        *) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
    esac
done

[[ "$TOP" =~ ^[0-9]+$ ]] || { echo "ERROR: --top must be a non-negative integer" >&2; exit 1; }

if [[ ! -d "$REPO" ]]; then
    echo "ERROR: --repo '$REPO' is not a directory" >&2
    exit 1
fi

REPO_ABS="$(cd "$REPO" && pwd)"
SELF_REPO="$(cd "$(dirname "$0")/../.." && pwd)"

unavailable() { echo '{"hotspots":[],"source":"unavailable"}'; exit 2; }

find_memory_bin "$REPO_ABS" "$SELF_REPO" || unavailable
command -v jq >/dev/null 2>&1 || unavailable

PROJECT="$(memory_ensure_index "$REPO_ABS" || true)"
[[ -n "$PROJECT" ]] || unavailable

ARCH_JSON="$(memory_cli get_architecture "{\"project\":\"$PROJECT\",\"aspects\":[\"hotspots\"]}" || true)"
[[ -n "$ARCH_JSON" ]] || unavailable

echo "$ARCH_JSON" | jq --argjson top "$TOP" '
    {
      hotspots: ([ (.hotspots // [])[] | {id: .qualified_name, name: .name, fanIn: .fan_in} ]
                 | if $top > 0 then .[0:$top] else . end),
      source: "memory-graph"
    }'
