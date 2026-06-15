#!/usr/bin/env bash
# parse-reports.sh — parse Draft reports (bughunt/review/tech-debt/...) and emit a structured summary.
#
# For each `*-report-*.md` under --root, extract YAML frontmatter fields and
# count severity markers in the report body.
#
# Output: JSON array of records:
# {path, report_type, track_id, generated_at, severity:{critical,high,medium,low,info}}
#
# Usage:
# scripts/tools/parse-reports.sh [--root DIR]
#
# Exit codes: 0 OK (even if no reports), 1 invocation error.
set -euo pipefail

# shellcheck source=_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

ROOT="."

usage() {
    cat <<'EOF'
parse-reports.sh — summarize Draft reports under a directory.

Usage:
  scripts/tools/parse-reports.sh [--root DIR]

Flags:
  --root DIR Directory to scan for *-report-*.md (default: cwd).
  --help Show this help.

Output: JSON array of {path, report_type, track_id, generated_at, severity}.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --root) ROOT="$2"; shift 2;;
        --help|-h) usage; exit 0;;
        *) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
    esac
done

if [[ ! -d "$ROOT" ]]; then
    echo "ERROR: --root '$ROOT' is not a directory" >&2
    exit 1
fi

# Extract YAML frontmatter fields + severity counts in a single awk pass over each file.
# Emits tab-separated: track_id<TAB>generated_at<TAB>critical<TAB>high<TAB>medium<TAB>low<TAB>info
parse_report_fields() {
    local file="$1"
    awk '
        BEGIN { in_fm = 0; past_fm = 0 }
        NR == 1 && /^---$/ { in_fm = 1; next }
        in_fm && /^---$/ { in_fm = 0; past_fm = 1; next }
        in_fm {
            if ($0 ~ /^track_id:[[:space:]]*/) {
                v = $0; sub(/^track_id:[[:space:]]*/, "", v)
                if (v ~ /^".*"$/) { v = substr(v, 2, length(v)-2) }
                sub(/[[:space:]]+$/, "", v)
                track_id = v
            } else if ($0 ~ /^generated_at:[[:space:]]*/) {
                v = $0; sub(/^generated_at:[[:space:]]*/, "", v)
                if (v ~ /^".*"$/) { v = substr(v, 2, length(v)-2) }
                sub(/[[:space:]]+$/, "", v)
                generated_at = v
            }
            next
        }
        past_fm {
            # Lowercase copy for severity detection.
            l = tolower($0)
            if (l ~ /(^|[^a-z])(severity:[[:space:]]*critical|\|[[:space:]]*critical[[:space:]]*\||^-[[:space:]]+critical:)/) crit++
            if (l ~ /(^|[^a-z])(severity:[[:space:]]*high|\|[[:space:]]*high[[:space:]]*\||^-[[:space:]]+high:)/) high++
            if (l ~ /(^|[^a-z])(severity:[[:space:]]*medium|\|[[:space:]]*medium[[:space:]]*\||^-[[:space:]]+medium:)/) med++
            if (l ~ /(^|[^a-z])(severity:[[:space:]]*low|\|[[:space:]]*low[[:space:]]*\||^-[[:space:]]+low:)/) low++
            if (l ~ /(^|[^a-z])(severity:[[:space:]]*info|\|[[:space:]]*info[[:space:]]*\||^-[[:space:]]+info:)/) info++
        }
        END {
            printf "%s\t%s\t%d\t%d\t%d\t%d\t%d", track_id, generated_at, crit+0, high+0, med+0, low+0, info+0
        }
    ' "$file"
}

first=true
printf '['
while IFS= read -r -d '' file; do
    base="$(basename "$file")"
    report_type=""
    if [[ "$base" =~ ^([a-z][a-z0-9-]+)-report- ]]; then
        report_type="${BASH_REMATCH[1]}"
    fi

    fields="$(parse_report_fields "$file")"
    IFS=$'\t' read -r track_id generated_at crit high med low info <<<"$fields" || true
    [[ "$track_id" == "null" ]] && track_id=""

    rel="${file#"$ROOT/"}"

    if $first; then first=false; else printf ','; fi
    printf '\n {"path":"%s","report_type":"%s","track_id":%s,"generated_at":"%s","severity":{"critical":%s,"high":%s,"medium":%s,"low":%s,"info":%s}}' \
        "$(json_escape "$rel")" \
        "$(json_escape "$report_type")" \
        "$([[ -n "$track_id" ]] && echo "\"$(json_escape "$track_id")\"" || echo "null")" \
        "$(json_escape "$generated_at")" \
        "${crit:-0}" "${high:-0}" "${med:-0}" "${low:-0}" "${info:-0}"
done < <(find "$ROOT" -type f -name '*-report-*.md' 2>/dev/null | sort | tr '\n' '\0')

if $first; then
    printf ']\n'
else
    printf '\n]\n'
fi
