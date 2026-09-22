#!/usr/bin/env bash
# Test suite for scripts/tools/mission-state.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/mission-state.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== mission-state.sh tests ==="
echo ""

if ! command -v jq >/dev/null 2>&1; then
    echo " SKIP: jq not available"
    finish_test "mission-state"
fi

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
git -C "$FIXTURE" init -q .
git -C "$FIXTURE" -c user.email=t@example.com -c user.name=Test commit -q --allow-empty -m init

STATE="$FIXTURE/draft/.state/mission.json"

echo "## init"
"$TOOL" --repo "$FIXTURE" init --source jira:ENG-1 >/dev/null
assert "init creates the state file" "$([[ -f "$STATE" ]] && echo true || echo false)"
assert "init records the source" "$([[ "$("$TOOL" --repo "$FIXTURE" get source)" == "jira:ENG-1" ]] && echo true || echo false)"
assert "init starts in intake/pending" "$([[ "$("$TOOL" --repo "$FIXTURE" get phase)" == "intake" ]] && echo true || echo false)"
assert "init stamps last_commit from git HEAD" \
    "$([[ "$("$TOOL" --repo "$FIXTURE" get last_commit)" == "$(git -C "$FIXTURE" rev-parse HEAD)" ]] && echo true || echo false)"

echo ""
echo "## init refuses to clobber an existing mission"
if "$TOOL" --repo "$FIXTURE" init --source jira:ENG-2 >/dev/null 2>&1; then
    assert "second init without --force is refused" "false"
else
    assert "second init without --force is refused" "true"
fi
assert "refused init left the original source intact" \
    "$([[ "$("$TOOL" --repo "$FIXTURE" get source)" == "jira:ENG-1" ]] && echo true || echo false)"

echo ""
echo "## set"
"$TOOL" --repo "$FIXTURE" set phase=build phase_status=in_progress next_task="write failing test" >/dev/null
assert "set writes phase" "$([[ "$("$TOOL" --repo "$FIXTURE" get phase)" == "build" ]] && echo true || echo false)"
assert "set writes a value containing spaces" \
    "$([[ "$("$TOOL" --repo "$FIXTURE" get next_task)" == "write failing test" ]] && echo true || echo false)"
"$TOOL" --repo "$FIXTURE" set tracks=001-auth,002-api >/dev/null
assert "set parses a comma list into an array" \
    "$([[ "$(jq -r '.tracks | length' "$STATE")" == "2" ]] && echo true || echo false)"
"$TOOL" --repo "$FIXTURE" set tracks= >/dev/null
assert "set with an empty list yields an empty array" \
    "$([[ "$(jq -r '.tracks | length' "$STATE")" == "0" ]] && echo true || echo false)"
"$TOOL" --repo "$FIXTURE" set recovery_attempts=2 >/dev/null
assert "integer fields stay JSON numbers" \
    "$([[ "$(jq -r '.recovery_attempts | type' "$STATE")" == "number" ]] && echo true || echo false)"

echo ""
echo "## set rejects bad input"
for bad in "phase=bogus" "phase_status=maybe" "nonsense=1" "recovery_attempts=abc" "handoff_notes=x"; do
    if "$TOOL" --repo "$FIXTURE" set "$bad" >/dev/null 2>&1; then
        assert "set rejects $bad" "false"
    else
        assert "set rejects $bad" "true"
    fi
done
assert "a rejected set left the file valid" "$("$TOOL" --repo "$FIXTURE" validate >/dev/null 2>&1 && echo true || echo false)"

echo ""
echo "## validate catches corruption"
cp "$STATE" "$FIXTURE/good.json"
jq 'del(.phase)' "$FIXTURE/good.json" > "$STATE"
if "$TOOL" --repo "$FIXTURE" validate >/dev/null 2>&1; then
    assert "validate fails on a missing field" "false"
else
    assert "validate fails on a missing field" "true"
fi
jq '. + {stray_field: 1}' "$FIXTURE/good.json" > "$STATE"
if "$TOOL" --repo "$FIXTURE" validate >/dev/null 2>&1; then
    assert "validate fails on an unknown field" "false"
else
    assert "validate fails on an unknown field" "true"
fi
jq '.tracks = "not-an-array"' "$FIXTURE/good.json" > "$STATE"
if "$TOOL" --repo "$FIXTURE" validate >/dev/null 2>&1; then
    assert "validate fails when tracks is not an array" "false"
else
    assert "validate fails when tracks is not an array" "true"
fi
printf 'not json' > "$STATE"
if "$TOOL" --repo "$FIXTURE" validate >/dev/null 2>&1; then
    assert "validate fails on malformed JSON" "false"
else
    assert "validate fails on malformed JSON" "true"
fi
cp "$FIXTURE/good.json" "$STATE"

echo ""
echo "## atomic write keeps a recoverable backup"
"$TOOL" --repo "$FIXTURE" set phase=ship >/dev/null
assert "a .bak is kept alongside the state" \
    "$([[ -f "$STATE.bak" ]] && echo true || echo false)"
assert "the .bak holds the previous phase" \
    "$([[ "$(jq -r '.phase' "$STATE.bak")" == "build" ]] && echo true || echo false)"

echo ""
echo "## missing state is an error, not a default"
EMPTY="$(mktemp -d)"
trap 'rm -rf "$FIXTURE" "$EMPTY"' EXIT
if "$TOOL" --repo "$EMPTY" get phase >/dev/null 2>&1; then
    assert "get on a missing mission fails" "false"
else
    assert "get on a missing mission fails" "true"
fi

finish_test "mission-state"
