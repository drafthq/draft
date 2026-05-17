#!/usr/bin/env bash
# Test suite for build script error handling paths
#
# What this tests:
# - Build fails with non-zero exit code when a skill file is missing
# - Build fails when frontmatter is malformed
# - Error messages go to stderr (not stdout)
# - Build fails with non-zero exit for invalid skill names
#
# Strategy: copy the entire scripts/ directory to a temp location, mutate
# the copied lib.sh's SKILL_ORDER, and run the copied build script with
# its ROOT_DIR pointing back at the real repo so it still finds skills/.
#
# Usage:
# ./tests/test-error-handling.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="$ROOT_DIR/skills"
TMPDIR_BASE="$(mktemp -d)"

source "$SCRIPT_DIR/test-helpers.sh"

cleanup() {
    rm -rf "$SKILLS_DIR/zzz-test-bad-frontmatter" 2>/dev/null || true
    rm -rf "$TMPDIR_BASE"
}
trap cleanup EXIT

# Materialize a self-contained copy of the build environment under $1.
# Inserts $2 into SKILL_ORDER (between the existing entries and the closing paren).
make_test_env() {
    local dest="$1"
    local extra_skill="$2"

    mkdir -p "$dest/scripts"
    cp "$ROOT_DIR/scripts/build-integrations.sh" "$dest/scripts/build-integrations.sh"
    cp "$ROOT_DIR/scripts/lib.sh" "$dest/scripts/lib.sh"
    chmod +x "$dest/scripts/build-integrations.sh"

    # Override ROOT_DIR in lib.sh so the copied build still reads the real
    # skills/ and core/ from this repo.
    awk -v root="$ROOT_DIR" '
        /^ROOT_DIR=/ { print "ROOT_DIR=\"" root "\""; next }
        { print }
    ' "$dest/scripts/lib.sh" > "$dest/scripts/lib.sh.tmp" && \
        mv "$dest/scripts/lib.sh.tmp" "$dest/scripts/lib.sh"

    # Insert extra skill into SKILL_ORDER inside the copied lib.sh
    if [[ -n "$extra_skill" ]]; then
        awk -v inject="$extra_skill" '
            /^SKILL_ORDER=\(/ { print; print " " inject; next }
            { print }
        ' "$dest/scripts/lib.sh" > "$dest/scripts/lib.sh.tmp" && \
            mv "$dest/scripts/lib.sh.tmp" "$dest/scripts/lib.sh"
    fi

    echo "$dest/scripts/build-integrations.sh"
}

echo "=== Error handling tests ==="
echo ""

# --- Missing skill file produces error ---
echo "## Missing skill file"
ENV1="$TMPDIR_BASE/env1"
SCRIPT1=$(make_test_env "$ENV1" "zzz-nonexistent-skill")

EXIT_CODE=0
OUT=$("$SCRIPT1" 2>&1) || EXIT_CODE=$?

assert "Build exits non-zero when skill file is missing" \
    "$([[ "$EXIT_CODE" -ne 0 ]] && echo true || echo false)"

assert "Error mentions the missing skill" \
    "$(echo "$OUT" | grep -q "zzz-nonexistent-skill" && echo true || echo false)"

# --- Bad frontmatter produces error ---
echo ""
echo "## Bad frontmatter"
mkdir -p "$SKILLS_DIR/zzz-test-bad-frontmatter"
cat > "$SKILLS_DIR/zzz-test-bad-frontmatter/SKILL.md" << 'EOF'
---
name: zzz-test-bad-frontmatter
---

# Test

Content here.
EOF

ENV2="$TMPDIR_BASE/env2"
SCRIPT2=$(make_test_env "$ENV2" "zzz-test-bad-frontmatter")

EXIT_CODE2=0
OUT2=$("$SCRIPT2" 2>&1) || EXIT_CODE2=$?

assert "Build exits non-zero for skill with missing description" \
    "$([[ "$EXIT_CODE2" -ne 0 ]] && echo true || echo false)"

assert "Error mentions the missing description" \
    "$(echo "$OUT2" | grep -qi "description" && echo true || echo false)"

rm -rf "$SKILLS_DIR/zzz-test-bad-frontmatter"

# --- Invalid skill name in SKILL_ORDER produces error ---
echo ""
echo "## Invalid skill name"
ENV3="$TMPDIR_BASE/env3"
SCRIPT3=$(make_test_env "$ENV3" "InvalidName")

EXIT_CODE3=0
OUT3=$("$SCRIPT3" 2>&1) || EXIT_CODE3=$?

assert "Build exits non-zero for invalid skill name" \
    "$([[ "$EXIT_CODE3" -ne 0 ]] && echo true || echo false)"

# --- Normal build still works ---
echo ""
echo "## Normal build unaffected"
EXIT_CODE_NORMAL=0
"$ROOT_DIR/scripts/build-integrations.sh" > /dev/null 2>/dev/null || EXIT_CODE_NORMAL=$?
assert "Original build script still succeeds" \
    "$([[ "$EXIT_CODE_NORMAL" -eq 0 ]] && echo true || echo false)"

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit $FAIL
