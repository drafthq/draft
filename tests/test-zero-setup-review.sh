#!/usr/bin/env bash
# Test suite for the zero-setup /draft:review contract.
#
# What this tests:
# - skills/review/SKILL.md has a Step 0 that branches on setup level
# - It no longer tells the user "Draft not initialized" and stops
# - The reference doc exists and covers scope resolution, degradation, output,
#   and the closing CTA
# - Zero-setup reports render inline instead of writing into draft/
# - core/shared/context-verify.md lists review as context-optional
# - The contract reaches the generated integrations
#
# Why: `/draft:review` is the wedge command. If it hard-requires /draft:init,
# the expensive step sits in front of the cheap one and first-time users leave
# before seeing a single finding.
#
# Usage:
#   ./tests/test-zero-setup-review.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/test-helpers.sh"
cd "$ROOT_DIR"

SKILL="skills/review/SKILL.md"
REF="skills/review/references/zero-setup-mode.md"
VERIFY="core/shared/context-verify.md"

echo "=== Zero-setup review contract tests ==="
echo ""

echo "## Files present"
assert "review SKILL.md exists"        "$([[ -f "$SKILL" ]] && echo true || echo false)"
assert "zero-setup reference exists"   "$([[ -f "$REF" ]] && echo true || echo false)"

echo ""
echo "## SKILL.md declares the mode"
assert "has a Step 0 setup-level detection section" \
    "$(grep -q '^## Step 0: Detect Setup Level' "$SKILL" && echo true || echo false)"
step0_line="$(grep -n '^## Step 0' "$SKILL" | head -n 1 | cut -d: -f1)"
step1_line="$(grep -n '^## Step 1:' "$SKILL" | head -n 1 | cut -d: -f1)"
assert "Step 0 precedes Step 1 ($step0_line < $step1_line)" \
    "$([[ -n "$step0_line" && -n "$step1_line" && "$step0_line" -lt "$step1_line" ]] && echo true || echo false)"
assert "declares the skill context-optional" \
    "$(grep -q 'context-optional' "$SKILL" && echo true || echo false)"
assert "names all three setup levels" \
    "$(grep -q 'zero-setup' "$SKILL" && grep -q 'graph-less' "$SKILL" && echo true || echo false)"
assert "links the zero-setup reference" \
    "$(grep -q 'references/zero-setup-mode.md' "$SKILL" && echo true || echo false)"

echo ""
echo "## The old hard stop is gone"
# The exact string the skill used to print before doing any work.
assert "does not print 'Error: Draft not initialized'" \
    "$(grep -q 'Error: Draft not initialized' "$SKILL" && echo false || echo true)"
assert "explicitly forbids that error" \
    "$(grep -qi 'never emit "draft not initialized"' "$SKILL" && echo true || echo false)"
assert "missing draft/ documented as a supported mode" \
    "$(grep -q 'Missing Draft Directory — not an error' "$SKILL" && echo true || echo false)"

echo ""
echo "## Degraded honesty is required, not optional"
assert "forbids simulating graph checks" \
    "$(grep -qi 'never simulate' "$SKILL" && echo true || echo false)"
assert "anti-pattern row covers refusing to run" \
    "$(grep -q 'Refuse to run because' "$SKILL" && echo true || echo false)"
assert "anti-pattern row covers faked blast radius" \
    "$(grep -qi 'blast radius / hotspots without the graph' "$SKILL" && echo true || echo false)"

echo ""
echo "## Reference doc covers the whole contract"
for section in \
    "## Why this mode exists" \
    "## Detection" \
    "## Scope resolution without tracks" \
    "## Stage behavior" \
    "## What degrades, precisely" \
    "## Output" \
    "## Closing call to action" \
    "## Anti-patterns specific to this mode"
do
    assert "reference has '$section'" \
        "$(grep -qF "$section" "$REF" && echo true || echo false)"
done

echo ""
echo "## Degradation table names the real tools"
for tool in graph-impact.sh graph-callers.sh hotspot-rank.sh; do
    assert "degradation table names $tool" \
        "$(grep -q "$tool" "$REF" && echo true || echo false)"
    assert "$tool exists (table is not stale)" \
        "$([[ -f "scripts/tools/$tool" ]] && echo true || echo false)"
done
assert "warns about project-specific false positives" \
    "$(grep -qi 'false.positive' "$REF" && echo true || echo false)"
assert "keeps the adversarial pass mandatory" \
    "$(grep -qi 'adversarial' "$REF" && echo true || echo false)"

echo ""
echo "## Output stays out of the user's repo"
assert "renders inline, writes no files" \
    "$(grep -qi 'write no files' "$REF" && echo true || echo false)"
assert "opt-in save path is outside draft/" \
    "$(grep -q '\.draft-review/review-report-' "$REF" && echo true || echo false)"
assert "SKILL.md repeats the inline-output rule" \
    "$(grep -q 'Zero-Setup Report' "$SKILL" && echo true || echo false)"

echo ""
echo "## Shared context contract agrees"
optional_row="$(grep -n 'context-optional' "$VERIFY" | head -n 1 | cut -d: -f1)"
assert "context-verify has a context-optional row" \
    "$([[ -n "$optional_row" ]] && echo true || echo false)"
assert "review listed as context-optional" \
    "$(grep -E 'context-optional.*/draft:review|/draft:review.*context-optional' "$VERIFY" >/dev/null && echo true || echo false)"
assert "review NOT listed as context-required" \
    "$(grep 'requires context' "$VERIFY" | grep -q '/draft:review' && echo false || echo true)"

echo ""
echo "## Contract reaches the generated integrations"
COPILOT="integrations/copilot/.github/copilot-instructions.md"
if [[ -f "$COPILOT" ]]; then
    assert "copilot integration carries Step 0" \
        "$(grep -q 'Detect Setup Level' "$COPILOT" && echo true || echo false)"
    assert "copilot integration carries the reference body" \
        "$(grep -q 'Zero-Setup Review Mode' "$COPILOT" && echo true || echo false)"
else
    echo " SKIP: integrations not built (run make build)"
fi

finish_test "zero-setup review"
