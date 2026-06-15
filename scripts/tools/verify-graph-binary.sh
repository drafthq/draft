#!/usr/bin/env bash
# verify-graph-binary.sh — validate and select the Draft knowledge-graph engine.
#
# The engine is the codebase-memory-mcp binary. Resolution order (see _lib.sh:find_memory_bin):
#   1. DRAFT_MEMORY_BIN override
#   2. codebase-memory-mcp on $PATH
#   3. Draft-managed install (~/.cache/draft/bin/)
#   4. Vendored arch-specific under bin/<arch>/
#
# Emits JSON or a human report. Exit 0 = found+usable, 2 = none (graceful for skills).
#
# Usage:
#   scripts/tools/verify-graph-binary.sh [--repo <dir>] [--plugin-root <dir>] [--json] [--verbose] [--strict]
#
# --strict : fail (exit 2) when no engine is found (release/CI gates)
# Integrates with install/package and the skills/init graph step.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$SCRIPT_DIR/_lib.sh"

REPO="."
PLUGIN_ROOT=""
EMIT_JSON=0
VERBOSE=0
STRICT=0

usage() {
  cat <<'EOF'
verify-graph-binary.sh — Draft knowledge-graph engine resolver + verifier

Engine: codebase-memory-mcp
Resolution: DRAFT_MEMORY_BIN > PATH > ~/.cache/draft/bin > bin/<arch>/

Options:
  --repo DIR         Repo root for context (default .)
  --plugin-root DIR  Explicit Draft plugin install root
  --json             Emit JSON report
  --verbose          Human progress
  --strict           Exit 2 if no engine found
  --help             This message

Exit codes:
  0  Usable engine found and responsive to --version
  1  Bad args
  2  No engine located
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --plugin-root) PLUGIN_ROOT="$2"; shift 2 ;;
    --json) EMIT_JSON=1; shift ;;
    --verbose) VERBOSE=1; shift ;;
    --strict) STRICT=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown: $1" >&2; usage; exit 1 ;;
  esac
done

log() { [[ $VERBOSE -eq 1 ]] && echo "[verify-graph] $*" >&2 || true; }

# Resolve architecture string for the report (linux-amd64, darwin-arm64, ...).
resolve_arch() {
  local os arch
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m)
  case "$arch" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    armv7l) arch="arm" ;;
  esac
  echo "${os}-${arch}"
}

ARCH="$(resolve_arch)"
log "Resolved arch: $ARCH"

REPO_ABS="$(cd "$REPO" 2>/dev/null && pwd || echo "$REPO")"
SELF_REPO="${PLUGIN_ROOT:-$SCRIPT_DIR/../..}"

# Classify the resolution source for reporting.
classify_source() {
  case "$MEMORY_BIN" in
    "$HOME/.cache/draft/bin/"*) echo "managed" ;;
    */bin/"$ARCH"/*) echo "bundled:$ARCH" ;;
    codebase-memory-mcp) echo "path" ;;
    "${DRAFT_MEMORY_BIN:-__none__}") echo "override" ;;
    *) echo "path" ;;
  esac
}

MEMORY_BIN=""
if ! find_memory_bin "$REPO_ABS" "$SELF_REPO"; then
  if [[ $EMIT_JSON -eq 1 ]]; then
    local_msg="No codebase-memory-mcp engine found in DRAFT_MEMORY_BIN, PATH, ~/.cache/draft/bin, or bin/<arch>/"
    if [[ $STRICT -eq 1 ]]; then
      printf '{"status":"none","engine_bin":null,"source":null,"arch":"%s","message":"strict mode: %s"}\n' "$ARCH" "$local_msg"
    else
      printf '{"status":"unavailable","engine_bin":null,"source":null,"arch":"%s","message":"%s"}\n' "$ARCH" "$local_msg"
    fi
  elif [[ $STRICT -eq 1 ]]; then
    echo "STRICT: No codebase-memory-mcp engine found." >&2
  else
    echo "ERROR: No Draft graph engine located (codebase-memory-mcp)." >&2
    echo "        Install it (scripts/fetch-memory-engine.sh) or put it on PATH." >&2
  fi
  exit 2
fi

SOURCE="$(classify_source)"
log "Selected engine: $MEMORY_BIN (source=$SOURCE)"

# Liveness: must respond to --version.
if ! "$MEMORY_BIN" --version >/dev/null 2>&1; then
  log "Selected engine failed --version"
  echo "ERROR: engine $MEMORY_BIN found but failed --version (wrong OS/arch or corrupt?)." >&2
  if [[ $EMIT_JSON -eq 1 ]]; then
    printf '{"status":"unusable","engine_bin":"%s","source":"%s","arch":"%s"}\n' \
      "$(json_escape "$MEMORY_BIN")" "$(json_escape "$SOURCE")" "$ARCH"
  fi
  exit 2
fi

STATUS="ok"

if [[ $EMIT_JSON -eq 1 ]]; then
  printf '{"status":"%s","engine_bin":"%s","source":"%s","arch":"%s"}\n' \
    "$(json_escape "$STATUS")" "$(json_escape "$MEMORY_BIN")" "$(json_escape "$SOURCE")" "$(json_escape "$ARCH")"
else
  echo "Draft graph engine: $MEMORY_BIN"
  echo "  source: $SOURCE (arch=$ARCH)"
  echo "  status: $STATUS"
fi

# Usage report side-effect when in a draft/ context (graph-usage-report contract).
if [[ -d "$REPO/draft" ]]; then
  mkdir -p "$REPO/draft"
  cat > "$REPO/draft/.graph-binary-report.json" <<EOF
{
  "detected_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "engine_bin": "$(json_escape "$MEMORY_BIN")",
  "source": "$(json_escape "$SOURCE")",
  "arch": "$(json_escape "$ARCH")",
  "status": "$(json_escape "$STATUS")"
}
EOF
  log "Wrote draft/.graph-binary-report.json (usage report contract)"
fi

exit 0
