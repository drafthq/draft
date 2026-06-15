#!/usr/bin/env bash
# Propagate the canonical version from package.json into every other
# version-bearing file. Single source of truth: package.json "version".
#
# Run automatically by the npm `version` lifecycle hook (see package.json),
# so `npm version <x>` updates all files atomically in the bump commit.
# Also runnable standalone: bash scripts/sync-version.sh
#
# Editorial copy (release headlines, dates, changelog prose) is NOT touched —
# only the version number is mechanical and drift-prone.
#
# Usage:
#   bash scripts/sync-version.sh
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

# Website: release pill tag + release strip version label (number only).
sed_i "s|(release-pill-tag\">v)[0-9][0-9.]*|\1${VERSION}|" web/index.html
sed_i "s|(release-strip-version\">v)[0-9][0-9.]*|\1${VERSION}|" web/index.html

echo "sync-version: all version-bearing files set to ${VERSION}"
