#!/usr/bin/env bash
# graph-init.sh — scope-aware, root-first knowledge-graph builder for /draft:init.
#
# Ensures the whole-repo "code graph knowledge memory" exists at the repository
# ROOT (the spine — the single structural source of truth), then builds a
# scope-local snapshot and links a sub-module's graph up to the root.
#
# Model:
#   - ROOT resolution: nearest ancestor ABOVE scope containing draft/ (bounded by
#     the git toplevel)  →  git toplevel  →  scope itself (no git / module-local).
#   - The engine is the default capability tier. If the codebase-memory-mcp binary
#     is missing it is fetched (blocking) unless --no-fetch or DRAFT_MEMORY_DISABLE.
#   - Root init (scope == root): build the whole-repo snapshot at <root>/draft/graph/.
#   - Module init (scope != root): unless --module-only, (re)build the root snapshot
#     first (the spine — index time is accepted, incremental once warm), then build
#     <scope>/draft/graph/ and write root-link.json pointing up to the root snapshot.
#
# The committed snapshot (draft/graph/) is the git-tracked memory; the engine's
# ~/.cache index is a disposable accelerator and is never committed.
#
# Usage: scripts/tools/graph-init.sh [--scope DIR] [--module-only] [--no-fetch] [--json]
# Exit codes: 0 OK, 1 invocation error, 2 graph engine unavailable.
set -euo pipefail

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$TOOLS_DIR/_lib.sh"

SCOPE="."
MODULE_ONLY=0
NO_FETCH=0
EMIT_JSON=0

usage() {
    cat <<'EOF'
graph-init.sh — scope-aware, root-first knowledge-graph builder.

Usage:
  scripts/tools/graph-init.sh [--scope DIR] [--module-only] [--no-fetch] [--json]

Flags:
  --scope DIR    Directory init was invoked in (default: cwd).
  --module-only  Do not touch the root; build only the module snapshot and mark
                 its root link "pending".
  --no-fetch     Never download the engine; degrade if it is absent (CI/tests).
  --json         Emit a machine-readable summary instead of a human report.
  --help         Show this help.

Exit 0 on success, 2 when the graph engine is unavailable (no snapshot built).
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --scope) SCOPE="$2"; shift 2;;
        --module-only) MODULE_ONLY=1; shift;;
        --no-fetch) NO_FETCH=1; shift;;
        --json) EMIT_JSON=1; shift;;
        --help|-h) usage; exit 0;;
        *) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
    esac
done

[[ -d "$SCOPE" ]] || { echo "ERROR: --scope '$SCOPE' is not a directory" >&2; exit 1; }
SCOPE_ABS="$(cd "$SCOPE" && pwd)"
SELF_REPO="$(cd "$TOOLS_DIR/../.." && pwd)"

# --- Resolve ROOT (bounded by the git toplevel; never escapes the repo) ---
GIT_TOP="$(git -C "$SCOPE_ABS" rev-parse --show-toplevel 2>/dev/null || true)"
resolve_root() {
    if [[ -z "$GIT_TOP" ]]; then printf '%s' "$SCOPE_ABS"; return; fi   # no git → module-local
    local d="$SCOPE_ABS"
    while [[ "$d" != "$GIT_TOP" && "$d" != "/" ]]; do
        d="$(dirname "$d")"
        if [[ "$d" != "$SCOPE_ABS" && -d "$d/draft" ]]; then printf '%s' "$d"; return; fi
    done
    printf '%s' "$GIT_TOP"
}
ROOT_ABS="$(resolve_root)"
IS_ROOT=0
[[ "$SCOPE_ABS" == "$ROOT_ABS" ]] && IS_ROOT=1

# --- Ensure the engine (the default tier); fetch when missing unless told not to ---
ensure_engine() {
    [[ -z "${DRAFT_MEMORY_DISABLE:-}" ]] || return 1
    find_memory_bin "$SCOPE_ABS" "$SELF_REPO" && return 0
    [[ "$NO_FETCH" -eq 0 ]] || return 1
    echo "Graph engine not found — fetching it (one-time download; this may take a while)..." >&2
    "$SELF_REPO/scripts/fetch-memory-engine.sh" >&2 2>&1 || true
    find_memory_bin "$SCOPE_ABS" "$SELF_REPO"
}

engine_unavailable() {
    if [[ "$EMIT_JSON" -eq 1 ]]; then
        printf '{"status":"unavailable","root":"%s","scope":"%s","is_root":%s}\n' \
            "$ROOT_ABS" "$SCOPE_ABS" "$IS_ROOT"
    else
        echo "WARNING: knowledge-graph engine (codebase-memory-mcp) is unavailable — no graph built." >&2
        echo "  The engine is Draft's default capability tier. Install it with:" >&2
        echo "    scripts/fetch-memory-engine.sh" >&2
        echo "  or put codebase-memory-mcp on PATH. Set DRAFT_MEMORY_DISABLE=1 to silence this." >&2
        echo "  Committed draft/graph/ snapshots (if present) still provide structural context." >&2
    fi
    exit 2
}

# Build a committed snapshot for a repo dir; returns graph-snapshot's exit code.
# Snapshot progress goes to stderr so stdout stays clean for --json consumers.
build_snapshot() {
    local rc=0
    "$TOOLS_DIR/graph-snapshot.sh" --repo "$1" 1>&2 || rc=$?
    return "$rc"
}

# Path from <module>/draft/graph back to <root>/draft/graph (module is under root).
root_link_relpath() {
    local sub="${SCOPE_ABS#"$ROOT_ABS"/}"
    local ups=2 seg
    IFS='/' read -ra seg <<< "$sub"
    ups=$(( ${#seg[@]} + 2 ))
    local i out=""
    for ((i = 0; i < ups; i++)); do out+="../"; done
    printf '%sdraft/graph' "$out"
}

write_root_link() {
    local status="$1"
    local mod_graph="$SCOPE_ABS/draft/graph"
    mkdir -p "$mod_graph"
    local rel root_project="unknown" root_commit ts schema="$ROOT_ABS/draft/graph/schema.yaml"
    rel="$(root_link_relpath)"
    if [[ -f "$schema" ]]; then
        root_project="$(grep -m1 '^project:' "$schema" 2>/dev/null | sed 's/^project:[[:space:]]*//; s/^"//; s/"$//' || true)"
        [[ -n "$root_project" ]] || root_project="unknown"
    fi
    root_commit="$(git -C "$ROOT_ABS" rev-parse --verify --quiet HEAD 2>/dev/null || echo none)"
    ts="$(date -Iseconds 2>/dev/null || date)"
    cat > "$mod_graph/root-link.json" <<EOF
{
  "root_graph": "$rel",
  "root_abs": "$ROOT_ABS/draft/graph",
  "root_project": "${root_project:-unknown}",
  "root_commit": "$root_commit",
  "status": "$status",
  "linked_at": "$ts",
  "linked_by": "graph-init.sh",
  "note": "Root is the authoritative whole-repo graph. Follow root_graph for cross-module understanding."
}
EOF
}

ensure_engine || engine_unavailable

ROOT_BUILT=0
MODULE_BUILT=0
LINK_STATUS="none"

if [[ "$IS_ROOT" -eq 1 ]]; then
    build_snapshot "$ROOT_ABS" && ROOT_BUILT=1
else
    if [[ "$MODULE_ONLY" -eq 0 ]]; then
        echo "Sub-module of $ROOT_ABS — ensuring the root code-graph spine first..." >&2
        build_snapshot "$ROOT_ABS" && ROOT_BUILT=1
    fi
    build_snapshot "$SCOPE_ABS" && MODULE_BUILT=1
    if [[ -f "$ROOT_ABS/draft/graph/schema.yaml" ]]; then
        LINK_STATUS="linked"
    else
        LINK_STATUS="pending"
    fi
    write_root_link "$LINK_STATUS"
fi

if [[ "$EMIT_JSON" -eq 1 ]]; then
    printf '{"status":"ok","root":"%s","scope":"%s","is_root":%s,"root_built":%s,"module_built":%s,"link_status":"%s"}\n' \
        "$ROOT_ABS" "$SCOPE_ABS" "$IS_ROOT" "$ROOT_BUILT" "$MODULE_BUILT" "$LINK_STATUS"
else
    echo "--- graph-init ---"
    echo "Root:  $ROOT_ABS$([[ $IS_ROOT -eq 1 ]] && echo '  (this scope is the root)')"
    [[ "$IS_ROOT" -eq 1 ]] && echo "Built whole-repo spine: $ROOT_ABS/draft/graph/"
    if [[ "$IS_ROOT" -eq 0 ]]; then
        [[ "$ROOT_BUILT" -eq 1 ]] && echo "Root spine: refreshed $ROOT_ABS/draft/graph/"
        echo "Module:    $SCOPE_ABS/draft/graph/"
        echo "Root link: $LINK_STATUS ($SCOPE_ABS/draft/graph/root-link.json)"
    fi
fi
exit 0
