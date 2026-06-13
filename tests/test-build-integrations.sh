#!/usr/bin/env bash
# Test suite for build-integrations.sh
#
# What this tests:
# - Build script exists and is executable
# - Output files are generated (Copilot, Gemini)
# - Output files have expected structure (> 100 lines)
# - Syntax transformations are correct (/draft: → @draft for Gemini, → draft for Copilot)
# - No @draft references in Copilot output
# - Idempotency (rebuilds produce identical output)
#
# What this does NOT test:
# - Skill content correctness
# - Skill frontmatter validation (handled by build script)
# - Error handling for malformed skill files
# - Individual skill inclusion/exclusion
#
# Usage:
# ./tests/test-build-integrations.sh
#
# Expected runtime: < 2 seconds
# Exit code: Number of failed tests (0 = all pass)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_SCRIPT="$ROOT_DIR/scripts/build-integrations.sh"
COPILOT_OUTPUT="$ROOT_DIR/integrations/copilot/.github/copilot-instructions.md"
BASELINE="$(mktemp)"
_errfile="$(mktemp)"
trap 'rm -f "$BASELINE" "$_errfile"' EXIT

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== build-integrations.sh tests ==="
echo ""

# --- Existence tests ---
echo "## Script existence"
assert "build-integrations.sh exists" \
    "$([[ -f "$BUILD_SCRIPT" ]] && echo true || echo false)"
assert "build-integrations.sh is executable" \
    "$([[ -x "$BUILD_SCRIPT" ]] && echo true || echo false)"

# --- Run the build (single invocation; capture stdout and stderr separately) ---
echo ""
echo "## Running build..."
if [[ -f "$BUILD_SCRIPT" && -x "$BUILD_SCRIPT" ]]; then
    BUILD_STDOUT="$("$BUILD_SCRIPT" 2>"$_errfile")" || true
    BUILD_STDERR="$(cat "$_errfile")"
    echo "$BUILD_STDOUT" | head -5
    echo ""
fi

# --- Build stderr check ---
echo ""
echo "## Build stderr check"
if [[ -f "$BUILD_SCRIPT" && -x "$BUILD_SCRIPT" ]]; then
    HAS_WARNING=$(echo "${BUILD_STDERR:-}" | grep -c -E 'WARNING|ERROR' || true)
    assert "Build produces no WARNING or ERROR on stderr" \
        "$([[ "${HAS_WARNING:-0}" -eq 0 ]] && echo true || echo false)"
fi

# --- Copilot output tests ---
echo "## Copilot output"
assert "Copilot copilot-instructions.md generated" \
    "$([[ -f "$COPILOT_OUTPUT" ]] && echo true || echo false)"

if [[ -f "$COPILOT_OUTPUT" ]]; then
    LINES=$(wc -l < "$COPILOT_OUTPUT" | tr -d ' ')
    assert "Copilot output has content (>100 lines)" \
        "$([[ "$LINES" -gt 100 ]] && echo true || echo false)"
    AT_DRAFT=$(grep -c '@draft' "$COPILOT_OUTPUT" 2>/dev/null || true)
    assert "Copilot output contains no @draft references" \
        "$([[ "${AT_DRAFT:-0}" -eq 0 ]] && echo true || echo false)"
    DRAFT_COLON=$(grep -c '/draft:' "$COPILOT_OUTPUT" 2>/dev/null || true)
    assert "Copilot output contains no /draft: references" \
        "$([[ "${DRAFT_COLON:-0}" -eq 0 ]] && echo true || echo false)"
    assert "Copilot output contains Draft methodology header" \
        "$(grep -q '# Draft - Context-Driven Development' "$COPILOT_OUTPUT" && echo true || echo false)"
    assert "Copilot output uses 'draft <cmd>' syntax (not @draft)" \
        "$(grep -q 'draft init' "$COPILOT_OUTPUT" && echo true || echo false)"
fi

# --- Idempotency test ---
echo ""
echo "## Idempotency"
if [[ -f "$COPILOT_OUTPUT" ]]; then
    cp "$COPILOT_OUTPUT" "$BASELINE"
    "$BUILD_SCRIPT" > /dev/null 2>&1 || true
    assert "Copilot output is idempotent (rebuild produces same result)" \
        "$(diff -q "$BASELINE" "$COPILOT_OUTPUT" > /dev/null 2>&1 && echo true || echo false)"
else
    assert "Copilot output is idempotent (rebuild produces same result)" "false"
fi

# --- AGENTS.md output tests ---
echo ""
echo "## AGENTS.md output"
AGENTS_OUTPUT="$ROOT_DIR/integrations/agents/AGENTS.md"
assert "AGENTS.md generated" \
    "$([[ -f "$AGENTS_OUTPUT" ]] && echo true || echo false)"
if [[ -f "$AGENTS_OUTPUT" ]]; then
    A_LINES=$(wc -l < "$AGENTS_OUTPUT" | tr -d ' ')
    assert "AGENTS.md has content (>100 lines)" \
        "$([[ "$A_LINES" -gt 100 ]] && echo true || echo false)"
    A_DRAFT_COLON=$(grep -c '/draft:' "$AGENTS_OUTPUT" 2>/dev/null || true)
    assert "AGENTS.md contains no /draft: references" \
        "$([[ "${A_DRAFT_COLON:-0}" -eq 0 ]] && echo true || echo false)"
    A_WORKSPACE=$(grep -c '@workspace' "$AGENTS_OUTPUT" 2>/dev/null || true)
    assert "AGENTS.md contains no @workspace (Copilot-only) references" \
        "$([[ "${A_WORKSPACE:-0}" -eq 0 ]] && echo true || echo false)"
    assert "AGENTS.md contains Draft methodology header" \
        "$(grep -q '# Draft - Context-Driven Development' "$AGENTS_OUTPUT" && echo true || echo false)"
fi

# --- Removed Gemini tests ---

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit $FAIL
