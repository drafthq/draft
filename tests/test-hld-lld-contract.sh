#!/usr/bin/env bash
# Test suite for HLD/LLD frontmatter & graph-slot contract
#
# What this tests:
# - hld.md and lld.md templates declare the expected GRAPH:track-* slots
# - spec.md frontmatter declares classification + approvers blocks
# - Approver keys named in lld.md / decompose match keys actually declared in spec.md
#
# Why these matter:
# - Slot rename in templates would silently break /draft:decompose Step 5a/5b directives
# - Missing classification/approvers in spec.md silently breaks /draft:upload gates
# - Mismatched approver keys silently produce empty Approvals tables in HLD/LLD
#
# Usage:
# ./tests/test-hld-lld-contract.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CORE_DIR="$ROOT_DIR/core"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== HLD/LLD contract tests ==="
echo ""

# --- Required GRAPH slots present in hld.md ---
echo "## hld.md graph slots"
for slot in track-component-diagram track-component-table track-dependencies; do
    if grep -q "GRAPH:${slot}:START" "$CORE_DIR/templates/hld.md" \
       && grep -q "GRAPH:${slot}:END" "$CORE_DIR/templates/hld.md"; then
        assert "hld.md declares GRAPH:${slot} slot (START + END)" "true"
    else
        assert "hld.md declares GRAPH:${slot} slot (START + END)" "false"
    fi
done
echo ""

# --- Required GRAPH slots present in lld.md ---
echo "## lld.md graph slots"
for slot in track-class-table track-data-models; do
    if grep -q "GRAPH:${slot}:START" "$CORE_DIR/templates/lld.md" \
       && grep -q "GRAPH:${slot}:END" "$CORE_DIR/templates/lld.md"; then
        assert "lld.md declares GRAPH:${slot} slot (START + END)" "true"
    else
        assert "lld.md declares GRAPH:${slot} slot (START + END)" "false"
    fi
done
echo ""

# --- spec.md frontmatter declares classification + approvers ---
echo "## spec.md frontmatter contract"
if grep -q "^classification:" "$CORE_DIR/templates/spec.md"; then
    assert "spec.md declares classification: block" "true"
else
    assert "spec.md declares classification: block" "false"
fi
if grep -q "^approvers:" "$CORE_DIR/templates/spec.md"; then
    assert "spec.md declares approvers: block" "true"
else
    assert "spec.md declares approvers: block" "false"
fi
echo ""

# --- Approver keys named in HLD/LLD pre-fill match keys in spec.md ---
echo "## approvers key alignment (spec.md ↔ hld.md/lld.md/decompose)"
HLD_REQUIRED_KEYS=(tech_leads arb_leads cloudops_leads qa_leads pm_leads)
LLD_REQUIRED_KEYS=(team_leads tech_leads qa)
ALL_REQUIRED_KEYS=(tech_leads arb_leads cloudops_leads qa_leads pm_leads team_leads qa)

for key in "${ALL_REQUIRED_KEYS[@]}"; do
    if grep -q "^ ${key}:" "$CORE_DIR/templates/spec.md"; then
        assert "spec.md frontmatter declares approvers.${key}" "true"
    else
        assert "spec.md frontmatter declares approvers.${key}" "false"
    fi
done

# Detect any approvers.lld_* references that would never resolve
if grep -rq "approvers\.lld_" "$ROOT_DIR/core" "$ROOT_DIR/skills" 2>/dev/null; then
    echo ""
    echo " FAIL: approvers.lld_* keys referenced but spec.md uses flat keys"
    grep -rn "approvers\.lld_" "$ROOT_DIR/core" "$ROOT_DIR/skills" 2>/dev/null
    FAIL=$((FAIL + 1))
else
    assert "no fictional approvers.lld_* references in core/ or skills/" "true"
fi
echo ""

# --- Sibling cross-references between hld.md and lld.md resolve to known sections ---
echo "## hld.md ↔ lld.md cross-references"
if grep -q "links:" "$CORE_DIR/templates/hld.md" \
   && grep -q "lld:" "$CORE_DIR/templates/hld.md"; then
    assert "hld.md frontmatter links to lld.md" "true"
else
    assert "hld.md frontmatter links to lld.md" "false"
fi
if grep -q "links:" "$CORE_DIR/templates/lld.md" \
   && grep -q "hld:" "$CORE_DIR/templates/lld.md"; then
    assert "lld.md frontmatter links to hld.md" "true"
else
    assert "lld.md frontmatter links to hld.md" "false"
fi
echo ""

# --- track-architecture.md template was retired (negative test) ---
echo "## retired template"
if [[ -f "$CORE_DIR/templates/track-architecture.md" ]]; then
    assert "track-architecture.md template removed (replaced by hld.md/lld.md)" "false"
else
    assert "track-architecture.md template removed (replaced by hld.md/lld.md)" "true"
fi
echo ""

echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] || exit 1
