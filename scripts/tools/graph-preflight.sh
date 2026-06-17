#!/usr/bin/env bash
# graph-preflight.sh — read-only go/no-go check before indexing a repo with the
# Draft knowledge-graph engine (codebase-memory-mcp).
#
# Indexes NOTHING. Walks git metadata + engine status only. Safe to run anywhere.
# Companion preflight for `scripts/tools/graph-init.sh` / `/draft:init --graph-only`.
#
# Usage:  scripts/tools/graph-preflight.sh [--json] [REPO_PATH]   (default repo: cwd)
#         --json   emit a machine-readable report on stdout (no human output)
# Exit:   0 = GO / GO-with-caution, 1 = NO-GO (blocking), 2 = bad invocation.
#
# Deliberately uses guard idioms (`|| true`, `|| echo 0`) rather than aborting:
# the report accumulates blockers/warnings and prints a verdict even under -e.
set -euo pipefail

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF_REPO="$(cd "$TOOLS_DIR/../.." && pwd)"
# shellcheck source=_lib.sh
source "$TOOLS_DIR/_lib.sh"

usage() {
  cat <<'EOF'
graph-preflight.sh — read-only go/no-go check before knowledge-graph indexing.

Usage:
  scripts/tools/graph-preflight.sh [--json] [REPO_PATH]   (default repo: cwd)

Flags:
  --json   Emit a machine-readable report on stdout (no human output).
  --help   Show this help.

Indexes nothing — walks git metadata + engine status only.
Exit codes: 0 GO / GO-with-caution, 1 NO-GO (blocking), 2 bad invocation.
EOF
}

# --- args ---
JSON_MODE=0
REPO=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_MODE=1; shift;;
    -h|--help) usage; exit 0;;
    -*) echo "Unknown flag: $1" >&2; usage >&2; exit 2;;
    *) if [[ -z "$REPO" ]]; then REPO="$1"; else echo "Unexpected arg: $1" >&2; exit 2; fi; shift;;
  esac
done
REPO="${REPO:-.}"
[[ -d "$REPO" ]] || { echo "ERROR: '$REPO' is not a directory" >&2; exit 2; }
REPO_ABS="$(cd "$REPO" && pwd)"

# --- formatting (color only on a tty, and never in --json) ---
if [[ -t 1 && "$JSON_MODE" -eq 0 ]]; then B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; D=$'\e[0m'; else B=""; G=""; Y=""; R=""; D=""; fi
hr()   { [[ "$JSON_MODE" -eq 0 ]] && printf '%s\n' "------------------------------------------------------------"; return 0; }
sec()  { [[ "$JSON_MODE" -eq 0 ]] && { echo; printf '%s== %s ==%s\n' "$B" "$1" "$D"; }; return 0; }
ok()   { [[ "$JSON_MODE" -eq 0 ]] && printf '  %s[ OK ]%s %s\n' "$G" "$D" "$1"; return 0; }
info() { [[ "$JSON_MODE" -eq 0 ]] && printf '         %s\n' "$1"; return 0; }
warn() { WARNINGS=$((WARNINGS+1)); WARN_J="${WARN_J:+$WARN_J,}\"$(json_escape "$1")\""; [[ "$JSON_MODE" -eq 0 ]] && printf '  %s[WARN]%s %s\n' "$Y" "$D" "$1"; return 0; }
fail() { BLOCKERS=$((BLOCKERS+1)); FAIL_J="${FAIL_J:+$FAIL_J,}\"$(json_escape "$1")\""; [[ "$JSON_MODE" -eq 0 ]] && printf '  %s[FAIL]%s %s\n' "$R" "$D" "$1"; return 0; }

WARNINGS=0; BLOCKERS=0; WARN_J=""; FAIL_J=""

# --- helpers ---
count_files() { { git -C "$REPO_ABS" ls-files -- "$@" 2>/dev/null || true; } | wc -l | tr -d ' '; }
count_loc() {
  [[ -n "$(git -C "$REPO_ABS" ls-files -- "$@" 2>/dev/null | head -1)" ]] || { echo 0; return; }
  # cat must run from the repo root so tracked paths resolve.
  ( cd "$REPO_ABS" && git ls-files -z -- "$@" 2>/dev/null | xargs -0 cat 2>/dev/null ) | wc -l | tr -d ' ' || true
}
human() { awk -v n="$1" 'BEGIN{ v=n; split("K M B",u); if(v<1000){printf "%d",v;exit}
  for(i=1;i<=3;i++){v/=1000; if(v<1000){printf "%.1f%s",v,u[i];exit}}}'; }

# --- collected fields (defaults so --json is always well-formed) ---
IS_GIT=false; AT_ROOT=false; GIT_TOP=""; COMMIT="none"
TRACKED=0; ALLDISK=0; TOTAL_LOC=0; CCGO_LOC=0; LANG_J=""
VEND_J=""; ENGINE=""; VER=""; LIMIT=""; ENGINE_FOUND=false
RAM_GB=""; FREE_GB=""

hr
[[ "$JSON_MODE" -eq 0 ]] && printf '%sDraft graph pre-flight%s — %s\n' "$B" "$D" "$REPO_ABS" || true
hr

# ============================================================
sec "1. Git boundary"
# ============================================================
GIT_TOP="$(git -C "$REPO_ABS" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$GIT_TOP" ]]; then
  fail "Not inside a git repo. The engine would raw-walk the filesystem (no .gitignore filter)."
  info "Point this at a real git repo root, never a parent container dir."
  GIT_OK=0
else
  GIT_OK=1; IS_GIT=true
  if [[ "$GIT_TOP" != "$REPO_ABS" ]]; then
    warn "Not at the git root. Git top is: $GIT_TOP"
    info "Run /draft:init --graph-only at the git root for whole-repo coverage."
  else
    AT_ROOT=true
    ok "Git root: $GIT_TOP"
  fi
  COMMIT="$(git -C "$REPO_ABS" rev-parse --short HEAD 2>/dev/null || echo none)"
  info "HEAD: $COMMIT"
  [[ -f "$GIT_TOP/.gitmodules" ]] && warn "Submodules present — engine indexes the superproject's tracked tree; submodule contents may need separate indexing." || true
fi

# ============================================================
sec "2. Index scope (git-tracked = what actually gets indexed)"
# ============================================================
if [[ "$GIT_OK" -eq 1 ]]; then
  TRACKED="$(count_files)"
  ALLDISK="$({ find "$REPO_ABS" -type d -name .git -prune -o -type f -print 2>/dev/null || true; } | wc -l | tr -d ' ')"
  ok "Git-tracked files: $TRACKED   (on disk: $ALLDISK — the difference is gitignored and SKIPPED)"

  [[ "$JSON_MODE" -eq 0 ]] && { echo; printf '  %-14s %10s %12s\n' "language" "files" "lines"; printf '  %-14s %10s %12s\n' "--------" "-----" "-----"; } || true
  declare -A GLOBS=(
    [C/C++]='*.c *.cc *.cpp *.cxx *.h *.hpp *.hh *.hxx'
    [Go]='*.go'
    [Python]='*.py'
    [TS/JS]='*.ts *.tsx *.js *.jsx *.mjs'
    [Rust]='*.rs'
    [Java]='*.java'
  )
  for lang in "C/C++" Go Python TS/JS Rust Java; do
    # shellcheck disable=SC2086
    read -ra g <<< "${GLOBS[$lang]}"
    f="$(count_files "${g[@]}")"
    [[ "$f" -eq 0 ]] && continue
    l="$(count_loc "${g[@]}")"
    [[ "$JSON_MODE" -eq 0 ]] && printf '  %-14s %10s %12s\n' "$lang" "$f" "$l" || true
    LANG_J="${LANG_J:+$LANG_J,}{\"lang\":\"$(json_escape "$lang")\",\"files\":$f,\"lines\":$l}"
    TOTAL_LOC=$((TOTAL_LOC + l))
    [[ "$lang" == "C/C++" || "$lang" == "Go" ]] && CCGO_LOC=$((CCGO_LOC + l)) || true
  done
  [[ "$JSON_MODE" -eq 0 ]] && printf '  %-14s %10s %12s\n' "TOTAL" "$TRACKED" "$TOTAL_LOC" || true
  info "Source LOC total: $(human "$TOTAL_LOC")   |   C/C++/Go: $(human "$CCGO_LOC")"
else
  warn "Skipped — no git repo."
fi

# ============================================================
sec "3. Committed vendor/generated trees (these WILL be indexed)"
# ============================================================
if [[ "$GIT_OK" -eq 1 ]]; then
  # Match vendor/generated *directories* (token followed by /) and protobuf-generated
  # file suffixes — not filenames that merely contain "gen"/"generate".
  VEND="$(git -C "$REPO_ABS" ls-files 2>/dev/null \
    | grep -iE '(^|/)(third_party|thirdparty|vendor|external|deps|generated)/|\.pb\.(cc|h|go)$|_pb2\.py$' \
    | sed -E 's#(^.*/(third_party|thirdparty|vendor|external|deps|generated))/.*#\1/#' \
    | sort -u | head -40 || true)"
  if [[ -n "$VEND" ]]; then
    warn "Committed vendor/generated paths found — gitignore to exclude, or accept index inflation:"
    while IFS= read -r p; do
      [[ -z "$p" ]] && continue
      info "$p"
      VEND_J="${VEND_J:+$VEND_J,}\"$(json_escape "$p")\""
    done <<< "$VEND"
  else
    ok "No obvious committed vendor/generated trees."
  fi
else
  warn "Skipped — no git repo."
fi

# ============================================================
sec "4. Engine availability"
# ============================================================
if find_memory_bin "$REPO_ABS" "$SELF_REPO"; then
  ENGINE="$MEMORY_BIN"
  ENGINE_FOUND=true
  VER="$("$ENGINE" --version 2>/dev/null | head -1 || echo '?')"
  ok "Engine: $ENGINE ($VER)"
  LIMIT="$("$ENGINE" config list 2>/dev/null | awk '/auto_index_limit/{print $3}' || true)"
  [[ -n "$LIMIT" ]] && info "auto_index_limit: $LIMIT (governs AUTO-index only; explicit index_repository should bypass)" || true
  if [[ "$GIT_OK" -eq 1 && -n "${LIMIT:-}" && "$TRACKED" -gt "$LIMIT" ]]; then
    warn "Tracked files ($TRACKED) > auto_index_limit ($LIMIT) — confirm the explicit index isn't truncated near $LIMIT."
  fi
else
  ENGINE=""
  fail "Engine 'codebase-memory-mcp' not found (checked \$DRAFT_MEMORY_BIN, PATH, ~/.cache/draft/bin/, vendored bin/<arch>/)."
  info "Install: scripts/fetch-memory-engine.sh   (or put the binary on PATH)"
fi

# ============================================================
sec "5. Machine headroom"
# ============================================================
if [[ -r /proc/meminfo ]]; then
  RAM_GB="$(awk '/MemTotal/{printf "%d", $2/1024/1024}' /proc/meminfo)"
  ok "Total RAM: ${RAM_GB} GB (engine self-budgets ~half)"
elif command -v sysctl >/dev/null 2>&1; then
  RAM_GB="$(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1024 / 1024 / 1024 ))"
  ok "Total RAM: ${RAM_GB} GB"
else
  warn "Could not read total RAM."
fi
CACHE_DIR="$HOME/.cache"; mkdir -p "$CACHE_DIR" 2>/dev/null || true
FREE_K="$(df -Pk "$CACHE_DIR" 2>/dev/null | awk 'NR==2{print $4}' || true)"
if [[ -n "${FREE_K:-}" ]]; then
  FREE_GB=$((FREE_K / 1024 / 1024))
  if [[ "$FREE_GB" -lt 10 ]]; then warn "$CACHE_DIR free: ${FREE_GB} GB (low — index lives here)"; else ok "$CACHE_DIR free: ${FREE_GB} GB"; fi
fi

# ============================================================
# Scale heuristic for first-pass time expectation.
if [[ "$CCGO_LOC" -ge 5000000 || "$TOTAL_LOC" -ge 5000000 ]]; then
  warn "Large codebase ($(human "$TOTAL_LOC") LOC) — expect a long first-pass index (likely hours). Run backgrounded; incremental thereafter."
fi

# --- verdict ---
if [[ "$BLOCKERS" -gt 0 ]]; then VERDICT="NO_GO"; VEXIT=1
elif [[ "$WARNINGS" -gt 0 ]]; then VERDICT="GO_WITH_CAUTION"; VEXIT=0
else VERDICT="GO"; VEXIT=0
fi

# ============================================================
# Output
# ============================================================
if [[ "$JSON_MODE" -eq 1 ]]; then
  printf '{\n'
  printf '  "repo": "%s",\n' "$(json_escape "$REPO_ABS")"
  printf '  "is_git_repo": %s,\n' "$IS_GIT"
  printf '  "git_root": %s,\n' "$([[ -n "$GIT_TOP" ]] && printf '"%s"' "$(json_escape "$GIT_TOP")" || printf 'null')"
  printf '  "at_git_root": %s,\n' "$AT_ROOT"
  printf '  "head": "%s",\n' "$(json_escape "$COMMIT")"
  printf '  "tracked_files": %s,\n' "$TRACKED"
  printf '  "files_on_disk": %s,\n' "$ALLDISK"
  printf '  "languages": [%s],\n' "$LANG_J"
  printf '  "total_source_loc": %s,\n' "$TOTAL_LOC"
  printf '  "ccgo_loc": %s,\n' "$CCGO_LOC"
  printf '  "committed_vendor_paths": [%s],\n' "$VEND_J"
  printf '  "engine": {"found": %s, "path": %s, "version": %s, "auto_index_limit": %s},\n' \
    "$ENGINE_FOUND" \
    "$([[ -n "$ENGINE" ]] && printf '"%s"' "$(json_escape "$ENGINE")" || printf 'null')" \
    "$([[ -n "$VER" ]] && printf '"%s"' "$(json_escape "$VER")" || printf 'null')" \
    "${LIMIT:-null}"
  printf '  "machine": {"ram_gb": %s, "cache_free_gb": %s},\n' "${RAM_GB:-null}" "${FREE_GB:-null}"
  printf '  "warnings": [%s],\n' "$WARN_J"
  printf '  "blockers": [%s],\n' "$FAIL_J"
  printf '  "verdict": "%s",\n' "$VERDICT"
  printf '  "exit_code": %s\n' "$VEXIT"
  printf '}\n'
  exit "$VEXIT"
fi

sec "Verdict"
echo
case "$VERDICT" in
  NO_GO)          printf '%s NO-GO %s — %d blocker(s), %d warning(s). Resolve blockers above first.\n' "$R" "$D" "$BLOCKERS" "$WARNINGS";;
  GO_WITH_CAUTION) printf '%s GO (with caution) %s — %d warning(s). Review them, then proceed.\n' "$Y" "$D" "$WARNINGS";;
  GO)             printf '%s GO %s — clear to index.\n' "$G" "$D";;
esac

cat <<EOF

Next step (when ready, from the git root):
  scripts/tools/graph-init.sh --scope . --json &     # or: /draft:init --graph-only
  ${ENGINE:-codebase-memory-mcp} cli list_projects '{}'
  ${ENGINE:-codebase-memory-mcp} cli index_status '{"project":"<name>"}'
EOF
hr
exit "$VEXIT"
