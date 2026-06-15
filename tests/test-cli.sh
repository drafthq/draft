#!/usr/bin/env bash
# Test suite for the npm `draft` CLI (cli/bin/draft.js).
#
# What this tests:
# - --version / --help / list exit 0 and name all 4 hosts
# - every host id and alias resolves; unknown host exits non-zero
# - install --dry-run writes ZERO files and prints the planned target
# - real installs land the expected artifact (codex AGENTS.md), and guard
#   refuses to overwrite without --force
#
# What this does NOT test:
# - the knowledge-graph engine fetch (network-gated; --no-graph used throughout)
# - host-side discovery/activation (out of process)
#
# Usage: ./tests/test-cli.sh
# Exit code: number of failed tests (0 = all pass)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CLI="$ROOT_DIR/cli/bin/draft.js"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== draft CLI tests ==="
echo ""

# --- Prerequisites ---
echo "## Prerequisites"
assert "node is available" \
    "$(command -v node >/dev/null 2>&1 && echo true || echo false)"
assert "cli/bin/draft.js exists" \
    "$([[ -f "$CLI" ]] && echo true || echo false)"
assert "cli/bin/draft.js is executable" \
    "$([[ -x "$CLI" ]] && echo true || echo false)"

# --- Top-level commands ---
echo ""
echo "## Commands"
VERSION_OUT="$(node "$CLI" --version 2>/dev/null || echo FAIL)"
assert "--version prints package version" \
    "$([[ "$VERSION_OUT" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]] && echo true || echo false)"

if node "$CLI" --help >/dev/null 2>&1; then HELP_OK=true; else HELP_OK=false; fi
assert "--help exits 0" "$HELP_OK"

LIST_OUT="$(node "$CLI" list 2>/dev/null)"
for host in claude-code cursor codex opencode; do
    assert "list names host '$host'" \
        "$(echo "$LIST_OUT" | grep -q "$host" && echo true || echo false)"
done

# --- Host resolution ---
echo ""
echo "## Host resolution"
# Aliases resolve (claude → claude-code); dry-run keeps it side-effect free.
ALIAS_TMP="$(mktemp -d)"
if ( cd "$ALIAS_TMP" && node "$CLI" install claude --dry-run >/dev/null 2>&1 ); then
    ALIAS_OK=true
else
    ALIAS_OK=false
fi
assert "alias 'claude' resolves to a host (exit 0)" "$ALIAS_OK"
rm -rf "$ALIAS_TMP"

if node "$CLI" install nonexistent-host --dry-run >/dev/null 2>&1; then
    assert "unknown host exits non-zero" "false"
else
    assert "unknown host exits non-zero" "true"
fi

# --- Dry-run writes nothing ---
echo ""
echo "## Dry run is side-effect free"
DRY_TMP="$(mktemp -d)"
DRY_HOME="$(mktemp -d)"
( cd "$DRY_TMP" && HOME="$DRY_HOME" node "$CLI" install codex --dry-run >/dev/null 2>&1 )
DRY_FILES=$(find "$DRY_TMP" "$DRY_HOME" -type f | wc -l | tr -d ' ')
assert "codex --dry-run writes zero files" \
    "$([[ "$DRY_FILES" -eq 0 ]] && echo true || echo false)"
DRY_PLAN="$( cd "$DRY_TMP" && node "$CLI" install codex --dry-run 2>/dev/null )"
assert "codex --dry-run names AGENTS.md" \
    "$(echo "$DRY_PLAN" | grep -q 'AGENTS.md' && echo true || echo false)"
rm -rf "$DRY_TMP" "$DRY_HOME"

# --- Real codex install + guard ---
echo ""
echo "## codex install + overwrite guard"
CDX_TMP="$(mktemp -d)"
( cd "$CDX_TMP" && node "$CLI" install codex --no-graph >/dev/null 2>&1 )
assert "codex install writes AGENTS.md" \
    "$([[ -f "$CDX_TMP/AGENTS.md" ]] && echo true || echo false)"
assert "AGENTS.md is non-trivial (>100 lines)" \
    "$([[ "$(wc -l < "$CDX_TMP/AGENTS.md" | tr -d ' ')" -gt 100 ]] && echo true || echo false)"
if ( cd "$CDX_TMP" && node "$CLI" install codex --no-graph >/dev/null 2>&1 ); then
    assert "re-install without --force is refused (exit non-zero)" "false"
else
    assert "re-install without --force is refused (exit non-zero)" "true"
fi
if ( cd "$CDX_TMP" && node "$CLI" install codex --no-graph --force >/dev/null 2>&1 ); then
    FORCE_OK=true
else
    FORCE_OK=false
fi
assert "re-install with --force succeeds (exit 0)" "$FORCE_OK"
rm -rf "$CDX_TMP"

# --- claude-code install drives the `claude plugin` CLI (no file copy) ---
echo ""
echo "## claude-code install (plugin registry)"
CC_TMP="$(mktemp -d)"
CC_PLAN="$( cd "$CC_TMP" && node "$CLI" install claude-code --dry-run 2>&1 )"
assert "claude-code --dry-run runs 'claude plugin marketplace add'" \
    "$(echo "$CC_PLAN" | grep -q 'claude plugin marketplace add drafthq/draft' && echo true || echo false)"
assert "claude-code --dry-run runs 'claude plugin install draft@draft-plugins'" \
    "$(echo "$CC_PLAN" | grep -q 'claude plugin install draft@draft-plugins' && echo true || echo false)"
assert "claude-code --dry-run writes no files to cwd" \
    "$([[ "$(find "$CC_TMP" -type f | wc -l | tr -d ' ')" -eq 0 ]] && echo true || echo false)"
rm -rf "$CC_TMP"

# --- Missing `claude` CLI: loud failure, not a silent no-op ---
echo ""
echo "## claude-code install when the claude CLI is absent"
NODE_BIN="$(command -v node)"
MISS_TMP="$(mktemp -d)"; MISS_HOME="$(mktemp -d)"
# Empty PATH so spawnSync('claude') hits ENOENT; node runs via its absolute path.
if ( cd "$MISS_TMP" && PATH="/nonexistent" HOME="$MISS_HOME" "$NODE_BIN" "$CLI" install claude-code --no-graph >/dev/null 2>&1 ); then
    assert "missing claude CLI exits non-zero" "false"
else
    assert "missing claude CLI exits non-zero" "true"
fi
MISS_OUT="$( cd "$MISS_TMP" && PATH="/nonexistent" HOME="$MISS_HOME" "$NODE_BIN" "$CLI" install claude-code --no-graph 2>&1 || true )"
assert "missing claude CLI says nothing was installed" \
    "$(echo "$MISS_OUT" | grep -qi 'nothing was installed' && echo true || echo false)"
assert "missing claude CLI prints the /plugin fallback" \
    "$(echo "$MISS_OUT" | grep -q '/plugin marketplace add drafthq/draft' && echo true || echo false)"
rm -rf "$MISS_TMP" "$MISS_HOME"

# --- Stale `claude` CLI (no `plugin` subcommand): step fails with an upgrade hint ---
echo ""
echo "## claude-code install when the claude CLI is too old"
STALE_DIR="$(mktemp -d)"; STALE_TMP="$(mktemp -d)"; STALE_HOME="$(mktemp -d)"
# Fake claude: answers --version (so the binary check passes) but errors on any
# subcommand (so `claude plugin marketplace add` fails like an old CLI would).
cat > "$STALE_DIR/claude" <<'FAKE'
#!/usr/bin/env bash
if [ "$1" = "--version" ]; then echo "1.0.0 (fake)"; exit 0; fi
echo "error: unknown command '$1'" >&2; exit 1
FAKE
chmod +x "$STALE_DIR/claude"
if ( cd "$STALE_TMP" && PATH="$STALE_DIR:$PATH" HOME="$STALE_HOME" "$NODE_BIN" "$CLI" install claude-code --no-graph >/dev/null 2>&1 ); then
    assert "stale claude CLI exits non-zero" "false"
else
    assert "stale claude CLI exits non-zero" "true"
fi
STALE_OUT="$( cd "$STALE_TMP" && PATH="$STALE_DIR:$PATH" HOME="$STALE_HOME" "$NODE_BIN" "$CLI" install claude-code --no-graph 2>&1 || true )"
assert "stale claude CLI hints to update Claude Code" \
    "$(echo "$STALE_OUT" | grep -qi 'claude update\|too old' && echo true || echo false)"
assert "stale claude CLI prints the /plugin fallback" \
    "$(echo "$STALE_OUT" | grep -q '/plugin marketplace add drafthq/draft' && echo true || echo false)"
rm -rf "$STALE_DIR" "$STALE_TMP" "$STALE_HOME"

# --- Old installer is gone ---
echo ""
echo "## Legacy installer removed"
assert "scripts/install.sh no longer exists" \
    "$([[ ! -f "$ROOT_DIR/scripts/install.sh" ]] && echo true || echo false)"

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
