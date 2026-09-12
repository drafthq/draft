#!/usr/bin/env bash
# Test suite for scripts/tools/gate-check.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
GATE="$ROOT_DIR/scripts/tools/gate-check.sh"
STATE_TOOL="$ROOT_DIR/scripts/tools/mission-state.sh"
EVIDENCE="$ROOT_DIR/scripts/tools/record-evidence.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== gate-check.sh tests ==="
echo ""

if ! command -v jq >/dev/null 2>&1; then
    echo " SKIP: jq not available"
    finish_test "gate-check"
fi

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
git -C "$FIXTURE" init -q .
commit() { git -C "$FIXTURE" -c user.email=t@example.com -c user.name=Test commit -q --allow-empty -m "$1"; }
commit init

gate() { "$GATE" --repo "$FIXTURE" "$@" >/dev/null 2>&1; }

echo "## a gate with no mission state fails"
if gate --phase build; then
    assert "build gate fails without mission state" "false"
else
    assert "build gate fails without mission state" "true"
fi

"$STATE_TOOL" --repo "$FIXTURE" init --source jira:ENG-1 >/dev/null
"$STATE_TOOL" --repo "$FIXTURE" set phase=build phase_status=in_progress >/dev/null

echo ""
echo "## a mission with no evidence still fails — state alone is not a pass"
if gate --phase build; then
    assert "build gate fails with no test evidence" "false"
else
    assert "build gate fails with no test evidence" "true"
fi

echo ""
echo "## fresh passing evidence clears the gate"
"$EVIDENCE" --repo "$FIXTURE" --phase build --label tests -- bash -c 'echo "all green"' >/dev/null
assert "build gate passes on fresh green evidence" "$(gate --phase build && echo true || echo false)"

echo ""
echo "## evidence goes stale when new work lands"
commit "new work"
if gate --phase build; then
    assert "build gate fails on evidence from an earlier commit" "false"
else
    assert "build gate fails on evidence from an earlier commit" "true"
fi
out="$("$GATE" --repo "$FIXTURE" --phase build 2>&1 || true)"
assert "the failure names staleness" "$(echo "$out" | grep -q 'stale' && echo true || echo false)"
"$EVIDENCE" --repo "$FIXTURE" --phase build --label tests -- bash -c 'echo "all green"' >/dev/null
assert "re-running the check clears the gate again" "$(gate --phase build && echo true || echo false)"

echo ""
echo "## a failing command never clears the gate"
"$EVIDENCE" --repo "$FIXTURE" --phase build --label tests -- bash -c 'exit 1' >/dev/null 2>&1 || true
if gate --phase build; then
    assert "build gate fails when the recorded run exited non-zero" "false"
else
    assert "build gate fails when the recorded run exited non-zero" "true"
fi

echo ""
echo "## a green claim whose log is gone cannot be corroborated"
"$EVIDENCE" --repo "$FIXTURE" --phase build --label tests -- bash -c 'echo ok' >/dev/null
rm -f "$FIXTURE"/draft/.state/evidence/build-tests-*.log
if gate --phase build; then
    assert "build gate fails when the evidence log is missing" "false"
else
    assert "build gate fails when the evidence log is missing" "true"
fi
out="$("$GATE" --repo "$FIXTURE" --phase build 2>&1 || true)"
assert "the failure names the missing corroboration" \
    "$(echo "$out" | grep -q 'corroborated' && echo true || echo false)"

echo ""
echo "## every required label must be satisfied"
"$EVIDENCE" --repo "$FIXTURE" --phase build --label tests -- bash -c 'echo ok' >/dev/null
assert "gate passes for the default label set" "$(gate --phase build && echo true || echo false)"
if gate --phase build --require tests --require lint; then
    assert "gate fails when an extra required label has no evidence" "false"
else
    assert "gate fails when an extra required label has no evidence" "true"
fi
"$EVIDENCE" --repo "$FIXTURE" --phase build --label lint -- bash -c 'echo clean' >/dev/null
assert "gate passes once every required label is satisfied" \
    "$(gate --phase build --require tests --require lint && echo true || echo false)"

echo ""
echo "## corrupt mission state fails the gate"
cp "$FIXTURE/draft/.state/mission.json" "$FIXTURE/good.json"
printf 'not json' > "$FIXTURE/draft/.state/mission.json"
if gate --phase build; then
    assert "build gate fails on malformed mission state" "false"
else
    assert "build gate fails on malformed mission state" "true"
fi
cp "$FIXTURE/good.json" "$FIXTURE/draft/.state/mission.json"

echo ""
echo "## ship phase additionally requires named, hygienic tracks"
"$EVIDENCE" --repo "$FIXTURE" --phase ship --label tests -- bash -c 'echo ok' >/dev/null
if gate --phase ship; then
    assert "ship gate fails when the mission names no tracks" "false"
else
    assert "ship gate fails when the mission names no tracks" "true"
fi
out="$("$GATE" --repo "$FIXTURE" --phase ship 2>&1 || true)"
assert "the failure says there is nothing to ship" \
    "$(echo "$out" | grep -q 'nothing to ship' && echo true || echo false)"
"$STATE_TOOL" --repo "$FIXTURE" set tracks=001-ghost >/dev/null
"$EVIDENCE" --repo "$FIXTURE" --phase ship --label tests -- bash -c 'echo ok' >/dev/null
if gate --phase ship; then
    assert "ship gate fails when a named track does not exist" "false"
else
    assert "ship gate fails when a named track does not exist" "true"
fi

echo ""
echo "## --json output"
json="$("$GATE" --repo "$FIXTURE" --phase build --json 2>/dev/null || true)"
assert "--json emits valid JSON" "$(echo "$json" | jq empty 2>/dev/null && echo true || echo false)"
assert "--json reports the phase" "$([[ "$(echo "$json" | jq -r '.phase')" == "build" ]] && echo true || echo false)"
assert "--json carries a check row per gate check" \
    "$([[ "$(echo "$json" | jq -r '.checks | length')" -ge 2 ]] && echo true || echo false)"

echo ""
echo "## usage errors"
if gate --phase nonsense; then
    assert "an unknown phase is a usage error" "false"
else
    assert "an unknown phase is a usage error" "true"
fi
if gate; then
    assert "a missing --phase is a usage error" "false"
else
    assert "a missing --phase is a usage error" "true"
fi

finish_test "gate-check"
