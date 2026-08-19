#!/usr/bin/env bash
# resolve-tools.sh — print the absolute path to Draft's bundled scripts/tools dir.
#
# Skills run with cwd = the user's project, and ${CLAUDE_PLUGIN_ROOT} is NOT exported
# into skill-driven Bash, so a bare `scripts/tools/foo.sh` invocation fails. This
# resolver finds the plugin's helper directory regardless of how Draft was installed.
# See core/shared/tool-resolver.md for the canonical procedure and the inline preamble
# skills embed (this script is the single source of truth for the resolution order).
#
# Resolution order is deliberately "authoritative install first, cwd last":
# skills execute whatever this prints, and the cwd is the repository under review,
# which Draft routinely runs against untrusted code. A project that ships its own
# scripts/tools/ must never shadow the installed plugin.
#
# Working on Draft itself? Export DRAFT_PLUGIN_ROOT="$PWD" — the explicit override
# is step 1 and always wins.
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
  # `|| true` is load-bearing: on a glob miss `ls` exits non-zero, pipefail
  # propagates it, and errexit would abort the whole resolver instead of letting
  # the remaining fallbacks run.
  # shellcheck disable=SC2086
  ls -d $1 2>/dev/null | sort -V | tail -1 || true
}

# Is DIR Draft's own source checkout? Checked before trusting the cwd at all.
is_draft_checkout() {
  [ -f "$1/scripts/tools/resolve-tools.sh" ] || return 1
  [ -f "$1/.claude-plugin/plugin.json" ] || return 1
  grep -q '"name"[[:space:]]*:[[:space:]]*"draft"' "$1/.claude-plugin/plugin.json" 2>/dev/null
}

resolve() {
  local d

  # 1. Explicit override (testing / pinned installs).
  d="${DRAFT_PLUGIN_ROOT:-}/scripts/tools"
  [ -n "${DRAFT_PLUGIN_ROOT:-}" ] && [ -d "$d" ] && { printf '%s' "$d"; return 0; }

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

  # 8. Last resort — dev / dogfooding inside Draft's own checkout. Deliberately
  # after every install location, and gated on the plugin manifest rather than on
  # a same-named file: a bare `$PWD/scripts/tools` test matched any project using
  # that very common layout and handed it script execution.
  is_draft_checkout "$PWD" && { printf '%s' "$PWD/scripts/tools"; return 0; }

  return 1
}

resolve
