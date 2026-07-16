#!/usr/bin/env bash
# Test suite for scripts/tools/emit-skill-metrics.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/emit-skill-metrics.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== emit-skill-metrics.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
METRICS="$FIXTURE/.draft/metrics.jsonl"

# The tool writes under $HOME — point HOME at the fixture.
run() { set +e; OUT="$(HOME="$FIXTURE" "$TOOL" "$@" 2>&1)"; RC=$?; set -e; }

# --- Happy path: record appended with injected ts ---
run '{"skill":"review","verdict":"approve"}'
assert "valid payload → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"
assert "metrics file created" "$([[ -f "$METRICS" ]] && echo true || echo false)"
assert "record is valid JSON with ts field" \
    "$(tail -1 "$METRICS" | jq -e '.skill == "review" and (.ts | length > 0)' >/dev/null 2>&1 && echo true || echo false)"

# --- Regression: trailing newline in the payload must not corrupt NDJSON ---
run $'{"skill":"decompose"}\n'
assert "trailing-newline payload → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"
assert "trailing-newline record still one valid JSON line" \
    "$(tail -1 "$METRICS" | jq -e '.skill == "decompose" and (.ts | length > 0)' >/dev/null 2>&1 && echo true || echo false)"
assert "every line in metrics file parses as JSON" \
    "$(jq -es 'length >= 2' "$METRICS" >/dev/null 2>&1 && echo true || echo false)"

# --- Non-object payload (no closing brace) is dropped, never corrupts ---
LINES_BEFORE="$(wc -l < "$METRICS" | tr -d ' ')"
run 'not-json-at-all'
LINES_AFTER="$(wc -l < "$METRICS" | tr -d ' ')"
assert "garbage payload → exit 0 (never fails caller)" "$([[ "$RC" == "0" ]] && echo true || echo false)"
assert "garbage payload writes nothing" "$([[ "$LINES_BEFORE" == "$LINES_AFTER" ]] && echo true || echo false)"

# --- Empty / missing payload is a silent no-op ---
run ''
assert "empty payload → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"
run
assert "no argument → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"

# --- Help exits 0 ---
run --help
assert "--help → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
