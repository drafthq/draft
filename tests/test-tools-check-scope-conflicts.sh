#!/usr/bin/env bash
# Test suite for scripts/tools/check-scope-conflicts.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/check-scope-conflicts.sh"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== check-scope-conflicts.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# --- Two tracks share tag, no exclusion → conflict ---
mkdir -p "$FIXTURE/tracks/a" "$FIXTURE/tracks/b"
cat > "$FIXTURE/tracks/a/metadata.json" <<'EOF'
{ "id": "a", "scope_includes": ["shuffle"], "scope_excludes": [] }
EOF
cat > "$FIXTURE/tracks/b/metadata.json" <<'EOF'
{ "id": "b", "scope_includes": ["shuffle"], "scope_excludes": [] }
EOF
set +e
"$TOOL" "$FIXTURE/tracks/a" "$FIXTURE/tracks/b" >/dev/null 2>&1
rc=$?
set -e
assert "Shared 'shuffle' tag, no excludes → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --- Two tracks share tag, one excludes the other's discriminator ---
mkdir -p "$FIXTURE/tracks/c" "$FIXTURE/tracks/d"
cat > "$FIXTURE/tracks/c/metadata.json" <<'EOF'
{ "id": "c", "scope_includes": ["shuffle", "record-path"], "scope_excludes": ["sst-path"] }
EOF
cat > "$FIXTURE/tracks/d/metadata.json" <<'EOF'
{ "id": "d", "scope_includes": ["shuffle", "sst-path"], "scope_excludes": ["record-path"] }
EOF
set +e
"$TOOL" "$FIXTURE/tracks/c" "$FIXTURE/tracks/d" >/dev/null 2>&1
rc=$?
set -e
assert "Mutual exclusion satisfied → exit 0" "$([[ "$rc" == "0" ]] && echo true || echo false)"

# --- Single track in isolation → no pair, no conflict ---
mkdir -p "$FIXTURE/tracks/solo"
cat > "$FIXTURE/tracks/solo/metadata.json" <<'EOF'
{ "id": "solo", "scope_includes": ["foo"], "scope_excludes": [] }
EOF
set +e
"$TOOL" "$FIXTURE/tracks/solo" >/dev/null 2>&1
rc=$?
set -e
assert "Single track → exit 0" "$([[ "$rc" == "0" ]] && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
