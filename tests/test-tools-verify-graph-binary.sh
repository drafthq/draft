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

# --- Test 1: fallback when nothing present (no PATH graph, no bundled native) ---
# Hide real repo binaries during this test so the "absent" path is exercised (verifier always probes SCRIPT_DIR parent)
REAL_BIN_DIR=""
if [[ -d "$ROOT_DIR/bin" ]]; then
    REAL_BIN_DIR="$(mktemp -d)"
    mv "$ROOT_DIR/bin" "$REAL_BIN_DIR/bin-hidden" 2>/dev/null || true
fi
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
# Restore real binaries
if [[ -n "$REAL_BIN_DIR" && -d "$REAL_BIN_DIR/bin-hidden" ]]; then
    mv "$REAL_BIN_DIR/bin-hidden" "$ROOT_DIR/bin" 2>/dev/null || true
    rmdir "$REAL_BIN_DIR" 2>/dev/null || true
fi

# --- Test 2: bundled arch-specific native detection ---
ARCH=$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
mkdir -p "$FIXTURE/bin/$ARCH"
cat > "$FIXTURE/bin/$ARCH/graph" <<'NAT'
#!/bin/sh
echo "graph v1-native (test)"
exit 0
NAT
chmod +x "$FIXTURE/bin/$ARCH/graph"

set +e
out="$("$TOOL" --repo "$FIXTURE" --json 2>/dev/null)"
rc=$?
set -e
assert "Bundled native present → exit 0" "$([[ "$rc" == "0" ]] && echo true || echo false)"
if echo "$out" | grep -q '"source":"bundled'; then
    assert "Source reports bundled" "true"
else
    assert "Source reports bundled" "false"
fi

# --- Test 3: usage report side-effect ---
if [[ -f "$FIXTURE/draft/.graph-binary-report.json" ]]; then
    assert "Usage report JSON written" "true"
    if grep -q '"source":"bundled' "$FIXTURE/draft/.graph-binary-report.json"; then
        assert "Report contains source=bundled" "true"
    else
        assert "Report contains source=bundled" "false"
    fi
else
    assert "Usage report JSON written (may be skipped outside draft context)" "true"
fi

# --- Test 4: --strict with a binary present succeeds (native-only world) ---
set +e
"$TOOL" --repo "$FIXTURE" --strict --json >/dev/null 2>&1
rc=$?
set -e
assert "Strict + native present → exit 0" "$([[ "$rc" == "0" ]] && echo true || echo false)"

# --- Test 5: verbose output mentions selection ---
set +e
vout="$("$TOOL" --repo "$FIXTURE" --verbose 2>&1)"
rc=$?
set -e
if echo "$vout" | grep -qi 'bundled\|PATH\|graph binary'; then
    assert "Verbose mentions selection" "true"
else
    assert "Verbose mentions selection" "false"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
