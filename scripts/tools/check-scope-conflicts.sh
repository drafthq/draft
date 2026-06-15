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
    while IFS= read -r p; do TRACK_PATHS+=("$p"); done < <(discover_track_dirs "$REPO_ROOT")
fi

conflict_count=0
declare -a conflicts=()
declare -a track_rels=()
declare -a track_includes=()
declare -a track_excludes=()

record() { conflicts+=("$1|$2|$3"); conflict_count=$((conflict_count + 1)); }

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
    track_rels+=("$rel")
    track_includes+=("$inc")
    track_excludes+=("$exc")
done

for ((i=0; i<${#track_rels[@]}; i++)); do
    for ((j=i+1; j<${#track_rels[@]}; j++)); do
        a="${track_rels[$i]}"
        b="${track_rels[$j]}"
        a_inc="${track_includes[$i]}"
        b_inc="${track_includes[$j]}"
        a_exc="${track_excludes[$i]}"
        b_exc="${track_excludes[$j]}"
        for tag in $a_inc; do
            [[ -z "$tag" ]] && continue
            if [[ " $b_inc " == *" $tag "* ]]; then
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
        for c in ${conflicts[@]+"${conflicts[@]}"}; do
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
            for c in ${conflicts[@]+"${conflicts[@]}"}; do
                IFS='|' read -r track kind detail <<< "$c"
                printf ' [%s] %s — %s\n' "$kind" "$track" "$detail" >&2
            done
        fi
    fi
}
emit

((conflict_count == 0))