#!/usr/bin/env bash
# Test suite for scripts/tools/graph-preflight.sh (read-only graph index go/no-go check)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/graph-preflight.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== graph-preflight.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# --- Test 1: --help exits 0 with output ---
set +e
out="$("$TOOL" --help 2>&1)"; rc=$?
set -e
assert "--help → exit 0" "$([[ "$rc" == "0" ]] && echo true || echo false)"
assert "--help prints usage" "$([[ -n "$out" ]] && echo true || echo false)"

# --- Test 2: bad flag → exit 2 ---
set +e
"$TOOL" --bogus >/dev/null 2>&1; rc=$?
set -e
assert "Unknown flag → exit 2" "$([[ "$rc" == "2" ]] && echo true || echo false)"

# --- Test 3: non-git dir + no engine → NO_GO (exit 1), well-formed JSON ---
NOGIT="$FIXTURE/nogit"; mkdir -p "$NOGIT"
set +e
out="$(DRAFT_MEMORY_DISABLE=1 "$TOOL" --json "$NOGIT" 2>/dev/null)"; rc=$?
set -e
assert "Non-git + no engine → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"
assert "JSON reports is_git_repo false" "$(echo "$out" | grep -q '"is_git_repo": false' && echo true || echo false)"
assert "JSON reports engine not found" "$(echo "$out" | grep -q '"found": false' && echo true || echo false)"
assert "JSON verdict NO_GO" "$(echo "$out" | grep -q '"verdict": "NO_GO"' && echo true || echo false)"

# --- Test 4: git repo at root + mock engine → not NO_GO (exit 0), git/engine detected ---
REPOG="$FIXTURE/repo"; mkdir -p "$REPOG"
git -C "$REPOG" init -q
printf 'def foo():\n    return 1\n' > "$REPOG/a.py"
git -C "$REPOG" add . >/dev/null 2>&1
MOCK="$(make_mock_memory_engine "$FIXTURE/mockbin")"
set +e
out="$(DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --json "$REPOG" 2>/dev/null)"; rc=$?
set -e
assert "Git + engine → exit 0 (not blocking)" "$([[ "$rc" == "0" ]] && echo true || echo false)"
assert "JSON reports is_git_repo true" "$(echo "$out" | grep -q '"is_git_repo": true' && echo true || echo false)"
assert "JSON reports at_git_root true" "$(echo "$out" | grep -q '"at_git_root": true' && echo true || echo false)"
assert "JSON reports engine found" "$(echo "$out" | grep -q '"found": true' && echo true || echo false)"
assert "JSON verdict is GO or GO_WITH_CAUTION" \
  "$(echo "$out" | grep -qE '"verdict": "GO(_WITH_CAUTION)?"' && echo true || echo false)"
assert "JSON counts the python file" "$(echo "$out" | grep -q '"tracked_files": 1' && echo true || echo false)"

# --- Test 5: JSON is parseable when jq is available ---
if command -v jq >/dev/null 2>&1; then
  assert "JSON output is valid (jq parses)" "$(echo "$out" | jq -e . >/dev/null 2>&1 && echo true || echo false)"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
