#!/usr/bin/env bash
# Test suite for version consistency across the repo.
#
# What this tests:
# - Every version-bearing file matches package.json (the single source of truth)
#
# This is the guard that catches a hand-edited version slipping out of sync
# (e.g. bumping package.json but forgetting marketplace.json). Read-only —
# run `bash scripts/sync-version.sh` to fix any drift it reports.
#
# Usage:
#   ./tests/test-version-sync.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/test-helpers.sh"
cd "$ROOT_DIR"

echo "=== Version sync tests ==="
echo ""

VERSION="$(node -p "require('./package.json').version")"
echo "## Canonical version (package.json): $VERSION"
echo ""

# Extract the relevant version string from each consumer.
plugin_v="$(node -p "require('./.claude-plugin/plugin.json').version")"
market_v="$(node -p "require('./.claude-plugin/marketplace.json').plugins[0].version")"
cursor_v="$(node -p "require('./.cursor-plugin/plugin.json').version")"

assert ".claude-plugin/plugin.json matches ($plugin_v)"        "$([[ "$plugin_v" == "$VERSION" ]] && echo true || echo false)"
assert ".claude-plugin/marketplace.json matches ($market_v)"   "$([[ "$market_v" == "$VERSION" ]] && echo true || echo false)"
assert ".cursor-plugin/plugin.json matches ($cursor_v)"        "$([[ "$cursor_v" == "$VERSION" ]] && echo true || echo false)"

finish_test "version sync"
