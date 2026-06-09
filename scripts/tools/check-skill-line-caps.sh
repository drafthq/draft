#!/usr/bin/env bash
# check-skill-line-caps.sh
#
# Enforces per-skill line-count caps (WS-10 prompt-economy budget). Walks
# skills/**/SKILL.md and reports any file whose line count exceeds its cap.
# Caps are sourced from a config file (default scripts/tools/skill-caps.conf)
# or the SKILL_CAPS env. A skill not listed inherits the GLOBAL_CAP default.
#
# Modes:
# default warn-only (exit 0 regardless; report on stderr)
# --enforce strict (exit 1 on any over-cap skill)
#
# Usage:
# scripts/tools/check-skill-line-caps.sh # warn-only
# scripts/tools/check-skill-line-caps.sh --enforce # strict
# scripts/tools/check-skill-line-caps.sh --json
#
# Exit codes:
# 0 clean (or warn-only mode regardless of findings)
# 1 --enforce and at least one skill exceeds its cap
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
CAPS_CONF_DEFAULT="$SCRIPT_DIR/skill-caps.conf"

EMIT_JSON=0
ENFORCE=0
CAPS_CONF="$CAPS_CONF_DEFAULT"

usage() {
    local stream=2 code=2
    if [[ "${USAGE_HELP_MODE:-0}" == 1 ]]; then stream=1; code=0; fi
    sed -n '2,21p' "$0" >&$stream
    exit "$code"
}

while (($#)); do
    case "$1" in
        -h|--help) USAGE_HELP_MODE=1 usage ;;
        --enforce) ENFORCE=1; shift ;;
        --json) EMIT_JSON=1; shift ;;
        --caps) CAPS_CONF="$2"; shift 2 ;;
        -*) printf 'Unknown flag: %s\n' "$1" >&2; usage ;;
        *) printf 'Unexpected arg: %s\n' "$1" >&2; usage ;;
    esac
done

# Load caps. Format per line:
# <skill-name> <max-lines>
# Lines starting with '#' or blank are ignored. A `*` skill-name sets the
# global default cap.
declare -A CAPS
GLOBAL_CAP=600

if [[ -f "$CAPS_CONF" ]]; then
    while read -r name cap; do
        [[ -z "$name" || "$name" == \#* ]] && continue
        if [[ "$name" == "*" ]]; then
            GLOBAL_CAP="$cap"
        else
            CAPS["$name"]="$cap"
        fi
    done < "$CAPS_CONF"
fi

over_count=0
declare -a findings=()
record() { findings+=("$1|$2|$3"); over_count=$((over_count + 1)); }

while IFS= read -r path; do
    rel="${path#"$REPO_ROOT/"}"
    name="$(basename "$(dirname "$path")")"
    lines="$(wc -l < "$path" | tr -d ' ')"
    cap="${CAPS[$name]:-$GLOBAL_CAP}"
    if (( lines > cap )); then
        record "$name" "$lines" "$cap"
    fi
done < <(find "$REPO_ROOT/skills" -mindepth 2 -maxdepth 2 -name 'SKILL.md' | sort)

emit() {
    if ((EMIT_JSON)); then
        printf '{"over_cap_count": %d, "global_cap": %d, "findings": [\n' \
            "$over_count" "$GLOBAL_CAP"
        local first=1 v name lines cap
        for v in "${findings[@]}"; do
            IFS='|' read -r name lines cap <<< "$v"
            if ((first)); then first=0; else printf ',\n'; fi
            printf ' {"skill":"%s","lines":%d,"cap":%d}' \
                "$(json_escape "$name")" "$lines" "$cap"
        done
        printf '\n]}\n'
    else
        if ((over_count == 0)); then
            printf 'OK: all skills within cap (default %d).\n' "$GLOBAL_CAP"
            return
        fi
        local mode="warn-only" stream=stderr
        ((ENFORCE)) && mode="enforced"
        if ((ENFORCE)); then
            printf 'SKILL-CAPS: %d skill(s) over cap (%s):\n' \
                "$over_count" "$mode" >&2
        else
            printf 'SKILL-CAPS: %d skill(s) over cap (%s):\n' \
                "$over_count" "$mode"
        fi
        local v name lines cap
        for v in "${findings[@]}"; do
            IFS='|' read -r name lines cap <<< "$v"
            if ((ENFORCE)); then
                printf ' %s: %d lines (cap %d)\n' "$name" "$lines" "$cap" >&2
            else
                printf ' %s: %d lines (cap %d)\n' "$name" "$lines" "$cap"
            fi
        done
    fi
}
emit

if ((ENFORCE && over_count > 0)); then exit 1; fi
