#!/usr/bin/env bash
# Propagate the canonical version from package.json into every other
# version-bearing file. Single source of truth: package.json "version".
#
# Run automatically by the npm `version` lifecycle hook (see package.json),
# so `npm version <x>` updates all files atomically in the bump commit.
# Also runnable standalone: bash scripts/sync-version.sh
#
# Version-bearing files: the plugin manifests, plus the website's version labels
# — the nav version pill on every page that has one, the landing hero's REV,
# and the book landing's REV — found by their CSS class in tracked pages, so a
# new page with the nav pill is covered without editing this script, and an
# untracked work-in-progress page is never bumped or staged.
#
# Editorial copy (release headlines, dates, changelog prose) is NOT touched —
# only the version number is mechanical and drift-prone.
#
# Usage:
#   bash scripts/sync-version.sh [--stage]
#
#   --stage   git add every file this script manages (the version hook uses it,
#             so the bump commit carries them). Standalone runs leave the index alone.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

VERSION="$(node -p "require('./package.json').version")"
[[ -n "$VERSION" ]] || { echo "sync-version: could not read version from package.json" >&2; exit 1; }

# Portable in-place edit (GNU + BSD sed both accept -i<suffix>); .bak removed after.
sed_i() { sed -i.bak -E "$1" "$2" && rm -f "$2.bak"; }

# JSON: top-level / first "version" field (plugin.json, marketplace.json each have one).
sed_i "s/(\"version\":[[:space:]]*\")[0-9][^\"]*(\")/\1${VERSION}\2/" .claude-plugin/plugin.json
sed_i "s/(\"version\":[[:space:]]*\")[0-9][^\"]*(\")/\1${VERSION}\2/" .claude-plugin/marketplace.json
sed_i "s/(\"version\":[[:space:]]*\")[0-9][^\"]*(\")/\1${VERSION}\2/" .cursor-plugin/plugin.json

# Website labels: <a class="nav-version ...">vX.Y.Z</a> and <span class="hero-rev|book-rev">REV X.Y.Z ...
LABEL_RE='(class="nav-version[^"]*"[^>]*>v|class="(hero|book)-rev">REV )[0-9][^ <&]*'
LABEL_PAGES=()
while IFS= read -r page; do LABEL_PAGES+=("$page"); done < <(git ls-files -z 'web/*.html' | xargs -0 grep -lE "$LABEL_RE" | sort)
for page in "${LABEL_PAGES[@]}"; do
  sed_i "s/(class=\"nav-version[^\"]*\"[^>]*>v)[0-9][^<]*(<)/\1${VERSION}\2/; s/(class=\"(hero|book)-rev\">REV )[0-9][^ <\&]*/\1${VERSION}/" "$page"
done

if [[ "${1:-}" == "--stage" ]]; then
  git add -- .claude-plugin/plugin.json .claude-plugin/marketplace.json .cursor-plugin/plugin.json "${LABEL_PAGES[@]}"
fi

echo "sync-version: all version-bearing files set to ${VERSION} (${#LABEL_PAGES[@]} site pages)"
