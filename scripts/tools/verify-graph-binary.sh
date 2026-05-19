#!/usr/bin/env bash
# verify-graph-binary.sh — validate and select the best Draft graph binary (native preferred).
#
# Implements the documented preference order for Phase 3 binary adoption skeleton:
#   1. graph on $PATH (native or override)
#   2. Bundled arch-specific under plugin graph/bin/<arch>/
#   3. Legacy graph/bin/graph (Node wrapper)
#
# Also probes for companion graph-clang in corresponding locations.
# Emits a machine-readable report (or human with --verbose).
# Exit: 0 = usable binary found (and verified), 1 = invocation error, 2 = no usable binary (graceful).
#
# Usage:
#   scripts/tools/verify-graph-binary.sh [--repo <dir>] [--plugin-root <dir>] [--json] [--verbose] [--strict]
#
# --strict : fail (exit 2) if only legacy Node binary is present (for CI gates later)
# Integrates with: Makefile verify-graph, install/package flows, init graph detection.
#
# Draft-only. No internal paths. Respects dual-mode (Node still works).

set -euo pipefail

# shellcheck source=_lib.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_lib.sh" 2>/dev/null || true   # best-effort; we reimplement resolver here for new order

REPO="."
PLUGIN_ROOT=""
EMIT_JSON=0
VERBOSE=0
STRICT=0

usage() {
  cat <<'EOF'
verify-graph-binary.sh — Draft graph binary resolver + verifier (native preference)

Detects and validates graph (and graph-clang) following:
  PATH > bundled <arch> > legacy Node

Options:
  --repo DIR         Repo root for context (default .)
  --plugin-root DIR  Explicit Draft plugin install root (overrides breadcrumb search)
  --json             Emit JSON report to stdout
  --verbose          Human-readable progress + decisions
  --strict           Exit 2 if no native binary (only legacy or nothing)
  --help             This message

Exit codes:
  0  Usable graph binary located and basic --help succeeded
  1  Bad arguments or internal error
  2  No usable graph binary (or strict mode rejected legacy-only)
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

log() {
  if [[ $VERBOSE -eq 1 ]]; then
    echo "[verify-graph] $*" >&2
  fi
}

# Resolve architecture string used in layout: linux-amd64, darwin-arm64, ...
resolve_arch() {
  local os arch
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m)
  case "$arch" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    armv7l) arch="arm" ;;
  esac
  case "$os" in
    linux|darwin) echo "${os}-${arch}" ;;
    msys*|mingw*|cygwin*) echo "windows-${arch}" ;;
    *) echo "${os}-${arch}" ;;
  esac
}

ARCH="$(resolve_arch)"
log "Resolved arch: $ARCH"

GRAPH_BIN=""
GRAPH_CLANG_BIN=""
SOURCE=""

# --- Preference 1: PATH (native first) ---
if command -v graph >/dev/null 2>&1; then
  cand="$(command -v graph)"
  if [[ -x "$cand" ]]; then
    # Basic liveness: must respond to --help without crashing (timeout not available in pure sh, simple exec)
    if "$cand" --help >/dev/null 2>&1 || "$cand" --version >/dev/null 2>&1; then
      GRAPH_BIN="$cand"
      SOURCE="path"
      log "Found on PATH: $GRAPH_BIN"
    else
      log "PATH graph present but --help/--version failed; skipping"
    fi
  fi
fi

# --- Preference 2: Bundled arch-specific (if no PATH or to prefer bundled? PATH wins per charter) ---
if [[ -z "$GRAPH_BIN" ]]; then
  # Determine plugin root candidates
  local_roots=()
  if [[ -n "$PLUGIN_ROOT" && -d "$PLUGIN_ROOT" ]]; then
    local_roots+=("$PLUGIN_ROOT")
  fi
  # Breadcrumb written by install.sh (see install.sh skeleton)
  for bc in \
      "$HOME/.cursor/plugins/local/draft/.draft-install-path" \
      "$HOME/.claude-plugin/../.draft-install-path" \
      "$HOME/.claude/plugins/draft/.draft-install-path"; do
    if [[ -f "$bc" ]]; then
      local pr; pr="$(cat "$bc" 2>/dev/null || true)"
      [[ -n "$pr" && -d "$pr" ]] && local_roots+=("$pr")
    fi
  done
  # Fallback relative to repo or self
  local_roots+=("$REPO" "$SCRIPT_DIR/../..")

  for pr in "${local_roots[@]}"; do
    bundled="$pr/graph/bin/$ARCH/graph"
    if [[ -x "$bundled" ]]; then
      if "$bundled" --help >/dev/null 2>&1 || "$bundled" --version >/dev/null 2>&1; then
        GRAPH_BIN="$bundled"
        SOURCE="bundled:$ARCH"
        log "Found bundled native: $GRAPH_BIN"
        # companion
        clang_cand="$pr/graph/bin/$ARCH/graph-clang"
        if [[ -x "$clang_cand" ]]; then
          GRAPH_CLANG_BIN="$clang_cand"
          log "Found bundled graph-clang: $GRAPH_CLANG_BIN"
        fi
        break
      fi
    fi
  done
fi

# --- Preference 3: Legacy Node wrapper (graph/bin/graph) ---
if [[ -z "$GRAPH_BIN" ]]; then
  for pr in "${local_roots[@]:-}" "$REPO" "$SCRIPT_DIR/../.."; do
    legacy="$pr/graph/bin/graph"
    if [[ -x "$legacy" ]]; then
      # Legacy always "works" for basic probe (node may be slow but present)
      if "$legacy" --help >/dev/null 2>&1 || true; then   # node wrapper accepts
        GRAPH_BIN="$legacy"
        SOURCE="legacy"
        log "Falling back to legacy Node: $GRAPH_BIN"
        break
      fi
    fi
  done
fi

# Companion search for legacy / PATH case (same-dir or PATH sibling)
if [[ -n "$GRAPH_BIN" && -z "$GRAPH_CLANG_BIN" ]]; then
  # Same directory as GRAPH_BIN
  dir_of_graph="$(dirname "$GRAPH_BIN")"
  clang_same="$dir_of_graph/graph-clang"
  if [[ -x "$clang_same" ]]; then
    GRAPH_CLANG_BIN="$clang_same"
    log "graph-clang sibling to graph: $GRAPH_CLANG_BIN"
  else
    # PATH sibling (if graph was from PATH)
    if command -v graph-clang >/dev/null 2>&1; then
      GRAPH_CLANG_BIN="$(command -v graph-clang)"
      log "graph-clang on PATH: $GRAPH_CLANG_BIN"
    fi
  fi
fi

# --- Verification & Report ---
if [[ -z "$GRAPH_BIN" ]]; then
  if [[ $EMIT_JSON -eq 1 ]]; then
    echo '{"status":"unavailable","graph_bin":null,"graph_clang_bin":null,"source":null,"arch":"'"$ARCH"'","message":"No graph binary found in PATH, bundled, or legacy locations"}'
  else
    echo "ERROR: No Draft graph binary located (tried PATH, graph/bin/$ARCH/, legacy graph/bin/graph)." >&2
    echo "        Install native binary or ensure legacy graph/bin/graph is executable." >&2
  fi
  exit 2
fi

# Final liveness (already passed most, but re-check for strict)
if ! "$GRAPH_BIN" --help >/dev/null 2>&1 && ! "$GRAPH_BIN" --version >/dev/null 2>&1; then
  log "Selected binary failed --help/--version"
  if [[ $EMIT_JSON -eq 1 ]]; then
    echo '{"status":"unusable","graph_bin":"'"$GRAPH_BIN"'","graph_clang_bin":"'"${GRAPH_CLANG_BIN:-}"'","source":"'"$SOURCE"'","arch":"'"$ARCH"'"}'
  fi
  exit 2
fi

# Strict mode: reject if SOURCE == legacy
if [[ $STRICT -eq 1 && "$SOURCE" == "legacy" ]]; then
  if [[ $EMIT_JSON -eq 1 ]]; then
    echo '{"status":"legacy-only","graph_bin":"'"$GRAPH_BIN"'","graph_clang_bin":"'"${GRAPH_CLANG_BIN:-}"'","source":"'"$SOURCE"'","arch":"'"$ARCH"'","message":"strict mode: legacy Node binary rejected"}'
  else
    echo "STRICT: Only legacy Node graph found at $GRAPH_BIN — native required." >&2
  fi
  exit 2
fi

status="ok"
[[ "$SOURCE" == "legacy" ]] && status="ok-legacy"

report() {
  local g="$1" c="$2" s="$3" a="$4" st="$5"
  if [[ $EMIT_JSON -eq 1 ]]; then
    printf '{"status":"%s","graph_bin":"%s","graph_clang_bin":"%s","source":"%s","arch":"%s"}\n' \
      "$st" "$g" "${c:-}" "$s" "$a"
  else
    echo "Draft graph binary: $g"
    echo "  source: $s (arch=$a)"
    [[ -n "$c" ]] && echo "  graph-clang: $c" || echo "  graph-clang: (not found — ctags fallback available)"
    echo "  status: $st"
  fi
}

report "$GRAPH_BIN" "$GRAPH_CLANG_BIN" "$SOURCE" "$ARCH" "$status"

# Also write a small usage report side-effect if in a draft/ context (for future graph-usage-report tooling)
if [[ -d "$REPO/draft" ]]; then
  mkdir -p "$REPO/draft"
  cat > "$REPO/draft/.graph-binary-report.json" <<EOF
{
  "detected_at": "$(date -Iseconds 2>/dev/null || date)",
  "graph_bin": "$GRAPH_BIN",
  "graph_clang_bin": "${GRAPH_CLANG_BIN:-null}",
  "source": "$SOURCE",
  "arch": "$ARCH",
  "status": "$status"
}
EOF
  log "Wrote draft/.graph-binary-report.json (usage report contract)"
fi

exit 0
