#!/usr/bin/env bash
# okf-render-views.sh — render the demoted views from an OKF taxonomy bundle.
#
# The wiki/ bundle is the source of truth. This produces the two derived,
# human-facing views deterministically (so they never drift from the bundle and
# carry zero extra maintenance):
#   1. architecture.md  — a single linear concatenation of every concept page,
#      frontmatter stripped, in canonical section order, with a banner + TOC.
#      This is the onboarding "read one doc" view (demoted, not deleted).
#   2. Concept Map       — a routing table injected between the
#      <!-- CONCEPT-MAP:START --> / <!-- CONCEPT-MAP:END --> markers in
#      wiki/index.md (and optionally another index-root file).
#   3. Section indexes   — (--section-indexes) each <section>/index.md concept
#      table rebuilt from the pages that actually exist in that directory, so its
#      links can never dangle (no more hand-authored, link-rotting indexes).
#
# Usage:
#   okf-render-views.sh <BUNDLE_DIR> --arch-out <FILE> [--concept-map-into <FILE>]
#
# BUNDLE_DIR is the wiki/ directory. Exit 0 ok, 1 error, 2 bundle not found.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/tools/_lib.sh
source "$SCRIPT_DIR/_lib.sh"

BUNDLE=""
ARCH_OUT=""
WEB_OUT=""
CMAP_INTO=()
SECTION_INDEXES=0
COVERAGE_REPORT=""
VALIDATED_AT=""

usage() {
    cat <<'EOF'
okf-render-views.sh — render architecture.md + Concept Map + HTML viewer from an OKF bundle.

Usage:
  okf-render-views.sh <BUNDLE_DIR> [--arch-out FILE] [--concept-map-into FILE]... [--web FILE]

Flags:
  --arch-out FILE          Write the rendered linear architecture.md here.
  --concept-map-into FILE  Inject the Concept Map between the CONCEPT-MAP markers
                           in FILE (repeatable: e.g. wiki/index.md and ai-context.md).
  --section-indexes        Regenerate each section's <section>/index.md concept
                           table (between its CONCEPT-MAP markers) from the pages
                           that actually exist in that directory. Eliminates
                           hand-authored, link-rotting section indexes.
  --web FILE               Write a self-contained, offline HTML viewer (single file:
                           all pages inlined, built-in markdown renderer, sidebar +
                           search). Double-click to open — no server, no internet.
  --coverage-report FILE   okf-coverage-check.sh JSON; its mapped/required/pct and
                           validity are rendered into the architecture.md banner.
  --validated-at STR       Timestamp string shown in the banner (caller supplies it;
                           this tool has no clock dependency).
  --help                   Show this help.

Requires jq (already a Draft prereq) for --web. Exit 0 ok, 1 error, 2 bundle not found.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --arch-out) ARCH_OUT="$2"; shift 2;;
        --concept-map-into) CMAP_INTO+=("$2"); shift 2;;
        --section-indexes) SECTION_INDEXES=1; shift;;
        --web) WEB_OUT="$2"; shift 2;;
        --coverage-report) COVERAGE_REPORT="$2"; shift 2;;
        --validated-at) VALIDATED_AT="$2"; shift 2;;
        --help|-h) usage; exit 0;;
        -*) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
        *)
            if [[ -z "$BUNDLE" ]]; then BUNDLE="$1"; else echo "Unexpected arg: $1" >&2; exit 1; fi
            shift
            ;;
    esac
done

[[ -n "$BUNDLE" ]] || { usage >&2; exit 1; }
[[ -d "$BUNDLE" ]] || { echo "ERROR: bundle directory not found: $BUNDLE" >&2; exit 2; }
BUNDLE="${BUNDLE%/}"

# Canonical section order for the linear render. Sections not present are skipped.
SECTIONS=(overview systems features reference entrypoints)

# Emit bundle-relative page paths in canonical order: for each section, its
# index.md first, then the rest alphabetically. Pages outside these sections
# (e.g. log.md, the bundle root index.md) are excluded from the linear view.
ordered_pages() {
    local sec dir f
    for sec in "${SECTIONS[@]}"; do
        dir="$BUNDLE/$sec"
        [[ -d "$dir" ]] || continue
        [[ -f "$dir/index.md" ]] && echo "$sec/index.md"
        while IFS= read -r f; do
            [[ "$(basename "$f")" == "index.md" ]] && continue
            echo "$sec/${f##*/}"
        done < <(find "$dir" -maxdepth 1 -type f -name '*.md' | sort)
    done
}

# Strip YAML frontmatter from a page (leading --- ... --- block on line 1).
strip_frontmatter() {
    awk '
        NR==1 && /^---$/ { fm=1; next }
        fm && /^---$/ { fm=0; next }
        !fm { print }
    ' "$1"
}

# Coverage-honesty banner, sourced from okf-coverage-check.sh's JSON report.
# Silent when no report is supplied (keeps the view backward-compatible).
emit_coverage_banner() {
    [[ -n "$COVERAGE_REPORT" && -f "$COVERAGE_REPORT" ]] || return 0
    command -v jq >/dev/null 2>&1 || return 0
    local valid mapped required pct
    valid="$(jq -r '.valid // empty' "$COVERAGE_REPORT" 2>/dev/null || true)"
    mapped="$(jq -r '.mapped // empty' "$COVERAGE_REPORT" 2>/dev/null || true)"
    required="$(jq -r '.required // empty' "$COVERAGE_REPORT" 2>/dev/null || true)"
    pct="$(jq -r '.coverage_pct // empty' "$COVERAGE_REPORT" 2>/dev/null || true)"
    [[ -n "$mapped" && -n "$required" ]] || return 0
    if [[ "$valid" == "true" ]]; then
        echo "> **Coverage:** ${mapped}/${required} required components (${pct}%)."
    else
        echo "> **⚠ INCOMPLETE — do not use for RCA:** only ${mapped}/${required} required"
        echo "> components (${pct}%) are documented. Re-run \`/draft:init\` to fill the gaps."
    fi
    [[ -n "$VALIDATED_AT" ]] && echo "> Validated: ${VALIDATED_AT} — $([[ "$valid" == "true" ]] && echo PASS || echo FAIL)."
    echo ""
}

# --- 1. Render architecture.md ---
render_architecture() {
    local out="$1"
    local tmp; tmp="$(mktemp)"
    {
        echo "---"
        echo "generated_by: \"draft:init (okf-render-views.sh)\""
        echo "view: rendered"
        echo "source_of_truth: \"wiki/\""
        echo "---"
        echo ""
        echo "# Architecture (Rendered View)"
        echo ""
        echo "> **Generated** from the \`wiki/\` bundle — do not edit by hand."
        echo "> The bundle is the source of truth; this is the single-document linear"
        echo "> view for onboarding. Regenerate with \`okf-render-views.sh\`."
        echo ""
        emit_coverage_banner
        echo "## Contents"
        echo ""
        # TOC from page titles.
        local rel title sec last_sec=""
        while IFS= read -r rel; do
            [[ -z "$rel" ]] && continue
            sec="${rel%%/*}"
            if [[ "$sec" != "$last_sec" ]]; then
                echo "- **${sec}/**"
                last_sec="$sec"
            fi
            title="$(get_yaml_field "$BUNDLE/$rel" title)"
            [[ -n "$title" ]] || title="$rel"
            local anchor; anchor="$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-')"
            anchor="${anchor#-}"; anchor="${anchor%-}"
            echo "  - [${title}](#${anchor})"
        done < <(ordered_pages)
        echo ""
        # Body: each page, frontmatter stripped.
        while IFS= read -r rel; do
            [[ -z "$rel" ]] && continue
            echo ""
            echo "---"
            echo ""
            strip_frontmatter "$BUNDLE/$rel"
        done < <(ordered_pages)
    } >"$tmp"
    mv "$tmp" "$out"
    echo "rendered architecture view → $out ($(ordered_pages | grep -c . ) pages)"
}

# --- 2. Build the Concept Map table (stdout) ---
build_concept_map() {
    echo "| Concept | Type | Open it when… |"
    echo "|---------|------|---------------|"
    local rel type title desc
    while IFS= read -r -d '' page; do
        rel="${page#"$BUNDLE/"}"
        [[ "$(basename "$rel")" == "index.md" ]] && continue
        type="$(get_yaml_field "$page" type)"
        [[ -n "$type" ]] || continue
        title="$(get_yaml_field "$page" title)"
        [[ -n "$title" ]] || title="$rel"
        # description may be a folded (>) block — take the first non-empty body line.
        desc="$(awk '
            NR==1&&/^---$/{fm=1;next} fm&&/^---$/{exit}
            fm && /^description:/ { collect=1; sub(/^description:[[:space:]]*>?[[:space:]]*/,""); if($0!=""){print; exit} next }
            fm && collect { sub(/^[[:space:]]+/,""); if($0!=""){print; exit} }
        ' "$page")"
        echo "| [${title}](${rel}) | ${type} | ${desc} |"
    done < <(find "$BUNDLE" -type f -name '*.md' -print0 | sort -z)
}

# First non-empty line of a page's `description` frontmatter (handles folded `>`).
page_desc() {
    awk '
        NR==1&&/^---$/{fm=1;next} fm&&/^---$/{exit}
        fm && /^description:/ { collect=1; sub(/^description:[[:space:]]*>?[[:space:]]*/,""); if($0!=""){print; exit} next }
        fm && collect { sub(/^[[:space:]]+/,""); if($0!=""){print; exit} }
    ' "$1"
}

# Build the per-section concept table (stdout) for a single section directory.
# Links are bundle-section-relative (just the filename) so they resolve from the
# section's own index.md. Only pages that actually exist are listed — so the
# table can never point at a missing file.
build_section_map() {
    local dir="$1" f rel base type title desc
    echo "| Concept | Type | Routing description |"
    echo "|---------|------|---------------------|"
    while IFS= read -r f; do
        base="$(basename "$f")"
        [[ "$base" == "index.md" ]] && continue
        [[ "$base" == "coverage.md" ]] && continue
        grep -q '<!-- okf:coverage-generated -->' "$f" 2>/dev/null && continue
        type="$(get_yaml_field "$f" type)"
        [[ -n "$type" ]] || continue
        title="$(get_yaml_field "$f" title)"; [[ -n "$title" ]] || title="$base"
        desc="$(page_desc "$f")"
        echo "| [${title}](${base}) | ${type} | ${desc} |"
    done < <(find "$dir" -maxdepth 1 -type f -name '*.md' | sort)
}

# Regenerate every <section>/index.md concept table from real pages.
render_section_indexes() {
    local sec dir idx
    for sec in "${SECTIONS[@]}"; do
        dir="$BUNDLE/$sec"
        idx="$dir/index.md"
        [[ -d "$dir" && -f "$idx" ]] || continue
        local map_tmp; map_tmp="$(mktemp)"
        build_section_map "$dir" >"$map_tmp"
        inject_concept_map "$idx" "$map_tmp"
        rm -f "$map_tmp"
    done
}

# Inject the Concept Map between markers in a target file (path may be relative
# to BUNDLE: links in the map are bundle-relative, so the target should resolve
# them — wiki/index.md works directly; an index root above wiki/ should prefix).
inject_concept_map() {
    local target="$1" map="$2"
    [[ -f "$target" ]] || { echo "WARN: concept-map target not found: $target" >&2; return 0; }
    if ! grep -q 'CONCEPT-MAP:START' "$target" || ! grep -q 'CONCEPT-MAP:END' "$target"; then
        echo "WARN: $target has no CONCEPT-MAP markers — skipping injection" >&2
        return 0
    fi
    local tmp; tmp="$(mktemp)"
    awk -v mapfile="$map" '
        /<!-- CONCEPT-MAP:START -->/ { print; while ((getline line < mapfile) > 0) print line; close(mapfile); skip=1; next }
        /<!-- CONCEPT-MAP:END -->/ { skip=0 }
        !skip { print }
    ' "$target" >"$tmp"
    mv "$tmp" "$target"
    echo "injected Concept Map → $target"
}

# --- 3. Render a self-contained offline HTML viewer (single file) ---
# All pages are inlined as JSON; a small built-in markdown renderer draws them in
# the browser. No server, no internet, no CDN. jq encodes page content safely
# (and we neutralize any literal </ so embedded "</script>" can't break parsing).
render_web() {
    local out="$1"
    command -v jq >/dev/null 2>&1 || { echo "ERROR: --web requires jq" >&2; return 1; }
    local tmp; tmp="$(mktemp)"

    cat >"$tmp" <<'HTML_HEAD'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Knowledge Bundle</title>
<style>
  :root { --bg:#0f1115; --panel:#161a22; --ink:#d7dce5; --muted:#8a93a6; --accent:#6ea8fe; --border:#262c38; --code:#1b2030; }
  * { box-sizing: border-box; }
  body { margin:0; font:15px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif; color:var(--ink); background:var(--bg); }
  #app { display:flex; min-height:100vh; }
  #side { width:300px; flex:0 0 300px; background:var(--panel); border-right:1px solid var(--border); height:100vh; overflow:auto; position:sticky; top:0; padding:14px; }
  #side h1 { font-size:14px; margin:0 0 10px; color:var(--muted); text-transform:uppercase; letter-spacing:.05em; }
  #search { width:100%; padding:8px 10px; margin-bottom:12px; background:var(--code); border:1px solid var(--border); border-radius:6px; color:var(--ink); }
  .sec { font-size:11px; text-transform:uppercase; letter-spacing:.06em; color:var(--muted); margin:14px 0 4px; }
  .nav a { display:block; padding:4px 8px; color:var(--ink); text-decoration:none; border-radius:5px; font-size:13.5px; }
  .nav a:hover { background:var(--code); }
  .nav a.active { background:var(--accent); color:#0b0e14; }
  .nav a .ty { float:right; font-size:10px; color:var(--muted); }
  .nav a.active .ty { color:#0b0e14; }
  #main { flex:1; max-width:900px; padding:32px 44px; }
  #content h1,#content h2,#content h3 { line-height:1.25; }
  #content h1 { font-size:28px; border-bottom:1px solid var(--border); padding-bottom:8px; }
  #content a { color:var(--accent); }
  #content code { background:var(--code); padding:2px 5px; border-radius:4px; font-size:90%; }
  #content pre { background:var(--code); border:1px solid var(--border); border-radius:8px; padding:12px 14px; overflow:auto; }
  #content pre code { background:none; padding:0; }
  #content pre.mermaid-src { border-left:3px solid var(--accent); }
  #content pre.mermaid-src::before { content:"⬡ Mermaid diagram (source)"; display:block; color:var(--muted); font-size:11px; margin-bottom:6px; }
  #content table { border-collapse:collapse; width:100%; margin:14px 0; font-size:13.5px; }
  #content th,#content td { border:1px solid var(--border); padding:6px 9px; text-align:left; vertical-align:top; }
  #content th { background:var(--code); }
  #content blockquote { border-left:3px solid var(--border); margin:12px 0; padding:2px 14px; color:var(--muted); }
  #content hr { border:none; border-top:1px solid var(--border); margin:22px 0; }
  .crumb { color:var(--muted); font-size:12px; margin-bottom:8px; }
</style>
</head>
<body>
<div id="app">
  <nav id="side">
    <h1>Knowledge Bundle</h1>
    <input id="search" placeholder="Search…" autocomplete="off">
    <div id="nav" class="nav"></div>
  </nav>
  <main id="main"><div id="content"></div></main>
</div>
<script>
HTML_HEAD

    # Inline page data: PAGES[rel] = {title, type, md}, plus ORDER (index first).
    {
        echo "const PAGES = {"
        while IFS= read -r -d '' page; do
            local rel title type
            rel="${page#"$BUNDLE/"}"
            title="$(get_yaml_field "$page" title)"; [[ -n "$title" ]] || title="$rel"
            type="$(get_yaml_field "$page" type)"
            printf '%s: {"title": %s, "type": %s, "md": %s},\n' \
                "$(jq -Rn --arg v "$rel" '$v')" \
                "$(jq -Rn --arg v "$title" '$v')" \
                "$(jq -Rn --arg v "$type" '$v')" \
                "$(strip_frontmatter "$page" | jq -Rs . | sed 's#</#<\\/#g')"
        done < <(find "$BUNDLE" -type f -name '*.md' -print0 | sort -z)
        echo "};"
        # ORDER: bundle root index.md first, then everything else sorted.
        echo "const ORDER = Object.keys(PAGES).sort(function(a,b){"
        echo "  if(a==='index.md') return -1; if(b==='index.md') return 1;"
        echo "  return a<b?-1:a>b?1:0; });"
    } >>"$tmp"

    cat >>"$tmp" <<'HTML_TAIL'
function esc(s){return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');}
function resolve(base, href){
  if(/^[a-z]+:\/\//.test(href)||href[0]==='#') return href;
  var dir = base.indexOf('/')<0 ? '' : base.replace(/\/[^/]*$/,'');
  var parts = (dir? dir.split('/'):[]).concat(href.split('/')), out=[];
  for(var i=0;i<parts.length;i++){ var p=parts[i];
    if(p==='..') out.pop(); else if(p!=='.'&&p!=='') out.push(p); }
  return out.join('/');
}
function inline(s, base){
  s = s.replace(/`([^`]+)`/g, function(m,c){return '<code>'+esc(c)+'</code>';});
  s = s.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, function(m,t,u){
    if(/^[a-z]+:\/\//.test(u)) return '<a href="'+u+'" target="_blank" rel="noopener">'+t+'</a>';
    var key=resolve(base,u);
    if(PAGES[key]) return '<a href="#'+key+'" data-nav="'+key+'">'+t+'</a>';
    return '<span title="'+esc(u)+'">'+t+'</span>';
  });
  s = s.replace(/\*\*([^*]+)\*\*/g,'<strong>$1</strong>');
  s = s.replace(/(^|[^*])\*([^*\n]+)\*/g,'$1<em>$2</em>');
  return s;
}
function render(md, base){
  // Pull fenced code blocks out first so their contents aren't block-parsed.
  var blocks=[], src=md.replace(/```(\w*)\n([\s\S]*?)```/g,function(m,lang,body){
    var cls = lang==='mermaid' ? ' class="mermaid-src"' : '';
    blocks.push('<pre'+cls+'><code>'+esc(body.replace(/\n$/,''))+'</code></pre>');
    return ' BLOCK'+(blocks.length-1)+' ';
  });
  var lines=src.split('\n'), out='', i=0, list='', tbl=[];
  function closeList(){ if(list){ out+='</'+list+'>'; list=''; } }
  function flushTbl(){
    if(!tbl.length) return;
    var rows=tbl.filter(function(r){return !/^\s*\|?[\s:|-]+\|?\s*$/.test(r);});
    out+='<table>';
    rows.forEach(function(r,ri){
      var cells=r.replace(/^\||\|$/g,'').split('|');
      out+='<tr>'+cells.map(function(c){var t=ri===0?'th':'td';return '<'+t+'>'+inline(c.trim(),base)+'</'+t+'>';}).join('')+'</tr>';
    });
    out+='</table>'; tbl=[];
  }
  for(;i<lines.length;i++){
    var ln=lines[i];
    if(/^\s*\|.*\|\s*$/.test(ln)){ closeList(); tbl.push(ln); continue; } else flushTbl();
    var h=ln.match(/^(#{1,6})\s+(.*)$/);
    if(h){ closeList(); out+='<h'+h[1].length+'>'+inline(esc(h[2]),base)+'</h'+h[1].length+'>'; continue; }
    if(/^\s*---\s*$/.test(ln)){ closeList(); out+='<hr>'; continue; }
    if(/^\s*>\s?/.test(ln)){ closeList(); out+='<blockquote>'+inline(esc(ln.replace(/^\s*>\s?/,'')),base)+'</blockquote>'; continue; }
    var li=ln.match(/^\s*([-*]|\d+\.)\s+(.*)$/);
    if(li){ var want=/^\d/.test(li[1])?'ol':'ul'; if(list!==want){ closeList(); list=want; out+='<'+want+'>'; } out+='<li>'+inline(esc(li[2]),base)+'</li>'; continue; }
    var b=ln.match(/^ BLOCK(\d+) $/);
    if(b){ closeList(); out+=blocks[+b[1]]; continue; }
    if(/^\s*$/.test(ln)){ closeList(); continue; }
    closeList(); out+='<p>'+inline(esc(ln),base)+'</p>';
  }
  flushTbl(); closeList();
  return out;
}
var navEl=document.getElementById('nav'), contentEl=document.getElementById('content');
function section(k){ return k.indexOf('/')<0 ? '(root)' : k.split('/')[0]; }
function buildNav(filter){
  navEl.innerHTML=''; var lastSec=null;
  ORDER.forEach(function(k){
    var p=PAGES[k];
    if(filter && (p.title+' '+p.md).toLowerCase().indexOf(filter)<0) return;
    var sec=section(k);
    if(sec!==lastSec){ var s=document.createElement('div'); s.className='sec'; s.textContent=sec; navEl.appendChild(s); lastSec=sec; }
    var a=document.createElement('a'); a.href='#'+k; a.dataset.nav=k;
    a.innerHTML=esc(p.title)+(p.type?'<span class="ty">'+esc(p.type)+'</span>':'');
    navEl.appendChild(a);
  });
}
function show(k){
  var p=PAGES[k]; if(!p){ k=ORDER[0]; p=PAGES[k]; }
  contentEl.innerHTML='<div class="crumb">'+esc(k)+'</div>'+render(p.md,k);
  document.querySelectorAll('#nav a').forEach(function(a){ a.classList.toggle('active', a.dataset.nav===k); });
  if(location.hash.slice(1)!==k) history.replaceState(null,'','#'+k);
  contentEl.parentElement.scrollTop=0; window.scrollTo(0,0);
}
document.addEventListener('click',function(e){ var a=e.target.closest('[data-nav]'); if(a){ e.preventDefault(); show(a.dataset.nav); } });
document.getElementById('search').addEventListener('input',function(e){ buildNav(e.target.value.toLowerCase().trim()); });
window.addEventListener('hashchange',function(){ var k=decodeURIComponent(location.hash.slice(1)); if(PAGES[k]) show(k); });
buildNav('');
show(decodeURIComponent(location.hash.slice(1)) || ORDER[0]);
</script>
</body>
</html>
HTML_TAIL

    mkdir -p "$(dirname "$out")"
    mv "$tmp" "$out"
    echo "rendered offline HTML viewer → $out ($(find "$BUNDLE" -type f -name '*.md' | grep -c .) pages)"
}

[[ -n "$ARCH_OUT" ]] && render_architecture "$ARCH_OUT"

if [[ ${#CMAP_INTO[@]} -gt 0 ]]; then
    MAP_TMP="$(mktemp)"
    build_concept_map >"$MAP_TMP"
    for tgt in "${CMAP_INTO[@]}"; do
        inject_concept_map "$tgt" "$MAP_TMP"
    done
    rm -f "$MAP_TMP"
fi

[[ $SECTION_INDEXES -eq 1 ]] && render_section_indexes

[[ -n "$WEB_OUT" ]] && render_web "$WEB_OUT"

[[ -n "$ARCH_OUT" || -n "$WEB_OUT" || ${#CMAP_INTO[@]} -gt 0 || $SECTION_INDEXES -eq 1 ]] \
    || { echo "ERROR: nothing to do (pass --arch-out, --web, --section-indexes, and/or --concept-map-into)" >&2; exit 1; }
exit 0
