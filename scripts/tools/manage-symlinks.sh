#!/usr/bin/env bash
# manage-symlinks.sh — refresh the "<kind>-latest.md" symlink in a directory.
#
# Finds the newest file matching "<kind>-report-*.md" in DIR and points
# "<kind>-report-latest.md" at it. Selection is by filename sort order
# (timestamps embedded in filenames), not mtime, so result is reproducible.
#
# Usage:
# scripts/tools/manage-symlinks.sh <DIR> <KIND>
#
# Exit codes: 0 created/refreshed, 1 invocation error, 2 no matching files.
set -euo pipefail

DIR=""
KIND=""

usage() {
    cat <<'EOF'
manage-symlinks.sh — point "<kind>-report-latest.md" at the newest timestamped report.

Usage:
  scripts/tools/manage-symlinks.sh <DIR> <KIND>

Positional:
  DIR Directory containing <kind>-report-<timestamp>.md files.
  KIND Report kind (e.g. "bughunt", "review", "standup").

Flags:
  --help Show this help.

Selects the highest-sorted filename, creates/refreshes <kind>-report-latest.md
(relative symlink). Emits the chosen target filename to stdout.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h) usage; exit 0;;
        -*) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
        *)
            if [[ -z "$DIR" ]]; then DIR="$1"
            elif [[ -z "$KIND" ]]; then KIND="$1"
            else echo "Unexpected arg: $1" >&2; exit 1
            fi
            shift
            ;;
    esac
done

if [[ -z "$DIR" || -z "$KIND" ]]; then
    usage >&2
    exit 1
fi

if [[ ! -d "$DIR" ]]; then
    echo "ERROR: '$DIR' is not a directory" >&2
    exit 1
fi

# Validate KIND (kebab-case-ish; no slashes, dots, or spaces)
if [[ ! "$KIND" =~ ^[a-z][a-z0-9-]*$ ]]; then
    echo "ERROR: KIND must be kebab-case (got: '$KIND')" >&2
    exit 1
fi

pattern="$KIND-report-*.md"
latest_name="$KIND-report-latest.md"

# Exclude the latest symlink itself from selection.
newest=""
while IFS= read -r -d '' f; do
    base="$(basename "$f")"
    [[ "$base" == "$latest_name" ]] && continue
    # File-only (not symlink we already manage)
    if [[ -L "$f" ]]; then continue; fi
    newest="$base"
done < <(find "$DIR" -maxdepth 1 -name "$pattern" | sort | tr '\n' '\0')

if [[ -z "$newest" ]]; then
    echo "No matching $pattern files in $DIR" >&2
    exit 2
fi

(cd "$DIR" && ln -sfn "$newest" "$latest_name")
echo "$newest"
