#!/usr/bin/env bash
# Test suite for marketing-claim discipline on the website.
#
# What this tests:
# - The "Maturity Level 4/5" / seniority-conferral framing does not come back
# - The landing page ships the evidence panel that replaced it
# - The panel's findings name real files that still exist in the repo
# - The panel's example query names a tool that still exists
#
# Why: the target reader is the engineer the copy claimed to elevate. An
# unfalsifiable seniority claim discredits the true claims next to it. Concrete
# output does the opposite — but only while it stays accurate, which is what the
# file-existence assertions below enforce.
#
# Usage:
#   ./tests/test-web-claims.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/test-helpers.sh"
cd "$ROOT_DIR"

LANDING="web/index.html"

echo "=== Website claim tests ==="
echo ""

assert "landing page exists" "$([[ -f "$LANDING" ]] && echo true || echo false)"

echo "## Banned framing"
# Scoped to live marketing surfaces. Excluded: the Book, which legitimately
# discusses "context maturity" and "operational maturity" as concepts; and the
# changelog, which quotes the retired copy as the record of its removal.
mapfile -t SURFACES < <(git ls-files 'web/*.html' | grep -Ev '^web/(book|changelog)/' || true)
assert "found marketing surfaces to scan (${#SURFACES[@]})" \
    "$([[ "${#SURFACES[@]}" -gt 0 ]] && echo true || echo false)"

for pattern in "Maturity Level" "on par with Staff Engineer" "FAANG-level"; do
    hits="$(grep -n -i -F "$pattern" "${SURFACES[@]}" 2>/dev/null || true)"
    if [[ -n "$hits" ]]; then
        assert "no '$pattern' claim" "false"
        echo "$hits"
    else
        assert "no '$pattern' claim" "true"
    fi
done

echo ""
echo "## Evidence panel is present"
assert "proof panel markup exists" \
    "$(grep -q 'class="proof"' "$LANDING" && echo true || echo false)"
assert "proof panel has findings" \
    "$(grep -q 'class="proof-finding"' "$LANDING" && echo true || echo false)"
assert "proof panel shows a real query" \
    "$(grep -q 'graph-callers.sh --repo . --symbol json_escape' "$LANDING" && echo true || echo false)"
assert "proof panel styles are defined" \
    "$(grep -rq '^\.proof {' web/css/ && echo true || echo false)"

echo ""
echo "## Funnel order matches the product"
# The site must not send new users to /draft:init first — review runs with no
# setup, and putting the expensive step in front of the cheap one is the exact
# funnel inversion the zero-setup mode was built to fix.
assert "landing page states review needs no setup" \
    "$(grep -qi 'no setup' "$LANDING" && echo true || echo false)"
assert "install panel leads with /draft:review" \
    "$(grep -q 'Start here — no setup' "$LANDING" && echo true || echo false)"
assert "primary command grid puts review at step 01" \
    "$(grep -A 2 'cmd-primary-step">01' "$LANDING" | grep -q 'cmd-review' && echo true || echo false)"
assert "terminal demo opens on the zero-setup review" \
    "$(grep -q "Zero-setup mode" web/js/terminal.js && echo true || echo false)"
assert "FAQ answers the init-prerequisite question" \
    "$(grep -q 'Do I have to run' "$LANDING" && echo true || echo false)"
# JSON-LD mirrors the visible FAQ; a drifted copy is what search engines index.
assert "JSON-LD FAQ carries the same answer" \
    "$(grep -c 'Do I have to run /draft:init before I get anything?' "$LANDING" | grep -q '^1$' && echo true || echo false)"

echo ""
echo "## Author attribution"
pkg_version="$(node -p "require('./package.json').version")"
assert "landing meta author is Mayur Pise" \
    "$(grep -q '<meta name="author" content="Mayur Pise">' "$LANDING" && echo true || echo false)"
assert "SoftwareApplication JSON-LD names Mayur Pise" \
    "$(grep -A 30 '"@type": "SoftwareApplication"' "$LANDING" | grep -q '"name": "Mayur Pise"' && echo true || echo false)"
assert "footer credits Mayur Pise" \
    "$(grep -q 'Mayur Pise' "$LANDING" && echo true || echo false)"
assert "book landing names Mayur Pise as author" \
    "$(grep -q 'Mayur Pise' web/book/index.html && echo true || echo false)"
assert "package.json author is Mayur Pise" \
    "$(node -p "require('./package.json').author.name" | grep -qx 'Mayur Pise' && echo true || echo false)"
assert "plugin.json author is Mayur Pise" \
    "$(node -p "require('./.claude-plugin/plugin.json').author.name" | grep -qx 'Mayur Pise' && echo true || echo false)"

echo ""
echo "## Public counts match the repo"
helper_count="$(python3 - <<'PY'
import re
text=open("scripts/lib.sh").read()
m=re.search(r'^TOOLS=\((.*?)^\)', text, re.M|re.S)
print(sum(1 for ln in m.group(1).splitlines() if ln.strip() and not ln.strip().startswith('#') and '"' in ln))
PY
)"
assert "TOOLS array is 56 ($helper_count)" \
    "$([[ "$helper_count" == "56" ]] && echo true || echo false)"
assert "landing page says 56 helpers, not 45" \
    "$(grep -q '56 helpers' "$LANDING" && ! grep -q '45 helpers' "$LANDING" && echo true || echo false)"
assert "hero REV matches package.json ($pkg_version)" \
    "$(grep -q "REV ${pkg_version}" "$LANDING" && echo true || echo false)"
assert "command-reference rows keep homepage deep-link ids" \
    "$(grep -q 'id="cmd-review"' web/book/command-reference/index.html \
       && grep -q 'id="cmd-init"' web/book/command-reference/index.html \
       && grep -q 'id="cmd-jira"' web/book/command-reference/index.html \
       && echo true || echo false)"

echo ""
echo "## Changelog page is not stale"
site_latest="$(grep -oE 'changelog-version">v[0-9]+\.[0-9]+\.[0-9]+' web/changelog/index.html | head -n 1 | sed 's/.*">v//')"
assert "newest release on the changelog page is the shipped version ($site_latest vs $pkg_version)" \
    "$([[ "$site_latest" == "$pkg_version" ]] && echo true || echo false)"
assert "exactly one entry is tagged latest/in-progress" \
    "$([[ "$(grep -c 'changelog-tag changelog-tag--latest' web/changelog/index.html)" -eq 1 ]] && echo true || echo false)"
assert "Unreleased changelog entry is not tagged latest" \
    "$(awk '/<!-- Unreleased -->/,/<\/article>/' web/changelog/index.html | grep -q 'changelog-tag--latest' && echo false || echo true)"
assert "Unreleased changelog entry does not use a vN.N.N version token" \
    "$(awk '/<!-- Unreleased -->/,/<\/article>/' web/changelog/index.html | grep -qE 'changelog-version">v[0-9]' && echo false || echo true)"

echo ""
echo "## Cited artifacts still exist"
# Each finding names a file. A finding that points at a deleted file is worse
# than no finding — it is a checkable claim that fails when checked.
for cited in \
    scripts/tools/_graph_queries.sh \
    scripts/tools/graph-impact.sh \
    scripts/tools/check-track-hygiene.sh \
    scripts/tools/graph-callers.sh \
    CHANGELOG.md \
    docs/WORK_TRACKER.md
do
    assert "cited on the landing page and present: $cited" \
        "$([[ -f "$cited" ]] && grep -q "$(basename "$cited")" "$LANDING" && echo true || echo false)"
done

echo ""
echo "## The cited symbols are real"
assert "gq_escape exists in _graph_queries.sh" \
    "$(grep -q 'gq_escape' scripts/tools/_graph_queries.sh && echo true || echo false)"
assert "json_escape exists in _lib.sh" \
    "$(grep -q 'json_escape' scripts/tools/_lib.sh && echo true || echo false)"

finish_test "website claims"
