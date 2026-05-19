#!/usr/bin/env bash
# Test suite for plugin manifest consistency
#
# What this tests:
# - plugin.json is valid JSON with required fields
# - marketplace.json is valid JSON with required structure
# - Version consistency between plugin.json and marketplace.json
# - Plugin name matches skill directory structure
# - Required fields present in plugin.json
#
# Usage:
# ./tests/test-plugin-manifest.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PLUGIN_JSON="$ROOT_DIR/.claude-plugin/plugin.json"
MARKETPLACE_JSON="$ROOT_DIR/.claude-plugin/marketplace.json"
SKILLS_DIR="$ROOT_DIR/skills"

source "$SCRIPT_DIR/test-helpers.sh"
# Source lib.sh for canonical SKILL_ORDER
source "$ROOT_DIR/scripts/lib.sh"

# Check if jq is available; if not, use python3 as fallback
json_get() {
    local file="$1"
    local query="$2"
    if command -v jq &>/dev/null; then
        jq -r "$query" "$file" 2>/dev/null
    elif command -v python3 &>/dev/null; then
        python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
keys = sys.argv[2].strip('.').split('.')
for k in keys:
    if k.startswith('[') and k.endswith(']'):
        data = data[int(k[1:-1])]
    else:
        data = data[k]
print(data)
" "$file" "$query" 2>/dev/null
    else
        echo "ERROR"
    fi
}

json_valid() {
    local file="$1"
    if command -v jq &>/dev/null; then
        jq empty "$file" 2>/dev/null
    elif command -v python3 &>/dev/null; then
        python3 -c "import json, sys; json.load(open(sys.argv[1]))" "$file" 2>/dev/null
    else
        return 1
    fi
}

echo "=== Plugin manifest consistency tests ==="
echo ""

# --- plugin.json exists and is valid JSON ---
echo "## plugin.json validity"
assert "plugin.json exists" \
    "$([[ -f "$PLUGIN_JSON" ]] && echo true || echo false)"

assert "plugin.json is valid JSON" \
    "$(json_valid "$PLUGIN_JSON" && echo true || echo false)"

# --- Required fields in plugin.json ---
echo ""
echo "## plugin.json required fields"
if [[ -f "$PLUGIN_JSON" ]]; then
    PLUGIN_NAME=$(json_get "$PLUGIN_JSON" ".name")
    assert "plugin.json has 'name' field" \
        "$([[ -n "$PLUGIN_NAME" && "$PLUGIN_NAME" != "null" ]] && echo true || echo false)"

    PLUGIN_DESC=$(json_get "$PLUGIN_JSON" ".description")
    assert "plugin.json has 'description' field" \
        "$([[ -n "$PLUGIN_DESC" && "$PLUGIN_DESC" != "null" ]] && echo true || echo false)"

    PLUGIN_VERSION=$(json_get "$PLUGIN_JSON" ".version")
    assert "plugin.json has 'version' field" \
        "$([[ -n "$PLUGIN_VERSION" && "$PLUGIN_VERSION" != "null" ]] && echo true || echo false)"

    # author.name and license are optional for internal forks
    PLUGIN_AUTHOR=$(json_get "$PLUGIN_JSON" ".author.name")
    if [[ -n "$PLUGIN_AUTHOR" && "$PLUGIN_AUTHOR" != "null" ]]; then
        echo " INFO: plugin.json has 'author.name' field: $PLUGIN_AUTHOR"
    fi

    PLUGIN_LICENSE=$(json_get "$PLUGIN_JSON" ".license")
    if [[ -n "$PLUGIN_LICENSE" && "$PLUGIN_LICENSE" != "null" ]]; then
        echo " INFO: plugin.json has 'license' field: $PLUGIN_LICENSE"
    fi
fi

# --- marketplace.json (optional for internal forks) ---
echo ""
echo "## marketplace.json validity"
if [[ -f "$MARKETPLACE_JSON" ]]; then
    assert "marketplace.json is valid JSON" \
        "$(json_valid "$MARKETPLACE_JSON" && echo true || echo false)"

    # --- Version consistency ---
    echo ""
    echo "## Version consistency"
    if [[ -f "$PLUGIN_JSON" ]]; then
        PLUGIN_VERSION=$(json_get "$PLUGIN_JSON" ".version")
        MARKETPLACE_VERSION=$(json_get "$MARKETPLACE_JSON" ".plugins.[0].version")
        echo " plugin.json version: $PLUGIN_VERSION"
        echo " marketplace.json version: $MARKETPLACE_VERSION"
        assert "Versions match between plugin.json and marketplace.json" \
            "$([[ "$PLUGIN_VERSION" == "$MARKETPLACE_VERSION" ]] && echo true || echo false)"
    fi
else
    echo " INFO: marketplace.json not present (optional for internal forks)"
fi

# --- Plugin name matches skills directory ---
echo ""
echo "## Plugin name consistency"
if [[ -f "$PLUGIN_JSON" ]]; then
    PLUGIN_NAME=$(json_get "$PLUGIN_JSON" ".name")
    # The plugin name should match the main skill directory name
    assert "Plugin name '$PLUGIN_NAME' has a matching skill directory" \
        "$([[ -d "$SKILLS_DIR/$PLUGIN_NAME" ]] && echo true || echo false)"
fi

# --- Skills on disk cross-validation ---
echo ""
echo "## Skills directory completeness"

# Every SKILL_ORDER entry should have a SKILL.md on disk
ALL_ON_DISK=true
for order_skill in "${SKILL_ORDER[@]}"; do
    expected_file="$SKILLS_DIR/$order_skill/SKILL.md"
    if [[ ! -f "$expected_file" ]]; then
        echo " MISSING on disk: skills/$order_skill/SKILL.md"
        ALL_ON_DISK=false
    fi
done
assert "Every SKILL_ORDER entry has a SKILL.md on disk" "$ALL_ON_DISK"

# Count skill directories on disk vs SKILL_ORDER
DISK_SKILL_COUNT=$(find "$SKILLS_DIR" -maxdepth 2 -name "SKILL.md" | wc -l)
assert "Skill count on disk (${DISK_SKILL_COUNT}) matches SKILL_ORDER count (${#SKILL_ORDER[@]})" \
    "$([[ "$DISK_SKILL_COUNT" -eq "${#SKILL_ORDER[@]}" ]] && echo true || echo false)"

# --- Marketplace plugin name matches plugin.json ---
echo ""
echo "## Marketplace-plugin name consistency"
if [[ -f "$PLUGIN_JSON" && -f "$MARKETPLACE_JSON" ]]; then
    PLUGIN_NAME=$(json_get "$PLUGIN_JSON" ".name")
    MARKETPLACE_PLUGIN_NAME=$(json_get "$MARKETPLACE_JSON" ".plugins.[0].name")
    assert "marketplace.json plugin name matches plugin.json name" \
        "$([[ "$PLUGIN_NAME" == "$MARKETPLACE_PLUGIN_NAME" ]] && echo true || echo false)"
else
    echo " INFO: Skipped (marketplace.json not present)"
fi

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
