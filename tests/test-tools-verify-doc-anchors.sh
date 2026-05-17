#!/usr/bin/env bash
# Test suite for scripts/tools/verify-doc-anchors.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/verify-doc-anchors.sh"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== verify-doc-anchors.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# --- Valid §-reference and #-anchor ---
mkdir -p "$FIXTURE/tracks/ok"
cat > "$FIXTURE/tracks/ok/spec.md" <<'EOF'
# Spec
See [hld.md §3.1](./hld.md#detailed-design) for details.
EOF
cat > "$FIXTURE/tracks/ok/hld.md" <<'EOF'
# HLD

## 3.1 First subsection

## Detailed Design
EOF
set +e
"$TOOL" "$FIXTURE/tracks/ok" >/dev/null 2>&1
rc=$?
set -e
assert "Valid §3.1 + #detailed-design → exit 0" "$([[ "$rc" == "0" ]] && echo true || echo false)"

# --- Plain prose §-ref is intentionally NOT validated ---
# Plain-prose §X.Y is too ambiguous (commonly used as shorthand for external
# docs like `architecture.md §20.2`). The verifier only checks anchored
# markdown links, so a plain prose §-ref must NOT cause a violation.
mkdir -p "$FIXTURE/tracks/plain-section"
cat > "$FIXTURE/tracks/plain-section/spec.md" <<'EOF'
# Spec
The §99.9 layout matches our needs.
EOF
cat > "$FIXTURE/tracks/plain-section/hld.md" <<'EOF'
# HLD
## 1 Intro
EOF
set +e
"$TOOL" "$FIXTURE/tracks/plain-section" >/dev/null 2>&1
rc=$?
set -e
assert "Plain prose §99.9 → not validated, exit 0" \
    "$([[ "$rc" == "0" ]] && echo true || echo false)"

# --- Bad #-anchor ---
mkdir -p "$FIXTURE/tracks/bad-anchor"
cat > "$FIXTURE/tracks/bad-anchor/spec.md" <<'EOF'
# Spec
See [HLD](./hld.md#not-a-real-section).
EOF
cat > "$FIXTURE/tracks/bad-anchor/hld.md" <<'EOF'
# HLD
## Real Section
EOF
set +e
"$TOOL" "$FIXTURE/tracks/bad-anchor" >/dev/null 2>&1
rc=$?
set -e
assert "Missing #anchor → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --- §-ref on a line that names an external file is skipped ---
mkdir -p "$FIXTURE/tracks/external-sec"
cat > "$FIXTURE/tracks/external-sec/spec.md" <<'EOF'
# Spec
See `architecture.md` §20.2 for the upstream decomposition.
EOF
# Only spec.md is a sibling; architecture.md is external. §20.2 must be
# skipped because it points into architecture.md, not this track.
set +e
"$TOOL" "$FIXTURE/tracks/external-sec" >/dev/null 2>&1
rc=$?
set -e
assert "External-file §-ref → skipped, exit 0" \
    "$([[ "$rc" == "0" ]] && echo true || echo false)"

# --- (planned) file that actually exists is a violation ---
mkdir -p "$FIXTURE/tracks/false-planned"
cat > "$FIXTURE/tracks/false-planned/spec.md" <<'EOF'
# Spec
config.yaml (planned).
EOF
cat > "$FIXTURE/tracks/false-planned/config.yaml" <<'EOF'
key: value
EOF
set +e
"$TOOL" "$FIXTURE/tracks/false-planned" >/dev/null 2>&1
rc=$?
set -e
assert "(planned) file exists locally → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
