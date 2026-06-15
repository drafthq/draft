#!/usr/bin/env bash
# Test suite for scripts/tools/graph-traces.sh (ingest_traces, experimental)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/graph-traces.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== graph-traces.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
TRACE="$FIXTURE/traces.json"
echo '[{"caller":"a","callee":"b"}]' > "$TRACE"

# --- Invocation error: missing action ---
set +e
"$TOOL" --repo "$FIXTURE" --file "$TRACE" --experimental >/dev/null 2>&1; rc=$?
set -e
assert "Missing 'ingest' action → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --- Invocation error: missing --experimental (write-path gate) ---
set +e
"$TOOL" ingest --repo "$FIXTURE" --file "$TRACE" >/dev/null 2>&1; rc=$?
set -e
assert "Missing --experimental → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --- Invocation error: missing file ---
set +e
"$TOOL" ingest --repo "$FIXTURE" --file "$FIXTURE/nope.json" --experimental >/dev/null 2>&1; rc=$?
set -e
assert "Nonexistent --file → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --- Fallback: engine disabled ---
set +e
out="$(DRAFT_MEMORY_DISABLE=1 "$TOOL" ingest --repo "$FIXTURE" --file "$TRACE" --experimental)"
rc=$?
set -e
assert "Exit 2 when engine unavailable" "$([[ "$rc" == "2" ]] && echo true || echo false)"
if command -v jq >/dev/null 2>&1; then
    assert "Fallback emits source:unavailable" \
        "$(echo "$out" | jq -e '.source == "unavailable"' >/dev/null 2>&1 && echo true || echo false)"

    # --- Happy path via mock engine ---
    MOCK="$(make_mock_memory_engine "$FIXTURE/mockbin")"
    out2="$(DRAFT_MEMORY_BIN="$MOCK" "$TOOL" ingest --repo "$FIXTURE" --file "$TRACE" --experimental)"
    assert "Mock yields engine status verbatim" \
        "$(echo "$out2" | jq -e '.status == "accepted"' >/dev/null 2>&1 && echo true || echo false)"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
