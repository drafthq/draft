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
        --repo) REPO="${2:?--repo requires a value}"; shift 2;;
        --out) OUT_DIR="${2:?--out requires a value}"; shift 2;;
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

# ...then ALWAYS re-index. memory_ensure_index calls index_repository only when the
# project is ABSENT — correct for the graph-*.sh query wrappers, which must stay
# cheap — so on an already-indexed repo this tool used to write a gate marker with a
# fresh `generated_at` over a frozen index: a deleted symbol stayed resolvable, a new
# one never appeared, and nothing in the output said so. Refreshing is this tool's
# entire job. The engine indexes incrementally, so the repeat call is cheap.
REFRESHED="$(memory_index_bounded "$REPO_ABS" 2>/dev/null | jq -r '.project // empty' 2>/dev/null || true)"
[[ -n "$REFRESHED" ]] && PROJECT="$REFRESHED"

mkdir -p "$OUT"

# Prune any stale fat-snapshot artifacts from a prior (pre-engine-only) run so a
# re-index migrates the repo to the thin model.
#
# Gated on $OUT carrying positive evidence that Draft owns it. --out is
# caller-supplied and the mkdir -p above will happily create a typo'd path, so an
# ungated `rm -rf "$OUT/okf"` turns a mistyped flag into data loss. Evidence is
# the default location, a marker from a previous run, or a prior fat snapshot
# (which always carried architecture.json / hotspots.jsonl).
draft_owns_out_dir() {
    [[ "$OUT" == "$REPO_ABS/draft/graph" ]] && return 0
    [[ -f "$OUT/schema.yaml" ]] && return 0
    [[ -f "$OUT/architecture.json" || -f "$OUT/hotspots.jsonl" ]] && return 0
    return 1
}

if draft_owns_out_dir; then
    rm -f "$OUT/architecture.json" "$OUT/hotspots.jsonl" \
          "$OUT/module-deps.mermaid" "$OUT/proto-map.mermaid" 2>/dev/null || true
    rm -rf "$OUT/okf" 2>/dev/null || true
fi

# schema.yaml — provenance + gate. Counts are point-of-index provenance only;
# the live engine is authoritative.
STATUS_JSON="$(memory_cli index_status "$(jq -n --arg p "$PROJECT" '{project:$p}')" || echo '{}')"
# Tolerate field-name variation AND non-JSON output across engine versions;
# counts are provenance only and must never abort the gate-marker write.
NODES="$(echo "$STATUS_JSON" | jq -r '.nodes // .node_count // .total_nodes // 0' 2>/dev/null || echo 0)"
EDGES="$(echo "$STATUS_JSON" | jq -r '.edges // .edge_count // .total_edges // 0' 2>/dev/null || echo 0)"
VER="$("$MEMORY_BIN" --version 2>/dev/null | awk '{print $NF}' || echo unknown)"

# Incremental-refresh provenance (graph-tooling-v2 Phase 5): the engine indexes
# incrementally (content-based, git-aware), so re-indexing only touches changed
# files. detect_changes reports that working-tree delta — recorded as provenance
# and echoed so a refresh shows what moved. Best-effort: never aborts the write.
CHANGES_JSON="$(memory_cli detect_changes "$(jq -n --arg p "$PROJECT" '{project:$p}')" 2>/dev/null || echo '{}')"
echo "$CHANGES_JSON" | jq -e . >/dev/null 2>&1 || CHANGES_JSON='{}'
CHANGED_FILES="$(echo "$CHANGES_JSON" | jq -r '.changed_count // (.changed_files | length?) // 0' 2>/dev/null || echo 0)"
IMPACTED="$(echo "$CHANGES_JSON" | jq -r '(.impacted_symbols | length?) // 0' 2>/dev/null || echo 0)"

# YAML double-quoted scalars: escape backslashes then quotes so an unusual
# project name or engine version string can never corrupt the marker.
PROJECT_Y="${PROJECT//\\/\\\\}"; PROJECT_Y="${PROJECT_Y//\"/\\\"}"
VER_Y="${VER//\\/\\\\}"; VER_Y="${VER_Y//\"/\\\"}"

cat > "$OUT/schema.yaml" <<EOF
# Draft graph gate marker — written by scripts/tools/graph-snapshot.sh
# Draft is engine-only: this file carries NO graph data. Its presence signals that
# the local codebase-memory-mcp engine is wired for this repo. Query the engine
# live via the graph-*.sh wrappers (or \`codebase-memory-mcp cli <tool>\`).
# Counts below are point-of-index provenance; the live engine is authoritative.
engine: codebase-memory-mcp
engine_version: "$VER_Y"
project: "$PROJECT_Y"
generated_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
indexed_nodes: $NODES
indexed_edges: $EDGES
changed_files: $CHANGED_FILES
impacted_symbols: $IMPACTED
access: engine-live
EOF

echo "Indexed $PROJECT and wrote gate marker to $OUT/schema.yaml (nodes=$NODES edges=$EDGES, changed_files=$CHANGED_FILES impacted_symbols=$IMPACTED)"
exit 0
