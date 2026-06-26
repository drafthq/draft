#!/usr/bin/env bash
# okf-coverage-check.sh — prove the OKF bundle documents EVERY required component.
#
# This is the gate that fixes "the wiki is not generated completely for all
# modules". It compares the deterministic expected set (concept-plan.json from
# okf-plan-concepts.sh) against the pages that actually exist in the bundle. A
# required concept with no page — or a present-but-empty page — fails the build,
# so a gappy bundle cannot be promoted (draft.tmp/ → draft/). Deferred entries
# must be reasoned in the generated coverage.md, never silently absent.
#
# Checks:
#   C-PLAN   every required plan entry has a bundle page (concept_id exists)
#   C-STUB   each satisfying page has real body content (>= --min-stub-lines)
#   C-DEFER  every deferred entry is recorded with a reason (always true: from plan)
#
# Side effect: regenerates <BUNDLE>/systems/coverage.md (tool-owned) unless
# --no-coverage-page is given.
#
# Usage:
#   okf-coverage-check.sh --plan FILE --bundle DIR [--min-stub-lines N]
#                         [--no-coverage-page] [--json] [--report FILE]
#
# Exit codes: 0 complete, 1 incomplete (missing/stub required), 2 plan/bundle missing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/tools/_lib.sh
source "$SCRIPT_DIR/_lib.sh"

PLAN=""
BUNDLE=""
MIN_STUB_LINES=10
WRITE_PAGE=1
JSON=0
REPORT=""

usage() {
    cat <<'EOF'
okf-coverage-check.sh — verify every required concept in the plan has a real page.

Usage:
  okf-coverage-check.sh --plan FILE --bundle DIR [--min-stub-lines N]
                        [--no-coverage-page] [--json] [--report FILE]

Flags:
  --plan FILE          concept-plan.json from okf-plan-concepts.sh (required).
  --bundle DIR         The wiki/ bundle directory (required).
  --min-stub-lines N   Min non-blank body lines for a page to count as real (default 10).
  --no-coverage-page   Do not (re)write <BUNDLE>/systems/coverage.md.
  --json               Emit a JSON summary.
  --report FILE        Also write the JSON summary to FILE.
  --help               Show this help.

Exit: 0 complete, 1 incomplete, 2 plan/bundle not found.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --plan) PLAN="$2"; shift 2;;
        --bundle) BUNDLE="$2"; shift 2;;
        --min-stub-lines) MIN_STUB_LINES="$2"; shift 2;;
        --no-coverage-page) WRITE_PAGE=0; shift;;
        --json) JSON=1; shift;;
        --report) REPORT="$2"; shift 2;;
        --help|-h) usage; exit 0;;
        -*) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
        *) echo "Unexpected arg: $1" >&2; usage >&2; exit 1;;
    esac
done

[[ -n "$PLAN" ]] || { usage >&2; exit 1; }
[[ -n "$BUNDLE" ]] || { usage >&2; exit 1; }
[[ -f "$PLAN" ]] || { echo "ERROR: plan not found: $PLAN" >&2; exit 2; }
[[ -d "$BUNDLE" ]] || { echo "ERROR: bundle directory not found: $BUNDLE" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required" >&2; exit 2; }
BUNDLE="${BUNDLE%/}"

jq -e '.expected' "$PLAN" >/dev/null 2>&1 || { echo "ERROR: plan has no .expected array: $PLAN" >&2; exit 2; }

# Non-blank body line count for a page.
body_lines() {
    awk 'NR==1&&/^---$/{fm=1;next} fm&&/^---$/{fm=0;next} !fm{print}' "$1" | grep -cE '.' || true
}

MISSING=()      # concept_id (required, no page)
STUB=()         # concept_id\tlines (required, page too thin)
FULL=()         # concept_id
DEFERRED=()     # concept_id\treason
EXPECTED_TOTAL=0; REQUIRED=0

# Iterate expected entries.
while IFS=$'\t' read -r cid required reason ftype fanin; do
    [[ -z "$cid" ]] && continue
    EXPECTED_TOTAL=$((EXPECTED_TOTAL + 1))
    if [[ "$required" == "true" ]]; then
        REQUIRED=$((REQUIRED + 1))
        if [[ -f "$BUNDLE/$cid" ]]; then
            bl="$(body_lines "$BUNDLE/$cid")"
            if [[ "$bl" -ge "$MIN_STUB_LINES" ]]; then
                FULL+=("$cid")
            else
                STUB+=("$cid"$'\t'"$bl")
            fi
        else
            MISSING+=("$cid")
        fi
    else
        DEFERRED+=("$cid"$'\t'"${reason:-unspecified}")
    fi
done < <(jq -r '.expected[] | [.concept_id, (.required|tostring), (.reason_if_deferred // "-"), (.type // "Module"), (.fan_in // 0 | tostring)] | @tsv' "$PLAN")

MAPPED=$(( ${#FULL[@]} ))
PASS=1
{ [[ ${#MISSING[@]} -gt 0 ]] || [[ ${#STUB[@]} -gt 0 ]]; } && PASS=0
PCT=100
[[ $REQUIRED -gt 0 ]] && PCT=$(( MAPPED * 100 / REQUIRED ))

# --- Generate coverage.md (tool-owned) ---
write_coverage_page() {
    local out="$BUNDLE/systems/coverage.md"
    mkdir -p "$BUNDLE/systems"
    local tmp; tmp="$(mktemp)"
    {
        # OKF §9.1/§9.2: every non-reserved .md needs parseable frontmatter with a
        # non-empty `type`. coverage.md is tool-generated and not a code concept, so
        # it uses a descriptive (non-frozen) type; okf-validate.sh exempts it from the
        # frozen-vocab check via is_meta_page (basename + the marker below).
        echo "---"
        echo "type: Report"
        echo "title: Component Coverage"
        echo "description: Coverage of required components by wiki pages — which are documented, stubbed, or missing."
        echo "resource: ."
        echo "---"
        echo ""
        echo "<!-- okf:coverage-generated -->"
        echo "# Component Coverage"
        echo ""
        echo "> Generated by \`okf-coverage-check.sh\` — do not hand-edit (except deferral reasons in the manifest)."
        echo "> Required components documented: ${MAPPED}/${REQUIRED} (${PCT}%)."
        echo ""
        echo "| Component | Wiki page | Status | Fan-in |"
        echo "|-----------|-----------|--------|--------|"
        local cid status fanin link
        while IFS=$'\t' read -r cid required reason ftype fanin; do
            [[ -z "$cid" ]] && continue
            if [[ "$required" == "true" ]]; then
                if [[ -f "$BUNDLE/$cid" ]]; then
                    bl="$(body_lines "$BUNDLE/$cid")"
                    # coverage.md lives in systems/; link relative to it. Concepts in
                    # other sections (entrypoints/, reference/, …) need a ../ prefix,
                    # otherwise the link dangles and fails structure validation.
                    case "$cid" in
                        systems/*) link="${cid#systems/}";;
                        *)         link="../$cid";;
                    esac
                    if [[ "$bl" -ge "$MIN_STUB_LINES" ]]; then
                        echo "| \`${cid%.md}\` | [page](${link}) | Full | ${fanin} |"
                    else
                        echo "| \`${cid%.md}\` | ${cid} | **STUB (${bl} lines)** | ${fanin} |"
                    fi
                else
                    echo "| \`${cid%.md}\` | — | **MISSING** | ${fanin} |"
                fi
            else
                echo "| \`${cid%.md}\` | — | Deferred (${reason:-unspecified}) | ${fanin} |"
            fi
        done < <(jq -r '.expected[] | [.concept_id, (.required|tostring), (.reason_if_deferred // "-"), (.type // "Module"), (.fan_in // 0 | tostring)] | @tsv' "$PLAN")
    } > "$tmp"
    mv "$tmp" "$out"
}
[[ $WRITE_PAGE -eq 1 ]] && write_coverage_page

# --- Report ---
emit_json() {
    printf '{"valid":%s,"bundle":"%s","plan":"%s","required":%d,"mapped":%d,"coverage_pct":%d,"missing":[' \
        "$([[ $PASS -eq 1 ]] && echo true || echo false)" \
        "$(json_escape "$BUNDLE")" "$(json_escape "$PLAN")" "$REQUIRED" "$MAPPED" "$PCT"
    for i in "${!MISSING[@]}"; do [[ $i -gt 0 ]] && printf ','; printf '"%s"' "$(json_escape "${MISSING[$i]}")"; done
    printf '],"stub":['
    local first=1
    for s in "${STUB[@]:-}"; do
        [[ -z "$s" ]] && continue
        IFS=$'\t' read -r cid bl <<< "$s"
        [[ $first -eq 1 ]] && first=0 || printf ','
        printf '{"concept_id":"%s","lines":%d}' "$(json_escape "$cid")" "$bl"
    done
    printf '],"deferred":%d}\n' "${#DEFERRED[@]}"
}

if [[ -n "$REPORT" ]]; then mkdir -p "$(dirname "$REPORT")"; emit_json > "$REPORT"; fi

if [[ $JSON -eq 1 ]]; then
    emit_json
else
    if [[ $PASS -eq 1 ]]; then
        echo "OKF coverage complete: ${MAPPED}/${REQUIRED} required components (${PCT}%), ${#DEFERRED[@]} deferred"
    else
        echo "OKF coverage INCOMPLETE: ${MAPPED}/${REQUIRED} required (${PCT}%)" >&2
        for m in "${MISSING[@]:-}"; do [[ -n "$m" ]] && echo "  - MISSING: $m" >&2; done
        for s in "${STUB[@]:-}"; do
            [[ -z "$s" ]] && continue
            IFS=$'\t' read -r cid bl <<< "$s"
            echo "  - STUB: $cid ($bl body lines < $MIN_STUB_LINES)" >&2
        done
    fi
fi

[[ $PASS -eq 1 ]] || exit 1
exit 0
