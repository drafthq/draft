#!/usr/bin/env bash
# okf-validate.sh — validate an OKF (Open Knowledge Format) taxonomy bundle.
#
# This is the deterministic ground-truth verifier for the `/draft:init` OKF
# emitter (DRAFT_INIT_MODE=okf). It fails the build on dangling cross-links,
# missing/invalid frontmatter, and an incomplete path→concept index, so a
# page-by-page generation pass cannot ship a structurally broken bundle.
#
# Checks:
#   1. BUNDLE_DIR exists and contains a root index.md.
#   2. Every concept page (any *.md whose frontmatter declares `type:`) carries
#      all required OKF frontmatter keys: type, title, description, resource.
#   3. Every declared `type` is in the frozen code-repo vocabulary (§4 of HLD).
#   4. Every relative markdown cross-link ( ](path.md) ) resolves to a file that
#      exists inside the bundle. External (http/https/mailto) and pure-anchor
#      (#frag) links are ignored.
#   5. (optional) --path-index FILE: every concept page referenced by the
#      path→concept index exists in the bundle (no dangle, no stale rename).
#
# Usage:
#   scripts/tools/okf-validate.sh <BUNDLE_DIR> [--path-index FILE] [--json]
#
# Exit codes: 0 valid, 1 invalid (diagnostics to stderr), 2 bundle not found.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/tools/_lib.sh
source "$SCRIPT_DIR/_lib.sh"

# Frozen concept `type` vocabulary for code repos. Changing this churns every
# generated file, so it is versioned in the bundle (index.md: okf_types_version).
OKF_TYPES="Subsystem Module Feature Entrypoint API DataModel Dependency ADR Runbook"

BUNDLE=""
PATH_INDEX=""
JSON=0

usage() {
    cat <<'EOF'
okf-validate.sh — validate an OKF taxonomy bundle (the /draft:init OKF emitter output).

Usage:
  scripts/tools/okf-validate.sh <BUNDLE_DIR> [--path-index FILE] [--json]

Flags:
  --path-index FILE  Validate a path→concept index (JSON): every concept page it
                     names must exist in the bundle.
  --json             Emit a JSON summary instead of human diagnostics.
  --help             Show this help.

Exit 0 valid, 1 invalid, 2 bundle directory not found.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --path-index) PATH_INDEX="$2"; shift 2;;
        --json) JSON=1; shift;;
        --help|-h) usage; exit 0;;
        -*) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
        *)
            if [[ -z "$BUNDLE" ]]; then BUNDLE="$1"
            else echo "Unexpected arg: $1" >&2; exit 1
            fi
            shift
            ;;
    esac
done

if [[ -z "$BUNDLE" ]]; then
    usage >&2
    exit 1
fi

if [[ ! -d "$BUNDLE" ]]; then
    echo "ERROR: bundle directory not found: $BUNDLE" >&2
    exit 2
fi

BUNDLE="${BUNDLE%/}"

ERRORS=()
PAGE_COUNT=0
CONCEPT_COUNT=0

add_error() { ERRORS+=("$1"); }

# Does the frozen vocabulary contain $1?
is_known_type() {
    local t="$1"
    [[ " $OKF_TYPES " == *" $t "* ]]
}

# --- 1. Root index ---
if [[ ! -f "$BUNDLE/index.md" ]]; then
    add_error "missing bundle root: $BUNDLE/index.md"
fi

# --- 2/3. Per-page frontmatter + type vocabulary ---
while IFS= read -r -d '' page; do
    PAGE_COUNT=$((PAGE_COUNT + 1))
    rel="${page#"$BUNDLE/"}"

    # A page is a "concept" only if its frontmatter declares a type.
    type_val="$(get_yaml_field "$page" "type")"
    [[ -z "$type_val" ]] && continue
    CONCEPT_COUNT=$((CONCEPT_COUNT + 1))

    for key in title description resource; do
        if [[ -z "$(get_yaml_field "$page" "$key")" ]]; then
            add_error "$rel: concept missing required frontmatter field '$key'"
        fi
    done

    if ! is_known_type "$type_val"; then
        add_error "$rel: unknown concept type '$type_val' (frozen vocab: $OKF_TYPES)"
    fi
done < <(find "$BUNDLE" -type f -name '*.md' -print0 | sort -z)

# --- 4. Cross-link resolution ---
# Scan every markdown page for relative links of the form ](target.md[#frag]).
# Resolve targets relative to the linking file's directory; flag dangles.
# Use a temp file (outside the bundle) because the scan runs in a pipeline
# subshell where add_error would not persist.
DANGLE_FILE="$(mktemp)"
trap 'rm -f "$DANGLE_FILE"' EXIT
while IFS= read -r -d '' page; do
    pdir="$(dirname "$page")"
    prel="${page#"$BUNDLE/"}"
    # Extract link targets: text inside ]( ... ) up to a space or closing paren.
    grep -oE '\]\([^) ]+\)' "$page" 2>/dev/null | sed -E 's/^\]\(//; s/\)$//' | while IFS= read -r target; do
        [[ -z "$target" ]] && continue
        # Skip external schemes and pure anchors.
        case "$target" in
            http://*|https://*|mailto:*|\#*) continue;;
        esac
        # Strip any #anchor and ?query.
        target="${target%%#*}"
        target="${target%%\?*}"
        [[ -z "$target" ]] && continue
        # Only resolve intra-bundle markdown/asset links (relative paths).
        case "$target" in
            /*) continue;;  # absolute path — out of scope for bundle integrity
        esac
        resolved="$pdir/$target"
        if [[ ! -e "$resolved" ]]; then
            printf '%s\t%s\n' "$prel" "$target"
        fi
    done || true   # inner pipeline returns non-zero at EOF; don't trip set -e
done < <(find "$BUNDLE" -type f -name '*.md' -print0 | sort -z) >>"$DANGLE_FILE"

if [[ -s "$DANGLE_FILE" ]]; then
    while IFS=$'\t' read -r prel target; do
        add_error "$prel: dangling cross-link → '$target'"
    done < "$DANGLE_FILE"
fi

# --- 5. path→concept index completeness (optional) ---
if [[ -n "$PATH_INDEX" ]]; then
    if [[ ! -f "$PATH_INDEX" ]]; then
        add_error "path-index not found: $PATH_INDEX"
    else
        # The index maps source path → array of concept page(s), bundle-relative:
        #   { "src/auth/login.go": ["systems/auth.md"], ... }
        # Validate the array VALUES (the pages) only. Keys are source paths and may
        # themselves end in .md (e.g. grounding to docs/INVARIANTS.md) — those are
        # not bundle pages, so we extract strings *inside* the [ ... ] value arrays
        # and ignore keys entirely. Each page must exist in the bundle.
        while IFS= read -r ref; do
            [[ -z "$ref" ]] && continue
            if [[ ! -f "$BUNDLE/$ref" ]]; then
                add_error "path-index references missing concept page: $ref"
            fi
        done < <(grep -oE '\[[^]]*\]' "$PATH_INDEX" 2>/dev/null \
                   | grep -oE '"[^"]+\.md"' | tr -d '"' | sort -u)
    fi
fi

# --- Report ---
if [[ $JSON -eq 1 ]]; then
    valid=true
    [[ ${#ERRORS[@]} -eq 0 ]] || valid=false
    printf '{"valid":%s,"bundle":"%s","pages":%d,"concepts":%d,"errors":[' \
        "$valid" "$(json_escape "$BUNDLE")" "$PAGE_COUNT" "$CONCEPT_COUNT"
    if [[ ${#ERRORS[@]} -gt 0 ]]; then
        for i in "${!ERRORS[@]}"; do
            [[ $i -gt 0 ]] && printf ','
            printf '"%s"' "$(json_escape "${ERRORS[$i]}")"
        done
    fi
    printf ']}\n'
else
    if [[ ${#ERRORS[@]} -gt 0 ]]; then
        echo "OKF bundle INVALID: $BUNDLE ($PAGE_COUNT pages, $CONCEPT_COUNT concepts)" >&2
        for e in "${ERRORS[@]}"; do
            echo "  - $e" >&2
        done
    else
        echo "OKF bundle valid: $BUNDLE ($PAGE_COUNT pages, $CONCEPT_COUNT concepts)"
    fi
fi

[[ ${#ERRORS[@]} -eq 0 ]] || exit 1
exit 0
