#!/usr/bin/env bash
# Test suite for core file registry
#
# What this tests:
# - All files listed in CORE_FILES array exist on disk
# - No duplicate entries in CORE_FILES
#
# Foundations additions (9 shared + guardrails/* + 2 templates) validated via
# expanded CORE_FILES per manifest §2.1, §2.5.
#
# Usage:
# ./tests/test-core-files.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/test-helpers.sh"
# Source lib.sh for canonical CORE_FILES and CORE_DIR
source "$ROOT_DIR/scripts/lib.sh"

echo "=== Core file registry tests ==="
echo ""

echo "## Core files count: ${#CORE_FILES[@]}"
echo ""

# --- All core files exist on disk ---
echo "## Core files exist on disk"
ALL_EXIST=true
for core_file in "${CORE_FILES[@]}"; do
    [[ -z "$core_file" ]] && continue
    full_path="$CORE_DIR/$core_file"
    if [[ ! -f "$full_path" ]]; then
        echo " MISSING: $full_path"
        ALL_EXIST=false
    fi
done
assert "All CORE_FILES entries exist on disk" "$ALL_EXIST"

# --- Every file on disk is in CORE_FILES (no orphans) ---
echo ""
echo "## No orphaned files"
ALL_REGISTERED=true
while IFS= read -r -d '' file; do
    rel_path="${file#"$CORE_DIR/"}"
    found=false
    for core_file in "${CORE_FILES[@]}"; do
        if [[ "$rel_path" == "$core_file" ]]; then
            found=true
            break
        fi
    done
    if [[ "$found" == false ]]; then
        echo " ORPHAN: $rel_path (on disk but not in CORE_FILES)"
        ALL_REGISTERED=false
    fi
done < <(find "$CORE_DIR" -type f -print0 | sort -z)
assert "Every file on disk under core/ is listed in CORE_FILES" "$ALL_REGISTERED"

# --- No duplicates ---
echo ""
echo "## No duplicates"
DUPES=$(printf '%s\n' "${CORE_FILES[@]}" | sort | uniq -d)
assert "CORE_FILES has no duplicate entries" \
    "$([[ -z "$DUPES" ]] && echo true || echo false)"

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
