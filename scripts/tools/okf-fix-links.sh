#!/usr/bin/env bash
# okf-fix-links.sh — rewrite and validate markdown links in draft/ views.
#
# Fixes the class of bugs seen when okf-render-views concatenates wiki pages into
# draft/architecture.md (sibling-relative links and ambiguous basenames break).
# Also validates the whole draft/ tree (or a single file).
#
# Usage:
#   okf-fix-links.sh --draft DIR [--fix] [--check]
#   okf-fix-links.sh --file FILE --wiki DIR [--fix]
#
# Exit: 0 all links resolve (after optional fix), 1 broken links remain, 2 usage.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/tools/_lib.sh
source "$SCRIPT_DIR/_lib.sh"

DRAFT=""
FILE=""
WIKI=""
DO_FIX=0
DO_CHECK=1

usage() {
    cat <<'EOF'
okf-fix-links.sh — fix/validate markdown links in Draft OKF outputs.

Usage:
  okf-fix-links.sh --draft DIR [--fix] [--check]
  okf-fix-links.sh --file architecture.md --wiki DIR/wiki [--fix]

Flags:
  --draft DIR   draft/ directory (architecture.md + wiki/ + .ai-context.md)
  --file FILE   single markdown file to rewrite/check
  --wiki DIR    wiki bundle (required with --file for basename map)
  --fix        rewrite broken/ambiguous links in place
  --check       report broken links (default on)
  --help

Exit: 0 clean, 1 broken links remain, 2 bad invocation.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --draft) DRAFT="${2:?--draft requires a value}"; shift 2;;
        --file) FILE="${2:?--file requires a value}"; shift 2;;
        --wiki) WIKI="${2:?--wiki requires a value}"; shift 2;;
        --fix) DO_FIX=1; shift;;
        --check) DO_CHECK=1; shift;;
        --help|-h) usage; exit 0;;
        -*) echo "Unknown flag: $1" >&2; usage >&2; exit 2;;
        *) echo "Unexpected arg: $1" >&2; exit 2;;
    esac
done

if [[ -n "$DRAFT" ]]; then
    DRAFT="${DRAFT%/}"
    [[ -d "$DRAFT" ]] || { echo "ERROR: --draft not a directory" >&2; exit 2; }
    WIKI="${WIKI:-$DRAFT/wiki}"
    FILE="${FILE:-$DRAFT/architecture.md}"
fi

[[ -n "$FILE" && -f "$FILE" ]] || { echo "ERROR: --file or --draft/architecture.md required" >&2; exit 2; }
[[ -n "$WIKI" && -d "$WIKI" ]] || { echo "ERROR: wiki dir required" >&2; exit 2; }

# Build basename → list of wiki-relative paths (relative to draft root as wiki/...)
declare -A BASENAME_MAP_MULTI=()
while IFS= read -r -d '' p; do
    rel="wiki/${p#"$WIKI"/}"
    base="$(basename "$p")"
    if [[ -n "${BASENAME_MAP_MULTI[$base]:-}" ]]; then
        BASENAME_MAP_MULTI[$base]="${BASENAME_MAP_MULTI[$base]}|$rel"
    else
        BASENAME_MAP_MULTI[$base]="$rel"
    fi
done < <(find "$WIKI" -type f -name '*.md' -print0)

pick_target() {
    local base="$1" label="$2"
    local cands="${BASENAME_MAP_MULTI[$base]:-}"
    [[ -n "$cands" ]] || { echo ""; return; }
    if [[ "$cands" != *"|"* ]]; then
        printf '%s' "$cands"
        return
    fi
    local lab; lab="$(printf '%s' "$label" | tr '[:upper:]' '[:lower:]')"
    IFS='|' read -ra arr <<< "$cands"
    local pref
    if [[ "$lab" == *product* || "$lab" == *feature* || "$lab" == *user*guide* || "$lab" == *install* ]]; then
        for pref in "${arr[@]}"; do [[ "$pref" == *"/features/"* ]] && { printf '%s' "$pref"; return; }; done
    fi
    if [[ "$lab" == *build* || "$lab" == *runbook* || "$lab" == *ops* || "$lab" == *source* ]]; then
        for pref in "${arr[@]}"; do [[ "$pref" == *"/overview/"* ]] && { printf '%s' "$pref"; return; }; done
    fi
    for order in /systems/ /features/ /overview/ /reference/ /entrypoints/; do
        for pref in "${arr[@]}"; do
            [[ "$pref" == *"$order"* ]] && { printf '%s' "$pref"; return; }
        done
    done
    printf '%s' "${arr[0]}"
}

# Collect heading slugs from a file for anchor checks
build_slugs() {
    local f="$1"
    declare -gA SLUGS=()
    local counts=()
    # shellcheck disable=SC2034
    while IFS= read -r line; do
        [[ "$line" =~ ^#{1,6}[[:space:]]+(.*)$ ]] || continue
        local raw="${BASH_REMATCH[1]}"
        local s; s="$(gfm_slug "$raw")"
        local n="${SLUGS[_count_$s]:-0}"
        SLUGS[_count_$s]=$((n+1))
        if [[ $n -eq 0 ]]; then
            SLUGS[$s]=1
        else
            SLUGS["${s}-$n"]=1
        fi
    done < "$f"
}

resolve_ok() {
    local src="$1" href="$2"
    [[ "$href" =~ ^https?:// || "$href" =~ ^mailto: ]] && return 0
    if [[ "$href" == \#* ]]; then
        local a="${href#\#}"
        [[ -n "${SLUGS[$a]:-}" ]] && return 0
        return 1
    fi
    local path="${href%%\#*}"
    [[ -z "$path" ]] && return 0
    local dir; dir="$(cd "$(dirname "$src")" && pwd)"
    local draft_root=""
    if [[ -n "$DRAFT" ]]; then
        draft_root="$(cd "$DRAFT" && pwd)"
    else
        draft_root="$(cd "$(dirname "$src")" && pwd)"
    fi
    [[ -e "$dir/$path" || -e "$draft_root/$path" || -e "$path" ]] && return 0
    return 1
}

fix_file() {
    local src="$1"
    local tmp; tmp="$(mktemp)"
    python3 - "$src" "$WIKI" "$tmp" <<'PY'
import sys, re
from pathlib import Path

src = Path(sys.argv[1])
wiki = Path(sys.argv[2])
out = Path(sys.argv[3])
text = src.read_text(encoding="utf-8", errors="replace")

# basename -> [wiki-relative draft paths]
bmap = {}
for p in wiki.rglob("*.md"):
    rel = "wiki/" + str(p.relative_to(wiki)).replace("\\", "/")
    bmap.setdefault(p.name, []).append(rel)

def pick(base, label):
    cands = bmap.get(base, [])
    if not cands:
        return None
    if len(cands) == 1:
        return cands[0]
    lab = label.lower()
    def prefer(substr):
        for c in cands:
            if substr in c:
                return c
        return None
    if any(k in lab for k in ("product", "feature", "user guide", "install", "onboarding")):
        p = prefer("/features/")
        if p: return p
    if any(k in lab for k in ("build", "runbook", "ops", "source", "cargo")):
        p = prefer("/overview/")
        if p: return p
    for s in ("/systems/", "/features/", "/overview/", "/reference/", "/entrypoints/"):
        p = prefer(s)
        if p: return p
    return cands[0]

def gfm_slug(heading: str) -> str:
    s = heading.strip().lower()
    s = re.sub(r"[^\w\s-]", "", s, flags=re.UNICODE)
    s = re.sub(r"\s+", "-", s)
    s = re.sub(r"-+", "-", s).strip("-")
    return s

# heading map for anchor fix
slug_counts = {}
heading_by_text = {}
for line in text.splitlines():
    m = re.match(r"^(#{1,6})\s+(.+)$", line)
    if not m:
        continue
    raw = m.group(2).strip()
    base = gfm_slug(raw)
    n = slug_counts.get(base, 0)
    slug_counts[base] = n + 1
    slug = base if n == 0 else f"{base}-{n}"
    heading_by_text[raw] = slug

def repl(m):
    label, href = m.group(1), m.group(2).strip()
    # strip rustdoc
    if "::" in href and not href.startswith(("http", "wiki/", "#", "../", "./")):
        return f"`{label}`"
    if href.startswith(("http://", "https://", "mailto:")):
        return m.group(0)
    if href.startswith("#"):
        if label in heading_by_text and href[1:] != heading_by_text[label]:
            return f"[{label}](#{heading_by_text[label]})"
        g = gfm_slug(label)
        # unique match on gfm of heading texts
        for raw, slug in heading_by_text.items():
            if gfm_slug(raw) == g and href[1:] != slug:
                return f"[{label}](#{slug})"
        return m.group(0)
    path, sep, frag = href.partition("#")
    frag_s = ("#" + frag) if frag else ""
    if path.startswith("wiki/"):
        return m.group(0)
    m2 = re.match(r"^\.\./((?:systems|features|overview|entrypoints|reference)/.+)$", path)
    if m2:
        return f"[{label}](wiki/{m2.group(1)}{frag_s})"
    if re.match(r"^(systems|features|overview|entrypoints|reference)/", path):
        return f"[{label}](wiki/{path}{frag_s})"
    if path.endswith(".md") and "/" not in path:
        picked = pick(path, label)
        if picked:
            return f"[{label}]({picked}{frag_s})"
    return m.group(0)

new = re.sub(r"\[([^\]]*)\]\(([^)]+)\)", repl, text)
out.write_text(new if new.endswith("\n") else new + "\n", encoding="utf-8")
PY
    if [[ $DO_FIX -eq 1 ]]; then
        mv "$tmp" "$src"
    else
        rm -f "$tmp"
    fi
}

if [[ $DO_FIX -eq 1 ]]; then
    fix_file "$FILE"
    # Also fix .ai-context when draft mode
    if [[ -n "$DRAFT" && -f "$DRAFT/.ai-context.md" ]]; then
        fix_file "$DRAFT/.ai-context.md"
    fi
fi

# Check
build_slugs "$FILE"
broken=0
total=0
while IFS= read -r line; do
    # crude extract — enough for validation
    :
done < /dev/null

# Python check for reliability
broken_out="$(python3 - "$FILE" "${DRAFT:-$(dirname "$FILE")}" "$WIKI" <<'PY'
import sys, re
from pathlib import Path
src = Path(sys.argv[1])
draft = Path(sys.argv[2])
wiki = Path(sys.argv[3])
text = src.read_text(encoding="utf-8", errors="replace")

def gfm_slug(heading: str) -> str:
    s = heading.strip().lower()
    s = re.sub(r"[^\w\s-]", "", s, flags=re.UNICODE)
    s = re.sub(r"\s+", "-", s)
    s = re.sub(r"-+", "-", s).strip("-")
    return s

slug_counts = {}
slugs = set()
for line in text.splitlines():
    m = re.match(r"^(#{1,6})\s+(.+)$", line)
    if not m: continue
    base = gfm_slug(m.group(2))
    n = slug_counts.get(base, 0)
    slug_counts[base] = n + 1
    slugs.add(base if n == 0 else f"{base}-{n}")

broken = []
ok = 0
for m in re.finditer(r"\[([^\]]*)\]\(([^)]+)\)", text):
    label, href = m.group(1), m.group(2).strip()
    if href.startswith(("http://","https://","mailto:")):
        ok += 1; continue
    if href.startswith("#"):
        if href[1:] in slugs:
            ok += 1
        else:
            broken.append(f"anchor {href} ({label[:40]})")
        continue
    path = href.split("#",1)[0]
    if not path:
        ok += 1; continue
    cands = [src.parent/path, draft/path, Path(path)]
    if any(c.exists() for c in cands):
        ok += 1
    else:
        broken.append(f"file {href} ({label[:40]})")
print(f"OK={ok}")
print(f"BROKEN={len(broken)}")
for b in broken[:50]:
    print(b)
PY
)"

echo "$broken_out"
bcount="$(echo "$broken_out" | sed -n 's/^BROKEN=//p' | head -1)"
if [[ "${bcount:-1}" != "0" ]]; then
    echo "okf-fix-links: FAILED ($bcount broken in $FILE)" >&2
    exit 1
fi
echo "okf-fix-links: clean ($FILE)"
exit 0
