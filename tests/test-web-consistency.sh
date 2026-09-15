#!/usr/bin/env bash
# Test suite for cross-page consistency of the website.
#
# What this tests:
# - Every full page under web/ shares one fonts URL, one theme-color, one
#   social-preview cache-buster, the dark markup default, and one early
#   theme script
# - Pages that render the shared nav load the script that drives it
# - Every internal link and in-page anchor resolves
# - Every shipped script parses
#
# Why: the site is plain HTML deployed straight from web/ on push. Design
# changes are applied to ~40 pages by hand, and a page missed by such a
# sweep ships silently — make test and lint never open an HTML file.
#
# Usage:
#   ./tests/test-web-consistency.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/test-helpers.sh"
cd "$ROOT_DIR"

echo "=== Website consistency tests ==="
echo ""

# Full pages only: web/book/chapters/*.html are content fragments without <html>.
mapfile -t PAGES < <(git ls-files 'web/*.html' | while read -r f; do grep -q '<html' "$f" && echo "$f"; done)
assert "found full pages to scan (${#PAGES[@]})" \
    "$([[ "${#PAGES[@]}" -gt 30 ]] && echo true || echo false)"

echo "## One identity across pages"
for probe in \
    'fonts.googleapis.com/css2?[^"]*|fonts URL' \
    '<meta name="theme-color" content="[^"]*">|theme-color' \
    'social-preview.png?v=[0-9]*|social preview cache-buster' \
    '<html[^>]*>|html element'
do
    pattern="${probe%%|*}"; label="${probe##*|}"
    distinct="$(grep -ho "$pattern" "${PAGES[@]}" | sort -u | wc -l)"
    assert "exactly one $label across pages ($distinct)" \
        "$([[ "$distinct" == "1" ]] && echo true || echo false)"
done
assert "html element declares the dark markup default" \
    "$(grep -l '<html lang="en" data-theme="dark">' "${PAGES[@]}" | wc -l | grep -qx "${#PAGES[@]}" && echo true || echo false)"

echo ""
echo "## Every page carries the early theme script"
missing_theme=0
for page in "${PAGES[@]}"; do
    grep -q "localStorage.getItem('draft-theme')==='light'" "$page" || { missing_theme=$((missing_theme + 1)); echo "   missing: $page"; }
done
assert "early theme script present on every page ($missing_theme missing)" \
    "$([[ "$missing_theme" == "0" ]] && echo true || echo false)"

echo ""
echo "## Fonts are loaded the same way everywhere"
bad_fonts=0
for page in "${PAGES[@]}"; do
    grep -q 'fonts.googleapis.com' "$page" || continue
    grep -q 'rel="preconnect" href="https://fonts.gstatic.com"' "$page" \
        && grep -q 'rel="preload" as="style"' "$page" \
        && grep -q '<noscript>' "$page" \
        || { bad_fonts=$((bad_fonts + 1)); echo "   drift: $page"; }
done
assert "font-loading pages use preconnect + preload + noscript ($bad_fonts drifted)" \
    "$([[ "$bad_fonts" == "0" ]] && echo true || echo false)"

echo ""
echo "## Shared nav is driven on every page that renders it"
no_main=0
for page in "${PAGES[@]}"; do
    grep -q 'id="gh-stars"\|class="nav-toggle"' "$page" || continue
    grep -q 'js/main.js' "$page" || { no_main=$((no_main + 1)); echo "   nav without main.js: $page"; }
done
assert "pages with the shared nav load main.js ($no_main missing)" \
    "$([[ "$no_main" == "0" ]] && echo true || echo false)"

echo ""
echo "## Links resolve"
link_report="$(python3 - "${PAGES[@]}" <<'PY'
import os, re, sys
pages = sys.argv[1:]
web = os.path.abspath('web')
index_ids = set(re.findall(r'id="([^"]+)"', open('web/index.html').read()))
broken, dangling = [], []
for page in pages:
    text = open(page).read()
    page_ids = set(re.findall(r'id="([^"]+)"', text))
    base = os.path.dirname(os.path.abspath(page))
    for href in re.findall(r'href="([^"]+)"', text):
        if re.match(r'^(https?:|mailto:|data:|javascript:)', href):
            continue
        path, _, anchor = href.partition('#')
        if not path:
            if anchor and anchor not in page_ids:
                dangling.append(f"{page}: #{anchor}")
            continue
        target = os.path.normpath(os.path.join(web if path.startswith('/') else base, path.lstrip('/')))
        if os.path.isdir(target):
            target = os.path.join(target, 'index.html')
        if not os.path.isfile(target):
            broken.append(f"{page}: {href}")
            continue
        if anchor and os.path.abspath(target) == os.path.join(web, 'index.html') and anchor not in index_ids:
            dangling.append(f"{page}: {href}")
print(f"broken={len(broken)} dangling={len(dangling)}")
for line in broken + dangling:
    print("   " + line)
PY
)"
echo "$link_report" | tail -n +2
assert "every internal href resolves to a file" \
    "$(echo "$link_report" | head -n 1 | grep -q 'broken=0 ' && echo true || echo false)"
assert "every in-page and homepage anchor resolves to an id" \
    "$(echo "$link_report" | head -n 1 | grep -q 'dangling=0' && echo true || echo false)"

echo ""
echo "## Shipped scripts parse"
js_ok=true
for script in web/js/*.js web/book/js/*.js; do
    node --check "$script" 2>/dev/null || { js_ok=false; echo "   syntax error: $script"; }
done
assert "every shipped script passes node --check" "$js_ok"

finish_test "website consistency"
