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

# --- Data-loss regression guard (macOS/BSD sed) ---
# The old normalisation used a GNU-only construct
# (`sed -e :a -e '/^\n*$/{$d;N;ba}'`) that errors on BSD sed (macOS) and emits
# empty output, causing the file to be overwritten with a single newline byte.
# On GNU sed these assertions were already green; on BSD sed they FAIL against
# the old code and PASS against the portable-awk fix.
RICH="$FIXTURE/rich.md"
printf '# Title   \nbody\t\n\n\n\n' > "$RICH"   # trailing WS + trailing blank lines
run "$RICH"
assert "content file not truncated (>1 byte)" \
    "$([[ "$(wc -c < "$RICH" | tr -d ' ')" -gt 1 ]] && echo true || echo false)"
assert "title line preserved" \
    "$(grep -qx '# Title' "$RICH" && echo true || echo false)"
assert "body line preserved" \
    "$(grep -qx 'body' "$RICH" && echo true || echo false)"
assert "trailing blank lines dropped (no 0a0a tail)" \
    "$([[ "$(tail -c 2 "$RICH" | od -An -tx1 | tr -d ' \n')" != "0a0a" ]] && echo true || echo false)"
assert "ends with exactly one newline" \
    "$([[ "$(tail -c 1 "$RICH" | od -An -tx1 | tr -d ' \n')" == "0a" ]] && echo true || echo false)"

# --- Interior blank lines are preserved (only trailing blanks are dropped) ---
INTERIOR="$FIXTURE/interior.md"
printf 'a\n\nb\n' > "$INTERIOR"
run "$INTERIOR"
assert "interior blank line preserved (byte-identical, idempotent)" \
    "$([[ "$(cat "$INTERIOR")" == "$(printf 'a\n\nb')" ]] && echo true || echo false)"

# --- A failing normalisation stage must not truncate the file ---
# Any stage erroring out yields empty output; the guard must refuse the write.
SHIM="$FIXTURE/shim"
mkdir -p "$SHIM"
printf '#!/bin/sh\nexit 1\n' > "$SHIM/awk"
chmod +x "$SHIM/awk"
GUARD="$FIXTURE/guard.md"
printf '# Title   \nbody\n\n' > "$GUARD"
BEFORE="$(cksum < "$GUARD")"
set +e; OUT="$(PATH="$SHIM:$PATH" "$TOOL" "$GUARD" 2>&1)"; RC=$?; set -e
assert "failing stage → exit 2" "$([[ "$RC" == "2" ]] && echo true || echo false)"
assert "failing stage → file untouched" "$([[ "$(cksum < "$GUARD")" == "$BEFORE" ]] && echo true || echo false)"

# --- Large files normalise; the guard must not misfire ---
# grep -q exits at its first match; a pipe feeding it more than the pipe buffer
# took SIGPIPE, which pipefail turned into a false "empty output" refusal.
BIG="$FIXTURE/big.md"
awk 'BEGIN { for (i = 0; i < 200000; i++) print "line   " }' > "$BIG"
run "$BIG"
assert "1 MB file → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"
assert "1 MB file → trailing whitespace stripped" \
    "$(grep -q ' $' "$BIG" && echo false || echo true)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
