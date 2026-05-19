#!/usr/bin/env bash
# Test suite for syntax transform functions
#
# What this tests:
# - Gemini transform: /draft:command → @draft command
# - Copilot transform: /draft:command → draft command, @draft → draft
# - Edge cases: multiple occurrences, mid-sentence, backtick-wrapped
#
# Usage:
# ./tests/test-syntax-transforms.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_SCRIPT="$ROOT_DIR/scripts/build-integrations.sh"
source "$SCRIPT_DIR/test-helpers.sh"

# Extract function definitions from the build script
FUNC_FILE="$(mktemp)"
# Extract exactly the function bodies, accounting for potential DOS line endings or trailing spaces
sed -n '/^transform_copilot_syntax()/,/^}/p' "$BUILD_SCRIPT" | tr -d '\r' > "$FUNC_FILE"

# Source the functions
if ! source "$FUNC_FILE"; then
    echo "ERROR: Failed to source extracted functions from $FUNC_FILE"
    cat -n "$FUNC_FILE"
    rm -f "$FUNC_FILE"
    exit 1
fi
rm -f "$FUNC_FILE"

assert_transform() {
    local description="$1"
    local transform_fn="$2"
    local input="$3"
    local expected="$4"
    local actual
    actual=$(echo "$input" | "$transform_fn")
    if [[ "$actual" == "$expected" ]]; then
        echo " PASS: $description"
        PASS=$((PASS + 1))
    else
        echo " FAIL: $description"
        echo " Input: '$input'"
        echo " Expected: '$expected'"
        echo " Actual: '$actual'"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Syntax transform tests ==="
echo ""

# (Removed Gemini transforms)

# --- Copilot transforms ---
echo ""
echo "## Copilot: /draft:cmd → draft cmd, @draft → draft"
assert_transform "Simple command" \
    transform_copilot_syntax \
    "/draft:init" \
    "draft init"

assert_transform "Hyphenated command" \
    transform_copilot_syntax \
    "/draft:new-track" \
    "draft new-track"

assert_transform "Mid-sentence" \
    transform_copilot_syntax \
    "Run /draft:init to set up the project" \
    "Run draft init to set up the project"

assert_transform "Multiple on one line" \
    transform_copilot_syntax \
    "Use /draft:init then /draft:new-track to start" \
    "Use draft init then draft new-track to start"

assert_transform "@draft becomes draft" \
    transform_copilot_syntax \
    "@draft is the tool" \
    "draft is the tool"

assert_transform "Backtick @draft becomes draft" \
    transform_copilot_syntax \
    'Use `@draft` for help' \
    'Use `draft` for help'

assert_transform "Backtick @draft with space becomes draft" \
    transform_copilot_syntax \
    'Use `@draft init` to start' \
    'Use `draft init` to start'

assert_transform "No match - plain text unchanged" \
    transform_copilot_syntax \
    "This has no draft commands" \
    "This has no draft commands"

echo ""
echo "## Copilot: /draft: → draft (Boundary cases)"
assert_transform "Double-hyphenated command" \
    transform_copilot_syntax \
    "/draft:deep-review" \
    "draft deep-review"

assert_transform "Start of string" \
    transform_copilot_syntax \
    "/draft:init should work" \
    "draft init should work"

assert_transform "End of string" \
    transform_copilot_syntax \
    "Use /draft:init" \
    "Use draft init"

assert_transform "Mixed @draft and /draft:" \
    transform_copilot_syntax \
    "Use @draft or /draft:init" \
    "Use draft or draft init"

echo ""
echo "## Copilot: Agent tags → @workspace"
assert_transform "Reviewer agent" \
    transform_copilot_syntax \
    "Ask @reviewer for help" \
    "Ask @workspace for help"

assert_transform "Architect agent" \
    transform_copilot_syntax \
    "Ask @architect for design" \
    "Ask @workspace for design"

assert_transform "Multiple agents" \
    transform_copilot_syntax \
    "@planner and @debugger" \
    "@workspace and @workspace"

assert_transform "Agent with trailing punctuation" \
    transform_copilot_syntax \
    "Contact @rca." \
    "Contact @workspace."

assert_transform "Backticked agent" \
    transform_copilot_syntax \
    'Use `@reviewer`' \
    'Use `@workspace`'

assert_transform "Should NOT transform non-agent @ tags (Java annotations)" \
    transform_copilot_syntax \
    "@Override" \
    "@Override"

assert_transform "Should NOT transform email addresses" \
    transform_copilot_syntax \
    "email@example.com" \
    "email@example.com"

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit $FAIL
