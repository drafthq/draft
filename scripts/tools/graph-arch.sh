#!/usr/bin/env bash
# graph-arch.sh — emit the architecture view from the knowledge graph.
#
# The engine-only replacement for the old committed architecture.json. Resolves
# the codebase-memory-mcp engine, indexes the repo on demand, auto-resolves the
# project, and prints the full get_architecture(all) JSON to stdout — node labels,
# edge types, languages, packages (fan-in/out), entry points, routes, hotspots,
# boundaries, layers, clusters, file tree. Pipe to jq to slice the field you need:
#
#   scripts/tools/graph-arch.sh --repo . | jq '.packages'
#   scripts/tools/graph-arch.sh --repo . | jq '.routes'
#
# The engine binary is usually NOT on $PATH; this wrapper resolves it (via
# _lib.sh:find_memory_bin) so callers never invoke `codebase-memory-mcp` directly.
#
# Usage: scripts/tools/graph-arch.sh [--repo DIR]
# Output: the architecture JSON object on success; {"source":"unavailable"} on failure.
# Exit codes: 0 OK, 1 invocation error, 2 graph engine/data unavailable.
set -euo pipefail

# shellcheck source=_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

REPO="."

usage() {
    cat <<'EOF'
graph-arch.sh — architecture view (packages, routes, layers, hotspots) from the graph.

Usage:
  scripts/tools/graph-arch.sh [--repo DIR]

Flags:
  --repo DIR  Repository root (default: cwd).
  --help      Show this help.

Output: the get_architecture(all) JSON object on success. Pipe to jq to slice it
(`| jq '.packages'`, `| jq '.routes'`, …). Emits {"source":"unavailable"} and exits 2
when the graph engine is unavailable.
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

unavailable() { echo '{"source":"unavailable"}'; exit 2; }

find_memory_bin "$REPO_ABS" "$SELF_REPO" || unavailable
command -v jq >/dev/null 2>&1 || unavailable

PROJECT="$(memory_ensure_index "$REPO_ABS" || true)"
[[ -n "$PROJECT" ]] || unavailable

ARCH_JSON="$(memory_cli get_architecture "{\"project\":\"$PROJECT\",\"aspects\":[\"all\"]}" || true)"
[[ -n "$ARCH_JSON" ]] || unavailable

# Validate it parses and looks like an architecture object before emitting.
echo "$ARCH_JSON" | jq -e '.total_nodes != null' >/dev/null 2>&1 || unavailable
echo "$ARCH_JSON" | jq '.'
