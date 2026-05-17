#!/usr/bin/env bash
# cycle-detect.sh — emit dependency cycles from the knowledge graph.
#
# Strategy:
# 1. If `graph` binary is available, run `graph --query --mode cycles`.
# 2. Else emit {"cycles":[],"source":"unavailable"} and exit 2.
#
# Usage:
# scripts/tools/cycle-detect.sh [--repo DIR] [--out DIR]
#
# Exit codes: 0 OK, 1 invocation error, 2 graph data unavailable.
set -euo pipefail

# shellcheck source=_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

REPO="."
OUT_DIR=""

usage() {
    cat <<'EOF'
cycle-detect.sh — dependency cycle detection from the knowledge graph.

Usage:
  scripts/tools/cycle-detect.sh [--repo DIR] [--out DIR]

Flags:
  --repo DIR Repository root (default: cwd).
  --out DIR Graph output dir (default: <repo>/draft/graph).
  --help Show this help.

Output: JSON from graph --query --mode cycles (adds .source). Fallback on missing
graph: {"cycles":[],"source":"unavailable"}, exit 2.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) REPO="$2"; shift 2;;
        --out) OUT_DIR="$2"; shift 2;;
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

if [[ -n "$GRAPH_BIN" && -d "$GRAPH_OUT" ]]; then
    if result="$("$GRAPH_BIN" --repo "$REPO_ABS" --out "$GRAPH_OUT" --query --mode cycles 2>/dev/null)"; then
        if [[ -n "$result" ]]; then
            if command -v jq >/dev/null 2>&1; then
                echo "$result" | jq '. + {source: "graph-query"}'
            else
                printf '%s\n' "$result"
            fi
            exit 0
        fi
    fi
fi

echo '{"cycles":[],"source":"unavailable"}'
exit 2
