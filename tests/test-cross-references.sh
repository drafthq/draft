#!/usr/bin/env bash
# tests/test-cross-references.sh — Verify that markdown/script cross-references exist.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Cross-reference integrity tests ==="
echo ""

# Patterns to search for
# 1. core/(shared|guardrails|templates|agents|references)/[a-z-]+\.(md|sh)
# 2. scripts/tools/[a-z-]+\.sh

PATHS_TO_CHECK=$(grep -roE "core/(shared|guardrails|templates|agents|references)/[a-z0-9._-]+\.(md|sh)|scripts/tools/[a-z0-9._-]+\.sh" "$ROOT_DIR/skills" "$ROOT_DIR/core" | cut -d: -f2 | sort -u)

PASS_COUNT=0
FAIL_COUNT=0
PATHS_TO_CHECK_COUNT=$(echo "$PATHS_TO_CHECK" | wc -l)

for rel_path in $PATHS_TO_CHECK; do
    # Handle relative paths in markdown like ../../core/shared/...
    # But grep -oE will return the matched string which starts with core/ or scripts/
    # So we can just check relative to ROOT_DIR.

    full_path="$ROOT_DIR/$rel_path"
    if [[ -f "$full_path" ]]; then
        # assert "Reference exists: $rel_path" "true"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        assert "Reference exists: $rel_path" "false"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done

echo ""
echo "Checked $PATHS_TO_CHECK_COUNT references."
echo "=== Results: $PASS_COUNT passed, $FAIL_COUNT failed ==="

if [[ $FAIL_COUNT -gt 0 ]]; then
    exit 1
fi
exit 0
