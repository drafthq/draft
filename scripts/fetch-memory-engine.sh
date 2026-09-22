#!/usr/bin/env bash
# fetch-memory-engine.sh — download and verify the Draft knowledge-graph engine.
#
# The engine is the codebase-memory-mcp single static binary. This script fetches
# the release archive for the host OS/arch from GitHub Releases, verifies its
# SHA-256 (against hashes pinned below for the default version, else against the
# release's checksums.txt), extracts it, and installs the binary to the
# Draft-managed location (~/.cache/draft/bin/codebase-memory-mcp),
# which scripts/tools/_lib.sh:find_memory_bin resolves.
#
# Pinned by default for reproducibility; override with CMM_VERSION (a tag, e.g.
# "v0.9.0", or "latest").
#
# Usage:
#   scripts/fetch-memory-engine.sh [--dest DIR] [--force]
#
# Env:
#   CMM_VERSION        Release tag to fetch (default: pinned DEFAULT_VERSION).
#   CMM_DOWNLOAD_URL   Override the release base URL (testing).
#   DRAFT_STRICT_VERIFY  1 = refuse to install when the checksum cannot be
#                      verified (missing checksums.txt or unlisted archive).
#                      Default is warn-and-continue, which keeps installs working
#                      on releases that ship no checksums file — acceptable for
#                      individuals, not for anyone who must attest to what runs
#                      on their machine.
#
# Exit codes: 0 installed/already-present, 1 invocation error, 2 fetch/verify failure.
set -euo pipefail

REPO="DeusData/codebase-memory-mcp"
DEFAULT_VERSION="v0.9.0"   # pinned; bump deliberately. NOTE: tag must carry the leading "v" AND have published assets (0.7.0 had none → 404).
VERSION="${CMM_VERSION:-$DEFAULT_VERSION}"
DEST="$HOME/.cache/draft/bin"
FORCE=0

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dest) DEST="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown flag: $1" >&2; usage >&2; exit 1 ;;
  esac
done

BIN_PATH="$DEST/codebase-memory-mcp"
# Keep an existing install only at the requested version, so a pin bump upgrades
# it. "latest" cannot be compared offline; any existing binary satisfies it.
if [[ -x "$BIN_PATH" && $FORCE -eq 0 ]]; then
  have="$("$BIN_PATH" --version 2>/dev/null | awk '{print $NF}' || true)"
  if [[ "$VERSION" == "latest" || "$have" == "${VERSION#v}" ]]; then
    echo "codebase-memory-mcp already installed at $BIN_PATH (${have:-unknown})"
    exit 0
  fi
  echo "Installed engine is ${have:-unknown}; replacing it with ${VERSION}."
fi

# --- Detect OS / arch (mirrors the engine's own install.sh naming) ---
case "$(uname -s)" in
  Darwin) OS="darwin" ;;
  Linux)  OS="linux" ;;
  *) echo "error: unsupported OS: $(uname -s)" >&2; exit 2 ;;
esac
case "$(uname -m)" in
  x86_64|amd64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *) echo "error: unsupported arch: $(uname -m)" >&2; exit 2 ;;
esac

# Linux ships a fully-static "-portable" build; macOS has no such variant.
PORTABLE=""
[[ "$OS" = "linux" ]] && PORTABLE="-portable"
ARCHIVE="codebase-memory-mcp-${OS}-${ARCH}${PORTABLE}.tar.gz"

if [[ -n "${CMM_DOWNLOAD_URL:-}" ]]; then
  BASE="$CMM_DOWNLOAD_URL"
elif [[ "$VERSION" = "latest" ]]; then
  BASE="https://github.com/${REPO}/releases/latest/download"
else
  BASE="https://github.com/${REPO}/releases/download/${VERSION}"
fi

case "$BASE" in https://*) ;; *) echo "error: refusing non-HTTPS URL: $BASE" >&2; exit 2 ;; esac

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Fetching ${ARCHIVE} (${VERSION})..."
if ! curl -fSL --proto '=https' --proto-redir '=https' --max-time 300 -o "$TMP/$ARCHIVE" "$BASE/$ARCHIVE"; then
  echo "error: download failed: $BASE/$ARCHIVE" >&2
  exit 2
fi

# --- Verify checksum ---
# A mismatch is always fatal. An *absent* checksum is fatal only under
# DRAFT_STRICT_VERIFY=1 — otherwise it warns, so that a release without a
# checksums.txt does not brick the install for everyone.
#
# checksums.txt ships in the same release as the archive, so it proves only that
# the download is intact: a replaced release asset passes it. The pinned
# version's archives are checked against SHA-256 values recorded here instead
# (copied from its checksums.txt when the pin was bumped) — update them with
# DEFAULT_VERSION.
pinned_sha256() {
  [[ "$VERSION" == "$DEFAULT_VERSION" ]] || return 0
  case "$1" in
    codebase-memory-mcp-darwin-amd64.tar.gz) echo 6af3d02a27f589901fa763d3971089337bc8c9838bbed5d0cf543ca9f1a9e543 ;;
    codebase-memory-mcp-darwin-arm64.tar.gz) echo faa02f0404230c451a9812230394481948f80183801fa5bf67044b41c2f25ed4 ;;
    codebase-memory-mcp-linux-amd64-portable.tar.gz) echo 8459d5c9d1457f2c82de3de307ffc7641ecbba2dde893427be1e62eca8ef9b25 ;;
    codebase-memory-mcp-linux-arm64-portable.tar.gz) echo b0a43fdaf534073c16707d72726b73b149d4c1212034b281ee8b7b2dac755107 ;;
  esac
}
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}
STRICT="${DRAFT_STRICT_VERIFY:-0}"
unverified() {
  if [[ "$STRICT" == "1" ]]; then
    echo "error: $1 (DRAFT_STRICT_VERIFY=1 refuses unverified binaries)" >&2
    exit 2
  fi
  echo "  warning: $1 — skipping verification (set DRAFT_STRICT_VERIFY=1 to make this fatal)" >&2
}

pinned="$(pinned_sha256 "$ARCHIVE")"
if [[ -n "$pinned" ]]; then
  actual="$(sha256_of "$TMP/$ARCHIVE")"
  if [[ "$pinned" != "$actual" ]]; then
    echo "error: $ARCHIVE does not match the SHA-256 pinned for $VERSION (expected $pinned, got $actual)" >&2
    exit 2
  fi
  echo "  checksum OK (pinned $pinned)"
elif curl -fsSL --proto '=https' --proto-redir '=https' --max-time 60 -o "$TMP/checksums.txt" "$BASE/checksums.txt" 2>/dev/null; then
  expected="$(grep "  $ARCHIVE\$" "$TMP/checksums.txt" 2>/dev/null | awk '{print $1}' | head -1 || true)"
  if [[ -n "$expected" ]]; then
    actual="$(sha256_of "$TMP/$ARCHIVE")"
    if [[ "$expected" != "$actual" ]]; then
      echo "error: checksum mismatch for $ARCHIVE (expected $expected, got $actual)" >&2
      exit 2
    fi
    echo "  checksum OK ($expected)"
  else
    unverified "$ARCHIVE not listed in checksums.txt"
  fi
else
  unverified "checksums.txt unavailable at $BASE"
fi

# --- Extract and install ---
tar -xzf "$TMP/$ARCHIVE" -C "$TMP"
SRC="$(find "$TMP" -maxdepth 2 -type f -name codebase-memory-mcp | head -1)"
if [[ -z "$SRC" ]]; then
  echo "error: codebase-memory-mcp binary not found in archive" >&2
  exit 2
fi

mkdir -p "$DEST"
install -m 0755 "$SRC" "$BIN_PATH" 2>/dev/null || { cp -f "$SRC" "$BIN_PATH"; chmod +x "$BIN_PATH"; }

echo "Installed: $("$BIN_PATH" --version 2>/dev/null || echo "$BIN_PATH")"
echo "  -> $BIN_PATH"
exit 0
