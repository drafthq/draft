#!/usr/bin/env bash
# verify-graph-binary.sh — validate and select the Draft graph native binary.
#
# Preference order:
#   1. graph on $PATH
#   2. Bundled arch-specific under bin/<arch>/ (canonical layout)
#   3. Legacy: graph/bin/<arch>/ (transition support)
#
# Probes for optional companion graph-clang.
# Emits JSON or human report. Exit 0 = found+usable, 2 = none (graceful for skills).
#
# Usage:
#   scripts/tools/verify-graph-binary.sh [--repo <dir>] [--plugin-root <dir>] [--json] [--verbose] [--strict]
#
# --strict : fail (exit 2) when no binary at all (for release/CI gates)
# Integrates with install/package and skills/init graph step.

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
verify-graph-binary.sh — Draft native graph binary resolver + verifier

Preference: PATH > bundled bin/<arch>/ > legacy graph/bin/<arch>/

Options:
  --repo DIR         Repo root for context (default .)
  --plugin-root DIR  Explicit Draft plugin install root
  --json             Emit JSON report
  --verbose          Human progress
  --strict           Exit 2 if no binary found at all
  --help             This message

Exit codes:
  0  Usable binary found and responsive to --help/--version
  1  Bad args
  2  No binary located
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
# Canonical: bin/<arch>/graph under plugin/repo root (correct layout).
# Legacy fallback: graph/bin/<arch>/graph for transition.
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
      pr="$(cat "$bc" 2>/dev/null || true)"
      [[ -n "$pr" && -d "$pr" ]] && local_roots+=("$pr")
    fi
  done
  # Fallback relative to repo or self
  local_roots+=("$REPO" "$SCRIPT_DIR/../..")

  for pr in "${local_roots[@]}"; do
    # Try canonical bin/<arch>/ first (correct location shipped in repo)
    for base in "bin" "graph/bin"; do
      bundled="$pr/$base/$ARCH/graph"
      if [[ -x "$bundled" ]]; then
        if "$bundled" --help >/dev/null 2>&1 || "$bundled" --version >/dev/null 2>&1; then
          GRAPH_BIN="$bundled"
          SOURCE="bundled:$ARCH"
          log "Found bundled native: $GRAPH_BIN (via $base)"
          # companion (sibling in same arch dir)
          clang_cand="$pr/$base/$ARCH/graph-clang"
          if [[ -x "$clang_cand" ]]; then
            GRAPH_CLANG_BIN="$clang_cand"
            log "Found bundled graph-clang: $GRAPH_CLANG_BIN"
          fi
          break 2
        fi
      fi
    done
  done
fi

# Companion search for PATH or bundled case (sibling dir or PATH)
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
    if [[ $STRICT -eq 1 ]]; then
      echo '{"status":"none","graph_bin":null,"graph_clang_bin":null,"source":null,"arch":"'"$ARCH"'","message":"strict mode: no graph binary found"}'
    else
      echo '{"status":"unavailable","graph_bin":null,"graph_clang_bin":null,"source":null,"arch":"'"$ARCH"'","message":"No graph binary found in PATH or bundled bin/<arch>/ (or legacy graph/bin/)"}'
    fi
  elif [[ $STRICT -eq 1 ]]; then
    echo "STRICT: No graph binary found (native required; looked in bin/<arch>/ and graph/bin/<arch>/)." >&2
  else
    echo "ERROR: No Draft graph binary located (tried PATH and bin/$ARCH/ or graph/bin/$ARCH/)." >&2
    echo "        Install native binary or ensure it is on PATH." >&2
  fi
  exit 2
fi

# Final liveness (already passed most, but re-check for strict)
if ! "$GRAPH_BIN" --help >/dev/null 2>&1 && ! "$GRAPH_BIN" --version >/dev/null 2>&1; then
  log "Selected binary failed --help/--version"
  echo "ERROR: graph binary $GRAPH_BIN found but failed --help/--version (wrong OS/arch or corrupt?)." >&2
  if [[ $EMIT_JSON -eq 1 ]]; then
    echo '{"status":"unusable","graph_bin":"'"$GRAPH_BIN"'","graph_clang_bin":"'"${GRAPH_CLANG_BIN:-}"'","source":"'"$SOURCE"'","arch":"'"$ARCH"'"}'
  fi
  exit 2
fi

status="ok"
SOURCE="${SOURCE:-bundled}"

report() {
  local g="$1" c="$2" s="$3" a="$4" st="$5"
  if [[ $EMIT_JSON -eq 1 ]]; then
    local cfield
    if [[ -n "$c" ]]; then cfield="\"$(json_escape "$c")\""; else cfield="null"; fi
    printf '{"status":"%s","graph_bin":"%s","graph_clang_bin":%s,"source":"%s","arch":"%s"}\n' \
      "$(json_escape "$st")" "$(json_escape "$g")" "$cfield" "$(json_escape "$s")" "$(json_escape "$a")"
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
  if [[ -n "${GRAPH_CLANG_BIN:-}" ]]; then
    clang_field="\"$(json_escape "$GRAPH_CLANG_BIN")\""
  else
    clang_field="null"
  fi
  cat > "$REPO/draft/.graph-binary-report.json" <<EOF
{
  "detected_at": "$(date -Iseconds 2>/dev/null || date)",
  "graph_bin": "$(json_escape "$GRAPH_BIN")",
  "graph_clang_bin": $clang_field,
  "source": "$(json_escape "$SOURCE")",
  "arch": "$(json_escape "$ARCH")",
  "status": "$(json_escape "$status")"
}
EOF
  log "Wrote draft/.graph-binary-report.json (usage report contract)"
fi

exit 0
