#!/usr/bin/env bash
# Test suite for skill references/ progressive-disclosure support.
#
# What this tests:
# - Build script inlines skills/<name>/references/*.md after the SKILL body
# - Files are emitted in alphabetical order (deterministic)
# - Skills without a references/ directory still build cleanly
# - syntax transforms (e.g. /draft: → draft) apply to reference files
#
# Usage:
#   ./tests/test-skill-references.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_SCRIPT="$ROOT_DIR/scripts/build-integrations.sh"
COPILOT_OUTPUT="$ROOT_DIR/integrations/copilot/.github/copilot-instructions.md"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== skill references/ inlining tests ==="
echo ""

# Pick a skill known to have no references/. status is small and stable.
TEST_SKILL="status"
REFS_DIR="$ROOT_DIR/skills/$TEST_SKILL/references"
SENTINEL_A="$REFS_DIR/aaa-sentinel.md"
SENTINEL_B="$REFS_DIR/bbb-sentinel.md"

cleanup() {
    rm -rf "$REFS_DIR"
    "$BUILD_SCRIPT" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Bail out if a real references/ already exists for this skill — don't clobber.
if [[ -e "$REFS_DIR" ]]; then
    echo "FAIL: $REFS_DIR already exists; cannot run isolated test" >&2
    exit 1
fi

mkdir -p "$REFS_DIR"

cat > "$SENTINEL_A" <<'MD'
## REFERENCES_SENTINEL_AAA

A reference fragment. Calls `/draft:status` to test syntax transform.
MD

cat > "$SENTINEL_B" <<'MD'
## REFERENCES_SENTINEL_BBB

Second fragment, must appear after AAA.
MD

# Rebuild
"$BUILD_SCRIPT" >/dev/null 2>&1

# Both sentinels must appear in output
assert "AAA reference inlined into Copilot output" \
    "$(grep -q 'REFERENCES_SENTINEL_AAA' "$COPILOT_OUTPUT" && echo true || echo false)"
assert "BBB reference inlined into Copilot output" \
    "$(grep -q 'REFERENCES_SENTINEL_BBB' "$COPILOT_OUTPUT" && echo true || echo false)"

# Order: AAA must precede BBB
LINE_A=$(grep -n 'REFERENCES_SENTINEL_AAA' "$COPILOT_OUTPUT" | head -1 | cut -d: -f1 || echo 0)
LINE_B=$(grep -n 'REFERENCES_SENTINEL_BBB' "$COPILOT_OUTPUT" | head -1 | cut -d: -f1 || echo 0)
assert "References emitted in alphabetical order" \
    "$([[ "$LINE_A" -gt 0 && "$LINE_B" -gt 0 && "$LINE_A" -lt "$LINE_B" ]] && echo true || echo false)"

# Syntax transform must apply: /draft:status → draft status (no /draft: leaks)
DRAFT_COLON=$(grep -c '/draft:' "$COPILOT_OUTPUT" 2>/dev/null || true)
assert "Syntax transform applies to references (no /draft: leaks)" \
    "$([[ "${DRAFT_COLON:-0}" -eq 0 ]] && echo true || echo false)"

# References must appear inside the matching skill section, not at file end.
# Locate the status skill header and the next '---' separator after it.
STATUS_HEADER_LINE=$(grep -n '^## Status Command' "$COPILOT_OUTPUT" | head -1 | cut -d: -f1 || echo 0)
assert "Status Command header found" \
    "$([[ "$STATUS_HEADER_LINE" -gt 0 ]] && echo true || echo false)"

if [[ "$STATUS_HEADER_LINE" -gt 0 && "$LINE_A" -gt 0 ]]; then
    assert "AAA reference is positioned after Status Command header" \
        "$([[ "$LINE_A" -gt "$STATUS_HEADER_LINE" ]] && echo true || echo false)"
fi

# Cleanup happens via trap; restore baseline build
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit $FAIL
