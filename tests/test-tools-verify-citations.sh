#!/usr/bin/env bash
# Test suite for scripts/tools/verify-citations.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/verify-citations.sh"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== verify-citations.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# Build a tiny git repo at the fixture root so citations resolve.
git init -q "$FIXTURE/repo" >/dev/null
cd "$FIXTURE/repo"
git config user.email "test@example.com"
git config user.name "Test"
mkdir -p src
printf 'line-1\nline-2\nline-3\nline-4\nline-5\n' > src/a.py
git add . >/dev/null
git commit -q -m initial >/dev/null
COMMIT="$(git rev-parse HEAD)"
cd - >/dev/null

# --- In-range citation ---
mkdir -p "$FIXTURE/repo/tracks/ok"
cat > "$FIXTURE/repo/tracks/ok/metadata.json" <<EOF
{ "id": "ok", "synced_to_commit": "$COMMIT" }
EOF
cat > "$FIXTURE/repo/tracks/ok/spec.md" <<'EOF'
# Spec
See src/a.py:2 for context.
EOF
set +e
"$TOOL" "$FIXTURE/repo/tracks/ok" >/dev/null 2>&1
rc=$?
set -e
assert "In-range citation → exit 0" "$([[ "$rc" == "0" ]] && echo true || echo false)"

# --- Past-EOF citation ---
mkdir -p "$FIXTURE/repo/tracks/bad"
cat > "$FIXTURE/repo/tracks/bad/metadata.json" <<EOF
{ "id": "bad", "synced_to_commit": "$COMMIT" }
EOF
cat > "$FIXTURE/repo/tracks/bad/spec.md" <<'EOF'
# Spec
See src/a.py:200 for context.
EOF
set +e
"$TOOL" "$FIXTURE/repo/tracks/bad" >/dev/null 2>&1
rc=$?
set -e
assert "Past-EOF citation → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --- Missing file at commit ---
mkdir -p "$FIXTURE/repo/tracks/missing"
cat > "$FIXTURE/repo/tracks/missing/metadata.json" <<EOF
{ "id": "missing", "synced_to_commit": "$COMMIT" }
EOF
cat > "$FIXTURE/repo/tracks/missing/spec.md" <<'EOF'
# Spec
See src/never_existed.py:1 for context.
EOF
set +e
"$TOOL" "$FIXTURE/repo/tracks/missing" >/dev/null 2>&1
rc=$?
set -e
assert "Missing-file citation → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --- VERIFIER:IGNORE block skipped ---
mkdir -p "$FIXTURE/repo/tracks/ignored"
cat > "$FIXTURE/repo/tracks/ignored/metadata.json" <<EOF
{ "id": "ignored", "synced_to_commit": "$COMMIT" }
EOF
cat > "$FIXTURE/repo/tracks/ignored/spec.md" <<'EOF'
# Spec
<!-- VERIFIER:IGNORE START -->
See src/a.py:9999 for context.
<!-- VERIFIER:IGNORE END -->
EOF
set +e
"$TOOL" "$FIXTURE/repo/tracks/ignored" >/dev/null 2>&1
rc=$?
set -e
assert "VERIFIER:IGNORE block skipped → exit 0" "$([[ "$rc" == "0" ]] && echo true || echo false)"

# --- Bare-basename citation resolves via tree lookup ---
mkdir -p "$FIXTURE/repo/tracks/basename"
cat > "$FIXTURE/repo/tracks/basename/metadata.json" <<EOF
{ "id": "basename", "synced_to_commit": "$COMMIT" }
EOF
# The citation is just `a.py:1` with no path — the verifier should walk
# the tree and accept it because exactly one file has that basename.
cat > "$FIXTURE/repo/tracks/basename/spec.md" <<'EOF'
# Spec
See a.py:1 for context.
EOF
set +e
"$TOOL" "$FIXTURE/repo/tracks/basename" >/dev/null 2>&1
rc=$?
set -e
assert "Bare-basename citation resolves → exit 0" \
    "$([[ "$rc" == "0" ]] && echo true || echo false)"

# --- (planned) annotation skipped ---
mkdir -p "$FIXTURE/repo/tracks/planned"
cat > "$FIXTURE/repo/tracks/planned/metadata.json" <<EOF
{ "id": "planned", "synced_to_commit": "$COMMIT" }
EOF
cat > "$FIXTURE/repo/tracks/planned/spec.md" <<'EOF'
# Spec
New file src/not_yet.py:1 (planned).
EOF
set +e
"$TOOL" "$FIXTURE/repo/tracks/planned" >/dev/null 2>&1
rc=$?
set -e
assert "(planned) annotation skipped → exit 0" "$([[ "$rc" == "0" ]] && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
