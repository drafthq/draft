#!/usr/bin/env bash
# verify-doc-anchors.sh

#
# Verify cross-document references in a track:
# - <doc>.md#<anchor> markdown anchors → resolve <anchor> against the
# target file's header slugs.
# - (planned) / [New file ...] annotations → file MUST NOT exist locally.
#
# Plain-prose `§X.Y` references are deliberately NOT validated: authors use them
# as shorthand for an external doc (`architecture.md §20.2`) without naming the
# file on the same line, so attribution is guesswork. A track that wants a
# machine-checkable §-reference writes it as a markdown link to the heading,
# which the anchor check above already covers.
#
# Skips content inside <!-- VERIFIER:IGNORE START --> ... END --> blocks.
#
# Usage:
# scripts/tools/verify-doc-anchors.sh # scan ./tracks/*
# scripts/tools/verify-doc-anchors.sh tracks/foo # scan one
# scripts/tools/verify-doc-anchors.sh --json ...
#
# Exit codes:
# 0 clean
# 1 anchor violation
# 2 usage / runtime error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

EMIT_JSON=0
TRACK_PATHS=()

usage() {
    local stream=2 code=2
    if [[ "${USAGE_HELP_MODE:-0}" == 1 ]]; then stream=1; code=0; fi
    sed -n '2,26p' "$0" >&$stream
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

violation_count=0
declare -a violations=()
record() { violations+=("$1|$2|$3|$4|$5"); violation_count=$((violation_count + 1)); }

# Build a deduplicated list of header slugs from a markdown file.
# Standard GitHub-flavored slug: lowercase, spaces → '-', strip punctuation.
md_slugs() {
    awk '
        /^#{1,6} +/ {
            s = $0
            sub(/^#+ +/, "", s)
            # Strip trailing whitespace
            sub(/[[:space:]]+$/, "", s)
            # Lowercase
            s = tolower(s)
            # Replace spaces with dashes
            gsub(/ +/, "-", s)
            # Strip punctuation except dashes and underscores. GitHub keeps `_`
            # in a heading slug (and so does _lib.sh:gfm_slug) — stripping it
            # here reported every valid #foo_bar-style anchor as missing.
            gsub(/[^a-z0-9_-]/, "", s)
            print s
        }
    ' "$1" | sort -u
}

scan_md() {
    local track_dir="$1" md="$2"
    local rel_track="${track_dir#"$REPO_ROOT/"}"
    local rel_md="${md#"$track_dir/"}"
    local ignore=0 lineno=0
    while IFS= read -r line; do
        lineno=$((lineno + 1))
        if [[ "$line" == *"<!-- VERIFIER:IGNORE START -->"* ]]; then ignore=1; continue; fi
        if [[ "$line" == *"<!-- VERIFIER:IGNORE END -->"* ]]; then ignore=0; continue; fi
        (( ignore )) && continue

        # 1. Markdown anchor references like ./hld.md#section-name
        if echo "$line" | grep -qE '\([^)]*\.md#[A-Za-z0-9_-]+\)'; then
            local m
            while IFS= read -r m; do
                m="${m#(}"; m="${m%)}"
                local path="${m%%#*}"
                local anchor="${m##*#}"
                local target
                if [[ "$path" == /* ]]; then
                    target="$path"
                else
                    target="$track_dir/${path#./}"
                fi
                if [[ ! -f "$target" ]]; then
                    record "$rel_track" "missing-doc" "$rel_md" "$lineno" \
                        "anchor target file not found: $path"
                    continue
                fi
                if ! md_slugs "$target" | grep -Fxq "$anchor"; then
                    record "$rel_track" "missing-anchor" "$rel_md" "$lineno" \
                        "$path has no slug '$anchor'"
                fi
            done < <(echo "$line" | grep -oE '\([^)]*\.md#[A-Za-z0-9_-]+\)')
        fi

        # 2. (planned) / [New file ...] annotations: the path mentioned on the
        # same line must NOT yet exist relative to the track.
        #
        # Only fire when the line has EXACTLY one path-looking token. Lines
        # with multiple paths (e.g. "Flag X (planned) — wired per `spec.md`")
        # make attribution ambiguous; the validator should not guess which
        # token the `(planned)` annotation owns.
        if echo "$line" | grep -qE '\(planned\)|\[New file'; then
            local paths
            paths="$(echo "$line" | grep -oE '[A-Za-z][A-Za-z0-9_./-]*\.[A-Za-z]+' | sort -u || true)"
            local path_count
            path_count="$(printf '%s\n' "$paths" | grep -c . || true)"
            if (( path_count == 1 )); then
                local p="$paths"
                local rel="${p#./}"
                if [[ -e "$track_dir/$rel" ]]; then
                    record "$rel_track" "planned-file-exists" "$rel_md" "$lineno" \
                        "$p annotated planned but exists at $track_dir/$rel"
                fi
            fi
        fi
    done < "$md"
}

for t in "${TRACK_PATHS[@]}"; do
    [[ -d "$t" ]] || { record "$t" "not-a-directory" "" "0" ""; continue; }
    track_dir="$(cd "$t" && pwd)"
    while IFS= read -r f; do
        scan_md "$track_dir" "$f"
    done < <(find "$track_dir" -maxdepth 1 -type f -name '*.md')
done

emit() {
    if ((EMIT_JSON)); then
        printf '{"violation_count": %d, "violations": [\n' "$violation_count"
        local first=1 v track kind file line detail
        for v in ${violations[@]+"${violations[@]}"}; do
            IFS='|' read -r track kind file line detail <<< "$v"
            if ((first)); then first=0; else printf ',\n'; fi
            printf ' {"track":"%s","kind":"%s","file":"%s","line":%s,"detail":"%s"}' \
                "$(json_escape "$track")" "$(json_escape "$kind")" \
                "$(json_escape "$file")" "${line:-0}" "$(json_escape "$detail")"
        done
        printf '\n]}\n'
    else
        if ((violation_count == 0)); then
            printf 'OK: anchors clean across %d track(s).\n' "${#TRACK_PATHS[@]}"
        else
            printf 'ANCHORS: %d violation(s) across %d track(s).\n' \
                "$violation_count" "${#TRACK_PATHS[@]}" >&2
            local v track kind file line detail
            for v in ${violations[@]+"${violations[@]}"}; do
                IFS='|' read -r track kind file line detail <<< "$v"
                printf ' [%s] %s/%s:%s — %s\n' "$kind" "$track" "$file" "$line" "$detail" >&2
            done
        fi
    fi
}
emit

((violation_count == 0))
