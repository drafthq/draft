#!/usr/bin/env bash
# hotspot-rank.sh — emit complexity-ranked files.
#
# Strategy, in order:
# 1. If `graph` binary is available, run `graph --query --mode hotspots`.
# 2. Else if draft/graph/hotspots.jsonl exists, read and emit it.
# 3. Else emit [] and exit 2 (graceful fallback — graph not built).
#
# Usage:
# scripts/tools/hotspot-rank.sh [--repo DIR] [--out DIR] [--top N] [--module NAME]
#
# Exit codes: 0 OK, 1 invocation error, 2 graph data unavailable.
set -euo pipefail

# shellcheck source=_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

REPO="."
OUT_DIR=""
TOP=0
MODULE=""

usage() {
    cat <<'EOF'
hotspot-rank.sh — complexity-ranked files from the knowledge graph.

Usage:
  scripts/tools/hotspot-rank.sh [--repo DIR] [--out DIR] [--top N] [--module NAME]

Flags:
  --repo DIR Repository root (default: cwd).
  --out DIR Graph output dir (default: <repo>/draft/graph).
  --top N Keep only top N hotspots (default: 0 = all).
  --module NAME Filter to a single module.
  --help Show this help.

Output: JSON {hotspots:[{id, module, lines, fanIn}], source}.
  source = "graph-query" | "hotspots.jsonl" | "unavailable"

Exit 0 with results, exit 2 with {"hotspots":[],"source":"unavailable"} if graph data is missing.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) REPO="$2"; shift 2;;
        --out) OUT_DIR="$2"; shift 2;;
        --top) TOP="$2"; shift 2;;
        --module) MODULE="$2"; shift 2;;
        --help|-h) usage; exit 0;;
        *) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
    esac
done

if [[ ! -d "$REPO" ]]; then
    echo "ERROR: --repo '$REPO' is not a directory" >&2
    exit 1
fi

REPO_ABS="$(cd "$REPO" && pwd)"
GRAPH_OUT="${OUT_DIR:-$REPO_ABS/draft/graph}"

SELF_REPO="$(cd "$(dirname "$0")/../.." && pwd)"
find_graph_bin "$REPO_ABS" "$SELF_REPO" || true

filter_json() {
    # Takes a hotspots JSON object on stdin; optionally filters by module, truncates to top.
    local top="$1"
    local module="$2"
    if ! command -v jq >/dev/null 2>&1; then
        cat
        return
    fi
    local q='.'
    if [[ "$top" -gt 0 ]]; then
        q="$q | .hotspots |= .[0:$top]"
    fi
    if [[ -n "$module" ]]; then
        jq --arg mod "$module" "$q | .hotspots |= map(select(.module == \$mod))"
    else
        jq "$q"
    fi
}

# Strategy 1: live query via graph binary
if [[ -n "$GRAPH_BIN" && -d "$GRAPH_OUT" ]]; then
    if result="$("$GRAPH_BIN" --repo "$REPO_ABS" --out "$GRAPH_OUT" --query --mode hotspots 2>/dev/null)"; then
        if [[ -n "$result" ]] && command -v jq >/dev/null 2>&1; then
            echo "$result" | jq --arg src "graph-query" '. + {source: $src}' | filter_json "$TOP" "$MODULE"
            exit 0
        elif [[ -n "$result" ]]; then
            printf '%s\n' "$result"
            exit 0
        fi
    fi
fi

# Strategy 2: read draft/graph/hotspots.jsonl directly
HOTSPOT_FILE="$GRAPH_OUT/hotspots.jsonl"
if [[ -f "$HOTSPOT_FILE" ]]; then
    if command -v jq >/dev/null 2>&1; then
        jq -s '{hotspots: ., source: "hotspots.jsonl"}' <"$HOTSPOT_FILE" | filter_json "$TOP" "$MODULE"
    else
        # Minimal concatenation fallback (not as clean but valid JSON).
        printf '{"hotspots":['
        first=true
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            if $first; then first=false; else printf ','; fi
            printf '%s' "$line"
        done <"$HOTSPOT_FILE"
        printf '],"source":"hotspots.jsonl"}\n'
    fi
    exit 0
fi

# Strategy 3: graph data missing
echo '{"hotspots":[],"source":"unavailable"}'
exit 2
