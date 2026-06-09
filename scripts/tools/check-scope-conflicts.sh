#!/usr/bin/env bash
# check-scope-conflicts.sh
#
# Walks every track in the repository (or those passed on the command line),
# reads `scope_includes` / `scope_excludes` from metadata.json (preferred) or
# the spec.md frontmatter (fallback), and flags any two tracks that share an
# included scope tag without one excluding the other's tag set.
#
# Usage:
# scripts/tools/check-scope-conflicts.sh # scan ./tracks/*
# scripts/tools/check-scope-conflicts.sh tracks/foo tracks/bar
# scripts/tools/check-scope-conflicts.sh --json ...
#
# Exit codes:
# 0 no conflicts
# 1 conflicts detected
# 2 usage / runtime error

set -euo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "${0##*/} — Foundations quality tool (see core/ docs for full behavior)"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

EMIT_JSON=0
TRACK_PATHS=()

usage() {
    local stream=2 code=2
    if [[ "${USAGE_HELP_MODE:-0}" == 1 ]]; then stream=1; code=0; fi
    sed -n '2,17p' "$0" >&$stream
    exit "$code"
}

while (($#)); do
    case "$1" in
        -h|--help) USAGE_HELP_MODE=1 usage ;;
        --json) EMIT_JSON=1; shift ;;
        -*) printf 'Unknown flag: %s\n' "$1" >&2; usage ;;
        *) TRACK_PATHS+=("$1"); shift ;;
    esac
done

if ((${#TRACK_PATHS[@]} == 0)); then
    while IFS= read -r p; do TRACK_PATHS+=("$p"); done < <(
        find "$REPO_ROOT" -type d -path '*/tracks/*' -maxdepth 4 -mindepth 2 \
            -not -path '*/.*' 2>/dev/null | sort
    )
fi

conflict_count=0
declare -a conflicts=()
record() { conflicts+=("$1|$2|$3"); conflict_count=$((conflict_count + 1)); }

# Parse a JSON or YAML array field "scope_includes:" / "scope_excludes:".
# Returns space-separated tags on stdout. Anchors the array search on the
# exact key so minified single-line JSON returns the correct payload.
read_scope_array() {
    local file="$1" key="$2"
    if [[ ! -f "$file" ]]; then return 0; fi
    case "$file" in
        *.json)
            awk -v key="$key" '
                {
                    # Match "key" : [ ... ] anchored to the exact key.
                    pat = "\""key"\"[[:space:]]*:[[:space:]]*\\[[^]]*\\]"
                    if (match($0, pat)) {
                        s = substr($0, RSTART, RLENGTH)
                        sub("^\""key"\"[[:space:]]*:[[:space:]]*", "", s)
                        gsub(/[\[\]",]/, " ", s)
                        print s
                        exit
                    }
                }' "$file"
            ;;
        *.md)
            awk -v key="$key" '
                NR==1 && /^---$/ { in_fm=1; next }
                in_fm && /^---$/ { exit }
                in_fm && $0 ~ "^"key":" {
                    sub("^"key":[[:space:]]*", "", $0)
                    gsub(/[\[\]",]/, " ", $0)
                    print $0
                    exit
                }' "$file"
            ;;
    esac
}

declare -A track_includes # track_rel -> "tag1 tag2 ..."
declare -A track_excludes # track_rel -> "tag1 tag2 ..."

for t in "${TRACK_PATHS[@]}"; do
    [[ -d "$t" ]] || { record "$t" "not-a-directory" ""; continue; }
    track_dir="$(cd "$t" && pwd)"
    rel="${track_dir#"$REPO_ROOT/"}"
    inc=""; exc=""
    [[ -f "$track_dir/metadata.json" ]] && {
        inc="$(read_scope_array "$track_dir/metadata.json" scope_includes)"
        exc="$(read_scope_array "$track_dir/metadata.json" scope_excludes)"
    }
    if [[ -z "$inc" && -f "$track_dir/spec.md" ]]; then
        inc="$(read_scope_array "$track_dir/spec.md" scope_includes)"
        exc="$(read_scope_array "$track_dir/spec.md" scope_excludes)"
    fi
    track_includes["$rel"]="$inc"
    track_excludes["$rel"]="$exc"
done

# Pairwise compare.
tracks=("${!track_includes[@]}")
for ((i=0; i<${#tracks[@]}; i++)); do
    for ((j=i+1; j<${#tracks[@]}; j++)); do
        a="${tracks[$i]}"
        b="${tracks[$j]}"
        a_inc="${track_includes[$a]:-}"
        b_inc="${track_includes[$b]:-}"
        a_exc="${track_excludes[$a]:-}"
        b_exc="${track_excludes[$b]:-}"
        for tag in $a_inc; do
            [[ -z "$tag" ]] && continue
            if [[ " $b_inc " == *" $tag "* ]]; then
                # Both include `tag`. Mutual exclusion satisfied if either
                # excludes a tag in the other's includes.
                conflict=1
                for ex in $a_exc; do
                    [[ -z "$ex" ]] && continue
                    if [[ " $b_inc " == *" $ex "* ]]; then conflict=0; break; fi
                done
                if ((conflict)); then
                    for ex in $b_exc; do
                        [[ -z "$ex" ]] && continue
                        if [[ " $a_inc " == *" $ex "* ]]; then conflict=0; break; fi
                    done
                fi
                if ((conflict)); then
                    record "$a" "scope-conflict" "shares '$tag' with $b without mutual exclusion"
                fi
            fi
        done
    done
done

emit() {
    if ((EMIT_JSON)); then
        printf '{"conflict_count": %d, "conflicts": [\n' "$conflict_count"
        local first=1 c track kind detail
        for c in "${conflicts[@]}"; do
            IFS='|' read -r track kind detail <<< "$c"
            if ((first)); then first=0; else printf ',\n'; fi
            printf ' {"track":"%s","kind":"%s","detail":"%s"}' \
                "$(json_escape "$track")" "$(json_escape "$kind")" \
                "$(json_escape "$detail")"
        done
        printf '\n]}\n'
    else
        if ((conflict_count == 0)); then
            printf 'OK: no scope conflicts across %d track(s).\n' "${#TRACK_PATHS[@]}"
        else
            printf 'SCOPE: %d conflict(s) across %d track(s).\n' \
                "$conflict_count" "${#TRACK_PATHS[@]}" >&2
            local c track kind detail
            for c in "${conflicts[@]}"; do
                IFS='|' read -r track kind detail <<< "$c"
                printf ' [%s] %s — %s\n' "$kind" "$track" "$detail" >&2
            done
        fi
    fi
}
emit

((conflict_count == 0))
