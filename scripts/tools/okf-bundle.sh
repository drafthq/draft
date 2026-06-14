#!/usr/bin/env bash
# okf-bundle.sh — make a draft/ context directory an Open Knowledge Format bundle.
#
# OKF (Google Cloud, open spec) treats a directory of markdown files with YAML
# frontmatter as a knowledge bundle: one file per concept, the file path is the
# concept's identity, concepts cross-link with markdown links, and index.md is
# the navigable root. Draft's project-doc files already carry the required
# `type` frontmatter (architecture.md, .ai-context.md, product.md, ...); this
# tool writes the bundle's root index.md so the whole draft/ tree is a portable,
# vendor-neutral OKF bundle.
# https://cloud.google.com/blog/products/data-analytics/how-the-open-knowledge-format-can-improve-data-sharing
#
# Default mode: write <dir>/index.md (type: Repository) linking every concept
#   file present, the tracks, and the graph sub-bundle (graph/okf/).
# --check mode: verify every canonical concept file present declares `type:`;
#   exit 1 listing any that do not (OKF requires `type` on every concept).
#
# Usage: scripts/tools/okf-bundle.sh [--dir DIR] [--check]
# Exit codes: 0 OK, 1 invocation error or conformance failure, 2 dir missing.
set -euo pipefail

DIR="draft"
CHECK=0

usage() {
    cat <<'EOF'
okf-bundle.sh — write the OKF root index.md for a draft/ context bundle.

Usage:
  scripts/tools/okf-bundle.sh [--dir DIR] [--check]

Flags:
  --dir DIR  Bundle root (default: draft).
  --check    Validate `type:` frontmatter on canonical concept files instead of
             writing; exit 1 if any concept file is missing it.
  --help     Show this help.

Default writes <dir>/index.md (OKF type: Repository) cross-linking every concept
present. Exit 0 OK, 1 invocation/conformance error, 2 when <dir> is absent.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir) DIR="$2"; shift 2;;
        --check) CHECK=1; shift;;
        --help|-h) usage; exit 0;;
        -*) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
        *) echo "Unexpected arg: $1" >&2; usage >&2; exit 1;;
    esac
done

[[ -d "$DIR" ]] || { echo "ERROR: --dir '$DIR' is not a directory" >&2; exit 2; }

# Canonical Draft concepts, ordered: "filename|label|expected-type".
# Each present file is linked from index.md and checked for `type:` under --check.
CONCEPTS=(
    ".ai-profile.md|AI Profile|Profile"
    ".ai-context.md|AI Context Map|ContextMap"
    "architecture.md|Architecture|Architecture"
    "product.md|Product|Product"
    "tech-stack.md|Tech Stack|TechStack"
    "workflow.md|Workflow|Workflow"
    "guardrails.md|Guardrails|Guardrails"
    "service-index.md|Service Index|ServiceIndex"
)

# read_fm_field FILE FIELD — print a top-level frontmatter scalar (quotes stripped).
read_fm_field() {
    awk -v field="$2" '
        NR==1 { if ($0 != "---") exit; next }
        /^---[[:space:]]*$/ { exit }
        {
            if (index($0, field ":") == 1) {
                sub("^" field ":[[:space:]]*", "")
                gsub(/^"|"$/, "")
                print
                exit
            }
        }
    ' "$1"
}

# --- --check: enforce `type:` on every present concept file ---
if [[ "$CHECK" == "1" ]]; then
    missing=()
    for entry in "${CONCEPTS[@]}"; do
        IFS='|' read -r fname _ _ <<< "$entry"
        [[ -f "$DIR/$fname" ]] || continue
        [[ -n "$(read_fm_field "$DIR/$fname" type)" ]] || missing+=("$fname")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "OKF conformance FAIL — concept files missing required 'type:' frontmatter:" >&2
        printf '  %s\n' "${missing[@]}" >&2
        exit 1
    fi
    echo "OKF conformance OK — all present concept files declare 'type:'."
    exit 0
fi

# --- default: write the bundle root index.md ---
TS="$(date -Iseconds 2>/dev/null || date)"

PROJECT=""
for probe in architecture.md .ai-context.md product.md .ai-profile.md; do
    if [[ -f "$DIR/$probe" ]]; then
        PROJECT="$(read_fm_field "$DIR/$probe" project)"
        [[ -n "$PROJECT" ]] && break
    fi
done
[[ -n "$PROJECT" && "$PROJECT" != "{PROJECT_NAME}" ]] || PROJECT="$(basename "$(cd "$DIR/.." && pwd)")"

INDEX="$DIR/index.md"
{
    printf -- '---\n'
    printf 'type: Repository\n'
    printf 'title: "%s"\n' "$PROJECT"
    printf 'description: "Draft context bundle (Open Knowledge Format root index)."\n'
    printf 'tags: [repository, draft, knowledge-bundle]\n'
    printf 'timestamp: "%s"\n' "$TS"
    printf -- '---\n\n'
    printf '# %s — Draft Context Bundle\n\n' "$PROJECT"
    printf 'Open Knowledge Format (OKF) bundle root. Each concept below is a markdown file\n'
    printf 'with a `type` frontmatter field; the links form the navigable knowledge graph.\n'

    # Context concepts (only if at least one is present)
    context=""
    for entry in "${CONCEPTS[@]}"; do
        IFS='|' read -r fname label expected <<< "$entry"
        [[ -f "$DIR/$fname" ]] || continue
        t="$(read_fm_field "$DIR/$fname" type)"
        [[ -n "$t" ]] || t="$expected"
        context+="$(printf -- '- [%s](%s) — `%s`' "$label" "$fname" "$t")"$'\n'
    done
    if [[ -n "$context" ]]; then
        printf '\n## Context\n\n%s' "$context"
    fi

    # Tracks
    if [[ -f "$DIR/tracks.md" || -d "$DIR/tracks" ]]; then
        printf '\n## Tracks\n\n'
        [[ -f "$DIR/tracks.md" ]] && printf -- '- [Track Index](tracks.md)\n'
        if [[ -d "$DIR/tracks" ]]; then
            for td in "$DIR"/tracks/*/; do
                [[ -d "$td" ]] || continue
                id="$(basename "$td")"
                [[ -f "$td/spec.md" ]] || continue
                title="$id"
                if command -v jq >/dev/null 2>&1 && [[ -f "$td/metadata.json" ]]; then
                    mt="$(jq -r '.title // empty' "$td/metadata.json" 2>/dev/null || true)"
                    [[ -n "$mt" ]] && title="$mt"
                fi
                printf -- '- [%s](tracks/%s/spec.md)\n' "$title" "$id"
            done
        fi
    fi

    # Knowledge graph sub-bundle
    if [[ -f "$DIR/graph/okf/index.md" ]]; then
        printf '\n## Knowledge graph\n\n'
        printf -- '- [Graph bundle](graph/okf/index.md) — `Repository`\n'
    fi
} > "$INDEX"

echo "OKF bundle root written to $INDEX"
exit 0
