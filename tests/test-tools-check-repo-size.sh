#!/usr/bin/env bash
# Test suite for scripts/tools/check-repo-size.sh
#
# What this tests:
# - Passes when HEAD is under the cap, fails when over (the v2.8.3 regression)
# - JSON shape is parseable and reports status/total_bytes/max_mb
# - Over-cap output names the offending blobs
# - Bad --max-mb / --top / --rev / unknown flags exit 2, not 1 (usage != breach)
#
# Usage:
#   ./tests/test-tools-check-repo-size.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/check-repo-size.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== check-repo-size.sh tests ==="
echo ""

assert "tool is executable" "$([[ -x "$TOOL" ]] && echo true || echo false)"

echo "## Real repo, generous cap"
if out="$("$TOOL" --max-mb 4096 2>&1)"; then
    assert "passes under cap" "true"
else
    assert "passes under cap" "false"
fi
assert "reports the cap it used" \
    "$(grep -q 'cap: 4096 MB' <<< "$out" && echo true || echo false)"

echo ""
echo "## Real repo, impossible cap"
set +e
over_out="$("$TOOL" --max-mb 0 2>&1)"
over_rc=$?
set -e
assert "exits 1 when over cap" "$([[ "$over_rc" -eq 1 ]] && echo true || echo false)"
assert "names the largest blobs" \
    "$(grep -q 'Largest tracked blobs' <<< "$over_out" && echo true || echo false)"
assert "explains the install consequence" \
    "$(grep -q 'marketplace add' <<< "$over_out" && echo true || echo false)"

echo ""
echo "## JSON output"
json="$("$TOOL" --max-mb 4096 --json)"
if command -v jq >/dev/null 2>&1; then
    assert "JSON parses" "$(jq -e . >/dev/null 2>&1 <<< "$json" && echo true || echo false)"
    assert "status is ok under cap" \
        "$([[ "$(jq -r .status <<< "$json")" == "ok" ]] && echo true || echo false)"
    assert "total_bytes is a positive integer" \
        "$(jq -e '.total_bytes > 0' >/dev/null 2>&1 <<< "$json" && echo true || echo false)"
    assert "max_mb echoes the requested cap" \
        "$([[ "$(jq -r .max_mb <<< "$json")" == "4096" ]] && echo true || echo false)"
    over_json="$("$TOOL" --max-mb 0 --json || true)"
    assert "status is over above cap" \
        "$([[ "$(jq -r .status <<< "$over_json")" == "over" ]] && echo true || echo false)"
else
    assert "JSON contains status field (jq unavailable)" \
        "$(grep -q '"status"' <<< "$json" && echo true || echo false)"
fi

echo ""
echo "## A repo with an oversized blob fails"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
(
    cd "$tmp"
    git init -q .
    git config user.email t@t.t
    git config user.name t
    head -c 2097152 /dev/zero > big.bin
    echo hi > small.txt
    git add -A
    git commit -qm "oversized asset"
) >/dev/null 2>&1
set +e
tmp_out="$("$TOOL" --repo "$tmp" --max-mb 1 2>&1)"
tmp_rc=$?
set -e
assert "synthetic 2 MB blob breaches a 1 MB cap" "$([[ "$tmp_rc" -eq 1 ]] && echo true || echo false)"
assert "synthetic breach names big.bin" \
    "$(grep -q 'big.bin' <<< "$tmp_out" && echo true || echo false)"
if "$TOOL" --repo "$tmp" --max-mb 8 >/dev/null 2>&1; then
    assert "same repo passes an 8 MB cap" "true"
else
    assert "same repo passes an 8 MB cap" "false"
fi

echo ""
echo "## Usage errors exit 2"
for bad in "--max-mb" "--max-mb x" "--top y" "--rev" "--bogus"; do
    set +e
    # shellcheck disable=SC2086  # intentional word splitting of the bad arg pair
    "$TOOL" $bad >/dev/null 2>&1
    rc=$?
    set -e
    assert "'$bad' exits 2" "$([[ "$rc" -eq 2 ]] && echo true || echo false)"
done

set +e
"$TOOL" --rev definitely-not-a-rev >/dev/null 2>&1
rc=$?
set -e
assert "unknown revision exits 2" "$([[ "$rc" -eq 2 ]] && echo true || echo false)"

set +e
"$TOOL" --repo /nonexistent-path-xyz >/dev/null 2>&1
rc=$?
set -e
assert "missing repo dir exits 2" "$([[ "$rc" -eq 2 ]] && echo true || echo false)"

set +e
"$TOOL" --repo "$(mktemp -d)" >/dev/null 2>&1
rc=$?
set -e
assert "non-git dir exits 2" "$([[ "$rc" -eq 2 ]] && echo true || echo false)"

finish_test "check-repo-size"
