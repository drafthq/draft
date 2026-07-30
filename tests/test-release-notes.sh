#!/usr/bin/env bash
# Test suite for scripts/release-notes.sh
#
# What this tests:
# - Every git tag has an extractable changelog section (so the Release workflow
#   never publishes a stub)
# - --list / --latest / --version-of-latest agree with the changelog
# - A `v` prefix is tolerated; Unreleased is never treated as a version
# - Leading/trailing blank lines are trimmed and section bodies stop at the
#   next heading
# - Unknown versions exit 1; bad usage exits 2
#
# Usage:
#   ./tests/test-release-notes.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/release-notes.sh"

source "$SCRIPT_DIR/test-helpers.sh"
cd "$ROOT_DIR"

echo "=== release-notes.sh tests ==="
echo ""

assert "script is executable" "$([[ -x "$TOOL" ]] && echo true || echo false)"

echo "## Version listing"
mapfile -t versions < <("$TOOL" --list)
assert "lists at least 8 versions (${#versions[@]})" \
    "$([[ "${#versions[@]}" -ge 8 ]] && echo true || echo false)"
assert "Unreleased is not listed" \
    "$(grep -qi 'unreleased' <<< "${versions[*]}" && echo false || echo true)"

pkg_version="$(node -p "require('./package.json').version")"
assert "newest listed version is package.json's ($pkg_version)" \
    "$([[ "$("$TOOL" --version-of-latest)" == "$pkg_version" ]] && echo true || echo false)"

echo ""
echo "## Section extraction"
latest="$("$TOOL" --latest)"
assert "--latest returns a non-empty body" "$([[ -n "$latest" ]] && echo true || echo false)"
assert "--latest matches the explicit version" \
    "$([[ "$latest" == "$("$TOOL" "$pkg_version")" ]] && echo true || echo false)"
assert "v-prefix is tolerated" \
    "$([[ "$("$TOOL" "v$pkg_version")" == "$latest" ]] && echo true || echo false)"
assert "body does not leak the next version heading" \
    "$(grep -qE '^## \[' <<< "$latest" && echo false || echo true)"
assert "body has no leading blank line" \
    "$([[ -n "$(head -n 1 <<< "$latest")" ]] && echo true || echo false)"
assert "body has no trailing blank line" \
    "$([[ -n "$(tail -n 1 <<< "$latest")" ]] && echo true || echo false)"
assert "--title prepends a release heading" \
    "$(head -n 1 <<< "$("$TOOL" "$pkg_version" --title)" | grep -q "^## Draft v$pkg_version$" && echo true || echo false)"

echo ""
echo "## Every tag resolves to notes"
# This is the guard that matters: the Release workflow reads notes by tag, so a
# tag without a changelog section ships an empty Release.
tag_count=0
while IFS= read -r tag; do
    [[ -n "$tag" ]] || continue
    tag_count=$((tag_count + 1))
    if "$TOOL" "$tag" >/dev/null 2>&1; then
        assert "$tag has changelog notes" "true"
    else
        assert "$tag has changelog notes" "false"
    fi
done < <(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' | sort -V)
assert "found tags to check ($tag_count)" \
    "$([[ "$tag_count" -gt 0 ]] && echo true || echo false)"

echo ""
echo "## Synthetic changelog"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/CHANGELOG.md" <<'EOF'
# Changelog

## [Unreleased]

## [2.0.0] - 2026-01-02

### Added
- second thing

## [1.0.0] - 2026-01-01

### Added
- first thing

## [0.9.0] - 2025-12-31
EOF

assert "synthetic newest is 2.0.0" \
    "$([[ "$("$TOOL" --file "$tmp/CHANGELOG.md" --version-of-latest)" == "2.0.0" ]] && echo true || echo false)"
assert "synthetic 1.0.0 body is exact" \
    "$([[ "$("$TOOL" --file "$tmp/CHANGELOG.md" 1.0.0)" == "### Added
- first thing" ]] && echo true || echo false)"

set +e
"$TOOL" --file "$tmp/CHANGELOG.md" 0.9.0 >/dev/null 2>&1
empty_rc=$?
"$TOOL" --file "$tmp/CHANGELOG.md" 5.0.0 >/dev/null 2>&1
missing_rc=$?
set -e
assert "empty section exits 1" "$([[ "$empty_rc" -eq 1 ]] && echo true || echo false)"
assert "absent version exits 1" "$([[ "$missing_rc" -eq 1 ]] && echo true || echo false)"

echo ""
echo "## Usage errors exit 2"
for bad in "--bogus" "not-a-version" "1.0" "--file"; do
    set +e
    # shellcheck disable=SC2086  # intentional word splitting
    "$TOOL" $bad >/dev/null 2>&1
    rc=$?
    set -e
    assert "'$bad' exits 2" "$([[ "$rc" -eq 2 ]] && echo true || echo false)"
done

set +e
"$TOOL" 1.0.0 2.0.0 >/dev/null 2>&1
rc=$?
set -e
assert "two versions exits 2" "$([[ "$rc" -eq 2 ]] && echo true || echo false)"

set +e
"$TOOL" --file /nonexistent/CHANGELOG.md --latest >/dev/null 2>&1
rc=$?
set -e
assert "missing changelog exits 2" "$([[ "$rc" -eq 2 ]] && echo true || echo false)"

finish_test "release-notes"
