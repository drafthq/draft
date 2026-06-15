#!/usr/bin/env bash
# graph-snippet.sh — verified source + caller/callee counts for a symbol.
#
# Wraps the engine's get_code_snippet (graph-tooling-v2 Phase 3). Replaces the
# grep-then-Read dance with the engine's own attributed source plus its
# pre-computed caller/callee counts and loop-depth risk signal.
#
# Usage:
#   scripts/tools/graph-snippet.sh --repo DIR --qualified NAME
#
# NAME is a fully qualified_name (e.g. pkg.module.Class.method). Use
# graph-search.sh or `graph-arch.sh | jq` to discover qualified names.
#
# Output: JSON {qualified_name, file, start_line, end_line, callers, callees,
#               transitive_loop_depth, complexity, code, status, source}.
#   status = "ok" | "no-match" | "unavailable"
#
# Exit codes: 0 OK, 1 invocation error, 2 graph engine unavailable.
set -euo pipefail

# shellcheck source=_graph_queries.sh
source "$(dirname "${BASH_SOURCE[0]}")/_graph_queries.sh"

REPO="."
QNAME=""

usage() {
    cat <<'EOF'
graph-snippet.sh — verified source + caller/callee counts for a symbol.

Usage:
  scripts/tools/graph-snippet.sh --repo DIR --qualified NAME

Flags:
  --repo DIR       Repository root (default: cwd).
  --qualified NAME Fully qualified symbol name (required).
  --help           Show this help.

Output: JSON {qualified_name, file, start_line, end_line, callers, callees,
transitive_loop_depth, complexity, code, status, source}. Exit 2 when engine
unavailable.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) REPO="$2"; shift 2;;
        --qualified|--symbol) QNAME="$2"; shift 2;;
        --help|-h) usage; exit 0;;
        *) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
    esac
done

[[ -d "$REPO" ]] || { echo "ERROR: --repo '$REPO' is not a directory" >&2; exit 1; }
[[ -n "$QNAME" ]] || { echo "ERROR: --qualified is required" >&2; usage >&2; exit 1; }

REPO_ABS="$(cd "$REPO" && pwd)"
SELF_REPO="$(cd "$(dirname "$0")/../.." && pwd)"

unavailable() {
    jq -n --arg q "$QNAME" '{qualified_name:$q, status:"unavailable", source:"unavailable"}' 2>/dev/null \
        || echo '{"status":"unavailable","source":"unavailable"}'
    exit 2
}

find_memory_bin "$REPO_ABS" "$SELF_REPO" || unavailable
command -v jq >/dev/null 2>&1 || unavailable

PROJECT="$(memory_ensure_index "$REPO_ABS" || true)"
[[ -n "$PROJECT" ]] || unavailable

ARGS="$(jq -n --arg p "$PROJECT" --arg q "$QNAME" '{project:$p, qualified_name:$q}')"
RES="$(memory_cli get_code_snippet "$ARGS" 2>/dev/null || true)"
[[ -n "$RES" ]] || unavailable
echo "$RES" | jq -e . >/dev/null 2>&1 || unavailable

# The engine field `source` carries the code text; rename to `code` to avoid
# colliding with our provenance `source`. no-match when the engine returns an
# object without a qualified_name/source for the requested symbol.
echo "$RES" | jq --arg q "$QNAME" '
    (.qualified_name // .name // null) as $found
    | {qualified_name: ($found // $q),
       file: (.file_path // ""),
       start_line: (.start_line // null),
       end_line: (.end_line // null),
       callers: (.callers // null),
       callees: (.callees // null),
       transitive_loop_depth: (.transitive_loop_depth // null),
       complexity: (.complexity // null),
       code: (.source // ""),
       status: (if ($found != null or (.source // "") != "") then "ok" else "no-match" end),
       source: "memory-graph"}'
