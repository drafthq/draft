#!/usr/bin/env bash
# fetch-memory-engine.sh — download and verify the Draft knowledge-graph engine.
#
# The engine is the codebase-memory-mcp single static binary. This script fetches
# the release archive for the host OS/arch from GitHub Releases, verifies its
# SHA-256 against the published checksums.txt, extracts it, and installs the
# binary to the Draft-managed location (~/.cache/draft/bin/codebase-memory-mcp),
# which scripts/tools/_lib.sh:find_memory_bin resolves.
#
# Pinned by default for reproducibility; override with CMM_VERSION (a tag, e.g.
# "v0.8.1", or "latest").
#
# Usage:
#   scripts/fetch-memory-engine.sh [--dest DIR] [--force]
#
# Env:
#   CMM_VERSION        Release tag to fetch (default: pinned DEFAULT_VERSION).
#   CMM_DOWNLOAD_URL   Override the release base URL (testing).
#
# Exit codes: 0 installed/already-present, 1 invocation error, 2 fetch/verify failure.
set -euo pipefail

REPO="DeusData/codebase-memory-mcp"
DEFAULT_VERSION="v0.8.1"   # pinned; bump deliberately. NOTE: tag must carry the leading "v" AND have published assets (0.7.0 had none → 404).
VERSION="${CMM_VERSION:-$DEFAULT_VERSION}"
DEST="$HOME/.cache/draft/bin"
FORCE=0

usage() { sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dest) DEST="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown flag: $1" >&2; usage >&2; exit 1 ;;
  esac
done

BIN_PATH="$DEST/codebase-memory-mcp"
if [[ -x "$BIN_PATH" && $FORCE -eq 0 ]]; then
  echo "codebase-memory-mcp already installed at $BIN_PATH ($("$BIN_PATH" --version 2>/dev/null || echo unknown))"
  exit 0
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
if ! curl -fSL --max-time 300 -o "$TMP/$ARCHIVE" "$BASE/$ARCHIVE"; then
  echo "error: download failed: $BASE/$ARCHIVE" >&2
  exit 2
fi

# --- Verify checksum (best-effort: hard-fail only if the archive is listed) ---
if curl -fsSL --max-time 60 -o "$TMP/checksums.txt" "$BASE/checksums.txt" 2>/dev/null; then
  expected="$(grep "  $ARCHIVE\$" "$TMP/checksums.txt" 2>/dev/null | awk '{print $1}' | head -1 || true)"
  if [[ -n "$expected" ]]; then
    if command -v sha256sum >/dev/null 2>&1; then
      actual="$(sha256sum "$TMP/$ARCHIVE" | awk '{print $1}')"
    else
      actual="$(shasum -a 256 "$TMP/$ARCHIVE" | awk '{print $1}')"
    fi
    if [[ "$expected" != "$actual" ]]; then
      echo "error: checksum mismatch for $ARCHIVE (expected $expected, got $actual)" >&2
      exit 2
    fi
    echo "  checksum OK"
  else
    echo "  warning: $ARCHIVE not found in checksums.txt — skipping verification" >&2
  fi
else
  echo "  warning: checksums.txt unavailable — skipping verification" >&2
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
