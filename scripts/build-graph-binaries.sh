#!/usr/bin/env bash
# scripts/build-graph-binaries.sh
#
# Generalized build/stage script for Draft graph native binaries (Rust core + optional graph-clang).
# Dual-mode friendly: does not touch or require removal of graph/src/ or dist/bundle.cjs.
#
# This script prepares the multi-arch layout under graph/bin/<arch>/ for packaging.
# It contains no internal company paths, no hard-coded forks, and uses only Draft terminology.
#
# Usage (run from Draft root):
#   ./scripts/build-graph-binaries.sh [options]
#
# Options:
#   --targets "linux-amd64 darwin-arm64 ..."   Space-separated list (default: common 4)
#   --out-dir <path>                           Output base (default: graph/bin)
#   --from <dir>                               Copy prebuilt binaries from here (e.g. a release dir)
#   --draft-root <path>                        Draft checkout root (default: dirname of script)
#   --help                                     Show this message
#
# Environment (optional, for when Rust sources co-located or in PATH):
#   DRAFT_GRAPH_RUST_SRC   Path to the Rust graph crate (if cargo build desired here)
#   CARGO, RUSTUP, CROSS   Toolchain overrides
#
# The script is intentionally lightweight for the skeleton phase:
# - Creates arch directories + README copy
# - If --from supplied, copies matching graph / graph-clang into each arch dir
# - Otherwise emits placeholder scripts (real binaries come from external build or CI release)
# - Leaves Node legacy wrapper and sources untouched
#
# Later: integrate with cross-rs or official Rust cross-compilation for actual `cargo build --target`.
# See graph/bin/README.md, Makefile:graph-binaries, verify-graph-binary.sh, install/package.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_DRAFT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DRAFT_ROOT="$DEFAULT_DRAFT_ROOT"
OUT_BASE="graph/bin"
TARGETS="linux-amd64 linux-arm64 darwin-arm64 darwin-x86_64"
FROM_DIR=""
DO_HELP=0

usage() {
  cat <<'EOF'
Draft graph binary staging (skeleton)

Prepares graph/bin/<arch>/{graph,graph-clang} layout for distribution.
Keeps full legacy Node support; adds native binary slots.

Options:
  --targets LIST     (default: linux-amd64 linux-arm64 darwin-arm64 darwin-x86_64)
  --out-dir DIR      (default: graph/bin relative to --draft-root)
  --from DIR         Copy graph+graph-clang from this dir into each arch (for release packaging)
  --draft-root PATH  Draft repository root (autodetected)
  --help             This help

Examples:
  ./scripts/build-graph-binaries.sh
  ./scripts/build-graph-binaries.sh --targets "linux-amd64 darwin-arm64" --from /tmp/graph-release
  DRAFT_GRAPH_RUST_SRC=../graph-rust ./scripts/build-graph-binaries.sh
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --targets) TARGETS="$2"; shift 2 ;;
    --out-dir) OUT_BASE="$2"; shift 2 ;;
    --from) FROM_DIR="$2"; shift 2 ;;
    --draft-root) DRAFT_ROOT="$2"; shift 2 ;;
    --help|-h) DO_HELP=1; shift ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ $DO_HELP -eq 1 ]]; then
  usage
  exit 0
fi

OUT_DIR="$DRAFT_ROOT/$OUT_BASE"
mkdir -p "$OUT_DIR"

echo "Draft graph binary staging"
echo "  Draft root : $DRAFT_ROOT"
echo "  Output     : $OUT_DIR"
echo "  Targets    : $TARGETS"
[[ -n "$FROM_DIR" ]] && echo "  Source from: $FROM_DIR"
echo

# Ensure the legacy wrapper and README are present (they are under source control)
if [[ ! -f "$OUT_DIR/graph" ]]; then
  echo "WARNING: legacy graph/bin/graph wrapper missing — this script does not create it."
fi
if [[ ! -f "$OUT_DIR/README.md" ]]; then
  echo "Copying README.md into output (if missing in worktree)..."
  cp -n "$OUT_DIR/README.md" "$OUT_DIR/README.md" 2>/dev/null || true
fi

normalize_arch() {
  local raw="$1"
  case "$raw" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *) echo "$raw" ;;
  esac
}

os_part() {
  local u
  u="$(uname -s | tr '[:upper:]' '[:lower:]')"
  case "$u" in
    linux) echo "linux" ;;
    darwin) echo "darwin" ;;
    msys*|mingw*|cygwin*) echo "windows" ;;
    *) echo "$u" ;;
  esac
}

for t in $TARGETS; do
  arch_dir="$OUT_DIR/$t"
  mkdir -p "$arch_dir"

  if [[ -n "$FROM_DIR" && -f "$FROM_DIR/graph" ]]; then
    echo "  Staging $t from $FROM_DIR ..."
    cp -f "$FROM_DIR/graph" "$arch_dir/graph"
    [[ -f "$FROM_DIR/graph-clang" ]] && cp -f "$FROM_DIR/graph-clang" "$arch_dir/graph-clang" || true
    chmod +x "$arch_dir/graph" 2>/dev/null || true
    chmod +x "$arch_dir/graph-clang" 2>/dev/null || true
  else
    # Create or refresh minimal executable placeholders (text, will be overwritten by real LFS objects)
    if [[ ! -f "$arch_dir/graph" ]]; then
      cat > "$arch_dir/graph" <<'PH'
#!/bin/sh
# Placeholder — replaced by real native binary during packaging / release.
# See graph/bin/README.md for LFS, build, and detection details.
echo "Draft native graph placeholder for $t (replace via build-graph-binaries.sh --from or CI)" >&2
exit 42
PH
      chmod +x "$arch_dir/graph"
    fi
    if [[ ! -f "$arch_dir/graph-clang" ]]; then
      cat > "$arch_dir/graph-clang" <<'PH'
#!/bin/sh
# Placeholder for optional graph-clang (C/C++ high-fidelity companion).
echo "Draft graph-clang placeholder for $t" >&2
exit 42
PH
      chmod +x "$arch_dir/graph-clang"
    fi
  fi

  echo "  Prepared: $arch_dir/{graph,graph-clang}"
done

echo
echo "Staging complete. Run 'make verify-graph' or scripts/tools/verify-graph-binary.sh to validate."
echo "Remember: add arch binaries to Git LFS (see graph/bin/README.md)."
echo "Node sources under graph/src/ and graph/bin/graph (wrapper) remain for dual-mode."
