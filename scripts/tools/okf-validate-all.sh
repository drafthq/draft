#!/usr/bin/env bash
# okf-validate-all.sh — single promotion gate for the OKF emitter.
#
# Runs the three validation layers in order and aggregates one verdict. The init
# / refresh pipeline conditions the atomic `mv draft.tmp/ draft/` on this exit
# code, so a bundle that is structurally broken, full of stubs, or missing
# required components is never promoted.
#
#   Layer 1  okf-validate.sh          structure (frontmatter, types, links, index)
#   Layer 2  okf-validate-quality.sh  per-type anti-stub / depth / mermaid lint
#   Layer 3  okf-coverage-check.sh    every required plan entry has a real page
#
# Usage:
#   okf-validate-all.sh <BUNDLE_DIR> [--plan FILE] [--path-index FILE]
#                       [--strict] [--report FILE] [--json]
#
# Layer 3 runs only when --plan is given (init/refresh always pass it). CI runs
# without a plan get layers 1–2.
#
# Exit codes: 0 all pass, 1 any layer failed, 2 bundle not found.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/tools/_lib.sh
source "$SCRIPT_DIR/_lib.sh"

BUNDLE=""
PLAN=""
PATH_INDEX=""
STRICT=0
REPORT=""
JSON=0

usage() {
    cat <<'EOF'
okf-validate-all.sh — run all OKF validation layers as one promotion gate.

Usage:
  okf-validate-all.sh <BUNDLE_DIR> [--plan FILE] [--path-index FILE]
                      [--strict] [--report FILE] [--json]

Flags:
  --plan FILE        concept-plan.json — enables Layer 3 (coverage).
  --path-index FILE  path-to-concept.json — enables index checks in Layer 1.
  --strict           Pass --strict to the quality layer (warnings → failures).
  --report FILE      Write an aggregated JSON report here.
  --json             Emit the aggregated JSON report to stdout.
  --help             Show this help.

Exit: 0 all pass, 1 any layer failed, 2 bundle not found.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --plan) PLAN="$2"; shift 2;;
        --path-index) PATH_INDEX="$2"; shift 2;;
        --strict) STRICT=1; shift;;
        --report) REPORT="$2"; shift 2;;
        --json) JSON=1; shift;;
        --help|-h) usage; exit 0;;
        -*) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
        *) if [[ -z "$BUNDLE" ]]; then BUNDLE="$1"; else echo "Unexpected arg: $1" >&2; exit 1; fi; shift;;
    esac
done

[[ -n "$BUNDLE" ]] || { usage >&2; exit 1; }
[[ -d "$BUNDLE" ]] || { echo "ERROR: bundle directory not found: $BUNDLE" >&2; exit 2; }

L1=skip; L2=skip; L3=skip
OVERALL=0

run_layer() {
    local name="$1"; shift
    set +e
    "$@" >/dev/null 2>&1
    local rc=$?
    set -e
    return $rc
}

# Layer 1: structure.
v1_args=("$BUNDLE")
[[ -n "$PATH_INDEX" ]] && v1_args+=(--path-index "$PATH_INDEX")
if run_layer structure "$SCRIPT_DIR/okf-validate.sh" "${v1_args[@]}"; then L1=pass; else L1=fail; OVERALL=1; fi

# Layer 2: quality.
q_args=("$BUNDLE"); [[ $STRICT -eq 1 ]] && q_args+=(--strict)
if run_layer quality "$SCRIPT_DIR/okf-validate-quality.sh" "${q_args[@]}"; then L2=pass; else L2=fail; OVERALL=1; fi

# Layer 3: coverage (only if a plan is supplied).
if [[ -n "$PLAN" ]]; then
    if run_layer coverage "$SCRIPT_DIR/okf-coverage-check.sh" --plan "$PLAN" --bundle "$BUNDLE"; then
        L3=pass
    else
        L3=fail; OVERALL=1
    fi
fi

REPORT_JSON="$(printf '{"valid":%s,"bundle":"%s","layers":{"structure":"%s","quality":"%s","coverage":"%s"}}\n' \
    "$([[ $OVERALL -eq 0 ]] && echo true || echo false)" "$(json_escape "$BUNDLE")" "$L1" "$L2" "$L3")"

[[ -n "$REPORT" ]] && { mkdir -p "$(dirname "$REPORT")"; printf '%s' "$REPORT_JSON" > "$REPORT"; }

if [[ $JSON -eq 1 ]]; then
    printf '%s' "$REPORT_JSON"
else
    echo "OKF validation — structure:$L1 quality:$L2 coverage:$L3 → $([[ $OVERALL -eq 0 ]] && echo PASS || echo FAIL)"
    if [[ $OVERALL -ne 0 ]]; then
        echo "  Re-run the failing layer directly for detail:" >&2
        [[ "$L1" == fail ]] && echo "    okf-validate.sh $BUNDLE ${PATH_INDEX:+--path-index $PATH_INDEX}" >&2
        [[ "$L2" == fail ]] && echo "    okf-validate-quality.sh $BUNDLE" >&2
        [[ "$L3" == fail ]] && echo "    okf-coverage-check.sh --plan $PLAN --bundle $BUNDLE" >&2
    fi
fi

exit $OVERALL
