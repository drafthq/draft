#!/usr/bin/env bash
# Cargo workspace discovery for okf-plan-concepts.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/okf-plan-concepts.sh"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== okf-plan-concepts cargo workspace tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
REPO="$FIXTURE/repo"
mkdir -p "$REPO/crates/alpha/src" "$REPO/crates/beta/src" "$REPO/third_party/noise"
cat > "$REPO/Cargo.toml" <<'EOF'
[workspace]
members = [
    "crates/alpha",
    "crates/beta",
]
resolver = "2"
EOF
echo 'fn main(){}' > "$REPO/crates/alpha/src/lib.rs"
echo 'fn main(){}' > "$REPO/crates/beta/src/lib.rs"
cat > "$REPO/crates/alpha/Cargo.toml" <<'EOF'
[package]
name = "alpha"
version = "0.1.0"
edition = "2021"
EOF
cat > "$REPO/crates/beta/Cargo.toml" <<'EOF'
[package]
name = "beta"
version = "0.1.0"
edition = "2021"
EOF

run() { set +e; OUT="$("$@" 2>/dev/null)"; RC=$?; set -e; }

run env DRAFT_MEMORY_DISABLE=1 "$TOOL" --repo "$REPO"
assert "Cargo workspace → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"
assert "source includes cargo" \
    "$(echo "$OUT" | jq -e '.source|tostring|contains("cargo")' >/dev/null && echo true || echo false)"
assert "required includes alpha" \
    "$(echo "$OUT" | jq -e '[.expected[].concept_id]|index("systems/alpha.md")' >/dev/null && echo true || echo false)"
assert "required includes beta" \
    "$(echo "$OUT" | jq -e '[.expected[].concept_id]|index("systems/beta.md")' >/dev/null && echo true || echo false)"
assert "at least 2 required" \
    "$(echo "$OUT" | jq -e '.counts.required>=2' >/dev/null && echo true || echo false)"
assert "discovery lists cargo" \
    "$(echo "$OUT" | jq -e '.discovery|index("cargo")' >/dev/null && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
