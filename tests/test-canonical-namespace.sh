#!/usr/bin/env bash
# Test suite for canonical GitHub namespace consistency.
#
# What this tests:
# - No shipped surface points at the pre-migration `mayurpise/draft` repo
# - Every `marketplace add` instruction names the canonical repo
# - Every raw.githubusercontent / github.com repo URL names the canonical org
# - package.json repository / homepage / bugs agree with it
#
# Why: the repo moved mayurpise/draft -> drafthq/draft. A single stale pointer
# splits stars and backlinks across two repos and hands new users install
# instructions for the deprecated one. Author-attribution links to the personal
# profile (github.com/mayurpise with no repo path) are legitimate and allowed.
#
# Usage:
#   ./tests/test-canonical-namespace.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/test-helpers.sh"
cd "$ROOT_DIR"

CANONICAL_ORG="drafthq"
CANONICAL_REPO="drafthq/draft"

# Audit and changelog prose quote the old namespace deliberately (as history).
EXCLUDE_RE='^(docs/internal/audit/|docs/tracker/|node_modules/|\.git/)'

echo "=== Canonical namespace tests ($CANONICAL_REPO) ==="
echo ""

# Text-bearing tracked files only; binaries would produce noise.
mapfile -t FILES < <(git ls-files \
    '*.md' '*.html' '*.json' '*.sh' '*.js' '*.yml' '*.yaml' '*.css' '*.txt' \
    | grep -Ev "$EXCLUDE_RE" || true)

assert "found tracked text files to scan (${#FILES[@]})" \
    "$([[ "${#FILES[@]}" -gt 0 ]] && echo true || echo false)"

echo "## No pointers at the deprecated repo"
stale="$(grep -n -I -E 'mayurpise/(draft|Draft)\b' "${FILES[@]}" 2>/dev/null || true)"
if [[ -n "$stale" ]]; then
    assert "no 'mayurpise/draft' references" "false"
    echo "$stale"
else
    assert "no 'mayurpise/draft' references" "true"
fi

echo ""
echo "## Install instructions name the canonical repo"
bad_install="$(grep -n -I -E 'marketplace add +[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+' "${FILES[@]}" 2>/dev/null \
    | grep -v "marketplace add $CANONICAL_REPO" || true)"
if [[ -n "$bad_install" ]]; then
    assert "every 'marketplace add' uses $CANONICAL_REPO" "false"
    echo "$bad_install"
else
    assert "every 'marketplace add' uses $CANONICAL_REPO" "true"
fi

# Sanity: the assertion above is vacuous unless install instructions exist.
install_count="$(grep -c -I -E "marketplace add +$CANONICAL_REPO" "${FILES[@]}" 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')"
assert "canonical install instructions present ($install_count)" \
    "$([[ "$install_count" -gt 0 ]] && echo true || echo false)"

echo ""
echo "## Draft repo URLs name the canonical org"
# Scoped to URLs whose repo component is Draft itself — third-party links
# (shellcheck, markdownlint, the graph engine) legitimately name other owners.
bad_urls="$(grep -n -I -oiE '(raw\.githubusercontent\.com|github\.com)/[A-Za-z0-9_.-]+/draft(\.git)?\b' "${FILES[@]}" 2>/dev/null \
    | grep -viE "/${CANONICAL_ORG}/draft" || true)"
if [[ -n "$bad_urls" ]]; then
    assert "no non-canonical Draft repo URLs" "false"
    echo "$bad_urls"
else
    assert "no non-canonical Draft repo URLs" "true"
fi

canon_urls="$(grep -c -I -oiE "github\.com/${CANONICAL_ORG}/draft" "${FILES[@]}" 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')"
assert "canonical Draft repo URLs present ($canon_urls)" \
    "$([[ "$canon_urls" -gt 0 ]] && echo true || echo false)"

echo ""
echo "## package.json metadata"
repo_url="$(node -p "require('./package.json').repository.url")"
homepage="$(node -p "require('./package.json').homepage")"
bugs="$(node -p "require('./package.json').bugs.url")"
pkg_name="$(node -p "require('./package.json').name")"

assert "repository.url is canonical ($repo_url)" \
    "$([[ "$repo_url" == *"$CANONICAL_REPO"* ]] && echo true || echo false)"
assert "homepage is canonical ($homepage)" \
    "$([[ "$homepage" == *"$CANONICAL_REPO"* ]] && echo true || echo false)"
assert "bugs.url is canonical ($bugs)" \
    "$([[ "$bugs" == *"$CANONICAL_REPO"* ]] && echo true || echo false)"
assert "npm scope matches the org ($pkg_name)" \
    "$([[ "$pkg_name" == "@$CANONICAL_ORG/"* ]] && echo true || echo false)"

finish_test "canonical namespace"
