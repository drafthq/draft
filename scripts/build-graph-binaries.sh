#!/usr/bin/env bash
# scripts/build-graph-binaries.sh
#
# Generalized build/stage script for Draft graph native binaries (Aether graph + optional graph-clang).
#
# Prepares the multi-arch layout under bin/<arch>/ (canonical) for packaging.
# Native-only (JS graph engine removed).
#
# Usage (run from Draft root):
#   ./scripts/build-graph-binaries.sh [options]
#
# Options:
#   --targets "linux-amd64 darwin-arm64 ..."   Space-separated list (default: common 4)
#   --out-dir <path>                           Output base (default: bin)
#   --from <dir>                               Copy prebuilt binaries from here (e.g. ../aether/dist)
#   --draft-root <path>                        Draft checkout root (default: dirname of script)
#   --help                                     Show this message
#
# Creates arch directories and either copies real binaries or leaves placeholders.
# See bin/README.md and scripts/tools/verify-graph-binary.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_DRAFT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DRAFT_ROOT="$DEFAULT_DRAFT_ROOT"
OUT_BASE="bin"
TARGETS="linux-amd64 linux-arm64 darwin-arm64 darwin-x86_64"
FROM_DIR=""
DO_HELP=0

usage() {
  cat <<'EOF'
Draft graph binary staging (skeleton)

Prepares bin/<arch>/{graph,graph-clang} layout (canonical) for distribution.
Legacy graph/bin/<arch> also supported by detectors for transition.

Options:
  --targets LIST     (default: linux-amd64 linux-arm64 darwin-arm64 darwin-x86_64)
  --out-dir DIR      (default: bin relative to --draft-root)
  --from DIR         Copy graph+graph-clang from this dir into each arch (for release packaging)
  --draft-root PATH  Draft repository root (autodetected)
  --help             This help

Examples:
  ./scripts/build-graph-binaries.sh
  ./scripts/build-graph-binaries.sh --targets "linux-amd64 darwin-arm64" --from /tmp/graph-release
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

# Note: for bin/ layout there is no top-level wrapper; arch dirs only (per bin/README.md)
if [[ "$OUT_BASE" == "graph/bin" && ! -f "$OUT_DIR/graph" ]]; then
  echo "WARNING: legacy graph/bin/graph wrapper missing — this script does not create it."
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

read -ra _TARGETS <<< "$TARGETS"
[[ ${#_TARGETS[@]} -gt 0 ]] || { echo "No targets specified" >&2; exit 1; }
for t in "${_TARGETS[@]}"; do
  arch_dir="$OUT_DIR/$t"
  mkdir -p "$arch_dir"

  if [[ -n "$FROM_DIR" && -f "$FROM_DIR/graph" ]]; then
    echo "  Staging $t from $FROM_DIR ..."
    cp -f "$FROM_DIR/graph" "$arch_dir/graph"
    chmod +x "$arch_dir/graph" 2>/dev/null || true
    if [[ -f "$FROM_DIR/graph-clang" ]]; then
      cp -f "$FROM_DIR/graph-clang" "$arch_dir/graph-clang"
      chmod +x "$arch_dir/graph-clang"
    fi
  else
    # Create or refresh minimal executable placeholders (text, will be overwritten by real LFS objects)
    if [[ ! -f "$arch_dir/graph" ]]; then
      cat > "$arch_dir/graph" <<'PH'
#!/bin/sh
# Placeholder — replaced by real native binary during packaging / release.
# See bin/README.md for LFS, build, and detection details.
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
echo "Remember: add arch binaries to Git LFS (see bin/README.md)."
echo "Native binaries only — JS graph removed."
