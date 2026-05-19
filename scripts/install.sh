#!/usr/bin/env bash
# scripts/install.sh
#
# Public Draft install-time bootstrap (skeleton for Phase 3/4 packaging).
# - Writes .draft-install-path breadcrumb for reliable plugin root discovery
# - Ensures Git LFS objects for native graph binaries are materialized
# - Verifies graph binary (native or legacy) using the new verifier
# - Safe for marketplace / git clone / tarball installs
# - Produces only draft/ artifacts; Draft-only language throughout
#
# Typical flows:
#   ./scripts/install.sh                 # after git clone of Draft
#   ./scripts/install.sh --prefix /opt/draft
#
# The script is idempotent and never mutates user projects.
# See graph/bin/README.md for LFS + layout details.
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
Native binaries (if present in graph/bin/<arch>/) will be preferred over the legacy Node wrapper.
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

# 2. Git LFS (respect instructions in graph/bin/README.md)
if [[ $DO_LFS -eq 1 ]]; then
  if command -v git-lfs >/dev/null 2>&1; then
    echo "Ensuring Git LFS objects for graph binaries..."
    (cd "$DRAFT_ROOT" && git lfs install --local 2>/dev/null || true)
    (cd "$DRAFT_ROOT" && git lfs pull --include="graph/bin/**/graph*" 2>/dev/null || echo "  (LFS pull skipped or partial — binaries may be placeholders until real artifacts added)")
  else
    echo "  git-lfs not found in PATH — native binaries (if LFS-tracked) will be missing placeholders."
    echo "  Install git-lfs and re-run with git lfs pull, or use a tarball that already contains the objects."
  fi
fi

# 3. Verify graph binary selection (uses new preference + writes usage report if in a draft context)
if [[ $DO_VERIFY -eq 1 ]]; then
  if [[ -x "$DRAFT_ROOT/scripts/tools/verify-graph-binary.sh" ]]; then
    echo "Verifying graph binary (PATH > bundled > legacy)..."
    "$DRAFT_ROOT/scripts/tools/verify-graph-binary.sh" --repo "$DRAFT_ROOT" --verbose || {
      echo "  (verify reported non-zero; native may be absent — legacy still functional)"
    }
  else
    echo "  verify-graph-binary.sh not present — skipping (legacy detection will be used at runtime)"
  fi
fi

# 4. Summary for user / CI
echo
echo "Install bootstrap complete for Draft."
echo "  - Breadcrumb ready for IDE/plugin detection"
echo "  - graph/bin/ layout + LFS respected (see graph/bin/README.md)"
echo "  - Next: run 'make build' then 'make lint' or invoke /draft:init in a project"
echo "  - Native graph binaries (when added) will be auto-preferred for best performance"
