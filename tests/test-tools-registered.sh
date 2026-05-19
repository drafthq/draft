#!/usr/bin/env bash
# Test suite for scripts/tools/ registry
#
# What this tests:
# - All files listed in TOOLS array exist and are executable
# - No duplicate entries in TOOLS
# - No orphan files under scripts/tools/ (everything there must be registered)
#
# Usage:
#   ./tests/test-tools-registered.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/test-helpers.sh"
source "$ROOT_DIR/scripts/lib.sh"

echo "=== Tools registry tests ==="
echo ""

echo "## TOOLS count: ${#TOOLS[@]}"
echo ""

# --- All tools exist and are executable ---
echo "## Registered tools exist and are executable"
ALL_OK=true
for tool in "${TOOLS[@]}"; do
    [[ -z "$tool" ]] && continue
    full_path="$TOOLS_DIR/$tool"
    if [[ ! -f "$full_path" ]]; then
        echo "  MISSING: $full_path"
        ALL_OK=false
        continue
    fi
    if [[ ! -x "$full_path" ]]; then
        echo "  NOT EXECUTABLE: $full_path"
        ALL_OK=false
    fi
done
assert "All TOOLS entries exist and are executable" "$ALL_OK"

# --- No orphan scripts under scripts/tools/ ---
echo ""
echo "## No orphaned scripts under scripts/tools/"
ALL_REGISTERED=true
if [[ -d "$TOOLS_DIR" ]]; then
    while IFS= read -r -d '' file; do
        rel_path="${file#"$TOOLS_DIR/"}"
        # Files starting with "_" are internal helpers, not invocable tools.
        # .conf files are supporting config (e.g. skill-caps.conf), not tools.
        local base
        base="$(basename "$rel_path")"
        [[ "$base" == _* ]] && continue
        [[ "$base" == *.conf ]] && continue
        found=false
        for tool in "${TOOLS[@]}"; do
            if [[ "$rel_path" == "$tool" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" == false ]]; then
            echo "  ORPHAN: $rel_path (on disk but not in TOOLS)"
            ALL_REGISTERED=false
        fi
    done < <(find "$TOOLS_DIR" -type f -print0 | sort -z)
fi
assert "Every script under scripts/tools/ is listed in TOOLS" "$ALL_REGISTERED"

# --- No duplicates ---
echo ""
echo "## No duplicates"
if [[ ${#TOOLS[@]} -eq 0 ]]; then
    DUPES=""
else
    DUPES=$(printf '%s\n' "${TOOLS[@]}" | sort | uniq -d)
fi
assert "TOOLS has no duplicate entries" \
    "$([[ -z "$DUPES" ]] && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
