#!/usr/bin/env bash
# Test suite for skill name security validation
#
# What this tests:
# - Build script rejects skill names with path traversal characters
# - Build script rejects skill names with uppercase letters
# - Build script rejects skill names with spaces or special characters
# - Build script accepts valid lowercase-alphanumeric-hyphen names
#
# The build script validates: [[ ! "$skill" =~ ^[a-z][a-z0-9]*(-[a-z0-9]+)*$ ]]
#
# Usage:
#   ./tests/test-skill-name-security.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/test-helpers.sh"
# Source lib.sh for canonical is_valid_skill_name and SKILLS_DIR
source "$ROOT_DIR/scripts/lib.sh"

echo "=== Skill name security validation tests ==="
echo ""

# --- Valid names ---
echo "## Valid names accepted"
assert "Accepts 'init'" \
    "$(is_valid_skill_name "init" && echo true || echo false)"
assert "Accepts 'new-track'" \
    "$(is_valid_skill_name "new-track" && echo true || echo false)"
assert "Accepts 'deep-review'" \
    "$(is_valid_skill_name "deep-review" && echo true || echo false)"
assert "Accepts 'adr'" \
    "$(is_valid_skill_name "adr" && echo true || echo false)"
assert "Accepts 'skill123'" \
    "$(is_valid_skill_name "skill123" && echo true || echo false)"

# --- Path traversal attempts ---
echo ""
echo "## Path traversal rejected"
assert "Rejects '../etc/passwd'" \
    "$(is_valid_skill_name "../etc/passwd" && echo false || echo true)"
assert "Rejects '../../secret'" \
    "$(is_valid_skill_name "../../secret" && echo false || echo true)"
assert "Rejects 'skill/../../etc'" \
    "$(is_valid_skill_name "skill/../../etc" && echo false || echo true)"
assert "Rejects './current'" \
    "$(is_valid_skill_name "./current" && echo false || echo true)"

# --- Uppercase rejected ---
echo ""
echo "## Uppercase rejected"
assert "Rejects 'Init'" \
    "$(is_valid_skill_name "Init" && echo false || echo true)"
assert "Rejects 'NEW-TRACK'" \
    "$(is_valid_skill_name "NEW-TRACK" && echo false || echo true)"
assert "Rejects 'camelCase'" \
    "$(is_valid_skill_name "camelCase" && echo false || echo true)"

# --- Special characters rejected ---
echo ""
echo "## Special characters rejected"
assert "Rejects 'skill name' (space)" \
    "$(is_valid_skill_name "skill name" && echo false || echo true)"
assert "Rejects 'skill_name' (underscore)" \
    "$(is_valid_skill_name "skill_name" && echo false || echo true)"
assert "Rejects 'skill.name' (dot)" \
    "$(is_valid_skill_name "skill.name" && echo false || echo true)"
assert "Rejects 'skill@name' (at sign)" \
    "$(is_valid_skill_name "skill@name" && echo false || echo true)"
assert "Rejects 'skill;rm -rf /' (injection)" \
    "$(is_valid_skill_name 'skill;rm -rf /' && echo false || echo true)"
assert "Rejects '' (empty string)" \
    "$(is_valid_skill_name "" && echo false || echo true)"

# --- All real skill directory names are valid ---
echo ""
echo "## Real skill directory names"
ALL_VALID=true
for skill_dir in "$SKILLS_DIR"/*/; do
    skill_name=$(basename "$skill_dir")
    if ! is_valid_skill_name "$skill_name"; then
        echo "  FAIL: Real skill directory '$skill_name' has invalid name"
        ALL_VALID=false
    fi
done
assert "All skill directory names match kebab-case regex" "$ALL_VALID"

# --- Kebab-case enforcement (tighter regex) ---
echo ""
echo "## Kebab-case enforcement"
assert "Rejects '---' (all hyphens)" \
    "$(is_valid_skill_name "---" && echo false || echo true)"
assert "Rejects '-init' (leading hyphen)" \
    "$(is_valid_skill_name "-init" && echo false || echo true)"
assert "Rejects 'init-' (trailing hyphen)" \
    "$(is_valid_skill_name "init-" && echo false || echo true)"
assert "Rejects '123skill' (starts with digit)" \
    "$(is_valid_skill_name "123skill" && echo false || echo true)"
assert "Rejects 'a--b' (consecutive hyphens)" \
    "$(is_valid_skill_name "a--b" && echo false || echo true)"

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
