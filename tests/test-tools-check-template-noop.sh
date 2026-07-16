#!/usr/bin/env bash
# Test suite for scripts/tools/check-template-noop.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/check-template-noop.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== check-template-noop.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# Fixture git repo with the directory shape the gate inspects.
git -C "$FIXTURE" init -q
git -C "$FIXTURE" config user.email test@example.invalid
git -C "$FIXTURE" config user.name "Test"
mkdir -p "$FIXTURE/skills/demo" "$FIXTURE/core/templates" "$FIXTURE/scripts/tools" "$FIXTURE/docs"
echo base > "$FIXTURE/skills/demo/SKILL.md"
echo base > "$FIXTURE/core/templates/spec.md"
echo base > "$FIXTURE/docs/readme.md"
git -C "$FIXTURE" add -A
git -C "$FIXTURE" commit -qm "baseline"

run() { set +e; OUT="$(cd "$FIXTURE" && "$TOOL" "$@" 2>&1)"; RC=$?; set -e; }

# --- Skill-only change without tag → violation ---
echo change1 >> "$FIXTURE/skills/demo/SKILL.md"
git -C "$FIXTURE" commit -aqm "feat: skill-only change"
run
assert "skill-only commit → exit 1" "$([[ "$RC" == "1" ]] && echo true || echo false)"

# --- Skill change WITH template change → OK ---
echo change2 >> "$FIXTURE/skills/demo/SKILL.md"
echo change2 >> "$FIXTURE/core/templates/spec.md"
git -C "$FIXTURE" commit -aqm "feat: skill + template together"
run
assert "skill+template commit → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"

# --- Skill-only change WITH [template-noop] tag → OK ---
echo change3 >> "$FIXTURE/skills/demo/SKILL.md"
git -C "$FIXTURE" commit -aqm "fix: prose tweak [template-noop]"
run
assert "tagged skill-only commit → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"

# --- Unrelated change → OK (gate not triggered) ---
echo change4 >> "$FIXTURE/docs/readme.md"
git -C "$FIXTURE" commit -aqm "docs: unrelated"
run
assert "unrelated commit → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"

# --- Range form spanning the violation commit ---
run "HEAD~4..HEAD~3"
assert "range form flags the skill-only commit → exit 1" "$([[ "$RC" == "1" ]] && echo true || echo false)"

# --- Outside a git repo → exit 2 ---
NOGIT="$(mktemp -d)"
set +e; (cd "$NOGIT" && GIT_CEILING_DIRECTORIES="$NOGIT" "$TOOL" >/dev/null 2>&1); RC=$?; set -e
rm -rf "$NOGIT"
assert "not a git repo → exit 2" "$([[ "$RC" == "2" ]] && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
