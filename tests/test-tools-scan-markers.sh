#!/usr/bin/env bash
# Test suite for scripts/tools/scan-markers.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/scan-markers.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== scan-markers.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

(
    cd "$FIXTURE"
    git init -q
    git config user.email "t@t.test"
    git config user.name "Tester"
    cat > app.py <<'PY'
def foo():
    # TODO: handle retry
    return 1

def bar():
    # FIXME: race condition
    pass

def baz():
    # just a normal comment
    pass
PY
    git add app.py
    GIT_AUTHOR_DATE="2026-01-01T10:00:00" GIT_COMMITTER_DATE="2026-01-01T10:00:00" \
        git commit -q -m "seed"
)

out="$("$TOOL" --root "$FIXTURE")"

# Valid JSON
if command -v jq >/dev/null 2>&1; then
    if echo "$out" | jq . >/dev/null 2>&1; then
        assert "Output is valid JSON" "true"
    else
        assert "Output is valid JSON" "false"
    fi
fi

# Contains TODO and FIXME
if echo "$out" | grep -q '"marker":"TODO"'; then
    assert "Detects TODO marker" "true"
else
    assert "Detects TODO marker" "false"
fi

if echo "$out" | grep -q '"marker":"FIXME"'; then
    assert "Detects FIXME marker" "true"
else
    assert "Detects FIXME marker" "false"
fi

# Non-marker comment is NOT emitted
if echo "$out" | grep -q 'just a normal comment'; then
    assert "Plain comment not emitted" "false"
else
    assert "Plain comment not emitted" "true"
fi

# Blame info is present (sha non-null)
if echo "$out" | grep -qE '"sha":"[0-9a-f]{7}"'; then
    assert "Emits 7-char blame sha" "true"
else
    assert "Emits 7-char blame sha" "false"
fi

# Path containing a colon still parses as one path + a numeric line.
(
    cd "$FIXTURE"
    mkdir -p src
    printf 'function x() {\n    // TODO: colon path\n}\n' > "src/foo:bar.js"
    git add "src/foo:bar.js"
    git commit -q -m "colon path"
)
colon_out="$("$TOOL" --root "$FIXTURE")"
assert "colon in path still emits valid JSON" \
    "$(echo "$colon_out" | jq . >/dev/null 2>&1 && echo true || echo false)"
assert "colon in path is kept in the path field" \
    "$(echo "$colon_out" | jq -e '.[] | select(.path | test("foo:bar"))' >/dev/null 2>&1 && echo true || echo false)"

# age_days is a non-negative integer
if echo "$out" | grep -qE '"age_days":[0-9]+'; then
    assert "age_days is non-negative integer" "true"
else
    assert "age_days is non-negative integer" "false"
fi

# --markers filter suppresses FIXME
todo_only="$("$TOOL" --root "$FIXTURE" --markers TODO)"
if echo "$todo_only" | grep -q '"marker":"FIXME"'; then
    assert "--markers TODO excludes FIXME" "false"
else
    assert "--markers TODO excludes FIXME" "true"
fi

# --min-age-days filter: far in future excludes all
future="$("$TOOL" --root "$FIXTURE" --min-age-days 99999)"
if [[ "$(echo "$future" | tr -d '[:space:]')" == "[]" ]]; then
    assert "--min-age-days huge value emits empty array" "true"
else
    assert "--min-age-days huge value emits empty array" "false"
fi

# Non-git directory exits 2 with []
NONGIT="$(mktemp -d)"
trap 'rm -rf "$FIXTURE" "$NONGIT"' EXIT
set +e
ng_out="$("$TOOL" --root "$NONGIT")"
rc=$?
set -e
if [[ "$rc" == "2" && "$(echo "$ng_out" | tr -d '[:space:]')" == "[]" ]]; then
    assert "Non-git dir exits 2 and emits []" "true"
else
    assert "Non-git dir exits 2 and emits []" "false"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
