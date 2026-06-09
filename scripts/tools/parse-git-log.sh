#!/usr/bin/env bash
# parse-git-log.sh — parse conventional commits into structured JSONL.
#
# Output one JSON object per commit:
# {sha, type, scope, track_id, subject, author, timestamp, files_changed}
#
# Conventional commit subject: "type(scope): subject"
# type may end in "!" to denote breaking change.
#
# track_id:
# - extracted from the scope if it matches --scope-pattern (default none)
# - OR from the subject if a literal `[TRACK-123]` / `(TRACK-123)` appears
# - else null
#
# Usage:
# scripts/tools/parse-git-log.sh [--since RANGE] [--limit N]
# [--scope-pattern REGEX] [--branch REF]
#
# Exit codes: 0 OK, 1 invocation error.
set -euo pipefail

# shellcheck source=_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

SINCE=""
LIMIT=""
SCOPE_PATTERN=""
BRANCH="HEAD"

usage() {
    cat <<'EOF'
parse-git-log.sh — parse conventional commits into JSONL.

Usage:
  scripts/tools/parse-git-log.sh [--since RANGE] [--limit N]
                                 [--scope-pattern REGEX] [--branch REF]

Flags:
  --since RANGE Passed to git log --since (e.g. "7d", "2 weeks ago").
  --limit N Max number of commits (git log -n N).
  --scope-pattern RE Extended regex; if a commit's scope matches, it becomes the track_id.
  --branch REF Branch/ref to inspect (default: HEAD).
  --help Show this help.

Output: JSONL with one record per commit.
Fields: sha, type, scope, track_id, subject, author, timestamp, files_changed
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --since) SINCE="$2"; shift 2;;
        --limit) LIMIT="$2"; shift 2;;
        --scope-pattern) SCOPE_PATTERN="$2"; shift 2;;
        --branch) BRANCH="$2"; shift 2;;
        --help|-h) usage; exit 0;;
        *) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
    esac
done

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "ERROR: not inside a git repository" >&2
    exit 1
fi

# Format: delimiter-separated metadata line, then --name-only file list, blank line separator.
GIT_ARGS=(log --pretty=tformat:'COMMIT%x1f%H%x1f%an%x1f%aI%x1f%s' --name-only --no-merges)
[[ -n "$SINCE" ]] && GIT_ARGS+=(--since="$SINCE")
[[ -n "$LIMIT" ]] && GIT_ARGS+=(-n "$LIMIT")
GIT_ARGS+=("$BRANCH")

# Read a commit block (metadata line + files) and emit one JSON record.
process_commit() {
    local sha="$1" author="$2" ts="$3" subject="$4" files_changed="$5"
    local type scope breaking clean_subject cc_re track_id token inner scope_val
    [[ -z "$sha" ]] && return

    # Parse conventional commit: type(scope)!: subject OR type: subject
    type="null"
    scope="null"
    breaking="false"
    clean_subject="$subject"
    cc_re='^([a-zA-Z]+)(\(([^)]+)\))?(!)?: (.+)$'
    if [[ "$subject" =~ $cc_re ]]; then
        type="\"${BASH_REMATCH[1]}\""
        if [[ -n "${BASH_REMATCH[3]:-}" ]]; then
            scope="\"$(json_escape "${BASH_REMATCH[3]}")\""
        fi
        [[ -n "${BASH_REMATCH[4]:-}" ]] && breaking="true"
        clean_subject="${BASH_REMATCH[5]}"
    fi

    # Track ID detection
    track_id="null"
    if [[ -n "$SCOPE_PATTERN" && "$scope" != "null" ]]; then
        scope_val="${scope#?}"
        scope_val="${scope_val%?}" # strip surrounding quotes
        if [[ "$scope_val" =~ $SCOPE_PATTERN ]]; then
            track_id="\"$(json_escape "$scope_val")\""
        fi
    fi
    # Look for [TRACK-XXX] or (TRACK-XXX) tokens in subject
    if [[ "$track_id" == "null" ]]; then
        token="$(printf '%s' "$clean_subject" | grep -oE '(\[[A-Z]+-[0-9]+\]|\([A-Z]+-[0-9]+\))' | head -1 || true)"
        if [[ -n "$token" ]]; then
            inner="${token#?}"
            inner="${inner%?}"
            track_id="\"$(json_escape "$inner")\""
        fi
    fi

    printf '{"sha":"%s","type":%s,"scope":%s,"breaking":%s,"track_id":%s,"subject":"%s","author":"%s","timestamp":"%s","files_changed":%s}\n' \
        "$sha" "$type" "$scope" "$breaking" "$track_id" \
        "$(json_escape "$clean_subject")" \
        "$(json_escape "$author")" \
        "$ts" "$files_changed"
}

# Single git log stream: each commit is `COMMIT<US>sha<US>author<US>ts<US>subject`
# followed by its file paths (one per line) and a blank separator.
cur_sha=""; cur_author=""; cur_ts=""; cur_subject=""; cur_files=0
while IFS= read -r line; do
    if [[ "$line" == COMMIT$'\x1f'* ]]; then
        if [[ -n "$cur_sha" ]]; then
            process_commit "$cur_sha" "$cur_author" "$cur_ts" "$cur_subject" "$cur_files"
        fi
        IFS=$'\x1f' read -r _ cur_sha cur_author cur_ts cur_subject <<<"$line"
        cur_files=0
    elif [[ -n "$line" ]]; then
        cur_files=$((cur_files + 1))
    fi
done < <(git "${GIT_ARGS[@]}")
if [[ -n "$cur_sha" ]]; then
    process_commit "$cur_sha" "$cur_author" "$cur_ts" "$cur_subject" "$cur_files"
fi
