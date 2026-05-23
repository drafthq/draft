#!/usr/bin/env bash
# Test suite for scripts/tools/check-skill-line-caps.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/check-skill-line-caps.sh"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== check-skill-line-caps.sh tests ==="
echo ""

# Warn-only against the current repo: must always exit 0.
set +e
"$TOOL" >/dev/null 2>&1
rc=$?
set -e
assert "Warn-only mode → exit 0 regardless" \
    "$([[ "$rc" == "0" ]] && echo true || echo false)"

# Custom caps config — small global, all skills over → enforce should fail.
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
cat > "$FIXTURE/caps.conf" <<'EOF'
* 1
EOF
set +e
"$TOOL" --enforce --caps "$FIXTURE/caps.conf" >/dev/null 2>&1
rc=$?
set -e
assert "Strict mode with impossible cap → exit 1" \
    "$([[ "$rc" == "1" ]] && echo true || echo false)"

# Custom caps config — huge cap, all skills clean → enforce exits 0.
cat > "$FIXTURE/caps2.conf" <<'EOF'
* 999999
EOF
set +e
"$TOOL" --enforce --caps "$FIXTURE/caps2.conf" >/dev/null 2>&1
rc=$?
set -e
assert "Strict mode with huge cap → exit 0" \
    "$([[ "$rc" == "0" ]] && echo true || echo false)"

# JSON mode emits expected keys.
out="$("$TOOL" --json 2>&1)"
assert "JSON mode emits over_cap_count" \
    "$(echo "$out" | grep -q '"over_cap_count"' && echo true || echo false)"
assert "JSON mode emits global_cap" \
    "$(echo "$out" | grep -q '"global_cap"' && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
