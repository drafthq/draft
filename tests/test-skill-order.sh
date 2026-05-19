#!/usr/bin/env bash
# Test suite for SKILL_ORDER completeness
#
# What this tests:
# - Every skill directory on disk has an entry in SKILL_ORDER
# - Every entry in SKILL_ORDER has a matching skill directory on disk
# - SKILL_ORDER has no duplicate entries
#
# Usage:
# ./tests/test-skill-order.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/test-helpers.sh"
# Source lib.sh for canonical SKILL_ORDER and SKILLS_DIR
source "$ROOT_DIR/scripts/lib.sh"

echo "=== SKILL_ORDER completeness tests ==="
echo ""

# Get actual skill directories
DISK_SKILLS=()
for skill_dir in "$SKILLS_DIR"/*/; do
    if [[ -f "$skill_dir/SKILL.md" ]]; then
        DISK_SKILLS+=("$(basename "$skill_dir")")
    fi
done

echo "## SKILL_ORDER entries: ${#SKILL_ORDER[@]}"
echo "## Disk skills: ${#DISK_SKILLS[@]}"
echo ""

# --- Count match ---
echo "## Count"
assert "SKILL_ORDER count matches disk skill count" \
    "$([[ ${#SKILL_ORDER[@]} -eq ${#DISK_SKILLS[@]} ]] && echo true || echo false)"

# --- Every disk skill is in SKILL_ORDER ---
echo ""
echo "## Disk skills present in SKILL_ORDER"

# Check if disk skills are in SKILL_ORDER using standard arrays
ALL_DISK_IN_ORDER=true
for disk_skill in "${DISK_SKILLS[@]}"; do
    found_in_order=false
    for order_skill in "${SKILL_ORDER[@]}"; do
        if [[ "$disk_skill" == "$order_skill" ]]; then
            found_in_order=true
            break
        fi
    done
    
    if [[ "$found_in_order" == false ]]; then
        echo " MISSING from SKILL_ORDER: $disk_skill"
        ALL_DISK_IN_ORDER=false
    fi
done
assert "Every skill on disk is listed in SKILL_ORDER" "$ALL_DISK_IN_ORDER"

# --- Every SKILL_ORDER entry exists on disk ---
echo ""
echo "## SKILL_ORDER entries exist on disk"
ALL_ORDER_ON_DISK=true
for order_skill in "${SKILL_ORDER[@]}"; do
    if [[ ! -d "$SKILLS_DIR/$order_skill" ]] || [[ ! -f "$SKILLS_DIR/$order_skill/SKILL.md" ]]; then
        echo " MISSING on disk: $order_skill"
        ALL_ORDER_ON_DISK=false
    fi
done
assert "Every SKILL_ORDER entry has a skill directory with SKILL.md" "$ALL_ORDER_ON_DISK"

# --- No duplicates in SKILL_ORDER ---
echo ""
echo "## No duplicates"
SORTED=$(printf '%s\n' "${SKILL_ORDER[@]}" | sort)
UNIQUE=$(printf '%s\n' "${SKILL_ORDER[@]}" | sort -u)
assert "SKILL_ORDER has no duplicate entries" \
    "$([[ "$SORTED" == "$UNIQUE" ]] && echo true || echo false)"

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
