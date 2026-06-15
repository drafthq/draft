#!/usr/bin/env bash
# graph-snapshot.sh — index the repo into the local graph engine and write the
# committed gate marker (schema.yaml).
#
# Draft is engine-only and opinionated: structural truth lives in the local
# codebase-memory-mcp engine, queried on demand via the `graph-*.sh` wrappers
# (which shell out to `codebase-memory-mcp cli <tool>`). There is no committed
# machine-readable mirror of the graph — no architecture.json, hotspots.jsonl,
# *.mermaid, or okf/ bundle. Those were lossy, went stale on the next commit, and
# duplicated what the engine serves precisely and live. Git remains the source of
# truth; the engine is the structural index over it.
#
# Writes one file under <repo>/draft/graph/:
#   schema.yaml   engine + project metadata + index counts. Its presence is the
#                 GATE that tells skills the graph engine is wired for this repo
#                 (see core/shared/graph-query.md Pre-Check). It carries no graph
#                 data — every structural query goes to the live engine.
#
# Re-running on a repo that still has an old fat snapshot prunes the stale
# committed artifacts, migrating it to the thin model.
#
# Usage: scripts/tools/graph-snapshot.sh [--repo DIR] [--out DIR]
# Exit codes: 0 OK, 1 invocation error, 2 graph engine unavailable.
set -euo pipefail

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$TOOLS_DIR/_lib.sh"

REPO="."
OUT_DIR=""

usage() {
    cat <<'EOF'
graph-snapshot.sh — index the repo and write the draft/graph/ gate marker.

Indexes the repository into the local graph engine and writes draft/graph/schema.yaml
(the gate + provenance marker). It writes NO committed graph data — structural
queries run live against the engine via the graph-*.sh wrappers.

Usage:
  scripts/tools/graph-snapshot.sh [--repo DIR] [--out DIR]

Flags:
  --repo DIR  Repository root (default: cwd).
  --out DIR   Gate-marker dir (default: <repo>/draft/graph).
  --help      Show this help.

Exit 0 on success, 2 when the graph engine is unavailable (nothing written).
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

[[ -d "$REPO" ]] || { echo "ERROR: --repo '$REPO' is not a directory" >&2; exit 1; }

REPO_ABS="$(cd "$REPO" && pwd)"
SELF_REPO="$(cd "$TOOLS_DIR/../.." && pwd)"
OUT="${OUT_DIR:-$REPO_ABS/draft/graph}"

find_memory_bin "$REPO_ABS" "$SELF_REPO" || { echo "graph engine unavailable — nothing written" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 2; }

# Index on demand; this is the valuable side-effect — it ensures the engine holds
# a current index of the repo so live queries resolve.
PROJECT="$(memory_ensure_index "$REPO_ABS" || true)"
[[ -n "$PROJECT" ]] || { echo "could not index repo — nothing written" >&2; exit 2; }

mkdir -p "$OUT"

# Prune any stale fat-snapshot artifacts from a prior (pre-engine-only) run so a
# re-index migrates the repo to the thin model.
rm -f "$OUT/architecture.json" "$OUT/hotspots.jsonl" \
      "$OUT/module-deps.mermaid" "$OUT/proto-map.mermaid" 2>/dev/null || true
rm -rf "$OUT/okf" 2>/dev/null || true

# schema.yaml — provenance + gate. Counts are point-of-index provenance only;
# the live engine is authoritative.
STATUS_JSON="$(memory_cli index_status "{\"project\":\"$PROJECT\"}" || echo '{}')"
NODES="$(echo "$STATUS_JSON" | jq -r '.nodes // 0')"
EDGES="$(echo "$STATUS_JSON" | jq -r '.edges // 0')"
VER="$("$MEMORY_BIN" --version 2>/dev/null | awk '{print $NF}' || echo unknown)"
cat > "$OUT/schema.yaml" <<EOF
# Draft graph gate marker — written by scripts/tools/graph-snapshot.sh
# Draft is engine-only: this file carries NO graph data. Its presence signals that
# the local codebase-memory-mcp engine is wired for this repo. Query the engine
# live via the graph-*.sh wrappers (or \`codebase-memory-mcp cli <tool>\`).
# Counts below are point-of-index provenance; the live engine is authoritative.
engine: codebase-memory-mcp
engine_version: "$VER"
project: "$PROJECT"
generated_at: "$(date -Iseconds 2>/dev/null || date)"
indexed_nodes: $NODES
indexed_edges: $EDGES
access: engine-live
EOF

echo "Indexed $PROJECT and wrote gate marker to $OUT/schema.yaml (nodes=$NODES edges=$EDGES)"
exit 0
