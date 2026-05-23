#!/usr/bin/env bash
# Test suite for scripts/tools/check-track-hygiene.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/check-track-hygiene.sh"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== check-track-hygiene.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# --- Clean track ---
mkdir -p "$FIXTURE/tracks/clean"
cat > "$FIXTURE/tracks/clean/metadata.json" <<'EOF'
{ "id": "clean", "title": "Clean", "status": "draft", "template_version": "2.0.0" }
EOF
cat > "$FIXTURE/tracks/clean/spec.md" <<'EOF'
---
project: t
track_id: clean
---
# Spec
A clean track with no forbidden placeholders.
EOF

set +e
"$TOOL" "$FIXTURE/tracks/clean" >/dev/null 2>&1
rc=$?
set -e
assert "Clean track → exit 0" "$([[ "$rc" == "0" ]] && echo true || echo false)"

# --- Forbidden author placeholder ---
mkdir -p "$FIXTURE/tracks/dirty-author"
cat > "$FIXTURE/tracks/dirty-author/metadata.json" <<'EOF'
{ "id": "dirty-author", "status": "draft" }
EOF
cat > "$FIXTURE/tracks/dirty-author/hld.md" <<'EOF'
# HLD
**Author1** (xxx@example.com)
EOF
set +e
"$TOOL" "$FIXTURE/tracks/dirty-author" >/dev/null 2>&1
rc=$?
set -e
assert "Author1 + xxx@example.com → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --- Status mismatch ---
mkdir -p "$FIXTURE/tracks/status-mismatch"
cat > "$FIXTURE/tracks/status-mismatch/metadata.json" <<'EOF'
{ "id": "status-mismatch", "status": "draft" }
EOF
cat > "$FIXTURE/tracks/status-mismatch/spec.md" <<'EOF'
# Spec
**Status:** [x] Complete
EOF
set +e
"$TOOL" "$FIXTURE/tracks/status-mismatch" >/dev/null 2>&1
rc=$?
set -e
assert "metadata.draft vs doc Complete → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --- TBD cap exceeded at ready-for-review ---
mkdir -p "$FIXTURE/tracks/over-cap"
cat > "$FIXTURE/tracks/over-cap/metadata.json" <<'EOF'
{ "id": "over-cap", "status": "ready-for-review" }
EOF
cat > "$FIXTURE/tracks/over-cap/spec.md" <<'EOF'
# Spec
- _TBD_a_ _TBD_b_ _TBD_c_ _TBD_d_ _TBD_e_
EOF
set +e
"$TOOL" "$FIXTURE/tracks/over-cap" >/dev/null 2>&1
rc=$?
set -e
assert "5 TBDs at ready-for-review (cap 3) → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --- JSON mode ---
output="$("$TOOL" --json "$FIXTURE/tracks/clean" 2>&1)"
assert "JSON mode emits violation_count key" \
    "$(echo "$output" | grep -q '"violation_count"' && echo true || echo false)"
