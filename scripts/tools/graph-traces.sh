#!/usr/bin/env bash
# graph-traces.sh — fold runtime call traces into the knowledge graph (EXPERIMENTAL).
#
# graph-tooling-v2 Phase 6. Wraps the engine's ingest_traces to close the
# static/dynamic gap — dynamic dispatch the static graph misses (e.g. closures,
# reflection, virtual calls). This is a WRITE path and is gated behind
# --experimental. NOTE: in engine v0.8.x ingest_traces is accepted but runtime
# edge creation is "not yet implemented" — the engine returns its status verbatim.
#
# Usage:
#   scripts/tools/graph-traces.sh ingest --repo DIR --file TRACES.json --experimental
#
# TRACES.json is a JSON array of trace records (engine-defined shape).
#
# Output: the engine's raw ingest_traces JSON; {"source":"unavailable"} (exit 2)
# when the engine is unavailable; exit 1 on invocation error or missing
# --experimental.
set -euo pipefail

# shellcheck source=_graph_queries.sh
source "$(dirname "${BASH_SOURCE[0]}")/_graph_queries.sh"

REPO="."
FILE=""
ACTION=""
EXPERIMENTAL=0

usage() {
    cat <<'EOF'
graph-traces.sh — fold runtime traces into the graph (EXPERIMENTAL, write path).

Usage:
  scripts/tools/graph-traces.sh ingest --repo DIR --file TRACES.json --experimental

Flags:
  ingest          The action (currently the only one).
  --repo DIR      Repository root (default: cwd).
  --file PATH     JSON array of trace records (required for ingest).
  --experimental  Required acknowledgement — this is a write/experimental path.
  --help          Show this help.

NOTE: engine v0.8.x accepts traces but runtime edge creation is not yet
implemented; the engine's status is returned verbatim.

Output: raw engine JSON; {"source":"unavailable"} (exit 2) when unavailable.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        ingest) ACTION="ingest"; shift;;
        --repo) REPO="$2"; shift 2;;
        --file) FILE="$2"; shift 2;;
        --experimental) EXPERIMENTAL=1; shift;;
        --help|-h) usage; exit 0;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 1;;
    esac
done

[[ "$ACTION" == "ingest" ]] || { echo "ERROR: action 'ingest' is required" >&2; usage >&2; exit 1; }
[[ "$EXPERIMENTAL" -eq 1 ]] || { echo "ERROR: --experimental is required (this writes to the graph)" >&2; exit 1; }
[[ -d "$REPO" ]] || { echo "ERROR: --repo '$REPO' is not a directory" >&2; exit 1; }
[[ -n "$FILE" ]] || { echo "ERROR: --file is required" >&2; usage >&2; exit 1; }
[[ -f "$FILE" ]] || { echo "ERROR: --file '$FILE' does not exist" >&2; exit 1; }

REPO_ABS="$(cd "$REPO" && pwd)"
SELF_REPO="$(cd "$(dirname "$0")/../.." && pwd)"

unavailable() { echo '{"source":"unavailable"}'; exit 2; }

find_memory_bin "$REPO_ABS" "$SELF_REPO" || unavailable
command -v jq >/dev/null 2>&1 || unavailable

jq -e . "$FILE" >/dev/null 2>&1 || { echo "ERROR: --file is not valid JSON" >&2; exit 1; }

PROJECT="$(memory_ensure_index "$REPO_ABS" || true)"
[[ -n "$PROJECT" ]] || unavailable

ARGS="$(jq -n --arg p "$PROJECT" --slurpfile t "$FILE" '{project:$p, traces:($t[0])}')"
RES="$(memory_cli ingest_traces "$ARGS" 2>/dev/null || true)"
[[ -n "$RES" ]] || unavailable
echo "$RES" | jq -e . >/dev/null 2>&1 || unavailable
printf '%s\n' "$RES"
