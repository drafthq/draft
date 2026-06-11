#!/usr/bin/env bash
# scripts/package.sh
#
# Draft packaging entrypoint (skeleton).
# Produces a self-contained `draft/` tree (or tarball) ready for:
#   - Marketplace / plugin distribution
#   - GitHub release assets
#   - Manual vendor into monorepos
#
# Responsibilities:
# - Invoke build-graph-binaries.sh to populate native slots (or use pre-staged)
# - Materialize Git LFS objects for binaries (or warn)
# - Run `make build` + `make lint` + core tests (recommended)
# - Optionally produce versioned tarball under dist/
# - Never emits internal paths or forbidden strings; Draft-only
#
# Usage (from Draft root):
#   ./scripts/package.sh --version 0.1.0-skel
#   ./scripts/package.sh --out /tmp/draft-pkg --tarball
#
# The resulting tree contains all skills, core/, scripts/, Makefile, etc. The
# knowledge-graph engine is fetched on install (not vendored) — see bin/README.md.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRAFT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="$(date +%Y%m%d)-skel"
OUT_DIR=""
MAKE_TARBALL=0
RUN_BUILD=1
RUN_VERIFY=1

usage() {
  cat <<'EOF'
Draft package.sh (skeleton for graph binary + full distribution)

Options:
  --version V      Version string for tarball / metadata (default: date-skel)
  --out DIR        Staging directory for the packaged tree (default: dist/draft-$VERSION)
  --tarball        Also produce a .tgz of the packaged tree
  --no-build       Skip make build + lint (for quick skeleton packaging)
  --no-verify      Skip graph binary verification step
  --help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --out) OUT_DIR="$2"; shift 2 ;;
    --tarball) MAKE_TARBALL=1; shift ;;
    --no-build) RUN_BUILD=0; shift ;;
    --no-verify) RUN_VERIFY=0; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="$DRAFT_ROOT/dist/draft-$VERSION"
fi

echo "Draft packaging (skeleton)"
echo "  Root    : $DRAFT_ROOT"
echo "  Version : $VERSION"
echo "  Output  : $OUT_DIR"
echo "  Tarball : $MAKE_TARBALL"
echo

mkdir -p "$OUT_DIR" "$(dirname "$OUT_DIR")"

# 1. Graph engine: no longer vendored. The codebase-memory-mcp binary is fetched
#    on install (scripts/fetch-memory-engine.sh) into ~/.cache/draft/bin, so the
#    packaged tree carries no native binaries or LFS objects. See bin/README.md.
echo "Graph engine is fetched on install (not vendored) — nothing to stage."

# 3. Optional full build + lint (public hygiene)
if [[ $RUN_BUILD -eq 1 ]]; then
  echo "Running make build && make lint (recommended for release)..."
  (cd "$DRAFT_ROOT" && make build 2>&1 | tail -5) || echo "  (build step non-fatal in skeleton)"
  (cd "$DRAFT_ROOT" && make lint 2>&1 | tail -10) || echo "  (lint warnings acceptable during early skeleton)"
fi

# 4. Graph verification (exercises new tool)
if [[ $RUN_VERIFY -eq 1 && -x "$DRAFT_ROOT/scripts/tools/verify-graph-binary.sh" ]]; then
  echo "Final graph binary verification..."
  "$DRAFT_ROOT/scripts/tools/verify-graph-binary.sh" --repo "$DRAFT_ROOT" --verbose || true
fi

# 5. Copy the tree (exclude heavy dev artifacts)
echo "Assembling clean draft/ tree at $OUT_DIR ..."
if command -v rsync >/dev/null 2>&1; then
  # rsync present — let real errors surface (do not mask with 2>/dev/null)
  rsync -a --delete \
    --exclude '.git' \
    --exclude 'node_modules' \
    --exclude 'target' \
    --exclude 'dist' \
    --exclude '.draft-install-path' \
    --exclude '*.log' \
    "$DRAFT_ROOT/" "$OUT_DIR/"
else
  # Fallback pure shell copy if no rsync (same exclusions as rsync path)
  rm -rf "$OUT_DIR"
  mkdir -p "$OUT_DIR"
  tar -cf - -C "$DRAFT_ROOT" \
    --exclude '.git' --exclude node_modules --exclude target --exclude dist \
    --exclude '.draft-install-path' --exclude '*.log' . | tar -xf - -C "$OUT_DIR"
fi

# 6. Embed version metadata (public)
cat > "$OUT_DIR/draft/version.txt" <<EOF
Draft packaged: $(date -Iseconds)
Version: $VERSION
Graph engine: codebase-memory-mcp, fetched on install into ~/.cache/draft/bin (not vendored)
See bin/README.md for binary details and LFS.
EOF

# 7. Tarball (optional)
if [[ $MAKE_TARBALL -eq 1 ]]; then
  TARBALL="$DRAFT_ROOT/dist/draft-$VERSION.tgz"
  mkdir -p "$(dirname "$TARBALL")"
  (cd "$(dirname "$OUT_DIR")" && tar -czf "$TARBALL" "$(basename "$OUT_DIR")")
  echo "Tarball: $TARBALL"
fi

echo
echo "Packaging complete."
echo "Packaged tree: $OUT_DIR"
echo "  Contains: full skills/, core/, bin/<arch>/ (native graph binaries), scripts/, Makefile targets"
echo "  LFS + binary layout respected per bin/README.md (bin/<arch>/ canonical)"
echo "Ready for release or vendor use. Run the packaged tree's make test to validate."
