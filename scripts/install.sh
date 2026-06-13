#!/usr/bin/env bash
#
# Install Draft plugin for Cursor, Claude Code, GitHub Copilot, Antigravity, or Gemini.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/drafthq/draft/main/scripts/install.sh | bash -s -- [target]
#
# Targets:
#   --cursor       Install to ~/.cursor/plugins/local/draft (default)
#   --claude       Install to ./.claude-plugin/ and project root
#   --copilot      Install to ./.github/copilot-instructions.md
#   --antigravity  Install to ~/.gemini/antigravity/skills/draft
#   --gemini       Install to ./.gemini.md
#
# After copying, the script fetches the knowledge-graph engine binary on demand
# (see scripts/fetch-memory-engine.sh and bin/README.md). Fetch failures are
# non-fatal so air-gapped / placeholder installs still succeed.
#

set -euo pipefail

REPO_URL="https://github.com/drafthq/draft.git"

# ── Parse flags ──────────────────────────────────────────────
TARGET="cursor"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --cursor)      TARGET="cursor";      shift ;;
        --claude)      TARGET="claude";      shift ;;
        --copilot)     TARGET="copilot";     shift ;;
        --antigravity) TARGET="antigravity"; shift ;;
        --gemini)      TARGET="gemini";      shift ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: install.sh [--cursor | --claude | --copilot | --antigravity | --gemini]" >&2
            exit 1
            ;;
    esac
done

# ── Download and extract ─────────────────────────────────────
INSTALL_TMPDIR="$(mktemp -d)"
trap 'rm -rf "$INSTALL_TMPDIR"' EXIT

echo "Downloading Draft..."
git clone --quiet --depth 1 "$REPO_URL" "$INSTALL_TMPDIR/draft"

# Fetch the knowledge-graph engine (codebase-memory-mcp) into the Draft-managed
# location (~/.cache/draft/bin). Network-gated and best-effort — graph features
# degrade gracefully when the engine is absent. See bin/README.md.
if [[ -x "$INSTALL_TMPDIR/draft/scripts/fetch-memory-engine.sh" ]]; then
    "$INSTALL_TMPDIR/draft/scripts/fetch-memory-engine.sh" \
        || echo "  (graph engine fetch skipped — install later with scripts/fetch-memory-engine.sh)"
fi

case "$TARGET" in
    cursor)
        INSTALL_DIR="$HOME/.cursor/plugins/local/draft"
        mkdir -p "$(dirname "$INSTALL_DIR")"
        rm -rf "$INSTALL_DIR"
        cp -R "$INSTALL_TMPDIR/draft" "$INSTALL_DIR"
        echo "$INSTALL_DIR" > "$INSTALL_DIR/.draft-install-path"
        echo "Draft installed to $INSTALL_DIR"
        echo "Restart Cursor to detect the plugin."
        ;;
    claude)
        INSTALL_DIR="$(pwd)"
        mkdir -p "$INSTALL_DIR/.claude-plugin"
        if [[ -d "$INSTALL_TMPDIR/draft/.claude-plugin" ]]; then
            cp -R "$INSTALL_TMPDIR/draft/.claude-plugin/." "$INSTALL_DIR/.claude-plugin/"
        fi
        for dir in skills core scripts bin graph; do
            if [[ -d "$INSTALL_TMPDIR/draft/$dir" ]]; then
                mkdir -p "$INSTALL_DIR/$dir"
                cp -R "$INSTALL_TMPDIR/draft/$dir/." "$INSTALL_DIR/$dir/"
            fi
        done
        echo "$INSTALL_DIR" > "$INSTALL_DIR/.draft-install-path"
        echo "Draft installed to current directory for Claude Code."
        ;;
    copilot)
        INSTALL_DIR="$(pwd)/.github"
        mkdir -p "$INSTALL_DIR"
        cp "$INSTALL_TMPDIR/draft/integrations/copilot/.github/copilot-instructions.md" "$INSTALL_DIR/copilot-instructions.md"
        echo "Copilot instructions installed to $INSTALL_DIR/copilot-instructions.md"
        echo "Commit this file to your repository."
        ;;
    gemini)
        INSTALL_DIR="$(pwd)"
        cp "$INSTALL_TMPDIR/draft/integrations/gemini/.gemini.md" "$INSTALL_DIR/.gemini.md"
        echo "Gemini instructions installed to $INSTALL_DIR/.gemini.md"
        ;;
    antigravity)
        INSTALL_DIR="$HOME/.gemini/antigravity/skills/draft"
        mkdir -p "$(dirname "$INSTALL_DIR")"
        rm -rf "$INSTALL_DIR"
        cp -R "$INSTALL_TMPDIR/draft" "$INSTALL_DIR"
        echo "$INSTALL_DIR" > "$INSTALL_DIR/.draft-install-path"

        GEMINI_MD="$HOME/.gemini.md"
        if ! grep -q "/.gemini/antigravity/skills/draft/skills" "$GEMINI_MD" 2>/dev/null; then
            echo "" >> "$GEMINI_MD"
            echo "**Skill Locations:**" >> "$GEMINI_MD"
            echo "The authoritative Draft implementation skills are located at:" >> "$GEMINI_MD"
            echo "\`$INSTALL_DIR/skills\`" >> "$GEMINI_MD"
        fi
        echo "Draft installed to $INSTALL_DIR and configured in ~/.gemini.md"
        ;;
esac

# Verify the graph binary selection in the installed tree (graceful — graph
# features degrade if the native binary is absent for this OS/arch).
if [[ -n "${INSTALL_DIR:-}" && -x "$INSTALL_DIR/scripts/tools/verify-graph-binary.sh" ]]; then
    "$INSTALL_DIR/scripts/tools/verify-graph-binary.sh" --repo "$INSTALL_DIR" 2>/dev/null \
        || echo "  (graph binary not verified — native binary may be absent; features degrade gracefully)"
fi

echo ""
echo "Done! Run /draft to see available commands."
