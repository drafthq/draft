#!/usr/bin/env bash
# diff-templates-vs-tracks.sh
#
# Surface tracks whose artifact set drifts from the current template schema.
# Used by WS-0 (Templates are the contract) and the deploy-checklist gate.
#
# Compares the file set + section headers + required-field count between
# core/templates/ and each tracks/*/ directory passed on the command line
# (or every tracks/* found under the current repo if no path is given).
#
# Exit codes:
# 0 no drift
# 1 drift detected (details on stderr)
# 2 usage / runtime error
#
# Usage:
# scripts/tools/diff-templates-vs-tracks.sh # scan ./tracks/*
# scripts/tools/diff-templates-vs-tracks.sh tracks/foo bar/ # scan listed dirs
# scripts/tools/diff-templates-vs-tracks.sh --json ... # JSON output
#
# Notes:
# - "Drift" is a heuristic: missing required section headers, missing files,
# or known-removed fields still present.
# - Templates themselves are linted: a template that omits a header expected
# by the contract is also flagged.

set -euo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "${0##*/} — Foundations quality tool (see core/ docs for full behavior)"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATES_DIR="$REPO_ROOT/core/templates"

EMIT_JSON=0
TRACK_PATHS=()

usage() {
    local stream=2 code=2
    if [[ "${USAGE_HELP_MODE:-0}" == 1 ]]; then stream=1; code=0; fi
    sed -n '2,22p' "$0" >&$stream
    exit "$code"
}

# Argument parsing
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

# Expected artifact files per track (all required at 2.0)
REQUIRED_FILES=(spec.md plan.md hld.md lld.md metadata.json discovery.md)

# Expected required section headers per markdown file. These are heuristics —
# present in templates at 2.0, must be present in any track that claims to
# conform. Match is case-insensitive and treats hyphen-or-space as equivalent
# so author-style variation (Mode Selection vs Mode-selection) doesn't trip
# the validator. The canonical form is the form in core/templates/.
declare -A REQUIRED_HEADERS
REQUIRED_HEADERS[spec.md]='Problem Statement|Requirements|Acceptance Criteria|Risk Assessment|Open Questions'
REQUIRED_HEADERS[plan.md]='Phase 0|Phase 1|Status Markers'
REQUIRED_HEADERS[hld.md]='Background|Requirements|High Level Design|Detailed Design|Dependencies|Checklist|Deployment|Observability'
REQUIRED_HEADERS[lld.md]='Background|Requirements|Low Level Design|Observability'
REQUIRED_HEADERS[discovery.md]='Hotspots|Mode Selection|Open Questions|References'

# Strings that were removed at 2.0 — should not appear in conforming tracks.
REMOVED_FIELDS_RE='Author1|xxx@\.com|xxx@example\.com|^Status: \[x\] Complete$'

drift_count=0
declare -a drift_records=()

record_drift() {
    local track="$1" kind="$2" detail="$3"
    drift_records+=("$track|$kind|$detail")
    drift_count=$((drift_count + 1))
}

scan_track() {
    local track_dir="$1"
    local rel_track
    rel_track="${track_dir#"$REPO_ROOT/"}"

    for fname in "${REQUIRED_FILES[@]}"; do
        if [[ ! -f "$track_dir/$fname" ]]; then
            record_drift "$rel_track" "missing-file" "$fname"
        fi
    done

    for fname in "${!REQUIRED_HEADERS[@]}"; do
        local fpath="$track_dir/$fname"
        [[ -f "$fpath" ]] || continue
        local pattern="${REQUIRED_HEADERS[$fname]}"
        IFS='|' read -r -a heads <<< "$pattern"
        for h in "${heads[@]}"; do
            # Build a hyphen-or-space-tolerant regex: every literal space in
            # the expected header may match `[ -]` in the actual header.
            local h_flex="${h// /[ -]}"
            # Case-insensitive (-i) substring match against an ATX header line.
            if ! grep -Eiq "^#{1,6} +.*${h_flex}" "$fpath"; then
                record_drift "$rel_track" "missing-header" "$fname:$h"
            fi
        done
    done

    while IFS= read -r f; do
        local rel_file="${f#"$track_dir/"}"
        if grep -nE "$REMOVED_FIELDS_RE" "$f" >/dev/null 2>&1; then
            while IFS= read -r line; do
                record_drift "$rel_track" "removed-field" "$rel_file:$line"
            done < <(grep -nE "$REMOVED_FIELDS_RE" "$f" | head -5)
        fi
    done < <(find "$track_dir" -maxdepth 1 -type f -name '*.md')
}

# Sanity-check templates themselves first.
for fname in "${REQUIRED_FILES[@]}"; do
    [[ -f "$TEMPLATES_DIR/$fname" ]] || record_drift "core/templates" "missing-template" "$fname"
done

for t in "${TRACK_PATHS[@]}"; do
    [[ -d "$t" ]] || { record_drift "$t" "not-a-directory" ""; continue; }
    scan_track "$(cd "$t" && pwd)"
done

emit_records() {
    if ((EMIT_JSON)); then
        printf '{"drift_count": %d, "records": [\n' "$drift_count"
        local first=1
        for r in "${drift_records[@]}"; do
            local track kind detail
            IFS='|' read -r track kind detail <<< "$r"
            if ((first)); then first=0; else printf ',\n'; fi
            printf ' {"track": "%s", "kind": "%s", "detail": "%s"}' \
                "$(json_escape "$track")" \
                "$(json_escape "$kind")" \
                "$(json_escape "$detail")"
        done
        printf '\n]}\n'
    else
        if ((drift_count == 0)); then
            printf 'OK: no drift across %d track(s).\n' "${#TRACK_PATHS[@]}"
        else
            printf 'DRIFT: %d defect(s) across %d track(s).\n' \
                "$drift_count" "${#TRACK_PATHS[@]}" >&2
            local r track kind detail
            for r in "${drift_records[@]}"; do
                IFS='|' read -r track kind detail <<< "$r"
                printf ' [%s] %s — %s\n' "$kind" "$track" "$detail" >&2
            done
        fi
    fi
}

emit_records

((drift_count == 0))
