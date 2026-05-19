#!/usr/bin/env bash
# Test suite for SKILL.md frontmatter and body format validation
#
# What this tests:
# - Rejects skills with missing YAML frontmatter delimiters
# - Rejects skills with missing 'name:' field
# - Rejects skills with missing 'description:' field
# - Rejects skills with invalid body format (must be: blank, # Title, blank)
# - All real skills pass frontmatter validation
#
# Usage:
# ./tests/test-skill-frontmatter.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="$ROOT_DIR/skills"
TMPDIR_BASE="$(mktemp -d)"

source "$SCRIPT_DIR/test-helpers.sh"

cleanup() {
    rm -rf "$TMPDIR_BASE"
}
trap cleanup EXIT

# Create a single test-runner that sources the canonical lib.sh functions.
# Used by both synthetic and real skill validation.
RUNNER="$TMPDIR_BASE/test-runner.sh"
cat > "$RUNNER" << RUNNER_SCRIPT
#!/usr/bin/env bash
set -euo pipefail

SKILL_FILE="\$1"

source "$ROOT_DIR/scripts/lib.sh"

# Run extract_body (validates frontmatter: delimiters, name:, description:)
extract_body "\$SKILL_FILE" > /dev/null || exit 1

# Validate body format using canonical lib.sh function
SKILL_NAME="\$(basename "\$(dirname "\$SKILL_FILE")")"
validate_skill_body_format "\$SKILL_NAME" "\$SKILL_FILE" || exit 1

echo "OK"
RUNNER_SCRIPT
chmod +x "$RUNNER"

# Helper: create a temporary skill directory with given SKILL.md content
# and run the canonical validation. Returns 0 if valid, 1 if invalid.
run_build_with_skill() {
    local skill_name="$1"
    local skill_content="$2"
    local tmpdir="$TMPDIR_BASE/$skill_name"
    mkdir -p "$tmpdir/skills/$skill_name"

    echo "$skill_content" > "$tmpdir/skills/$skill_name/SKILL.md"

    "$RUNNER" "$tmpdir/skills/$skill_name/SKILL.md" >/dev/null 2>/dev/null
}

echo "=== SKILL.md frontmatter & body format tests ==="
echo ""

# --- Missing frontmatter delimiters ---
echo "## Missing frontmatter delimiters"
CONTENT_NO_DELIMITERS="name: test
description: A test skill

# Test Skill

Some content here."

assert "Rejects skill with no --- delimiters" \
    "$(run_build_with_skill "no-delimiters" "$CONTENT_NO_DELIMITERS" && echo false || echo true)"

# --- Missing closing delimiter ---
CONTENT_NO_CLOSE="---
name: test
description: A test skill

# Test Skill

Some content here."

assert "Rejects skill with missing closing ---" \
    "$(run_build_with_skill "no-close" "$CONTENT_NO_CLOSE" && echo false || echo true)"

# --- Missing name field ---
echo ""
echo "## Missing name field"
CONTENT_NO_NAME="---
description: A test skill
---

# Test Skill

Some content here."

assert "Rejects skill with missing name: field" \
    "$(run_build_with_skill "no-name" "$CONTENT_NO_NAME" && echo false || echo true)"

# --- Missing description field ---
echo ""
echo "## Missing description field"
CONTENT_NO_DESC="---
name: test
---

# Test Skill

Some content here."

assert "Rejects skill with missing description: field" \
    "$(run_build_with_skill "no-desc" "$CONTENT_NO_DESC" && echo false || echo true)"

# --- Invalid body format: no blank first line ---
echo ""
echo "## Invalid body format"
CONTENT_BAD_BODY1="---
name: test
description: A test skill
---
# Test Skill

Some content here."

assert "Rejects skill with non-blank first body line" \
    "$(run_build_with_skill "bad-body1" "$CONTENT_BAD_BODY1" && echo false || echo true)"

# --- Invalid body format: no # Title on line 2 ---
CONTENT_BAD_BODY2="---
name: test
description: A test skill
---

Not a heading

Some content here."

assert "Rejects skill with missing # Title on line 2" \
    "$(run_build_with_skill "bad-body2" "$CONTENT_BAD_BODY2" && echo false || echo true)"

# --- Invalid body format: non-blank third line ---
CONTENT_BAD_BODY3="---
name: test
description: A test skill
---

# Test Skill
Not blank line here."

assert "Rejects skill with non-blank third body line" \
    "$(run_build_with_skill "bad-body3" "$CONTENT_BAD_BODY3" && echo false || echo true)"

# --- Valid skill passes ---
echo ""
echo "## Valid skill accepted"
CONTENT_VALID="---
name: test
description: A test skill
---

# Test Skill

Some content here."

assert "Accepts valid skill with correct frontmatter and body" \
    "$(run_build_with_skill "valid" "$CONTENT_VALID" && echo true || echo false)"

# --- All real skills pass validation ---
echo ""
echo "## Real skill validation"
ALL_REAL_PASS=true
for skill_dir in "$SKILLS_DIR"/*/; do
    skill_name=$(basename "$skill_dir")
    skill_file="$skill_dir/SKILL.md"
    if [[ -f "$skill_file" ]]; then
        if ! "$RUNNER" "$skill_file" > /dev/null 2>&1; then
            echo " FAIL: Real skill '$skill_name' failed validation"
            ALL_REAL_PASS=false
        fi
    fi
done
assert "All real skills (skills/*) pass frontmatter + body validation" "$ALL_REAL_PASS"

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
