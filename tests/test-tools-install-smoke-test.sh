#!/usr/bin/env bash
# Test suite for scripts/tools/install-smoke-test.sh
#
# What this tests:
# - A healthy checkout passes every check and exits 0
# - JSON mode is parseable and reports zero failures
# - The sandbox is removed unless --keep, and --keep leaves a clone behind
# - A checkout with a broken plugin.json fails (the check is not vacuous)
# - Unknown flags / missing --repo value exit 2
#
# The tool clones, so this suite is slower than the rest. It is still cheap
# relative to shipping a broken install.
#
# Usage:
#   ./tests/test-tools-install-smoke-test.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/install-smoke-test.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== install-smoke-test.sh tests ==="
echo ""

assert "tool is executable" "$([[ -x "$TOOL" ]] && echo true || echo false)"

if ! command -v node >/dev/null 2>&1; then
    echo "## node not available — skipping clone-based checks"
    finish_test "install-smoke-test"
fi

echo "## Healthy checkout"
if out="$("$TOOL" 2>&1)"; then
    assert "this repo passes the smoke test" "true"
else
    assert "this repo passes the smoke test" "false"
    echo "$out" | tail -n 15
fi
assert "reports the clone step" \
    "$(grep -q 'shallow clone succeeds' <<< "$out" && echo true || echo false)"
assert "reports per-host dry runs" \
    "$(grep -q 'install --dry-run: claude-code' <<< "$out" && echo true || echo false)"
assert "asserts the dry run wrote nothing" \
    "$(grep -q 'dry run left HOME untouched' <<< "$out" && echo true || echo false)"

echo ""
echo "## Sandbox lifecycle"
sandbox="$(grep -o '/[^ ]*draft-install-smoke\.[A-Za-z0-9]*' <<< "$out" | head -n 1)"
assert "sandbox path reported" "$([[ -n "$sandbox" ]] && echo true || echo false)"
assert "sandbox removed by default" "$([[ ! -d "$sandbox" ]] && echo true || echo false)"

keep_out="$("$TOOL" --keep 2>&1)"
keep_sandbox="$(grep -o '/[^ ]*draft-install-smoke\.[A-Za-z0-9]*' <<< "$keep_out" | head -n 1)"
assert "--keep retains the sandbox" "$([[ -d "$keep_sandbox" ]] && echo true || echo false)"
assert "--keep sandbox holds the clone" "$([[ -d "$keep_sandbox/clone/.claude-plugin" ]] && echo true || echo false)"
rm -rf "$keep_sandbox"

echo ""
echo "## JSON output"
json="$("$TOOL" --json)"
if command -v jq >/dev/null 2>&1; then
    assert "JSON parses" "$(jq -e . >/dev/null 2>&1 <<< "$json" && echo true || echo false)"
    assert "zero failures reported" \
        "$([[ "$(jq -r .failures <<< "$json")" == "0" ]] && echo true || echo false)"
    assert "every check reports ok" \
        "$(jq -e 'all(.checks[]; .ok)' >/dev/null 2>&1 <<< "$json" && echo true || echo false)"
else
    assert "JSON contains failures field (jq unavailable)" \
        "$(grep -q '"failures"' <<< "$json" && echo true || echo false)"
fi

echo ""
echo "## Broken checkout is caught"
broken="$(mktemp -d)"
trap 'rm -rf "$broken"' EXIT
git clone --quiet --depth 1 "file://$ROOT_DIR" "$broken/repo" 2>/dev/null
(
    cd "$broken/repo"
    git config user.email t@t.t
    git config user.name t
    echo '{ "not": "a plugin manifest" }' > .claude-plugin/plugin.json
    git add -A
    git commit -qm "break the manifest"
) >/dev/null 2>&1
set +e
broken_out="$("$TOOL" --repo "$broken/repo" 2>&1)"
broken_rc=$?
set -e
assert "broken plugin.json exits non-zero" "$([[ "$broken_rc" -ne 0 ]] && echo true || echo false)"
assert "broken plugin.json names the manifest check" \
    "$(grep -q 'FAIL: plugin manifests resolve' <<< "$broken_out" && echo true || echo false)"

echo ""
echo "## Usage errors exit 2"
for bad in "--repo" "--bogus"; do
    set +e
    # shellcheck disable=SC2086  # intentional word splitting
    "$TOOL" $bad >/dev/null 2>&1
    rc=$?
    set -e
    assert "'$bad' exits 2" "$([[ "$rc" -eq 2 ]] && echo true || echo false)"
done

set +e
"$TOOL" --repo /nonexistent-path-xyz >/dev/null 2>&1
rc=$?
set -e
assert "missing repo dir exits 2" "$([[ "$rc" -eq 2 ]] && echo true || echo false)"

finish_test "install-smoke-test"
