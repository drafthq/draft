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

# --- From a foreign cwd, still resolves a real, existing scripts/tools dir ---
# (Does not depend on HOW it resolves — marker, glob, or override — only that the
#  result exists and contains a known helper. This is the property that was broken:
#  a bare `scripts/tools/x.sh` from a user project cwd never resolves.)
FOREIGN="$(mktemp -d)"
out="$(cd "$FOREIGN" && DRAFT_PLUGIN_ROOT="$ROOT_DIR" "$TOOL")"
assert "From a foreign cwd, resolves to an existing scripts/tools dir" \
    "$([[ -d "$out" && -f "$out/hotspot-rank.sh" ]] && echo true || echo false)"
rm -rf "$FOREIGN"

# ---------------------------------------------------------------------------
# Install-location fallbacks (steps 2-8).
#
# Every case below runs under a synthetic HOME. Without that, whatever Draft
# install the developer happens to have leaks into the assertions — which is
# exactly why steps 2-8 went untested, and why two defects lived in them: the
# cwd captured resolution ahead of every install location, and a glob miss at
# step 5 aborted the script before steps 6-8 could run.
# ---------------------------------------------------------------------------

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$OVERRIDE" "$SANDBOX"' EXIT

# A believable installed plugin: a directory that carries scripts/tools/.
make_install() {
    local dir="$1"
    mkdir -p "$dir/scripts/tools"
    : > "$dir/scripts/tools/hotspot-rank.sh"
    printf '%s' "$dir"
}

# A cwd that is NOT Draft's checkout, so the last-resort step cannot fire.
NEUTRAL="$SANDBOX/neutral"; mkdir -p "$NEUTRAL"

# resolve <home> [cwd] — run the resolver under a synthetic HOME. Echoes stdout
# and returns the resolver's exit code (capture it with RC=$? at the call site;
# a global set in here would die with the command-substitution subshell).
resolve() {
    local home="$1" cwd="${2:-$NEUTRAL}"
    ( cd "$cwd" && env -u DRAFT_PLUGIN_ROOT -u CLAUDE_PLUGIN_ROOT HOME="$home" "$TOOL" )
}

# --- Step 2: the install marker written by `draft install` ---
H="$SANDBOX/h-marker"; mkdir -p "$H/.cache/draft"
MARKED="$(make_install "$SANDBOX/marked")"
printf '%s\n' "$MARKED" > "$H/.cache/draft/plugin-root"
out="$(resolve "$H")"
assert "Step 2: install marker resolves" \
    "$([[ "$out" == "$MARKED/scripts/tools" ]] && echo true || echo false)"

# --- Step 3: CLAUDE_PLUGIN_ROOT (hook/MCP contexts) ---
H="$SANDBOX/h-env"; mkdir -p "$H"
ENVROOT="$(make_install "$SANDBOX/envroot")"
set +e
out="$(cd "$NEUTRAL" && env -u DRAFT_PLUGIN_ROOT HOME="$H" CLAUDE_PLUGIN_ROOT="$ENVROOT" "$TOOL")"
set -e
assert "Step 3: CLAUDE_PLUGIN_ROOT resolves" \
    "$([[ "$out" == "$ENVROOT/scripts/tools" ]] && echo true || echo false)"

# --- Step 4: Claude Code's own plugin registry ---
if command -v jq >/dev/null 2>&1; then
    H="$SANDBOX/h-reg"; mkdir -p "$H/.claude/plugins"
    REG="$(make_install "$SANDBOX/registered")"
    printf '{"plugins":{"draft@draft-plugins":[{"installPath":"%s"}]}}\n' "$REG" \
        > "$H/.claude/plugins/installed_plugins.json"
    out="$(resolve "$H")"
    assert "Step 4: installed_plugins.json registry resolves" \
        "$([[ "$out" == "$REG/scripts/tools" ]] && echo true || echo false)"
fi

# --- Step 5: newest versioned dir under the plugin cache (version sort) ---
H="$SANDBOX/h-cache"
mkdir -p "$H/.claude/plugins/cache/mkt/draft/1.9.0/scripts/tools" \
         "$H/.claude/plugins/cache/mkt/draft/1.10.0/scripts/tools"
out="$(resolve "$H")"
assert "Step 5: cache glob picks the version-newest install" \
    "$([[ "$out" == "$H/.claude/plugins/cache/mkt/draft/1.10.0/scripts/tools" ]] && echo true || echo false)"

# --- Step 6: marketplace clone ---
H="$SANDBOX/h-mkt"; mkdir -p "$H/.claude/plugins/marketplaces/drafthq-draft/scripts/tools"
out="$(resolve "$H")"
assert "Step 6: marketplace clone resolves (reached only if step 5's glob miss does not abort)" \
    "$([[ "$out" == "$H/.claude/plugins/marketplaces/drafthq-draft/scripts/tools" ]] && echo true || echo false)"

# --- Step 7: Cursor local install ---
# The regression test for the pipefail abort: `ls` failing on the step-5 glob used
# to kill the script outright, so a Cursor-only install resolved to nothing.
H="$SANDBOX/h-cursor"; mkdir -p "$H/.cursor/plugins/local/draft/scripts/tools"
out="$(resolve "$H")"
assert "Step 7: Cursor local install resolves after a step-5 glob miss" \
    "$([[ "$out" == "$H/.cursor/plugins/local/draft/scripts/tools" ]] && echo true || echo false)"

# --- Step 8: last resort — Draft's own checkout, under a clean HOME ---
H="$SANDBOX/h-empty"; mkdir -p "$H"
out="$(resolve "$H" "$ROOT_DIR")"
assert "Step 8: from Draft's checkout with nothing installed, resolves to the repo" \
    "$([[ "$out" == "$ROOT_DIR/scripts/tools" ]] && echo true || echo false)"

# --- Nothing installed anywhere: the documented exit 1, not an errexit abort ---
set +e; out="$(resolve "$SANDBOX/h-empty")"; RC=$?; set -e
assert "Nothing installed → empty output" "$([[ -z "$out" ]] && echo true || echo false)"
assert "Nothing installed → documented exit 1 (not a mid-chain abort)" \
    "$([[ "$RC" == "1" ]] && echo true || echo false)"

# ---------------------------------------------------------------------------
# The cwd must never outrank an install location. Skills execute whatever this
# prints, and the cwd is the repository under review — which Draft is routinely
# pointed at without trusting it.
# ---------------------------------------------------------------------------

HOSTILE="$SANDBOX/hostile"
mkdir -p "$HOSTILE/scripts/tools" "$HOSTILE/.claude-plugin"
cp "$TOOL" "$HOSTILE/scripts/tools/resolve-tools.sh"
printf '{"name":"draft"}\n' > "$HOSTILE/.claude-plugin/plugin.json"
: > "$HOSTILE/scripts/tools/hotspot-rank.sh"

out="$(resolve "$SANDBOX/h-cursor" "$HOSTILE")"
assert "A repo impersonating Draft does not outrank an installed plugin" \
    "$([[ "$out" == "$SANDBOX/h-cursor/.cursor/plugins/local/draft/scripts/tools" ]] && echo true || echo false)"

# A plain project that merely uses the scripts/tools/ layout must resolve nothing.
PLAIN="$SANDBOX/plain"; mkdir -p "$PLAIN/scripts/tools"
set +e; out="$(resolve "$SANDBOX/h-empty" "$PLAIN")"; RC=$?; set -e
assert "A project with an unrelated scripts/tools/ dir is never selected" \
    "$([[ -z "$out" && "$RC" == "1" ]] && echo true || echo false)"

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
