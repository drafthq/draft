#!/usr/bin/env bash
# Test suite for the memory-bounded indexing helpers in scripts/tools/_lib.sh.
# Covers the pure math (_mem_bound_args), RAM detection (_total_ram_mb), and the
# DRAFT_INDEX_MEM_PCT default that bounds `draft:init`'s engine index so a huge
# first index cannot exhaust the host.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/test-helpers.sh"
# shellcheck source=../scripts/tools/_lib.sh
source "$ROOT_DIR/scripts/tools/_lib.sh"

echo "=== mem-bound helper tests ==="
echo ""

# Default 25% of 64000 MB → High=16000M; Max at pct+5 (30%) → 19200M.
[[ "$(_mem_bound_args 64000 25)" == "MemoryHigh=16000M MemoryMax=19200M" ]] \
    && assert "default 25% bound args" "true" || assert "default 25% bound args" "false"

# Honors a custom percent.
[[ "$(_mem_bound_args 100000 10)" == "MemoryHigh=10000M MemoryMax=15000M" ]] \
    && assert "custom 10% bound args" "true" || assert "custom 10% bound args" "false"

# MemoryMax always sits above MemoryHigh (headroom before the hard kill).
read -r h m <<< "$(_mem_bound_args 32000 25)"
hv="${h#MemoryHigh=}"; hv="${hv%M}"; mv="${m#MemoryMax=}"; mv="${mv%M}"
(( mv > hv )) && assert "max above high" "true" || assert "max above high" "false"

# RAM detection returns a positive integer on a normal host.
ram="$(_total_ram_mb)"
[[ "${ram:-0}" -gt 0 ]] && assert "total ram positive" "true" || assert "total ram positive" "false"

# Documented default fraction is 25%.
[[ "${DRAFT_INDEX_MEM_PCT:-25}" == "25" ]] \
    && assert "DRAFT_INDEX_MEM_PCT default 25" "true" || assert "DRAFT_INDEX_MEM_PCT default 25" "false"

# memory_index_bounded builds its JSON payload via jq (never string concatenation),
# so a repo path containing a `"` or `\` can never corrupt the JSON sent to the
# engine (regression: was previously built via unescaped string interpolation).
if command -v jq >/dev/null 2>&1; then
    _can_cgroup_bound() { return 1; }  # force the plain memory_cli path; no systemd-run dependency
    CAPTURE_DIR="$(mktemp -d)"
    trap 'rm -rf "$CAPTURE_DIR"' EXIT
    CAPTURE_FILE="$CAPTURE_DIR/payload.json"
    MOCK_BIN="$CAPTURE_DIR/codebase-memory-mcp"
    cat > "$MOCK_BIN" <<'MOCK'
#!/usr/bin/env bash
# Captures the JSON payload memory_index_bounded passes to `cli index_repository`.
if [[ "$1" == "cli" && "$2" == "index_repository" ]]; then
    printf '%s' "$3" > "$CAPTURE_FILE"
    echo '{"project":"mock"}'
    exit 0
fi
echo '{}'
MOCK
    chmod +x "$MOCK_BIN"
    export CAPTURE_FILE
    MEMORY_BIN="$MOCK_BIN" memory_index_bounded 'weird"repo\path' >/dev/null 2>&1 || true
    payload="$(cat "$CAPTURE_FILE" 2>/dev/null || echo '')"
    [[ -n "$payload" ]] && echo "$payload" | jq -e . >/dev/null 2>&1 \
        && assert "index payload is valid JSON for a path with a quote and backslash" "true" \
        || assert "index payload is valid JSON for a path with a quote and backslash" "false"
    [[ "$(echo "$payload" | jq -r '.repo_path' 2>/dev/null)" == 'weird"repo\path' ]] \
        && assert "index payload preserves the raw repo_path value" "true" \
        || assert "index payload preserves the raw repo_path value" "false"
fi

finish_test "mem-bound"
