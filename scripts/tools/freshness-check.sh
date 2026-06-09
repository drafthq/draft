#!/usr/bin/env bash
# freshness-check.sh — verify recorded file hashes against current contents.
#
# Input state file format (draft/.state/freshness.json):
# {
# "generated_at": "2026-04-22T10:00:00Z",
# "files": [
# {"path": "draft/architecture.md", "sha256": "abc..."},
# ...
# ]
# }
#
# Emits:
# {
# "fresh": true|false,
# "stale_files": ["..."],
# "missing_files": ["..."],
# "reason": "..."
# }
#
# Usage:
# scripts/tools/freshness-check.sh [--state PATH] [--root DIR]
#
# Exit codes: 0 fresh, 1 invocation error, 2 stale (still emits JSON).
set -euo pipefail

STATE_FILE=""
ROOT="."

usage() {
    cat <<'EOF'
freshness-check.sh — verify file hashes against a recorded state snapshot.

Usage:
  scripts/tools/freshness-check.sh [--state PATH] [--root DIR]

Flags:
  --state PATH Path to freshness JSON (default: <root>/draft/.state/freshness.json).
  --root DIR Repository root to resolve file paths against (default: cwd).
  --help Show this help.

Output: JSON {fresh, stale_files, missing_files, reason}.
Exit 0 fresh, 2 stale (still emits JSON), 1 invocation error.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --state) STATE_FILE="$2"; shift 2;;
        --root) ROOT="$2"; shift 2;;
        --help|-h) usage; exit 0;;
        *) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
    esac
done

if [[ ! -d "$ROOT" ]]; then
    echo "ERROR: --root '$ROOT' is not a directory" >&2
    exit 1
fi
ROOT_ABS="$(cd "$ROOT" && pwd)"

if [[ -z "$STATE_FILE" ]]; then
    STATE_FILE="$ROOT_ABS/draft/.state/freshness.json"
fi

if [[ ! -f "$STATE_FILE" ]]; then
    esc="${STATE_FILE//\\/\\\\}"; esc="${esc//\"/\\\"}"
    printf '{"fresh": false, "stale_files": [], "missing_files": [], "reason": "no state file at %s"}\n' "$esc"
    exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required" >&2
    exit 1
fi

# hash calc: prefer sha256sum; fallback shasum -a 256
sha256() {
    local f="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$f" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$f" | awk '{print $1}'
    else
        return 1
    fi
}

stale=()
missing=()

while IFS=$'\t' read -r path expected; do
    [[ -z "$path" ]] && continue
    full="$ROOT_ABS/$path"
    if [[ ! -f "$full" ]]; then
        missing+=("$path")
        continue
    fi
    actual="$(sha256 "$full")"
    if [[ "$actual" != "$expected" ]]; then
        stale+=("$path")
    fi
done < <(jq -r '.files[]? | [.path, .sha256] | @tsv' "$STATE_FILE")

fresh="true"
reason=""
if [[ ${#stale[@]} -gt 0 || ${#missing[@]} -gt 0 ]]; then
    fresh="false"
    reason="$([[ ${#stale[@]} -gt 0 ]] && echo "${#stale[@]} stale" || echo "")"
    if [[ ${#missing[@]} -gt 0 ]]; then
        if [[ -n "$reason" ]]; then reason="$reason, "; fi
        reason="${reason}${#missing[@]} missing"
    fi
fi

json_array() {
    local arr=("$@")
    if [[ ${#arr[@]} -eq 0 ]]; then
        printf '[]'
        return
    fi
    printf '['
    local first=true
    for x in "${arr[@]}"; do
        if $first; then first=false; else printf ','; fi
        # Escape quotes.
        escaped="${x//\\/\\\\}"
        escaped="${escaped//\"/\\\"}"
        printf '"%s"' "$escaped"
    done
    printf ']'
}

printf '{"fresh":%s,"stale_files":%s,"missing_files":%s,"reason":"%s"}\n' \
    "$fresh" \
    "$(json_array "${stale[@]+"${stale[@]}"}")" \
    "$(json_array "${missing[@]+"${missing[@]}"}")" \
    "$reason"

if [[ "$fresh" == "false" ]]; then
    exit 2
fi
exit 0
