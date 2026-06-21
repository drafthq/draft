#!/usr/bin/env bash
# okf-validate-quality.sh — deterministic per-page SEMANTIC checks for an OKF bundle.
#
# okf-validate.sh proves a page is structurally sound (frontmatter, type, links).
# This proves a page is actually WRITTEN — not a stub, redirect, or template
# leftover — so that "every module has a page" (okf-coverage-check.sh) cannot be
# satisfied with placeholder content. Thresholds are per concept TYPE: a
# Subsystem must carry a diagram and real depth; an ADR or Dependency legitimately
# does not, so applying one global bar would false-fail them.
#
# Pages in scope: any *.md whose frontmatter declares a frozen `type:`. Section
# index.md pages, log.md, and the generated coverage page are excluded.
#
# Checks (per type): required H2 sections, min body lines, >=1 mermaid block
# (diagram types only), min x-grounded-paths, anti-stub patterns, unreplaced
# template tokens, duplicate "What it is" paragraphs, and a syntax-only mermaid
# lint (no Node, no headless browser).
#
# Usage:
#   okf-validate-quality.sh <BUNDLE_DIR> [--strict] [--json]
#
# Exit codes: 0 pass, 1 fail, 2 bundle not found.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/tools/_lib.sh
source "$SCRIPT_DIR/_lib.sh"

BUNDLE=""
STRICT=0
JSON=0

usage() {
    cat <<'EOF'
okf-validate-quality.sh — per-page semantic / anti-stub checks for an OKF bundle.

Usage:
  okf-validate-quality.sh <BUNDLE_DIR> [--strict] [--json]

Flags:
  --strict   Treat warnings (e.g. duplicate paragraphs) as failures.
  --json     Emit a JSON summary instead of human diagnostics.
  --help     Show this help.

Exit: 0 pass, 1 fail, 2 bundle not found.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --strict) STRICT=1; shift;;
        --json) JSON=1; shift;;
        --help|-h) usage; exit 0;;
        -*) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
        *) if [[ -z "$BUNDLE" ]]; then BUNDLE="$1"; else echo "Unexpected arg: $1" >&2; exit 1; fi; shift;;
    esac
done

[[ -n "$BUNDLE" ]] || { usage >&2; exit 1; }
[[ -d "$BUNDLE" ]] || { echo "ERROR: bundle directory not found: $BUNDLE" >&2; exit 2; }
BUNDLE="${BUNDLE%/}"

FAILURES=()   # page\tcheck\tdetail
WARNINGS=()
CHECKED=0

fail() { FAILURES+=("$1"$'\t'"$2"$'\t'"$3"); }
warn() { WARNINGS+=("$1"$'\t'"$2"$'\t'"$3"); }

# Body (everything after the frontmatter block).
body_of() {
    awk 'NR==1&&/^---$/{fm=1;next} fm&&/^---$/{fm=0;next} !fm{print}' "$1"
}

# Count body lines after the frontmatter close (Q-LEN = "lines after frontmatter").
body_lines() { body_of "$1" | wc -l | tr -d ' '; }

# x-grounded-paths array length (entries inside [ ... ]).
grounded_count() {
    local arr
    arr="$(grep -m1 -E '^x-grounded-paths:' "$1" 2>/dev/null || true)"
    [[ -z "$arr" ]] && { echo 0; return; }
    arr="${arr#*[}"; arr="${arr%]*}"
    arr="$(printf '%s' "$arr" | tr -d ' ')"
    [[ -z "$arr" ]] && { echo 0; return; }
    awk -F',' '{print NF}' <<< "$arr"
}

has_section() { grep -qE "^##[[:space:]]+$1([[:space:]]|$)" "$2"; }

mermaid_block_count() { grep -cE '^[[:space:]]*```mermaid' "$1" || true; }

# Syntax-only mermaid lint: catch the breakers that silently fail previewers
# without spawning Node. Returns 0 clean, 1 with a reason on stdout.
mermaid_lint() {
    local file="$1"
    # Extract content of every ```mermaid ... ``` block.
    local blocks; blocks="$(awk '
        /^[[:space:]]*```mermaid/ {inb=1; next}
        inb && /^[[:space:]]*```/ {inb=0; next}
        inb {print}
    ' "$file")"
    [[ -z "$blocks" ]] && return 0
    # Unicode arrows.
    if printf '%s' "$blocks" | grep -qE '→|⟶|⇒|←'; then
        echo "unicode arrow in mermaid (use --> not →)"; return 1
    fi
    # '&' node chaining (common breaker).
    if printf '%s' "$blocks" | grep -qE '[A-Za-z0-9_]\s*&\s*[A-Za-z0-9_]'; then
        echo "'&' node chaining in mermaid"; return 1
    fi
    # Reserved bareword node ids.
    if printf '%s' "$blocks" | grep -qE '(^|[[:space:]])(end|class|click|graph|subgraph)[[:space:]]*(--|==|-\.)'; then
        echo "reserved word used as node id in mermaid"; return 1
    fi
    # Unbalanced subgraph/end.
    local sg en
    sg="$(printf '%s' "$blocks" | grep -cE '^[[:space:]]*subgraph' || true)"
    en="$(printf '%s' "$blocks" | grep -cE '^[[:space:]]*end[[:space:]]*$' || true)"
    if [[ "$sg" -gt 0 && "$sg" != "$en" ]]; then
        echo "unbalanced subgraph/end ($sg subgraph, $en end)"; return 1
    fi
    return 0
}

# Normalized hash of the first paragraph under "## What it is" (dup detection).
whatitis_hash() {
    local p
    p="$(awk '
        /^##[[:space:]]+What it is/ {grab=1; next}
        grab && /^##[[:space:]]/ {exit}
        grab && /^[[:space:]]*$/ { if (seen) exit; else next }
        grab {seen=1; print}
    ' "$1")"
    [[ -z "$p" ]] && return 0
    printf '%s' "$p" | tr '[:upper:]' '[:lower:]' | tr -s ' \t' ' ' | cksum | awk '{print $1}'
}

ANTI_STUB='see architecture\.md|deferred to ref-docs|\bTBD\b|TODO:[[:space:]]*document|stub page|placeholder page'
TOKEN_RE='\{[A-Z_]+\}'

# Per-type policy. echoes: sections|min_lines|need_mermaid|min_grounded
type_policy() {
    case "$1" in
        Subsystem|Module|Feature|Entrypoint)
            echo "What it is;How it works;Used by;Blast radius;See also|25|1|2";;
        API|DataModel)
            echo "What it is;How it works;See also|18|0|1";;
        Dependency)
            echo "What it is;Used by|10|0|0";;
        ADR|Runbook)
            echo "|8|0|0";;
        *)
            echo "|8|0|0";;
    esac
}

# Seen "What it is" hashes (hash<TAB>rel), as a temp file for bash 3.2 portability.
WHATIS_SEEN="$(mktemp)"
trap 'rm -f "$WHATIS_SEEN"' EXIT

while IFS= read -r -d '' page; do
    rel="${page#"$BUNDLE/"}"
    base="$(basename "$rel")"
    # Exclusions: section/root index, log, generated coverage page.
    [[ "$base" == "index.md" ]] && continue
    [[ "$base" == "log.md" ]] && continue
    [[ "$base" == "coverage.md" ]] && continue
    grep -q '<!-- okf:coverage-generated -->' "$page" 2>/dev/null && continue

    type_val="$(get_yaml_field "$page" type)"
    [[ -z "$type_val" ]] && continue   # not a concept page
    CHECKED=$((CHECKED + 1))

    IFS='|' read -r sections min_lines need_mermaid min_grounded <<< "$(type_policy "$type_val")"

    # Q-SEC: required sections.
    if [[ -n "$sections" ]]; then
        IFS=';' read -ra secs <<< "$sections"
        for s in "${secs[@]}"; do
            has_section "$s" "$page" || fail "$rel" "Q-SEC" "missing required section '## $s'"
        done
    fi

    # Q-LEN: body length.
    bl="$(body_lines "$page")"
    [[ "$bl" -ge "$min_lines" ]] || fail "$rel" "Q-LEN" "body $bl lines < $min_lines for type $type_val"

    # Q-DIAG: mermaid presence for diagram types.
    if [[ "$need_mermaid" == "1" ]]; then
        mc="$(mermaid_block_count "$page")"
        [[ "$mc" -ge 1 ]] || fail "$rel" "Q-DIAG" "no mermaid block (required for $type_val)"
    fi

    # Q-MERMAID: syntax lint on any present blocks.
    if [[ "$(mermaid_block_count "$page")" -ge 1 ]]; then
        if reason="$(mermaid_lint "$page")"; [[ -n "$reason" ]]; then
            fail "$rel" "Q-MERMAID" "$reason"
        fi
    fi

    # Q-GROUND: grounded paths count.
    if [[ "$min_grounded" -gt 0 ]]; then
        gc="$(grounded_count "$page")"
        [[ "$gc" -ge "$min_grounded" ]] || fail "$rel" "Q-GROUND" "x-grounded-paths $gc < $min_grounded"
    fi

    # Q-STUB: anti-stub patterns in body.
    if body_of "$page" | grep -qiE "$ANTI_STUB"; then
        fail "$rel" "Q-STUB" "matches anti-stub pattern"
    fi

    # Q-TEMPLATE: unreplaced {TOKEN} placeholders.
    if body_of "$page" | grep -qE "$TOKEN_RE"; then
        fail "$rel" "Q-TEMPLATE" "unreplaced template token {PLACEHOLDER}"
    fi

    # Q-DUP: duplicate "What it is" opening paragraph (warning unless --strict).
    h="$(whatitis_hash "$page")"
    if [[ -n "$h" ]]; then
        prev="$(awk -F'\t' -v h="$h" '$1==h{print $2; exit}' "$WHATIS_SEEN")"
        if [[ -n "$prev" ]]; then
            warn "$rel" "Q-DUP" "duplicate 'What it is' paragraph (matches $prev)"
        else
            printf '%s\t%s\n' "$h" "$rel" >> "$WHATIS_SEEN"
        fi
    fi
done < <(find "$BUNDLE" -type f -name '*.md' -print0 | sort -z)

# In --strict, warnings become failures.
if [[ $STRICT -eq 1 && ${#WARNINGS[@]} -gt 0 ]]; then
    for w in "${WARNINGS[@]}"; do FAILURES+=("$w"); done
    WARNINGS=()
fi

if [[ $JSON -eq 1 ]]; then
    valid=true; [[ ${#FAILURES[@]} -eq 0 ]] || valid=false
    printf '{"valid":%s,"bundle":"%s","concepts_checked":%d,"failures":[' \
        "$valid" "$(json_escape "$BUNDLE")" "$CHECKED"
    for i in "${!FAILURES[@]}"; do
        [[ $i -gt 0 ]] && printf ','
        IFS=$'\t' read -r p c d <<< "${FAILURES[$i]}"
        printf '{"page":"%s","check":"%s","detail":"%s"}' \
            "$(json_escape "$p")" "$(json_escape "$c")" "$(json_escape "$d")"
    done
    printf '],"warnings":['
    for i in "${!WARNINGS[@]}"; do
        [[ $i -gt 0 ]] && printf ','
        IFS=$'\t' read -r p c d <<< "${WARNINGS[$i]}"
        printf '{"page":"%s","check":"%s","detail":"%s"}' \
            "$(json_escape "$p")" "$(json_escape "$c")" "$(json_escape "$d")"
    done
    printf ']}\n'
else
    if [[ ${#FAILURES[@]} -gt 0 ]]; then
        echo "OKF quality FAIL: $BUNDLE ($CHECKED concepts checked)" >&2
        for f in "${FAILURES[@]}"; do
            IFS=$'\t' read -r p c d <<< "$f"
            echo "  - [$c] $p: $d" >&2
        done
    else
        echo "OKF quality pass: $BUNDLE ($CHECKED concepts checked)"
    fi
    for w in "${WARNINGS[@]:-}"; do
        [[ -z "$w" ]] && continue
        IFS=$'\t' read -r p c d <<< "$w"
        echo "  warn [$c] $p: $d" >&2
    done
fi

[[ ${#FAILURES[@]} -eq 0 ]] || exit 1
exit 0
