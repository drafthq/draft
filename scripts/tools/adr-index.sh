#!/usr/bin/env bash
# adr-index.sh — index Architecture Decision Records.
#
# Walks --root and emits a JSON {adrs:[{id,title,date,status,path,related_tracks}]}.
# Default --root is <cwd>/draft/adrs. id is derived from filename prefix (NNN-…) when
# present, else filename without extension.
#
# Usage:
# scripts/tools/adr-index.sh [--root DIR]
set -euo pipefail

# shellcheck source=_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

ROOT=""

usage() {
    cat <<'EOF'
adr-index.sh — emit a JSON index of ADR files.

Usage:
  scripts/tools/adr-index.sh [--root DIR]

Flags:
  --root DIR Directory containing ADR markdown files (default: draft/adrs).
  --help Show this help.

Reads YAML frontmatter (title, date, status, related_tracks) from each ADR file.
Output: {adrs:[{id,title,date,status,path,related_tracks}]}
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --root) ROOT="$2"; shift 2;;
        --help|-h) usage; exit 0;;
        *) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
    esac
done

if [[ -z "$ROOT" ]]; then
    ROOT="draft/adrs"
fi

if [[ ! -d "$ROOT" ]]; then
    printf '{"adrs":[]}\n'
    exit 0
fi

# Related tracks: YAML list under "related_tracks:" — one item per line like " - XYZ".
get_related_tracks() {
    local file="$1"
    awk '
        NR == 1 && /^---$/ { in_fm = 1; next }
        in_fm && /^---$/ { exit }
        in_fm {
            if ($0 ~ /^related_tracks:/) { in_list = 1; next }
            if (in_list) {
                if ($0 ~ /^[[:space:]]*-[[:space:]]+/) {
                    v = $0
                    sub(/^[[:space:]]*-[[:space:]]+/, "", v)
                    gsub(/^"/, "", v); gsub(/"$/, "", v)
                    print v
                } else if ($0 !~ /^[[:space:]]/) {
                    in_list = 0
                }
            }
        }
    ' "$file"
}

first=true
printf '{"adrs":['
while IFS= read -r -d '' file; do
    base="$(basename "$file")"
    id="${base%.md}"
    if [[ "$base" =~ ^([0-9]+)- ]]; then
        id="${BASH_REMATCH[1]}"
    fi

    title="$(get_yaml_field "$file" title)"
    date_val="$(get_yaml_field "$file" date)"
    status="$(get_yaml_field "$file" status)"

    # If no title in frontmatter, fallback to first H1.
    if [[ -z "$title" ]]; then
        title="$(grep -m1 '^# ' "$file" 2>/dev/null | sed 's/^#[[:space:]]*//' || true)"
    fi

    tracks=()
    while IFS= read -r tr; do
        [[ -n "$tr" ]] && tracks+=("$tr")
    done < <(get_related_tracks "$file")

    tr_json='['
    tr_first=true
    for t in "${tracks[@]+"${tracks[@]}"}"; do
        if $tr_first; then tr_first=false; else tr_json+=','; fi
        tr_json+="\"$(json_escape "$t")\""
    done
    tr_json+=']'

    if $first; then first=false; else printf ','; fi
    printf '\n {"id":"%s","title":"%s","date":"%s","status":"%s","path":"%s","related_tracks":%s}' \
        "$(json_escape "$id")" \
        "$(json_escape "$title")" \
        "$(json_escape "$date_val")" \
        "$(json_escape "$status")" \
        "$(json_escape "$file")" \
        "$tr_json"
done < <(find "$ROOT" -maxdepth 2 -type f -name '*.md' 2>/dev/null | sort | tr '\n' '\0')

if $first; then
    printf ']}\n'
else
    printf '\n]}\n'
fi
