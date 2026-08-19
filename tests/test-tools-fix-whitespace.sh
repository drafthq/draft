#!/usr/bin/env bash
# Test suite for scripts/tools/fix-whitespace.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/fix-whitespace.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== fix-whitespace.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

run() { set +e; OUT="$("$TOOL" "$@" 2>&1)"; RC=$?; set -e; }

# --- Idempotency: an already-clean file must NOT be reported/rewritten ---
CLEAN="$FIXTURE/clean.md"
printf 'line one\nline two\n' > "$CLEAN"
BEFORE="$(cksum < "$CLEAN")"
run "$CLEAN"
AFTER="$(cksum < "$CLEAN")"
assert "clean file → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"
assert "clean file NOT reported as normalised (idempotent)" \
    "$(echo "$OUT" | grep -q 'normalised' && echo false || echo true)"
assert "clean file unchanged on disk" "$([[ "$BEFORE" == "$AFTER" ]] && echo true || echo false)"

# --- Dirty file: trailing whitespace + trailing blank lines are fixed ---
DIRTY="$FIXTURE/dirty.md"
printf 'trailing ws   \nbody\n\n\n' > "$DIRTY"
run "$DIRTY"
assert "dirty file reported as normalised" \
    "$(echo "$OUT" | grep -q 'normalised' && echo true || echo false)"
assert "dirty file content normalised to expected bytes" \
    "$([[ "$(cat "$DIRTY")" == "$(printf 'trailing ws\nbody')" ]] && echo true || echo false)"

# --- Second pass over the now-clean file is idempotent ---
BEFORE2="$(cksum < "$DIRTY")"
run "$DIRTY"
AFTER2="$(cksum < "$DIRTY")"
assert "second pass NOT reported as normalised" \
    "$(echo "$OUT" | grep -q 'normalised' && echo false || echo true)"
assert "second pass leaves file byte-identical" "$([[ "$BEFORE2" == "$AFTER2" ]] && echo true || echo false)"

# --- Empty file: must not be corrupted with a spurious newline ---
EMPTY="$FIXTURE/empty.md"
: > "$EMPTY"
run "$EMPTY"
assert "empty file NOT reported as normalised" \
    "$(echo "$OUT" | grep -q 'normalised' && echo false || echo true)"
assert "empty file stays empty" "$([[ ! -s "$EMPTY" ]] && echo true || echo false)"

# --- Missing final newline IS a real fix (exactly one newline added) ---
NONL="$FIXTURE/nonl.md"
printf 'no newline' > "$NONL"
run "$NONL"
assert "missing final newline added" \
    "$([[ "$(cat "$NONL")" == "no newline" && "$(wc -c < "$NONL" | tr -d ' ')" == "11" ]] && echo true || echo false)"

# --- The rewrite must not change the file's permissions ---
# mktemp creates 0600 and `mv` swaps the inode, so the normaliser used to hand
# back a 0600 file no matter what it was given.
PERM="$FIXTURE/perm.md"
printf 'trailing   \n\n\n' > "$PERM"
chmod 644 "$PERM"
run "$PERM"
MODE="$(stat -c '%a' "$PERM" 2>/dev/null || stat -f '%Lp' "$PERM" 2>/dev/null)"
assert "normalising a 0644 file leaves it 0644" "$([[ "$MODE" == "644" ]] && echo true || echo false)"

PERM6="$FIXTURE/perm600.md"
printf 'trailing   \n\n\n' > "$PERM6"
chmod 600 "$PERM6"
run "$PERM6"
MODE6="$(stat -c '%a' "$PERM6" 2>/dev/null || stat -f '%Lp' "$PERM6" 2>/dev/null)"
assert "a deliberately 0600 file stays 0600" "$([[ "$MODE6" == "600" ]] && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
