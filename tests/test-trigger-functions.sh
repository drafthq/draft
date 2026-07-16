#!/usr/bin/env bash
# Test suite for skill metadata (SKILL_META) coverage
#
# What this tests:
# - Every skill in SKILL_ORDER has an explicit SKILL_META row (no skill
#   silently falls through to the wildcard header/trigger fallbacks)
# - Every SKILL_META row is well-formed: known skill, non-empty header,
#   non-empty trigger
# - Copilot triggers do NOT contain @draft prefix
#
# Usage:
# ./tests/test-trigger-functions.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
LIB_SCRIPT="$ROOT_DIR/scripts/lib.sh"

source "$SCRIPT_DIR/test-helpers.sh"
# SKILL_ORDER, SKILL_META, get_skill_header, get_copilot_trigger
source "$LIB_SCRIPT"

echo "=== Skill metadata (SKILL_META) coverage tests ==="
echo ""

META_KEYS=()
for row in "${SKILL_META[@]}"; do
    META_KEYS+=("${row%%|*}")
done

# --- Every SKILL_ORDER entry has an explicit SKILL_META row ---
echo "## SKILL_META coverage"
ALL_COVERED=true
for skill in "${SKILL_ORDER[@]}"; do
    found=false
    for key in "${META_KEYS[@]}"; do
        [[ "$key" == "$skill" ]] && { found=true; break; }
    done
    if ! $found; then
        echo " MISSING SKILL_META row for: $skill"
        ALL_COVERED=false
    fi
done
assert "Every SKILL_ORDER entry has an explicit SKILL_META row" "$ALL_COVERED"

# --- Every SKILL_META row is well-formed ---
echo ""
echo "## SKILL_META row shape"
ALL_WELLFORMED=true
for row in "${SKILL_META[@]}"; do
    key="${row%%|*}"
    rest="${row#*|}"
    header="${rest%%|*}"
    trigger="${rest#*|}"
    known=false
    for skill in "${SKILL_ORDER[@]}"; do
        [[ "$skill" == "$key" ]] && { known=true; break; }
    done
    if ! $known; then
        echo " SKILL_META row for unknown skill: $key"
        ALL_WELLFORMED=false
    fi
    if [[ "$rest" == "$row" || -z "$header" || -z "$trigger" || "$trigger" == "$rest" ]]; then
        echo " Malformed SKILL_META row (need name|header|trigger): $row"
        ALL_WELLFORMED=false
    fi
done
assert "Every SKILL_META row is name|header|trigger with no empty field" "$ALL_WELLFORMED"

# --- Copilot triggers do NOT contain @draft ---
echo ""
echo "## Copilot trigger syntax"
ALL_COPILOT_SYNTAX=true
for skill in "${SKILL_ORDER[@]}"; do
    TRIGGER="$(get_copilot_trigger "$skill")"
    if echo "$TRIGGER" | grep -q '@draft'; then
        echo " HAS @draft in trigger for: $skill → $TRIGGER"
        ALL_COPILOT_SYNTAX=false
    fi
done
assert "No Copilot triggers contain @draft" "$ALL_COPILOT_SYNTAX"

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit $FAIL
