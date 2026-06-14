#!/usr/bin/env bash
# okf-emit.sh — emit an Open Knowledge Format (OKF) bundle from a graph snapshot.
#
# OKF is an open, vendor-neutral spec (Google Cloud): a directory of markdown
# files with YAML frontmatter, one file per concept, where the file path is the
# concept's identity and concepts cross-link with normal markdown links. The
# only required frontmatter field is `type`. This makes Draft's knowledge graph
# portable — consumable by any OKF reader (visualizers, catalogs, other agents).
# https://cloud.google.com/blog/products/data-analytics/how-the-open-knowledge-format-can-improve-data-sharing
#
# Reads a graph snapshot's architecture.json and writes a conformant bundle:
#   index.md            type: Repository — bundle root + progressive disclosure
#   modules/<slug>.md   type: Module     — one concept per package, cross-linked
#
# Degrades gracefully: with no packages/boundaries in the snapshot it still emits
# index.md (counts, languages, hotspots) and an empty modules/ directory.
#
# Usage: scripts/tools/okf-emit.sh [--repo DIR] [--snapshot DIR] [--out DIR]
# Exit codes: 0 OK, 1 invocation error, 2 snapshot/architecture.json unavailable.
set -euo pipefail

REPO="."
SNAPSHOT=""
OUT=""

usage() {
    cat <<'EOF'
okf-emit.sh — emit an Open Knowledge Format (OKF) bundle from a graph snapshot.

Usage:
  scripts/tools/okf-emit.sh [--repo DIR] [--snapshot DIR] [--out DIR]

Flags:
  --repo DIR      Repository root (default: cwd).
  --snapshot DIR  Snapshot dir holding architecture.json (default: <repo>/draft/graph).
  --out DIR       Bundle output dir (default: <snapshot>/okf).
  --help          Show this help.

Writes index.md + modules/<slug>.md (OKF v0.1). Exit 0 on success, 2 when no
architecture.json is available (nothing emitted).
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) REPO="$2"; shift 2;;
        --snapshot) SNAPSHOT="$2"; shift 2;;
        --out) OUT="$2"; shift 2;;
        --help|-h) usage; exit 0;;
        -*) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
        *) echo "Unexpected arg: $1" >&2; usage >&2; exit 1;;
    esac
done

[[ -d "$REPO" ]] || { echo "ERROR: --repo '$REPO' is not a directory" >&2; exit 1; }
REPO_ABS="$(cd "$REPO" && pwd)"
SNAP="${SNAPSHOT:-$REPO_ABS/draft/graph}"
ARCH="$SNAP/architecture.json"
OUT="${OUT:-$SNAP/okf}"

command -v jq >/dev/null 2>&1 || { echo "jq required for OKF emit" >&2; exit 2; }
[[ -f "$ARCH" ]] || { echo "no architecture.json at $ARCH — nothing to emit" >&2; exit 2; }

# slugify a concept name into a filesystem- and link-safe identifier.
slug() {
    local s
    s="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' \
        | sed -e 's#[^a-z0-9]\{1,\}#-#g' -e 's#^-##' -e 's#-$##')"
    [[ -n "$s" ]] || s="module"
    printf '%s' "$s"
}

# escape a value for a YAML double-quoted scalar.
yesc() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '%s' "$s"
}

TS="$(date -Iseconds 2>/dev/null || date)"
PROJECT="$(jq -r '.project // "repository"' "$ARCH")"
TOTAL_NODES="$(jq -r '.total_nodes // 0' "$ARCH")"
TOTAL_EDGES="$(jq -r '.total_edges // 0' "$ARCH")"

PKGS="$(jq -r '.packages[]? | [.name, (.node_count//0), (.fan_in//0), (.fan_out//0)] | @tsv' "$ARCH")"
BOUNDS="$(jq -r '.boundaries[]? | [.from, .to, (.call_count//0)] | @tsv' "$ARCH")"

mkdir -p "$OUT/modules"

# --- One concept file per package, cross-linked via boundaries ---
PKG_COUNT=0
if [[ -n "$PKGS" ]]; then
    while IFS=$'\t' read -r name nc fi fo; do
        [[ -n "$name" ]] || continue
        PKG_COUNT=$((PKG_COUNT + 1))
        s="$(slug "$name")"
        {
            printf -- '---\n'
            printf 'type: Module\n'
            printf 'title: "%s"\n' "$(yesc "$name")"
            printf 'description: "Code module %s: %s nodes, fan-in %s, fan-out %s."\n' \
                "$(yesc "$name")" "$nc" "$fi" "$fo"
            printf 'tags: [module, knowledge-graph]\n'
            printf 'timestamp: "%s"\n' "$TS"
            printf -- '---\n\n'
            printf '# %s\n\n' "$name"
            printf 'Structural module derived from the knowledge graph. Nodes: %s, fan-in: %s, fan-out: %s.\n' \
                "$nc" "$fi" "$fo"

            # Depends on (outbound boundaries)
            outs="$(awk -F'\t' -v n="$name" '$1==n && $2!="" {print $2"\t"$3}' <<< "$BOUNDS")"
            if [[ -n "$outs" ]]; then
                printf '\n## Depends on\n\n'
                while IFS=$'\t' read -r to cc; do
                    [[ -n "$to" ]] || continue
                    printf -- '- [%s](%s.md) — %s call(s)\n' "$to" "$(slug "$to")" "$cc"
                done <<< "$outs"
            fi

            # Depended on by (inbound boundaries)
            ins="$(awk -F'\t' -v n="$name" '$2==n && $1!="" {print $1"\t"$3}' <<< "$BOUNDS")"
            if [[ -n "$ins" ]]; then
                printf '\n## Depended on by\n\n'
                while IFS=$'\t' read -r from cc; do
                    [[ -n "$from" ]] || continue
                    printf -- '- [%s](%s.md) — %s call(s)\n' "$from" "$(slug "$from")" "$cc"
                done <<< "$ins"
            fi
        } > "$OUT/modules/$s.md"
    done <<< "$PKGS"
fi

# --- Bundle root: index.md (progressive disclosure) ---
{
    printf -- '---\n'
    printf 'type: Repository\n'
    printf 'title: "%s"\n' "$(yesc "$PROJECT")"
    printf 'description: "Knowledge-graph snapshot: %s nodes, %s edges, %s modules."\n' \
        "$TOTAL_NODES" "$TOTAL_EDGES" "$PKG_COUNT"
    printf 'tags: [repository, knowledge-graph, draft]\n'
    printf 'timestamp: "%s"\n' "$TS"
    printf -- '---\n\n'
    printf '# %s\n\n' "$PROJECT"
    printf 'Open Knowledge Format bundle generated by Draft from the codebase-memory-mcp knowledge graph.\n\n'
    printf -- '- Nodes: %s\n' "$TOTAL_NODES"
    printf -- '- Edges: %s\n' "$TOTAL_EDGES"
    printf -- '- Modules: %s\n' "$PKG_COUNT"

    langs="$(jq -r '.languages[]? | "- \(.language): \(.file_count) file(s)"' "$ARCH")"
    if [[ -n "$langs" ]]; then
        printf '\n## Languages\n\n%s\n' "$langs"
    fi

    if [[ "$PKG_COUNT" -gt 0 ]]; then
        printf '\n## Modules\n\n'
        while IFS=$'\t' read -r name _ _ _; do
            [[ -n "$name" ]] || continue
            printf -- '- [%s](modules/%s.md)\n' "$name" "$(slug "$name")"
        done < <(printf '%s\n' "$PKGS" | sort)
    fi

    hot="$(jq -r '.hotspots[:10][]? | "- \(.name) — fan-in \(.fan_in)"' "$ARCH")"
    if [[ -n "$hot" ]]; then
        printf '\n## Top hotspots\n\n%s\n' "$hot"
    fi
} > "$OUT/index.md"

echo "OKF bundle written to $OUT (modules=$PKG_COUNT)"
exit 0
