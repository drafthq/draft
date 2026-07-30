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
# Scoped to marketing surfaces. The Book legitimately discusses "context
# maturity" and "operational maturity" as concepts, which is a different claim.
mapfile -t SURFACES < <(git ls-files 'web/*.html' | grep -v '^web/book/' || true)
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
