#!/usr/bin/env bash
# Test suite for scripts/tools/parse-git-log.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/parse-git-log.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== parse-git-log.sh tests ==="
echo ""

out="$("$TOOL" --limit 5)"

# --- Every line parses as JSON ---
ALL_JSON=true
any=false
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    any=true
    if command -v jq >/dev/null 2>&1; then
        echo "$line" | jq . >/dev/null 2>&1 || ALL_JSON=false
    elif command -v python3 >/dev/null 2>&1; then
        echo "$line" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null || ALL_JSON=false
    fi
done <<<"$out"
assert "Output is non-empty (commits exist)" "$any"
assert "Every output line is valid JSON" "$ALL_JSON"

# --- Required fields present ---
first="$(echo "$out" | head -1)"
for field in sha type scope breaking track_id subject author timestamp files_changed; do
    if echo "$first" | grep -q "\"$field\""; then
        assert "First record has '$field'" "true"
    else
        assert "First record has '$field'" "false"
    fi
done

# --- SHA is 40 hex ---
if echo "$first" | grep -qE '"sha":"[0-9a-f]{40}"'; then
    assert "sha is a 40-char hex" "true"
else
    assert "sha is a 40-char hex" "false"
fi

# --- Fixture repo with conventional + plain commits ---
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
(
    cd "$FIXTURE"
    git init -q
    git config user.email "t@t.test"
    git config user.name "Tester"
    echo "a" > a.txt; git add a.txt
    GIT_AUTHOR_DATE="2026-01-01T10:00:00" GIT_COMMITTER_DATE="2026-01-01T10:00:00" \
        git commit -q -m "feat(auth): add login handler"
    echo "b" > b.txt; git add b.txt
    GIT_AUTHOR_DATE="2026-01-02T10:00:00" GIT_COMMITTER_DATE="2026-01-02T10:00:00" \
        git commit -q -m "fix!: drop legacy endpoint"
    echo "c" > c.txt; git add c.txt
    GIT_AUTHOR_DATE="2026-01-03T10:00:00" GIT_COMMITTER_DATE="2026-01-03T10:00:00" \
        git commit -q -m "docs: plain subject no type parens"
    echo "d" > d.txt; git add d.txt
    GIT_AUTHOR_DATE="2026-01-04T10:00:00" GIT_COMMITTER_DATE="2026-01-04T10:00:00" \
        git commit -q -m "fix(api): closes [DRAFT-42] leak"
)

fout="$(cd "$FIXTURE" && "$TOOL")"

if echo "$fout" | grep -q '"type":"feat","scope":"auth"'; then
    assert "Parses feat(auth)" "true"
else
    assert "Parses feat(auth)" "false"
fi

if echo "$fout" | grep -qE '"type":"fix".*"breaking":true'; then
    assert "Detects breaking change (!) marker" "true"
else
    assert "Detects breaking change (!) marker" "false"
fi

if echo "$fout" | grep -qE '"type":"docs","scope":null'; then
    assert "Scopeless commit has null scope" "true"
else
    assert "Scopeless commit has null scope" "false"
fi

if echo "$fout" | grep -q '"track_id":"DRAFT-42"'; then
    assert "Extracts [DRAFT-42] token as track_id" "true"
else
    assert "Extracts [DRAFT-42] token as track_id" "false"
fi

# --- a failing git log must not look like "no commits" ---
# The stream used to run inside a process substitution, which swallowed git's
# exit status: a bad ref produced empty JSONL and exit 0.
set +e
bad_out="$("$TOOL" --branch definitely-not-a-ref-xyz 2>/dev/null)"
bad_rc=$?
set -e
assert "unknown --branch → non-zero exit" "$([[ "$bad_rc" != "0" ]] && echo true || echo false)"
assert "unknown --branch emits no records" "$([[ -z "$bad_out" ]] && echo true || echo false)"

set +e
"$TOOL" --limit not-a-number >/dev/null 2>&1
bad_limit_rc=$?
set -e
assert "non-numeric --limit → non-zero exit" \
    "$([[ "$bad_limit_rc" != "0" ]] && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
