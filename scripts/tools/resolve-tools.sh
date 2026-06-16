#!/usr/bin/env bash
# resolve-tools.sh — print the absolute path to Draft's bundled scripts/tools dir.
#
# Skills run with cwd = the user's project, and ${CLAUDE_PLUGIN_ROOT} is NOT exported
# into skill-driven Bash, so a bare `scripts/tools/foo.sh` invocation fails. This
# resolver finds the plugin's helper directory regardless of how Draft was installed.
# See core/shared/tool-resolver.md for the canonical procedure and the inline preamble
# skills embed (this script is the single source of truth for the resolution order).
#
# Usage:
#   DRAFT_TOOLS="$(scripts/tools/resolve-tools.sh)"   # prints the dir, exit 0 if found
#   scripts/tools/resolve-tools.sh || echo "tools not found"   # exit 1 if none exist
set -euo pipefail

case "${1:-}" in
  -h|--help)
    sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
esac

newest() {
  # Echo the lexically-newest existing match of a glob (by version sort), or nothing.
  # shellcheck disable=SC2086
  ls -d $1 2>/dev/null | sort -V | tail -1
}

resolve() {
  local d

  # 1. Explicit override (testing / pinned installs).
  d="${DRAFT_PLUGIN_ROOT:-}/scripts/tools"
  [ -n "${DRAFT_PLUGIN_ROOT:-}" ] && [ -d "$d" ] && { printf '%s' "$d"; return 0; }

  # 1b. Dev / dogfooding: cwd IS the draft repo. Guarded by this script's own
  # presence so it can never misfire in a user project (which has no resolve-tools.sh).
  [ -f "$PWD/scripts/tools/resolve-tools.sh" ] && { printf '%s' "$PWD/scripts/tools"; return 0; }

  # 2. Install marker written by `draft install` (authoritative).
  local marker="$HOME/.cache/draft/plugin-root"
  if [ -f "$marker" ]; then
    d="$(cat "$marker" 2>/dev/null)/scripts/tools"
    [ -d "$d" ] && { printf '%s' "$d"; return 0; }
  fi

  # 3. ${CLAUDE_PLUGIN_ROOT} — set in hook/MCP contexts; harmless to probe.
  d="${CLAUDE_PLUGIN_ROOT:-}/scripts/tools"
  [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -d "$d" ] && { printf '%s' "$d"; return 0; }

  # 4. Claude Code's own registry (authoritative installPath; needs jq).
  local reg="$HOME/.claude/plugins/installed_plugins.json"
  if command -v jq >/dev/null 2>&1 && [ -f "$reg" ]; then
    local ip
    ip="$(jq -r '.plugins | to_entries[] | select(.key|startswith("draft@")) | .value[0].installPath' \
          "$reg" 2>/dev/null | head -1)"
    [ -n "$ip" ] && [ -d "$ip/scripts/tools" ] && { printf '%s' "$ip/scripts/tools"; return 0; }
  fi

  # 5. Newest cache install (glob).
  d="$(newest "$HOME/.claude/plugins/cache/*/draft/*/scripts/tools")"
  [ -n "$d" ] && [ -d "$d" ] && { printf '%s' "$d"; return 0; }

  # 6. Marketplace clone.
  d="$(newest "$HOME/.claude/plugins/marketplaces/*draft*/scripts/tools")"
  [ -n "$d" ] && [ -d "$d" ] && { printf '%s' "$d"; return 0; }

  # 7. Cursor local install.
  d="$HOME/.cursor/plugins/local/draft/scripts/tools"
  [ -d "$d" ] && { printf '%s' "$d"; return 0; }

  # 8. Dev / dogfooding (running inside the draft repo itself).
  d="$PWD/scripts/tools"
  [ -d "$d" ] && { printf '%s' "$d"; return 0; }

  return 1
}

resolve
