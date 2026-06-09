#!/usr/bin/env bash
# render-track.sh
#
# Render a Draft track's markdown set into a single HTML viewer artifact
# on demand. Replaces the pre-2.0 pattern of checking generated HTML into
# the track directory; viewer artifacts are now git-ignored and rebuilt
# whenever a reader wants them.
#
# Usage:
# scripts/tools/render-track.sh <track_dir> [--out <path>]
# scripts/tools/render-track.sh <track_dir> --stdout
#
# Default output: <track_dir>/track-reader.html (git-ignored).
#
# Implementation note: pandoc is preferred if present; otherwise a minimal
# markdown-to-HTML render is used via awk. No external network calls.

set -euo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "${0##*/} — Foundations quality tool (see core/ docs for full behavior)"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

html_escape() {
    local s="$1"
    s="${s//&/&amp;}"
    s="${s//</&lt;}"
    s="${s//>/&gt;}"
    printf '%s' "$s"
}

usage() {
    local stream=2 code=2
    if [[ "${USAGE_HELP_MODE:-0}" == 1 ]]; then stream=1; code=0; fi
    sed -n '2,16p' "$0" >&$stream
    exit "$code"
}

TRACK_DIR=""
OUT_PATH=""
TO_STDOUT=0

while (($#)); do
    case "$1" in
        -h|--help) USAGE_HELP_MODE=1 usage ;;
        --out) OUT_PATH="$2"; shift 2 ;;
        --stdout) TO_STDOUT=1; shift ;;
        -*) printf 'Unknown flag: %s\n' "$1" >&2; usage ;;
        *) TRACK_DIR="$1"; shift ;;
    esac
done

[[ -z "$TRACK_DIR" ]] && usage
[[ ! -d "$TRACK_DIR" ]] && { printf 'Not a directory: %s\n' "$TRACK_DIR" >&2; exit 2; }

TRACK_DIR="$(cd "$TRACK_DIR" && pwd)"
track_id="$(basename "$TRACK_DIR")"

if (( ! TO_STDOUT )) && [[ -z "$OUT_PATH" ]]; then
    OUT_PATH="$TRACK_DIR/track-reader.html"
fi

# Pre-2.0 cleanup: warn if a stale HTML artifact is checked in.
if (( ! TO_STDOUT )) && git -C "$TRACK_DIR" ls-files --error-unmatch \
       "track-reader.html" >/dev/null 2>&1; then
    printf 'render-track: WARNING — track-reader.html is checked into git.\n' >&2
    printf ' Remove it: git rm tracks/.../track-reader.html\n' >&2
    printf ' Draft 2.0 makes viewer artifacts git-ignored runtime output.\n' >&2
fi

ORDER=(spec.md plan.md hld.md lld.md discovery.md)
ALL_MD=("${ORDER[@]}")
# Append any extras found that are not already in ORDER.
while IFS= read -r f; do
    name="$(basename "$f")"
    skip=0
    for o in "${ORDER[@]}"; do [[ "$name" == "$o" ]] && skip=1 && break; done
    (( skip )) || ALL_MD+=("$name")
done < <(find "$TRACK_DIR" -maxdepth 1 -type f -name '*.md' | sort)

render_with_pandoc() {
    local title="$1"; shift
    local files=()
    for f in "$@"; do
        [[ -f "$TRACK_DIR/$f" ]] && files+=("$TRACK_DIR/$f")
    done
    (( ${#files[@]} > 0 )) || return 1
    pandoc -s --toc --metadata title="$title" "${files[@]}"
}

render_minimal() {
    local title="$1"; shift
    local files=()
    for f in "$@"; do
        [[ -f "$TRACK_DIR/$f" ]] && files+=("$TRACK_DIR/$f")
    done
    (( ${#files[@]} > 0 )) || return 1
    printf '<!doctype html>\n<html><head><meta charset="utf-8">'
    printf '<title>%s</title>' "$(html_escape "$title")"
    cat <<'CSS'
<style>
body{font:14px/1.5 system-ui,sans-serif;max-width:920px;margin:2em auto;padding:0 1em;color:#222}
h1,h2,h3{font-weight:600}h1{border-bottom:1px solid #ccc;padding-bottom:.3em}
code{background:#f4f4f4;padding:.1em .3em;border-radius:3px;font-size:.95em}
pre{background:#f8f8f8;padding:.8em;border-radius:5px;overflow-x:auto}
table{border-collapse:collapse}td,th{border:1px solid #ddd;padding:.4em .6em}
nav.toc{background:#fafafa;border:1px solid #eee;padding:.6em 1em;margin:1em 0}
hr.docsep{margin:3em 0;border:0;border-top:2px dashed #ccc}
.meta{color:#888;font-size:.9em}
</style></head><body>
CSS
    printf '<h1>%s</h1>\n<nav class="toc"><strong>Documents</strong><ul>\n' "$(html_escape "$title")"
    for f in "${files[@]}"; do
        local n; n="$(basename "$f")"
        printf '<li><a href="#%s">%s</a></li>\n' "$(html_escape "$n")" "$(html_escape "$n")"
    done
    printf '</ul></nav>\n'
    for f in "${files[@]}"; do
        local n; n="$(basename "$f")"
        printf '<hr class="docsep"><section id="%s"><p class="meta">— %s —</p>\n<pre><code>' "$(html_escape "$n")" "$(html_escape "$n")"
        sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' "$f"
        printf '</code></pre></section>\n'
    done
    printf '</body></html>\n'
}

OUTPUT=""
if command -v pandoc >/dev/null 2>&1; then
    OUTPUT="$(render_with_pandoc "Draft Track: $track_id" "${ALL_MD[@]}" || true)"
fi
if [[ -z "$OUTPUT" ]]; then
    OUTPUT="$(render_minimal "Draft Track: $track_id" "${ALL_MD[@]}")"
fi

if (( TO_STDOUT )); then
    printf '%s' "$OUTPUT"
else
    printf '%s' "$OUTPUT" > "$OUT_PATH"
    printf 'Wrote %s (%d bytes)\n' "$OUT_PATH" "${#OUTPUT}"
fi
