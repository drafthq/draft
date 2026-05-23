#!/usr/bin/env bash
# Test suite for scripts/tools/diff-templates-vs-tracks.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/diff-templates-vs-tracks.sh"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== diff-templates-vs-tracks.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# Empty track-list → only template self-check; pass when all templates present.
set +e
"$TOOL" "$FIXTURE/no-such-track" >/dev/null 2>&1
rc=$?
set -e
assert "Non-existent track dir → exit 1 (drift recorded)" \
    "$([[ "$rc" == "1" ]] && echo true || echo false)"

# Removed-field detection.
mkdir -p "$FIXTURE/tracks/legacy"
cat > "$FIXTURE/tracks/legacy/spec.md" <<'EOF'
# Spec
Author1 wrote this. xxx@example.com
EOF
set +e
out="$("$TOOL" "$FIXTURE/tracks/legacy" 2>&1)"
set -e
echo "$out" | grep -q "removed-field" && match=1 || match=0
assert "Detects Author1 + xxx@example.com as removed-field" \
    "$([[ "$match" == "1" ]] && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
