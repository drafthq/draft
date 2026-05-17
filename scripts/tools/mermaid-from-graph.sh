#!/usr/bin/env bash
# mermaid-from-graph.sh — emit Mermaid diagrams from the knowledge graph.
#
# Thin wrapper around `graph --query --mode mermaid`. When graph data is missing,
# emits an empty diagram stub and exits 2 so consuming skills can degrade gracefully.
#
# Usage:
# scripts/tools/mermaid-from-graph.sh [--repo DIR] [--out DIR]
# [--diagram module-deps|proto-map]
#
# Exit codes: 0 OK, 1 invocation error, 2 graph data unavailable.
set -euo pipefail

# shellcheck source=_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

REPO="."
OUT_DIR=""
DIAGRAM=""

usage() {
    cat <<'EOF'
mermaid-from-graph.sh — emit Mermaid diagrams from the knowledge graph.

Usage:
  scripts/tools/mermaid-from-graph.sh [--repo DIR] [--out DIR]
                                      [--diagram module-deps|proto-map]

Flags:
  --repo DIR Repository root (default: cwd).
  --out DIR Graph output dir (default: <repo>/draft/graph).
  --diagram NAME module-deps or proto-map (default: both, raw markdown).
  --help Show this help.

Exit 0 with diagram output, exit 2 with empty stub when graph data is missing.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) REPO="$2"; shift 2;;
        --out) OUT_DIR="$2"; shift 2;;
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
GRAPH_OUT="${OUT_DIR:-$REPO_ABS/draft/graph}"

SELF_REPO="$(cd "$(dirname "$0")/../.." && pwd)"
find_graph_bin "$REPO_ABS" "$SELF_REPO" || true

if [[ -n "$GRAPH_BIN" && -d "$GRAPH_OUT" ]]; then
    QUERY_ARGS=(--repo "$REPO_ABS" --out "$GRAPH_OUT" --query --mode mermaid)
    [[ -n "$DIAGRAM" ]] && QUERY_ARGS+=(--symbol "$DIAGRAM")
    if result="$("$GRAPH_BIN" "${QUERY_ARGS[@]}" 2>/dev/null)" && [[ -n "$result" ]]; then
        printf '%s\n' "$result"
        exit 0
    fi
fi

# Graceful fallback: empty diagram block so downstream consumers can still inject.
cat <<'EOF'
```mermaid
%% graph data unavailable — run `graph --repo .` first
flowchart LR
    empty["graph not built"]
```
EOF
exit 2
