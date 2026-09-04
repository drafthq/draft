#!/usr/bin/env bash
# Test suite for scripts/package.sh safety fences.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/package.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== package.sh tests ==="
echo ""

assert "script is executable" "$([[ -x "$TOOL" ]] && echo true || echo false)"

set +e
"$TOOL" --out / --no-build --no-verify >/dev/null 2>&1
root_rc=$?
"$TOOL" --version '../escape' --no-build --no-verify >/dev/null 2>&1
ver_rc=$?
set -e
assert "--out / is refused (exit 2)" "$([[ "$root_rc" -eq 2 ]] && echo true || echo false)"
assert "--version with .. is refused (exit 2)" "$([[ "$ver_rc" -eq 2 ]] && echo true || echo false)"

finish_test "package.sh"
