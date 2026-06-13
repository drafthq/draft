#!/usr/bin/env bash
# verify-citations.sh
#
# Resolve every `path:line` and `path:line-range` citation in a track's
# Markdown against the commit pinned in `metadata.json:synced_to_commit`,
# and confirm the cited content still resides within the line window.
#
# Drift tolerance is configurable (default ±5 lines). Citations wrapped
# inside <!-- VERIFIER:IGNORE START --> ... <!-- VERIFIER:IGNORE END -->
# blocks are skipped. Citations annotated as `(planned)` or carrying a
# `[New file ...]` annotation are skipped (must not exist yet).
#
# Usage:
# scripts/tools/verify-citations.sh # scan ./tracks/*
# scripts/tools/verify-citations.sh tracks/foo # scan one
# scripts/tools/verify-citations.sh --tolerance 10 --json tracks/foo
#
# Exit codes:
# 0 clean
# 1 drift detected
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
TOLERANCE=5
TRACK_PATHS=()

usage() {
    local stream=2 code=2
    if [[ "${USAGE_HELP_MODE:-0}" == 1 ]]; then stream=1; code=0; fi
    sed -n '2,20p' "$0" >&$stream
    exit "$code"
}

while (($#)); do
    case "$1" in
        -h|--help) USAGE_HELP_MODE=1 usage ;;
        --json) EMIT_JSON=1; shift ;;
        --tolerance) TOLERANCE="$2"; shift 2 ;;
        -*) printf 'Unknown flag: %s\n' "$1" >&2; usage ;;
        *) TRACK_PATHS+=("$1"); shift ;;
    esac
done

if ((${#TRACK_PATHS[@]} == 0)); then
    while IFS= read -r p; do TRACK_PATHS+=("$p"); done < <(discover_track_dirs "$REPO_ROOT")
fi

violation_count=0
declare -a violations=()

record() {
    violations+=("$1|$2|$3|$4|$5")
    violation_count=$((violation_count + 1))
}

# Extract citations from a markdown file, skipping VERIFIER:IGNORE blocks.
# Output: file<TAB>line<TAB>cite (cite is path:LINE or path:LINE-LINE).
extract_citations() {
    local md="$1"
    awk '
        BEGIN { ignore = 0 }
        /<!-- VERIFIER:IGNORE START -->/ { ignore = 1; next }
        /<!-- VERIFIER:IGNORE END -->/ { ignore = 0; next }
        ignore == 1 { next }
        /\(planned\)|\[New file/ { next }
        {
            s = $0
            gsub(/https?:\/\/[^[:space:]]*/, "", s)
            # Use a string regex (not a /.../ literal): a literal "/" inside a
            # bracket expression prematurely terminates a regex literal in
            # POSIX/BSD awk ("nonterminated character class"), though gawk is
            # lenient. The string form is portable across awk implementations.
            while (match(s, "[A-Za-z0-9_][A-Za-z0-9_./-]*\\.[A-Za-z0-9]+:[0-9]+")) {
                cite = substr(s, RSTART, RLENGTH)
                printf("%s\t%d\t%s\n", FILENAME, NR, cite)
                s = substr(s, RSTART + RLENGTH)
            }
        }
    ' "$md"
}

# Resolve cite against the synced_to_commit content using git show.
# Returns 0 if match within tolerance, 1 if past-EOF, 2 if file truly missing.
#
# When the cite is a bare basename (no slash) and the literal path doesn't
# exist at the commit, fall back to a basename search across the tree — this
# accepts narrative citations like `foo.cc:42` that mean `path/to/foo.cc:42`.
# Skipped when multiple files share the basename (ambiguous → reject).
verify_one_citation() {
    local repo_root="$1" commit="$2" cite="$3"
    local path lo hi
    path="${cite%%:*}"
    local range="${cite#*:}"
    if [[ "$range" == *-* ]]; then
        lo="${range%%-*}"
        hi="${range##*-}"
    else
        lo="$range"
        hi="$range"
    fi
    path="${path#./}"

    local resolved_path="$path"

    # Probe via git show.
    if ! git -C "$repo_root" cat-file -e "$commit":"$path" 2>/dev/null; then
        # Bare-basename fallback: if the cite carries no slash, search the
        # tree for files whose basename matches and accept when unique.
        if [[ "$path" != */* ]]; then
            local matches
            matches="$(git -C "$repo_root" ls-tree -r --name-only "$commit" 2>/dev/null \
                | awk -v b="$path" 'BEGIN{FS="/"} $NF==b{print}')"
            local match_count
            match_count="$(printf '%s\n' "$matches" | grep -c . || true)"
            if (( match_count == 1 )); then
                resolved_path="$matches"
            elif (( match_count > 1 )); then
                printf 'ambiguous-basename|%s has %d candidates: %s\n' \
                    "$path" "$match_count" \
                    "$(printf '%s' "$matches" | tr '\n' ',' | sed 's/,$//')"
                return 1
            else
                return 2
            fi
        else
            return 2
        fi
    fi

    local total_lines
    total_lines="$(git -C "$repo_root" show "$commit":"$resolved_path" 2>/dev/null | wc -l | tr -d ' ')"
    if (( lo < 1 )); then
        printf 'invalid-line|cite %s has line < 1\n' "$cite"
        return 1
    fi
    if (( hi > total_lines + TOLERANCE )); then
        printf 'past-eof|file %s has %d lines, cite %s exceeds (+tol %d)\n' \
            "$resolved_path" "$total_lines" "$cite" "$TOLERANCE"
        return 1
    fi
    if (( lo > total_lines + TOLERANCE )); then
        printf 'past-eof|file %s has %d lines, cite %s start exceeds (+tol %d)\n' \
            "$resolved_path" "$total_lines" "$cite" "$TOLERANCE"
        return 1
    fi
    return 0
}

scan_one_track() {
    local track_dir="$1"
    local rel_track="${track_dir#"$REPO_ROOT/"}"
    local meta="$track_dir/metadata.json"
    local commit=""
    if [[ -f "$meta" ]]; then
        commit="$(read_json_str "$meta" "synced_to_commit")"
    fi
    if [[ -z "$commit" ]]; then
        # Fall back to YAML frontmatter on spec.md if present.
        [[ -f "$track_dir/spec.md" ]] && commit="$(get_yaml_field "$track_dir/spec.md" "synced_to_commit")"
    fi
    if [[ -z "$commit" ]]; then
        record "$rel_track" "no-pinned-commit" "metadata.json" "0" \
            "no synced_to_commit; cannot verify citations"
        return
    fi

    # Determine which git repo to query. Prefer the track's enclosing repo
    # (first git dir above the track_dir). Fall back to Draft repo.
    local probe="$track_dir"
    local target_repo=""
    while [[ "$probe" != "/" ]]; do
        if [[ -e "$probe/.git" ]]; then target_repo="$probe"; break; fi
        probe="$(dirname "$probe")"
    done
    [[ -z "$target_repo" ]] && target_repo="$REPO_ROOT"

    while IFS= read -r f; do
        local rel_md="${f#"$track_dir/"}"
        while IFS=$'\t' read -r md_file lineno cite; do
            local md_line="$md_file"
            local result rc=0
            # set +e to capture rc; set -e would exit on a non-zero return.
            set +e
            result="$(verify_one_citation "$target_repo" "$commit" "$cite" 2>&1)"
            rc=$?
            set -e
            if (( rc == 1 )); then
                record "$rel_track" "cite-drift" "$rel_md" "$lineno" \
                    "$cite — $result"
            elif (( rc == 2 )); then
                record "$rel_track" "cite-missing-file" "$rel_md" "$lineno" \
                    "$cite — file not present at commit $commit"
            fi
        done < <(extract_citations "$f")
    done < <(find "$track_dir" -maxdepth 1 -type f -name '*.md')
}

for t in "${TRACK_PATHS[@]}"; do
    [[ -d "$t" ]] || { record "$t" "not-a-directory" "" "0" ""; continue; }
    scan_one_track "$(cd "$t" && pwd)"
done

emit() {
    if ((EMIT_JSON)); then
        printf '{"violation_count": %d, "tolerance": %d, "violations": [\n' \
            "$violation_count" "$TOLERANCE"
        local first=1 v track kind file line detail
        # Guard the expansion: "${arr[@]}" on an empty array is an unbound-variable
        # error under `set -u` in bash <= 4.3 (e.g. macOS).
        if ((violation_count > 0)); then
            for v in "${violations[@]}"; do
                IFS='|' read -r track kind file line detail <<< "$v"
                if ((first)); then first=0; else printf ',\n'; fi
                printf ' {"track":"%s","kind":"%s","file":"%s","line":%s,"detail":"%s"}' \
                    "$(json_escape "$track")" "$(json_escape "$kind")" \
                    "$(json_escape "$file")" "${line:-0}" "$(json_escape "$detail")"
            done
        fi
        printf '\n]}\n'
    else
        if ((violation_count == 0)); then
            printf 'OK: citations clean across %d track(s) (tol=±%d).\n' \
                "${#TRACK_PATHS[@]}" "$TOLERANCE"
        else
            printf 'CITATIONS: %d violation(s) across %d track(s) (tol=±%d).\n' \
                "$violation_count" "${#TRACK_PATHS[@]}" "$TOLERANCE" >&2
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
