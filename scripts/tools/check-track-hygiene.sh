#!/usr/bin/env bash
# check-track-hygiene.sh
#
# Hygiene validator for Draft tracks. Enforces WS-1 contract from
# core/shared/template-hygiene.md. Generic across any project, any track,
# any domain.
#
# Checks per track:
# 1. Status parity: metadata.json:status vs Markdown "Status:" lines.
# 2. Author resolution: no Author1 / xxx@*.com / [name] placeholders.
# 3. Approver placeholders: no empty cells in Approval-bearing tables.
# 4. TBD budget: per-doc cap depends on metadata.json:status.
# 5. Plan staleness (WS-6 chain): plan.md generated_at not older than HLD/LLD.
#
# Usage:
# scripts/tools/check-track-hygiene.sh # scan all ./tracks/*
# scripts/tools/check-track-hygiene.sh tracks/foo # scan one
# scripts/tools/check-track-hygiene.sh --json ... # JSON output
#
# Exit codes:
# 0 clean
# 1 hygiene violation
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
    sed -n '2,21p' "$0" >&$stream
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

# Patterns
FORBIDDEN_AUTHOR_RE='Author[0-9]+|xxx@(|example)\.(com|org)|\[name\]'
EMPTY_APPROVAL_ROW_RE='^\|[^|]*\|[[:space:]]*\|[[:space:]]*\|[[:space:]]*\|[[:space:]]*\|[[:space:]]*$'
TBD_RE='_TBD_[A-Za-z0-9_]+_'

violation_count=0
declare -a violations=()

record() {
    local track="$1" kind="$2" file="$3" line="$4" detail="$5"
    violations+=("$track|$kind|$file|$line|$detail")
    violation_count=$((violation_count + 1))
}

scan_one_track() {
    local track_dir="$1"
    local rel_track="${track_dir#"$REPO_ROOT/"}"
    local meta="$track_dir/metadata.json"

    local meta_status="draft"
    if [[ -f "$meta" ]]; then
        local s
        s="$(read_json_str "$meta" "status")"
        [[ -n "$s" ]] && meta_status="$s"
    fi

    # 1. Status parity: search for "Status:" lines in markdown.
    while IFS= read -r f; do
        local rel_file="${f#"$track_dir/"}"
        local n=0
        while IFS= read -r line; do
            n=$((n + 1))
            case "$line" in
                Status:*|*"**Status:**"*|*"Status: [x] Complete"*)
                    # Heuristic: if metadata says draft but doc says Complete, mismatch.
                    if [[ "$meta_status" != "completed" ]] && [[ "$line" == *'[x] Complete'* ]]; then
                        record "$rel_track" "status-mismatch" "$rel_file" "$n" \
                            "metadata.status=$meta_status, doc says Complete"
                    fi
                    ;;
            esac
        done < "$f"
    done < <(find "$track_dir" -maxdepth 1 -type f -name '*.md')

    # 2. Forbidden author placeholders.
    while IFS= read -r f; do
        local rel_file="${f#"$track_dir/"}"
        while IFS= read -r match; do
            local n
            n="${match%%:*}"
            local rest="${match#*:}"
            record "$rel_track" "forbidden-author" "$rel_file" "$n" "$rest"
        done < <(grep -nE "$FORBIDDEN_AUTHOR_RE" "$f" 2>/dev/null || true)
    done < <(find "$track_dir" -maxdepth 1 -type f -name '*.md')

    # 3. Approval-bearing tables: detect empty cells.
    while IFS= read -r f; do
        local rel_file="${f#"$track_dir/"}"
        local in_table=0
        local n=0
        while IFS= read -r line; do
            n=$((n + 1))
            # Detect a markdown table header starting with | Role |
            if echo "$line" | grep -qiE '^\|[[:space:]]*role[[:space:]]*\|'; then
                in_table=1
                continue
            fi
            # Detect end of table: blank line.
            if ((in_table)) && [[ -z "$line" ]]; then
                in_table=0
                continue
            fi
            if ((in_table)) && [[ "$line" =~ $EMPTY_APPROVAL_ROW_RE ]]; then
                record "$rel_track" "empty-approver" "$rel_file" "$n" "$line"
            fi
        done < "$f"
    done < <(find "$track_dir" -maxdepth 1 -type f -name '*.md')

    # 4. TBD budget per-doc.
    case "$meta_status" in
        draft|archived) ;;
        ready-for-review|in_progress)
            local tbd_cap=3
            while IFS= read -r f; do
                local rel_file="${f#"$track_dir/"}"
                local count
                count="$(grep -oE "$TBD_RE" "$f" 2>/dev/null | wc -l | tr -d ' ')"
                if (( count > tbd_cap )); then
                    record "$rel_track" "tbd-over-cap" "$rel_file" "0" \
                        "$count TBD sentinel(s) (cap $tbd_cap at status=$meta_status)"
                fi
            done < <(find "$track_dir" -maxdepth 1 -type f -name '*.md')
            ;;
        completed)
            while IFS= read -r f; do
                local rel_file="${f#"$track_dir/"}"
                local count
                count="$(grep -oE "$TBD_RE" "$f" 2>/dev/null | wc -l | tr -d ' ')"
                if (( count > 0 )); then
                    record "$rel_track" "tbd-in-completed" "$rel_file" "0" \
                        "$count TBD sentinel(s) at status=completed"
                fi
            done < <(find "$track_dir" -maxdepth 1 -type f -name '*.md')
            ;;
    esac

    # 5. Plan staleness vs HLD/LLD (WS-6).
    if [[ -f "$track_dir/plan.md" ]]; then
        local plan_ts hld_ts lld_ts
        plan_ts="$(get_yaml_field "$track_dir/plan.md" "generated_at" || true)"
        [[ -f "$track_dir/hld.md" ]] && hld_ts="$(get_yaml_field "$track_dir/hld.md" "generated_at" || true)"
        [[ -f "$track_dir/lld.md" ]] && lld_ts="$(get_yaml_field "$track_dir/lld.md" "generated_at" || true)"
        for sib_ts_pair in "hld.md|$hld_ts" "lld.md|$lld_ts"; do
            local sib="${sib_ts_pair%%|*}"
            local sib_ts="${sib_ts_pair#*|}"
            [[ -z "$sib_ts" || -z "$plan_ts" ]] && continue
            # Lexicographic compare works on ISO-8601 strings.
            if [[ "$plan_ts" < "$sib_ts" ]]; then
                record "$rel_track" "stale-plan" "plan.md" "0" \
                    "plan.md generated_at=$plan_ts older than $sib generated_at=$sib_ts"
            fi
        done
    fi
}

# Self-check: git identity must be set.
if ! git config user.name >/dev/null 2>&1 || ! git config user.email >/dev/null 2>&1; then
    printf 'check-track-hygiene: WARNING — git user.name/user.email not configured.\n' >&2
fi

for t in "${TRACK_PATHS[@]}"; do
    [[ -d "$t" ]] || { record "$t" "not-a-directory" "" "0" ""; continue; }
    scan_one_track "$(cd "$t" && pwd)"
done

emit() {
    if ((EMIT_JSON)); then
        printf '{"violation_count": %d, "violations": [\n' "$violation_count"
        local first=1 v track kind file line detail
        for v in "${violations[@]}"; do
            IFS='|' read -r track kind file line detail <<< "$v"
            if ((first)); then first=0; else printf ',\n'; fi
            printf ' {"track":"%s","kind":"%s","file":"%s","line":%s,"detail":"%s"}' \
                "$(json_escape "$track")" "$(json_escape "$kind")" \
                "$(json_escape "$file")" "${line:-0}" "$(json_escape "$detail")"
        done
        printf '\n]}\n'
    else
        if ((violation_count == 0)); then
            printf 'OK: clean across %d track(s).\n' "${#TRACK_PATHS[@]}"
        else
            printf 'HYGIENE: %d violation(s) across %d track(s).\n' \
                "$violation_count" "${#TRACK_PATHS[@]}" >&2
            local v track kind file line detail
            for v in "${violations[@]}"; do
                IFS='|' read -r track kind file line detail <<< "$v"
                printf ' [%s] %s/%s:%s — %s\n' "$kind" "$track" "$file" "$line" "$detail" >&2
            done
        fi
    fi
}
emit

((violation_count == 0))
