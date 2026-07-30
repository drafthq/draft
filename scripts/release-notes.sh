#!/usr/bin/env bash
# release-notes.sh
#
# Extracts one version's section from CHANGELOG.md for use as GitHub Release
# notes.
#
# The repo had eight tags and one GitHub Release, so a visitor saw a project
# with no release history while a 32 KB changelog sat in the tree. This is the
# bridge: tag -> notes -> Release, with no hand-copying.
#
# Usage:
#   scripts/release-notes.sh 3.6.0            # section body for 3.6.0
#   scripts/release-notes.sh v3.6.0           # leading v is tolerated
#   scripts/release-notes.sh --latest         # newest released version
#   scripts/release-notes.sh --list           # every version in the changelog
#   scripts/release-notes.sh 3.6.0 --title    # prepend a release title line
#
# Exit codes:
#   0  section found and printed
#   1  no such version in the changelog
#   2  usage / runtime error

set -euo pipefail

usage() {
    cat <<'EOF'
release-notes.sh — extract a version's notes from CHANGELOG.md

Usage:
  release-notes.sh <version>     Print that version's changelog section
  release-notes.sh --latest      Print the newest released version's section
  release-notes.sh --list        List versions present in the changelog
  release-notes.sh --version-of-latest   Print just the newest version number

Options:
  --file <path>  Changelog to read (default: CHANGELOG.md at the repo root)
  --title        Prepend a "## Draft vX.Y.Z" heading
  --help, -h     Show this message

Notes:
  "Unreleased" is never treated as a version.
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHANGELOG="$REPO_ROOT/CHANGELOG.md"
WANT=""
MODE="section"
WITH_TITLE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h) usage; exit 0 ;;
        --latest) MODE="latest"; shift ;;
        --list) MODE="list"; shift ;;
        --version-of-latest) MODE="version-of-latest"; shift ;;
        --title) WITH_TITLE=1; shift ;;
        --file)
            [[ -n "${2:-}" ]] || { echo "release-notes: --file requires a value" >&2; exit 2; }
            CHANGELOG="$2"; shift 2 ;;
        -*) echo "release-notes: unknown flag '$1'" >&2; usage >&2; exit 2 ;;
        *)
            [[ -z "$WANT" ]] || { echo "release-notes: only one version may be given" >&2; exit 2; }
            WANT="$1"; shift ;;
    esac
done

[[ -f "$CHANGELOG" ]] || { echo "release-notes: no changelog at $CHANGELOG" >&2; exit 2; }

# Released versions in file order (newest first, per Keep a Changelog).
mapfile -t VERSIONS < <(grep -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' "$CHANGELOG" | sed 's/^## \[//; s/\]$//')

if [[ "$MODE" == "list" ]]; then
    [[ "${#VERSIONS[@]}" -gt 0 ]] || { echo "release-notes: no versioned sections in $CHANGELOG" >&2; exit 1; }
    printf '%s\n' "${VERSIONS[@]}"
    exit 0
fi

if [[ "$MODE" == "latest" || "$MODE" == "version-of-latest" ]]; then
    [[ "${#VERSIONS[@]}" -gt 0 ]] || { echo "release-notes: no versioned sections in $CHANGELOG" >&2; exit 1; }
    WANT="${VERSIONS[0]}"
    [[ "$MODE" == "version-of-latest" ]] && { echo "$WANT"; exit 0; }
fi

[[ -n "$WANT" ]] || { echo "release-notes: a version is required (or --latest)" >&2; usage >&2; exit 2; }

WANT="${WANT#v}"
[[ "$WANT" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "release-notes: '$WANT' is not a semver version" >&2; exit 2; }

# Body between this version's heading and the next `## ` heading, trimmed of
# leading/trailing blank lines. awk over sed/grep here because the section is a
# range with a variable-length body.
body="$(awk -v want="## [$WANT]" '
    index($0, want) == 1 { inside = 1; next }
    inside && /^## / { exit }
    inside { print }
' "$CHANGELOG" | awk '
    NF { blanks = 0; hold[++n] = $0; last = n; next }
    n  { hold[++n] = $0 }
    END { for (i = 1; i <= last; i++) print hold[i] }
')"

if [[ -z "$body" ]]; then
    # Distinguish "version absent" from "version present but empty".
    if grep -qF "## [$WANT]" "$CHANGELOG"; then
        echo "release-notes: $WANT has an empty changelog section" >&2
    else
        echo "release-notes: $WANT not found in $CHANGELOG" >&2
    fi
    exit 1
fi

if [[ "$WITH_TITLE" -eq 1 ]]; then
    echo "## Draft v$WANT"
    echo ""
fi
printf '%s\n' "$body"
