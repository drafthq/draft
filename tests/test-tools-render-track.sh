#!/usr/bin/env bash
# Test suite for scripts/tools/render-track.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/render-track.sh"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== render-track.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

mkdir -p "$FIXTURE/tracks/example"
cat > "$FIXTURE/tracks/example/spec.md" <<'EOF'
# Spec
Hello world.
EOF
cat > "$FIXTURE/tracks/example/plan.md" <<'EOF'
# Plan
Phase 1 — bootstrap.
EOF

# --- --stdout produces a non-empty HTML document ---
set +e
output="$("$TOOL" "$FIXTURE/tracks/example" --stdout 2>/dev/null)"
rc=$?
set -e
assert "--stdout → exit 0" "$([[ "$rc" == "0" ]] && echo true || echo false)"
assert "--stdout produces HTML doctype" \
    "$(echo "$output" | grep -q "<!doctype" && echo true || echo false)"
assert "--stdout includes spec.md content" \
    "$(echo "$output" | grep -q "Hello world" && echo true || echo false)"

# --- Default output writes a file ---
"$TOOL" "$FIXTURE/tracks/example" >/dev/null 2>&1
assert "Default output writes track-reader.html" \
    "$([[ -f "$FIXTURE/tracks/example/track-reader.html" ]] && echo true || echo false)"

# --- Custom --out ---
"$TOOL" "$FIXTURE/tracks/example" --out "$FIXTURE/custom.html" >/dev/null 2>&1
assert "--out custom path written" \
    "$([[ -f "$FIXTURE/custom.html" ]] && echo true || echo false)"

# --- Bad input directory ---
set +e
"$TOOL" "$FIXTURE/does-not-exist" >/dev/null 2>&1
rc=$?
set -e
assert "Missing dir → exit 2" "$([[ "$rc" == "2" ]] && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
