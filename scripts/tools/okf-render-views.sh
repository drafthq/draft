#!/usr/bin/env bash
# okf-render-views.sh — render the demoted views from an OKF taxonomy bundle.
#
# The wiki/ bundle is the source of truth. This produces the two derived,
# human-facing views deterministically (so they never drift from the bundle and
# carry zero extra maintenance):
#   1. architecture.md  — a single linear concatenation of every concept page,
#      frontmatter stripped, in canonical section order, with a banner + TOC.
#      This is the onboarding "read one doc" view (demoted, not deleted).
#   2. Concept Map       — a routing table injected between the
#      <!-- CONCEPT-MAP:START --> / <!-- CONCEPT-MAP:END --> markers in
#      wiki/index.md (and optionally another index-root file).
#
# Usage:
#   okf-render-views.sh <BUNDLE_DIR> --arch-out <FILE> [--concept-map-into <FILE>]
#
# BUNDLE_DIR is the wiki/ directory. Exit 0 ok, 1 error, 2 bundle not found.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/tools/_lib.sh
source "$SCRIPT_DIR/_lib.sh"

BUNDLE=""
ARCH_OUT=""
CMAP_INTO=()

usage() {
    cat <<'EOF'
okf-render-views.sh — render architecture.md + Concept Map from an OKF bundle.

Usage:
  okf-render-views.sh <BUNDLE_DIR> --arch-out <FILE> [--concept-map-into <FILE>]...

Flags:
  --arch-out FILE          Write the rendered linear architecture.md here.
  --concept-map-into FILE  Inject the Concept Map between the CONCEPT-MAP markers
                           in FILE (repeatable: e.g. wiki/index.md and ai-context.md).
  --help                   Show this help.

Exit 0 ok, 1 error, 2 bundle directory not found.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --arch-out) ARCH_OUT="$2"; shift 2;;
        --concept-map-into) CMAP_INTO+=("$2"); shift 2;;
        --help|-h) usage; exit 0;;
        -*) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
        *)
            if [[ -z "$BUNDLE" ]]; then BUNDLE="$1"; else echo "Unexpected arg: $1" >&2; exit 1; fi
            shift
            ;;
    esac
done

[[ -n "$BUNDLE" ]] || { usage >&2; exit 1; }
[[ -d "$BUNDLE" ]] || { echo "ERROR: bundle directory not found: $BUNDLE" >&2; exit 2; }
BUNDLE="${BUNDLE%/}"

# Canonical section order for the linear render. Sections not present are skipped.
SECTIONS=(overview systems features reference entrypoints)

# Emit bundle-relative page paths in canonical order: for each section, its
# index.md first, then the rest alphabetically. Pages outside these sections
# (e.g. log.md, the bundle root index.md) are excluded from the linear view.
ordered_pages() {
    local sec dir f
    for sec in "${SECTIONS[@]}"; do
        dir="$BUNDLE/$sec"
        [[ -d "$dir" ]] || continue
        [[ -f "$dir/index.md" ]] && echo "$sec/index.md"
        while IFS= read -r f; do
            [[ "$(basename "$f")" == "index.md" ]] && continue
            echo "$sec/${f##*/}"
        done < <(find "$dir" -maxdepth 1 -type f -name '*.md' | sort)
    done
}

# Strip YAML frontmatter from a page (leading --- ... --- block on line 1).
strip_frontmatter() {
    awk '
        NR==1 && /^---$/ { fm=1; next }
        fm && /^---$/ { fm=0; next }
        !fm { print }
    ' "$1"
}

# --- 1. Render architecture.md ---
render_architecture() {
    local out="$1"
    local tmp; tmp="$(mktemp)"
    {
        echo "---"
        echo "generated_by: \"draft:init (okf-render-views.sh)\""
        echo "view: rendered"
        echo "source_of_truth: \"wiki/\""
        echo "---"
        echo ""
        echo "# Architecture (Rendered View)"
        echo ""
        echo "> **Generated** from the \`wiki/\` OKF bundle — do not edit by hand."
        echo "> The bundle is the source of truth; this is the single-document linear"
        echo "> view for onboarding. Regenerate with \`okf-render-views.sh\`."
        echo ""
        echo "## Contents"
        echo ""
        # TOC from page titles.
        local rel title sec last_sec=""
        while IFS= read -r rel; do
            [[ -z "$rel" ]] && continue
            sec="${rel%%/*}"
            if [[ "$sec" != "$last_sec" ]]; then
                echo "- **${sec}/**"
                last_sec="$sec"
            fi
            title="$(get_yaml_field "$BUNDLE/$rel" title)"
            [[ -n "$title" ]] || title="$rel"
            local anchor; anchor="$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-')"
            anchor="${anchor#-}"; anchor="${anchor%-}"
            echo "  - [${title}](#${anchor})"
        done < <(ordered_pages)
        echo ""
        # Body: each page, frontmatter stripped.
        while IFS= read -r rel; do
            [[ -z "$rel" ]] && continue
            echo ""
            echo "---"
            echo ""
            strip_frontmatter "$BUNDLE/$rel"
        done < <(ordered_pages)
    } >"$tmp"
    mv "$tmp" "$out"
    echo "rendered architecture view → $out ($(ordered_pages | grep -c . ) pages)"
}

# --- 2. Build the Concept Map table (stdout) ---
build_concept_map() {
    echo "| Concept | Type | Open it when… |"
    echo "|---------|------|---------------|"
    local rel type title desc
    while IFS= read -r -d '' page; do
        rel="${page#"$BUNDLE/"}"
        [[ "$(basename "$rel")" == "index.md" ]] && continue
        type="$(get_yaml_field "$page" type)"
        [[ -n "$type" ]] || continue
        title="$(get_yaml_field "$page" title)"
        [[ -n "$title" ]] || title="$rel"
        # description may be a folded (>) block — take the first non-empty body line.
        desc="$(awk '
            NR==1&&/^---$/{fm=1;next} fm&&/^---$/{exit}
            fm && /^description:/ { collect=1; sub(/^description:[[:space:]]*>?[[:space:]]*/,""); if($0!=""){print; exit} next }
            fm && collect { sub(/^[[:space:]]+/,""); if($0!=""){print; exit} }
        ' "$page")"
        echo "| [${title}](${rel}) | ${type} | ${desc} |"
    done < <(find "$BUNDLE" -type f -name '*.md' -print0 | sort -z)
}

# Inject the Concept Map between markers in a target file (path may be relative
# to BUNDLE: links in the map are bundle-relative, so the target should resolve
# them — wiki/index.md works directly; an index root above wiki/ should prefix).
inject_concept_map() {
    local target="$1" map="$2"
    [[ -f "$target" ]] || { echo "WARN: concept-map target not found: $target" >&2; return 0; }
    if ! grep -q 'CONCEPT-MAP:START' "$target" || ! grep -q 'CONCEPT-MAP:END' "$target"; then
        echo "WARN: $target has no CONCEPT-MAP markers — skipping injection" >&2
        return 0
    fi
    local tmp; tmp="$(mktemp)"
    awk -v mapfile="$map" '
        /<!-- CONCEPT-MAP:START -->/ { print; while ((getline line < mapfile) > 0) print line; close(mapfile); skip=1; next }
        /<!-- CONCEPT-MAP:END -->/ { skip=0 }
        !skip { print }
    ' "$target" >"$tmp"
    mv "$tmp" "$target"
    echo "injected Concept Map → $target"
}

[[ -n "$ARCH_OUT" ]] && render_architecture "$ARCH_OUT"

if [[ ${#CMAP_INTO[@]} -gt 0 ]]; then
    MAP_TMP="$(mktemp)"
    build_concept_map >"$MAP_TMP"
    for tgt in "${CMAP_INTO[@]}"; do
        inject_concept_map "$tgt" "$MAP_TMP"
    done
    rm -f "$MAP_TMP"
fi

[[ -n "$ARCH_OUT" || ${#CMAP_INTO[@]} -gt 0 ]] || { echo "ERROR: nothing to do (pass --arch-out and/or --concept-map-into)" >&2; exit 1; }
exit 0
