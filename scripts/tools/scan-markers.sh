#!/usr/bin/env bash
# scan-markers.sh — find TODO/FIXME/HACK/XXX/DEPRECATED markers with blame age.
#
# Emits a JSON array. Per entry:
# {path, line, marker, text, sha, author, introduced, age_days}
#
# Usage:
# scripts/tools/scan-markers.sh [--root DIR] [--markers LIST]
# [--min-age-days N] [--include-untracked]
#
# Exit codes: 0 OK (even with zero hits), 1 invocation error, 2 not a git repo
# (emits [] on stdout so consumers can still parse).
set -euo pipefail

# shellcheck source=_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

ROOT="."
MARKERS="TODO,FIXME,HACK,XXX,DEPRECATED"
MIN_AGE=0

usage() {
    cat <<'EOF'
scan-markers.sh — find code markers (TODO/FIXME/...) with git blame age.

Usage:
  scripts/tools/scan-markers.sh [--root DIR] [--markers LIST] [--min-age-days N]

Flags:
  --root DIR Root directory to scan (default: cwd).
  --markers LIST Comma-separated marker list (default: TODO,FIXME,HACK,XXX,DEPRECATED).
  --min-age-days N Only emit markers older than N days (default: 0).
  --help Show this help.

Output: JSON array of {path, line, marker, text, sha, author, introduced, age_days}.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --root) ROOT="$2"; shift 2;;
        --markers) MARKERS="$2"; shift 2;;
        --min-age-days) MIN_AGE="$2"; shift 2;;
        --help|-h) usage; exit 0;;
        *) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
    esac
done

if [[ ! -d "$ROOT" ]]; then
    echo "ERROR: --root '$ROOT' is not a directory" >&2
    exit 1
fi

cd "$ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "[]"
    exit 2
fi

# Build a regex like "\b(TODO|FIXME|HACK|XXX|DEPRECATED)\b"
IFS=',' read -ra MARK_ARRAY <<<"$MARKERS"
PATTERN_INNER="$(IFS='|'; echo "${MARK_ARRAY[*]}")"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

# Prefer ripgrep; fall back to git grep.
if command -v rg >/dev/null 2>&1; then
    rg -n --no-heading -w -e "($PATTERN_INNER)" . >"$TMP" 2>/dev/null || true
else
    git grep -n -w -E "$PATTERN_INNER" -- . >"$TMP" 2>/dev/null || true
fi

NOW_SEC="$(date -u +%s)"

emit_array() {
    local first=true
    printf '['
    while IFS= read -r _ln; do
        path="${_ln%%:*}"; rest="${_ln#*:}"; linenum="${rest%%:*}"; rest="${rest#*:}"
        [[ -z "$path" || -z "$linenum" ]] && continue
        # Skip binaries or tool's own output directory.
        [[ "$path" == */.git/* ]] && continue

        # Identify which marker matched first in this line (pure-bash, no fork).
        marker=""
        for m in "${MARK_ARRAY[@]}"; do
            if [[ "$rest" == *"$m"* ]]; then
                marker="$m"
                break
            fi
        done
        [[ -z "$marker" ]] && continue

        # Trim whitespace from text
        text="${rest#"${rest%%[![:space:]]*}"}"
        text="${text%"${text##*[![:space:]]}"}"
        # Limit text length
        if [[ ${#text} -gt 300 ]]; then
            text="${text:0:300}"
        fi

        # Blame info
        sha="null"
        author=""
        introduced=""
        age_days=0
        if blame_line="$(git blame -L "$linenum,$linenum" --porcelain -- "$path" 2>/dev/null)"; then
            blame_sha="$(echo "$blame_line" | head -1 | awk '{print $1}')"
            if [[ -n "$blame_sha" && "$blame_sha" != "0000000000000000000000000000000000000000" ]]; then
                sha="\"${blame_sha:0:7}\""
                author="$(echo "$blame_line" | awk '/^author / {sub(/^author /,""); print; exit}')"
                ts="$(echo "$blame_line" | awk '/^author-time / {print $2; exit}')"
                if [[ -n "$ts" ]]; then
                    introduced="$(date -u -d "@$ts" +%Y-%m-%d 2>/dev/null || date -u -r "$ts" +%Y-%m-%d 2>/dev/null || echo "")"
                    age_days=$(( (NOW_SEC - ts) / 86400 ))
                fi
            fi
        fi

        if [[ "$age_days" -lt "$MIN_AGE" ]]; then
            continue
        fi

        if $first; then first=false; else printf ','; fi
        printf '\n {"path":"%s","line":%s,"marker":"%s","text":"%s","sha":%s,"author":"%s","introduced":"%s","age_days":%s}' \
            "$(json_escape "$path")" \
            "$linenum" \
            "$marker" \
            "$(json_escape "$text")" \
            "$sha" \
            "$(json_escape "$author")" \
            "$(json_escape "$introduced")" \
            "$age_days"
    done <"$TMP"
    if $first; then
        printf ']\n'
    else
        printf '\n]\n'
    fi
}

emit_array
