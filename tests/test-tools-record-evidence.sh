#!/usr/bin/env bash
# Test suite for scripts/tools/record-evidence.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/record-evidence.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== record-evidence.sh tests ==="
echo ""

if ! command -v jq >/dev/null 2>&1; then
    echo " SKIP: jq not available"
    finish_test "record-evidence"
fi

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
git -C "$FIXTURE" init -q .
git -C "$FIXTURE" -c user.email=t@example.com -c user.name=Test commit -q --allow-empty -m init
HEAD_SHA="$(git -C "$FIXTURE" rev-parse HEAD)"

INDEX="$FIXTURE/draft/.state/evidence/index.jsonl"

echo "## recording a passing command"
"$TOOL" --repo "$FIXTURE" --phase build --label tests -- bash -c 'echo "42 passed"' >/dev/null
assert "an index entry is written" "$([[ -f "$INDEX" ]] && echo true || echo false)"
rec="$("$TOOL" --repo "$FIXTURE" --latest --phase build --label tests)"
assert "the record carries exit_code 0" "$([[ "$(echo "$rec" | jq -r '.exit_code')" == "0" ]] && echo true || echo false)"
assert "the record pins the commit it ran against" \
    "$([[ "$(echo "$rec" | jq -r '.commit')" == "$HEAD_SHA" ]] && echo true || echo false)"
assert "the record names the command" \
    "$(echo "$rec" | jq -r '.command' | grep -q '42 passed' && echo true || echo false)"
log_rel="$(echo "$rec" | jq -r '.log')"
assert "the referenced log exists on disk" \
    "$([[ -f "$FIXTURE/draft/.state/$log_rel" ]] && echo true || echo false)"
assert "the log holds the real command output" \
    "$(grep -q '42 passed' "$FIXTURE/draft/.state/$log_rel" && echo true || echo false)"

echo ""
echo "## a failing command is recorded as failing, not swallowed"
set +e
"$TOOL" --repo "$FIXTURE" --phase build --label lint -- bash -c 'echo "boom" >&2; exit 7' >/dev/null 2>&1
propagated=$?
set -e
assert "the wrapped command's exit code is propagated" "$([[ "$propagated" == "7" ]] && echo true || echo false)"
rec="$("$TOOL" --repo "$FIXTURE" --latest --phase build --label lint)"
assert "the failing record stores exit_code 7" "$([[ "$(echo "$rec" | jq -r '.exit_code')" == "7" ]] && echo true || echo false)"
assert "stderr is captured in the log" \
    "$(grep -q 'boom' "$FIXTURE/draft/.state/$(echo "$rec" | jq -r '.log')" && echo true || echo false)"

echo ""
echo "## --latest returns the newest matching record"
"$TOOL" --repo "$FIXTURE" --phase build --label tests -- bash -c 'echo "second run"' >/dev/null
rec="$("$TOOL" --repo "$FIXTURE" --latest --phase build --label tests)"
assert "--latest picks the most recent entry" \
    "$(echo "$rec" | jq -r '.command' | grep -q 'second run' && echo true || echo false)"
assert "records accumulate rather than overwrite" \
    "$([[ "$(wc -l < "$INDEX")" -eq 3 ]] && echo true || echo false)"

echo ""
echo "## --latest is scoped by phase and label"
if "$TOOL" --repo "$FIXTURE" --latest --phase ship --label tests >/dev/null 2>&1; then
    assert "a different phase does not match" "false"
else
    assert "a different phase does not match" "true"
fi
if "$TOOL" --repo "$FIXTURE" --latest --phase build --label nonexistent >/dev/null 2>&1; then
    assert "an unknown label does not match" "false"
else
    assert "an unknown label does not match" "true"
fi

echo ""
echo "## every line of the index is valid JSON"
ALL_JSON=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    echo "$line" | jq empty 2>/dev/null || ALL_JSON=false
done < "$INDEX"
assert "index.jsonl is well-formed JSONL" "$ALL_JSON"

echo ""
echo "## usage errors"
if "$TOOL" --repo "$FIXTURE" --phase build --label tests >/dev/null 2>&1; then
    assert "run mode without a command is a usage error" "false"
else
    assert "run mode without a command is a usage error" "true"
fi
if "$TOOL" --repo "$FIXTURE" --label tests -- true >/dev/null 2>&1; then
    assert "a missing --phase is a usage error" "false"
else
    assert "a missing --phase is a usage error" "true"
fi

finish_test "record-evidence"
