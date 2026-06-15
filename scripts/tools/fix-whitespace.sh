#!/usr/bin/env bash
# fix-whitespace.sh — strip trailing whitespace and blank lines at EOF from
# AI-generated markdown files.
#
# GitHub (and git --check) rejects commits with trailing whitespace or a blank
# final line. This script normalises draft-generated markdown in-place before
# the files are committed, preventing upload failures.
#
# Usage:
# # Fix specific files:
# scripts/tools/fix-whitespace.sh <file> [<file> ...]
#
# # Fix all markdown files in a track:
# scripts/tools/fix-whitespace.sh --track <track_id>
#
# # Fix all draft-generated markdown in the repo (safe subset):
# scripts/tools/fix-whitespace.sh --draft [<repo_root>]
#
# Exit codes:
# 0 — success (all files normalised; prints list of changed files)
# 1 — invocation error
# 2 — one or more files could not be processed

set -euo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "${0##*/} — Foundations quality tool (see core/ docs for full behavior)"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$SCRIPT_DIR/_lib.sh"

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

usage() {
    sed -n '2,/^[^#]/p' "$0" | grep '^#' | sed 's/^# \?//'
}

# Fix a single file in-place.
# Returns: 0 if modified, 1 if already clean (exit code from the function,
# not the script — caller decides whether to count it).
fix_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo " SKIP (not a file): $file" >&2
        return 2
    fi
    if [[ ! -w "$file" ]]; then
        echo " ERROR (not writable): $file" >&2
        return 2
    fi

    # Empty file: nothing to normalize (avoid writing a spurious newline).
    if [[ ! -s "$file" ]]; then
        return 1
    fi

    local original
    original="$(cat "$file")"

    # 1. Strip trailing whitespace on every line (spaces and tabs).
    # 2. Strip trailing blank lines at EOF, then add exactly one final newline.
    local fixed
    fixed="$(
        printf '%s' "$original" \
        | sed 's/[[:space:]]*$//' \
        | sed -e :a -e '/^\n*$/{$d;N;ba}'
    )"$'\n'

    # Compare the bytes we would write against the file on disk — NOT the
    # command-substitution copies (which strip then re-add the trailing newline,
    # so they could never compare equal). This keeps fix_file idempotent.
    local _tmp
    _tmp="$(mktemp "${file}.XXXXXX")"
    printf '%s' "$fixed" > "$_tmp" || { rm -f "$_tmp"; return 2; }

    if cmp -s "$_tmp" "$file"; then
        rm -f "$_tmp"
        return 1 # already clean — no change on disk
    fi

    mv -f "$_tmp" "$file"
    return 0
}

# ---------------------------------------------------------------------------
# Collect target files from arguments
# ---------------------------------------------------------------------------

TARGETS=()
REPO_ROOT=""

if [[ $# -eq 0 ]]; then
    usage
    exit 0
fi

case "$1" in
    --track)
        [[ $# -ge 2 ]] || { echo "ERROR: --track requires a track_id argument." >&2; exit 1; }
        TRACK_ID="$2"
        # Determine repo root: walk up from cwd until draft/ is found.
        REPO_ROOT="$(pwd)"
        while [[ ! -d "$REPO_ROOT/draft" && "$REPO_ROOT" != "/" ]]; do
            REPO_ROOT="$(dirname "$REPO_ROOT")"
        done
        TRACK_DIR="$REPO_ROOT/draft/tracks/$TRACK_ID"
        if [[ ! -d "$TRACK_DIR" ]]; then
            echo "ERROR: track directory not found: $TRACK_DIR" >&2
            exit 1
        fi
        while IFS= read -r -d '' f; do
            TARGETS+=("$f")
        done < <(find "$TRACK_DIR" -maxdepth 1 -name "*.md" | sort | tr '\n' '\0')
        ;;
    --draft)
        REPO_ROOT="${2:-$(pwd)}"
        while [[ ! -d "$REPO_ROOT/draft" && "$REPO_ROOT" != "/" ]]; do
            REPO_ROOT="$(dirname "$REPO_ROOT")"
        done
        if [[ ! -d "$REPO_ROOT/draft" ]]; then
            echo "ERROR: could not locate draft/ directory from: ${2:-$(pwd)}" >&2
            exit 1
        fi
        # Safe subset: only files produced by draft skills.
        while IFS= read -r -d '' f; do
            TARGETS+=("$f")
        done < <(
            find "$REPO_ROOT/draft" \
                -name "architecture.md" \
                -o -name ".ai-context.md" \
                -o -name ".ai-profile.md" \
                -o -name "hld.md" \
                -o -name "lld.md" \
                -o -name "spec.md" \
                -o -name "plan.md" \
                -o -name "rca.md" \
                -o -name "guardrails.md" \
                -o -name "product.md" \
                -o -name "tech-stack.md" \
            | sort \
            | tr '\n' '\0'
        )
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    -*)
        echo "ERROR: unknown option: $1" >&2
        exit 1
        ;;
    *)
        TARGETS=("$@")
        ;;
esac

if [[ ${#TARGETS[@]} -eq 0 ]]; then
    echo "fix-whitespace: no files to process."
    exit 0
fi

# ---------------------------------------------------------------------------
# Process files
# ---------------------------------------------------------------------------

CHANGED=()
ERRORS=()

for f in "${TARGETS[@]}"; do
    rc=0
    fix_file "$f" || rc=$?
    case $rc in
        0) CHANGED+=("$f") ;;
        1) ;; # already clean — silent
        *) ERRORS+=("$f") ;;
    esac
done

if [[ ${#CHANGED[@]} -gt 0 ]]; then
    echo "fix-whitespace: normalised ${#CHANGED[@]} file(s):"
    for f in "${CHANGED[@]}"; do
        echo " $f"
    done
fi

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo "fix-whitespace: ERROR — could not process ${#ERRORS[@]} file(s):" >&2
    for f in "${ERRORS[@]}"; do
        echo " $f" >&2
    done
    exit 2
fi

