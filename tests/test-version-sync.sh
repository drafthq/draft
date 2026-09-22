#!/usr/bin/env bash
# Test suite for version consistency across the repo.
#
# What this tests:
# - Every version-bearing file matches package.json (the single source of truth),
#   including the website's version labels (nav pill, hero REV, book REV)
# - sync-version.sh rewrites all of them, and --stage (the npm version hook)
#   stages exactly those files
#
# This is the guard that catches a hand-edited version slipping out of sync
# (e.g. bumping package.json but forgetting marketplace.json). Read-only —
# run `bash scripts/sync-version.sh` to fix any drift it reports.
#
# Usage:
#   ./tests/test-version-sync.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/test-helpers.sh"
cd "$ROOT_DIR"

echo "=== Version sync tests ==="
echo ""

VERSION="$(node -p "require('./package.json').version")"
echo "## Canonical version (package.json): $VERSION"
echo ""

# Extract the relevant version string from each consumer.
plugin_v="$(node -p "require('./.claude-plugin/plugin.json').version")"
market_v="$(node -p "require('./.claude-plugin/marketplace.json').plugins[0].version")"
cursor_v="$(node -p "require('./.cursor-plugin/plugin.json').version")"

assert ".claude-plugin/plugin.json matches ($plugin_v)"        "$([[ "$plugin_v" == "$VERSION" ]] && echo true || echo false)"
assert ".claude-plugin/marketplace.json matches ($market_v)"   "$([[ "$market_v" == "$VERSION" ]] && echo true || echo false)"
assert ".cursor-plugin/plugin.json matches ($cursor_v)"        "$([[ "$cursor_v" == "$VERSION" ]] && echo true || echo false)"

# Website labels: the nav version pill on every page that has one, the landing
# hero's REV, and the book landing's REV.
LABEL_RE='(class="nav-version[^"]*"[^>]*>v|class="(hero|book)-rev">REV )[0-9][^ <&]*'
site_labels() {  # site_labels <root> -> sorted unique versions across tracked pages
    (cd "$1" && git ls-files -z 'web/*.html' | xargs -0 grep -hoE "$LABEL_RE" | sed -E 's/.*(>v|REV )//' | sort -u)
}
label_pages="$(git ls-files -z 'web/*.html' | xargs -0 grep -lE "$LABEL_RE" | sort)"
echo ""
echo "## Website version labels ($(echo "$label_pages" | grep -c .) pages)"
site_v="$(site_labels .)"
assert "every site version label matches (${site_v//$'\n'/, })" \
    "$([[ -n "$label_pages" && "$site_v" == "$VERSION" ]] && echo true || echo false)"

echo ""
echo "## sync-version.sh rewrites and stages"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/scripts"
cp scripts/sync-version.sh "$tmp/scripts/"
cp -R package.json .claude-plugin .cursor-plugin web "$tmp/"
git -C "$tmp" init -q
git -C "$tmp" add .
git -C "$tmp" -c user.email=t@t -c user.name=t commit -qm base
node -e 'const f=process.argv[1],p=require(f);p.version="9.9.9";require("fs").writeFileSync(f,JSON.stringify(p,null,2)+"\n")' "$tmp/package.json"
echo "<!-- unrelated edit -->" >> "$tmp/web/sitemap.xml"
# An untracked page is someone's work in progress: never bumped, never staged.
printf '<a href="changelog/" class="nav-version" title="Release notes">v1.0.0</a>\n' > "$tmp/web/wip.html"

bash "$tmp/scripts/sync-version.sh" >/dev/null
assert "a standalone run stages nothing" \
    "$([[ -z "$(git -C "$tmp" diff --cached --name-only)" ]] && echo true || echo false)"
assert "every site label is rewritten" \
    "$([[ "$(site_labels "$tmp")" == "9.9.9" ]] && echo true || echo false)"
assert "every manifest is rewritten" \
    "$([[ "$(cd "$tmp" && node -p "[require('./.claude-plugin/plugin.json').version, require('./.claude-plugin/marketplace.json').plugins[0].version, require('./.cursor-plugin/plugin.json').version].join()")" == "9.9.9,9.9.9,9.9.9" ]] && echo true || echo false)"

bash "$tmp/scripts/sync-version.sh" --stage >/dev/null
expected="$(printf '%s\n' .claude-plugin/marketplace.json .claude-plugin/plugin.json .cursor-plugin/plugin.json $label_pages | sort)"
assert "--stage stages exactly the manifests and labelled pages" \
    "$([[ "$(git -C "$tmp" diff --cached --name-only | sort)" == "$expected" ]] && echo true || echo false)"
assert "an untracked page is left alone" \
    "$(grep -q '>v1.0.0<' "$tmp/web/wip.html" && echo true || echo false)"

finish_test "version sync"
