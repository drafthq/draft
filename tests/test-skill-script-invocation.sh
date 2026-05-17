#!/usr/bin/env bash
# Test suite for scripts/tools/ invocation discipline in skills + core docs.
#
# What this tests:
# - Any line that *invokes* a scripts/tools/X.sh script (as opposed to
# mentioning it in prose) must use the canonical resolver pattern:
# bash "$DRAFT_TOOLS/<name>.sh" ...
# and must NOT use the bare relative form:
# scripts/tools/<name>.sh ...
# or a literal `bash scripts/tools/<name>.sh` form.
# - Every file that invokes a tool via "$DRAFT_TOOLS/..." also defines
# DRAFT_TOOLS (the three-line resolver) somewhere above the invocation,
# OR references core/shared/tool-resolver.md to incorporate it.
#
# Why: bare relative paths break the moment a skill runs inside a target
# project (the normal case). The plugin installs scripts/tools/ under
# $HOME/.claude/plugins/draft/scripts/tools/, not $PWD/scripts/tools/.
# 3k+ engineers hit this in production.
#
# Usage:
# ./tests/test-skill-script-invocation.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Skill / core tool-invocation discipline tests ==="
echo ""

# tool-resolver.md documents the pattern itself — exclude from scanning.
# graph-query.md L121 has a prose mention "matching `scripts/tools/classify-files.sh`"
# which is descriptive, not an invocation.
SCAN_PATHS=(
    "$ROOT_DIR/skills"
    "$ROOT_DIR/core"
)

# Invocation-shaped patterns (anything that looks like the shell about to run the script):
# - "scripts/tools/x.sh" at the start of a line (possibly indented)
# - "bash scripts/tools/x.sh" (any indent)
# - "sh scripts/tools/x.sh"
# - "./scripts/tools/x.sh"
# Excluded: backtick-wrapped prose mentions ("`scripts/tools/x.sh`") and
# inline-code mentions in tables, since those are descriptive.
BARE_INVOCATION_REGEX='(^|[[:space:]]|\$\(|"|/)(\./)?(bash[[:space:]]+|sh[[:space:]]+)?scripts/tools/[a-z0-9][a-z0-9._-]*\.(sh|py|js)([[:space:]]|$|"|\\)'

echo "## No bare 'scripts/tools/X.sh' invocations remain in skills/ or core/"
ALL_OK=true
OFFENDERS=()

while IFS= read -r -d '' file; do
    base="$(basename "$file")"
    # Skip the resolver doc and this test's siblings.
    [[ "$base" == "tool-resolver.md" ]] && continue
    # Skip the audit doc which discusses these paths in prose.
    case "$file" in
        */docs/audit/*) continue ;;
    esac

    # Find candidate lines.
    matches=$(grep -nE "$BARE_INVOCATION_REGEX" "$file" 2>/dev/null || true)
    [[ -z "$matches" ]] && continue

    while IFS= read -r line; do
        # Strip line number for downstream filters.
        content="${line#*:}"
        # If the match is wrapped in backticks ("`scripts/tools/x.sh`"),
        # it's a prose mention — descriptive, not an invocation. Skip.
        if [[ "$content" =~ \`[^\`]*scripts/tools/[^\`]*\` ]]; then
            # Could be both prose AND an invocation on the same line — check
            # whether the *invocation* form (no backticks) also appears.
            stripped=$(echo "$content" | sed 's/`[^`]*`//g')
            if ! [[ "$stripped" =~ scripts/tools/ ]]; then
                continue
            fi
        fi
        # If the line is in a markdown table cell (starts with |) the path
        # is descriptive. Skip.
        if [[ "$content" =~ ^[[:space:]]*\| ]]; then
            continue
        fi
        # Otherwise: real offender.
        rel="${file#"$ROOT_DIR/"}"
        OFFENDERS+=("$rel:$line")
        ALL_OK=false
    done <<< "$matches"
done < <(find "${SCAN_PATHS[@]}" -type f \( -name '*.md' -o -name '*.sh' \) -print0)

if [[ ${#OFFENDERS[@]} -gt 0 ]]; then
    echo " Found ${#OFFENDERS[@]} bare invocation(s):"
    for o in "${OFFENDERS[@]}"; do
        echo " $o"
    done
fi
assert "Skills + core docs use \$DRAFT_TOOLS/, not bare scripts/tools/" "$ALL_OK"

# --- Resolver-define check ---
echo ""
echo "## Files that invoke \$DRAFT_TOOLS/ also define DRAFT_TOOLS"
RESOLVER_USE_REGEX='\$DRAFT_TOOLS/[a-z0-9]'
RESOLVER_DEF_REGEX='DRAFT_TOOLS=.*scripts/tools'

ALL_DEFINED=true
while IFS= read -r -d '' file; do
    base="$(basename "$file")"
    [[ "$base" == "tool-resolver.md" ]] && continue
    [[ "$base" == "draft-context-loading.md" ]] && continue # documents the pattern

    if grep -qE "$RESOLVER_USE_REGEX" "$file" 2>/dev/null; then
        if ! grep -qE "$RESOLVER_DEF_REGEX" "$file" 2>/dev/null; then
            rel="${file#"$ROOT_DIR/"}"
            echo " USES \$DRAFT_TOOLS but never defines it: $rel"
            ALL_DEFINED=false
        fi
    fi
done < <(find "${SCAN_PATHS[@]}" -type f \( -name '*.md' -o -name '*.sh' \) -print0)
assert "Every \$DRAFT_TOOLS user defines DRAFT_TOOLS in-file" "$ALL_DEFINED"

# --- Resolver lines, when present, are the canonical form ---
echo ""
echo "## DRAFT_TOOLS resolver definitions use the canonical 3-line form"
ALL_CANONICAL=true
while IFS= read -r -d '' file; do
    base="$(basename "$file")"
    [[ "$base" == "tool-resolver.md" ]] && continue

    if grep -qE "$RESOLVER_DEF_REGEX" "$file" 2>/dev/null; then
        # The first assignment line must point at the Claude plugin default.
        first=$(grep -E '^[[:space:]]*DRAFT_TOOLS=' "$file" | head -1)
        if ! [[ "$first" =~ DRAFT_PLUGIN_ROOT ]]; then
            rel="${file#"$ROOT_DIR/"}"
            echo " Non-canonical first DRAFT_TOOLS= line in $rel:"
            echo " $first"
            ALL_CANONICAL=false
        fi
    fi
done < <(find "${SCAN_PATHS[@]}" -type f \( -name '*.md' -o -name '*.sh' \) -print0)
assert "All DRAFT_TOOLS resolvers begin with the \$DRAFT_PLUGIN_ROOT default" "$ALL_CANONICAL"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
