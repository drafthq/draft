#!/usr/bin/env bash
<<<<<<< HEAD
# scripts/install.sh
#
# Public Draft install-time bootstrap (skeleton for Phase 3/4 packaging).
# - Writes .draft-install-path breadcrumb for reliable plugin root discovery
# - Ensures Git LFS objects for native graph binaries are materialized
# - Verifies graph native binary using the verifier (PATH > bundled arch)
# - Safe for marketplace / git clone / tarball installs
# - Produces only draft/ artifacts; Draft-only language throughout
#
# Typical flows:
#   ./scripts/install.sh                 # after git clone of Draft
#   ./scripts/install.sh --prefix /opt/draft
#
# The script is idempotent and never mutates user projects.
# See bin/README.md for LFS + layout details (bin/<arch>/ is canonical).
# Called (or emulated) by IDE plugin installers and by package.sh consumers.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRAFT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PREFIX=""
DO_VERIFY=1
DO_LFS=1

usage() {
  cat <<'EOF'
Draft install bootstrap (skeleton)

  --prefix DIR     Install root (writes $PREFIX/.draft-install-path)
  --no-lfs         Skip git lfs pull (for air-gapped or already-materialized trees)
  --no-verify      Skip post-install graph binary verification
  --help           This message

After a successful run, any Draft invocation can locate the bundled graph via the breadcrumb.
Native binaries (bin/<arch>/graph canonical; graph/bin/ legacy transition) are used when present.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix) PREFIX="$2"; shift 2 ;;
    --no-lfs) DO_LFS=0; shift ;;
    --no-verify) DO_VERIFY=0; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$PREFIX" ]]; then
  PREFIX="$DRAFT_ROOT"
fi

echo "Draft install bootstrap"
echo "  Draft root : $DRAFT_ROOT"
echo "  Prefix     : $PREFIX"
echo

# 1. Write breadcrumb (used by detection in init, graph-query, verify-*, tools)
BREADCRUMB="$PREFIX/.draft-install-path"
echo "$DRAFT_ROOT" > "$BREADCRUMB"
echo "Wrote breadcrumb: $BREADCRUMB → $DRAFT_ROOT"

# 2. Git LFS (respect instructions in bin/README.md for canonical layout)
if [[ $DO_LFS -eq 1 ]]; then
  if command -v git-lfs >/dev/null 2>&1; then
    echo "Ensuring Git LFS objects for graph binaries..."
    (cd "$DRAFT_ROOT" && git lfs install --local 2>/dev/null || true)
    (cd "$DRAFT_ROOT" && git lfs pull --include="bin/**/graph*" 2>/dev/null || echo "  (LFS pull skipped or partial — binaries may be placeholders until real artifacts added)")
  else
    echo "  git-lfs not found in PATH — native binaries (if LFS-tracked) will be missing placeholders."
    echo "  Install git-lfs and re-run with git lfs pull, or use a tarball that already contains the objects."
  fi
fi

# 3. Verify graph binary selection (uses new preference + writes usage report if in a draft context)
if [[ $DO_VERIFY -eq 1 ]]; then
  if [[ -x "$DRAFT_ROOT/scripts/tools/verify-graph-binary.sh" ]]; then
    echo "Verifying graph binary (PATH > bundled arch)..."
    "$DRAFT_ROOT/scripts/tools/verify-graph-binary.sh" --repo "$DRAFT_ROOT" --verbose || {
      echo "  (verify reported non-zero; native binary may be absent — graph features will degrade gracefully)"
    }
  else
    echo "  verify-graph-binary.sh not present — skipping (graph features will be unavailable until binary is installed)"
  fi
fi

# 4. Summary for user / CI
echo
echo "Install bootstrap complete for Draft."
echo "  - Breadcrumb ready for IDE/plugin detection"
echo "  - bin/<arch>/ layout (canonical) + legacy graph/bin/ supported; LFS respected (see bin/README.md)"
echo "  - Next: run 'make build' then 'make lint' or invoke /draft:init in a project"
echo "  - Native graph binaries (when added) will be auto-preferred for best performance"
=======
#
# Install Draft plugin for Cursor, Claude Code, GitHub Copilot, Antigravity, or Gemini.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/mayurpise/draft/main/scripts/install.sh | bash -s -- [target]
#
# Targets:
#   --cursor       Install to ~/.cursor/plugins/local/draft (default)
#   --claude       Install to ./.claude-plugin/ and project root
#   --copilot      Install to ./.github/copilot-instructions.md
#   --antigravity  Install to ~/.gemini/antigravity/skills/draft
#   --gemini       Install to ./.gemini.md
#

set -euo pipefail

REPO_URL="https://github.com/mayurpise/draft.git"

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
            cp -R "$INSTALL_TMPDIR/draft/.claude-plugin/"* "$INSTALL_DIR/.claude-plugin/"
        fi
        for dir in skills core scripts graph; do
            if [[ -d "$INSTALL_TMPDIR/draft/$dir" ]]; then
                mkdir -p "$INSTALL_DIR/$dir"
                cp -R "$INSTALL_TMPDIR/draft/$dir/"* "$INSTALL_DIR/$dir/"
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

echo ""
echo "Done! Run /draft to see available commands."
>>>>>>> a79c14023e16774c77463870ac3510b728e8a91c
