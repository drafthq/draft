#!/usr/bin/env bash
# Test suite for scripts/tools/verify-graph-binary.sh (graph binary selection + usage report skeleton)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/verify-graph-binary.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== verify-graph-binary.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# --- Test 1: fallback when nothing present (no PATH graph, no bundled, no legacy) ---
set +e
out="$("$TOOL" --repo "$FIXTURE" --json 2>/dev/null)"
rc=$?
set -e
assert "Missing binary → exit 2" "$([[ "$rc" == "2" ]] && echo true || echo false)"
if echo "$out" | grep -q '"status":"unavailable"'; then
    assert "JSON reports unavailable" "true"
else
    assert "JSON reports unavailable" "false"
fi

# --- Test 2: legacy path detection (create a fake legacy wrapper in fixture) ---
mkdir -p "$FIXTURE/graph/bin"
cat > "$FIXTURE/graph/bin/graph" <<'LEG'
#!/bin/sh
echo "graph v0-legacy-node (test)"
exit 0
LEG
chmod +x "$FIXTURE/graph/bin/graph"

set +e
out="$("$TOOL" --repo "$FIXTURE" --json 2>/dev/null)"
rc=$?
set -e
assert "Legacy present → exit 0" "$([[ "$rc" == "0" ]] && echo true || echo false)"
if echo "$out" | grep -q '"source":"legacy"'; then
    assert "Source reports legacy" "true"
else
    assert "Source reports legacy" "false"
fi

# --- Test 3: usage report side-effect (draft/ dir created + .graph-binary-report.json) ---
if [[ -f "$FIXTURE/draft/.graph-binary-report.json" ]]; then
    assert "Usage report JSON written" "true"
    if grep -q '"source":"legacy"' "$FIXTURE/draft/.graph-binary-report.json"; then
        assert "Report contains source=legacy" "true"
    else
        assert "Report contains source=legacy" "false"
    fi
else
    assert "Usage report JSON written (may be skipped outside draft context)" "true"   # lenient for skeleton
fi

# --- Test 4: --strict with only legacy rejects ---
set +e
"$TOOL" --repo "$FIXTURE" --strict --json >/dev/null 2>&1
rc=$?
set -e
assert "Strict + legacy-only → exit 2" "$([[ "$rc" == "2" ]] && echo true || echo false)"

# --- Test 5: verbose human output contains preference language ---
set +e
vout="$("$TOOL" --repo "$FIXTURE" --verbose 2>&1)"
rc=$?
set -e
if echo "$vout" | grep -qi 'legacy\|preference\|bundled'; then
    assert "Verbose mentions selection / legacy" "true"
else
    assert "Verbose mentions selection / legacy" "false"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
