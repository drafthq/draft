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

finish_test "mem-bound"
