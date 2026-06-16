#!/usr/bin/env bash
# Test suite for scripts/tools/resolve-tools.sh
#
# resolve-tools.sh prints the absolute path to Draft's bundled scripts/tools dir,
# regardless of how Draft was installed and regardless of the caller's cwd. This is
# the canonical resolution logic skills embed inline (see core/shared/tool-resolver.md);
# without it, skills invoke helpers by a cwd-relative path that fails in user projects.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/resolve-tools.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== resolve-tools.sh tests ==="
echo ""

# --- --help works (convention) ---
set +e
help_out="$("$TOOL" --help)"; help_rc=$?
set -e
assert "--help exits 0" "$([[ "$help_rc" == "0" ]] && echo true || echo false)"
assert "--help prints non-empty usage" "$([[ -n "$help_out" ]] && echo true || echo false)"

# --- Explicit override (DRAFT_PLUGIN_ROOT) wins ---
OVERRIDE="$(mktemp -d)"; mkdir -p "$OVERRIDE/scripts/tools"
trap 'rm -rf "$OVERRIDE"' EXIT
out="$(DRAFT_PLUGIN_ROOT="$OVERRIDE" "$TOOL")"
assert "DRAFT_PLUGIN_ROOT override resolves to its scripts/tools" \
    "$([[ "$out" == "$OVERRIDE/scripts/tools" ]] && echo true || echo false)"

# --- Dev/dogfood: run from the repo, resolves to the repo's own scripts/tools ---
out="$(cd "$ROOT_DIR" && "$TOOL")"
assert "From the draft repo cwd, resolves to repo scripts/tools" \
    "$([[ "$out" == "$ROOT_DIR/scripts/tools" ]] && echo true || echo false)"

# --- From a foreign cwd, still resolves a real, existing scripts/tools dir ---
# (Does not depend on HOW it resolves — marker, glob, or override — only that the
#  result exists and contains a known helper. This is the property that was broken:
#  a bare `scripts/tools/x.sh` from a user project cwd never resolves.)
FOREIGN="$(mktemp -d)"
out="$(cd "$FOREIGN" && DRAFT_PLUGIN_ROOT="$ROOT_DIR" "$TOOL")"
assert "From a foreign cwd, resolves to an existing scripts/tools dir" \
    "$([[ -d "$out" && -f "$out/hotspot-rank.sh" ]] && echo true || echo false)"
rm -rf "$FOREIGN"

# --- Guard: no skill ships a bare, cwd-relative `scripts/tools/<tool>` INVOCATION.
# Invocations are bare paths at a command position or piped/backgrounded; doc-links
# `](.../scripts/tools/...)` and prose mentions inside backticks that are not commands
# are excluded. We flag the specific broken form: a line that runs `scripts/tools/x.sh`
# or `bash scripts/tools/x.sh` without a leading "$DRAFT_TOOLS/" anchor.
BAD=0
while IFS= read -r line; do
    BAD=$((BAD + 1))
    echo "   bare invocation: $line"
done < <(grep -rnE '(^|[`; ]|bash )scripts/tools/[a-z0-9-]+\.sh' "$ROOT_DIR"/skills/*/SKILL.md \
            | grep -vE '\$DRAFT_TOOLS|\$DRAFT_SCRIPTS|\]\(' \
            | grep -vE ':[0-9]+:[[:space:]]*\|' \
            | grep -vE 'check-graph-usage-report|check-scope-conflicts|_lib\.sh' || true)
assert "No skill ships a bare cwd-relative scripts/tools invocation" \
    "$([[ "$BAD" == "0" ]] && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
