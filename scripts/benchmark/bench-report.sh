#!/usr/bin/env bash
# bench-report.sh
#
# Turns graded benchmark results into the publishable metric table.
#
# Deliberately does no interpretation: it computes catch rate, partial rate,
# false-positive rate, findings per PR, and the graph delta, then prints them.
# Every metric the protocol promises is emitted, including the unflattering
# ones — a report that can only produce good news is not evidence.
#
# Results format (tab-separated, '#' comments and blank lines ignored):
#   repo <TAB> pr <TAB> mode <TAB> grade <TAB> findings_total <TAB> findings_fp
# mode  : zero | indexed
# grade : caught | partial | missed
#
# Usage:
#   scripts/benchmark/bench-report.sh --results docs/internal/benchmark/results.tsv
#   scripts/benchmark/bench-report.sh --results <f> --markdown > report.md
#
# Exit codes:
#   0  report produced
#   1  no usable rows
#   2  usage / runtime error

set -euo pipefail

usage() {
    cat <<'EOF'
bench-report.sh — compute publishable metrics from graded benchmark results

Options:
  --results <file>  Results TSV (required)
  --markdown        Emit a Markdown table instead of plain text
  --help, -h        Show this message
EOF
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    usage
    exit 0
fi

RESULTS=""
MARKDOWN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --results) [[ -n "${2:-}" ]] || { echo "bench-report: --results requires a value" >&2; exit 2; }; RESULTS="$2"; shift 2 ;;
        --markdown) MARKDOWN=1; shift ;;
        --help|-h) usage; exit 0 ;;
        *) echo "bench-report: unknown argument '$1'" >&2; usage >&2; exit 2 ;;
    esac
done

[[ -n "$RESULTS" ]]  || { echo "bench-report: --results is required" >&2; exit 2; }
[[ -f "$RESULTS" ]]  || { echo "bench-report: no such results file: $RESULTS" >&2; exit 2; }

# One awk pass per mode; the shell only formats. Invalid grades/modes are fatal
# rather than silently dropped — a typo'd grade would inflate the denominator's
# complement and quietly improve the numbers.
metrics="$(awk -F'\t' '
    /^#/ || NF == 0 { next }
    {
        mode = $3; grade = $4; total = $5; fp = $6
        if (mode != "zero" && mode != "indexed") {
            printf "bench-report: row %d has invalid mode \"%s\"\n", NR, mode > "/dev/stderr"; bad = 1; next
        }
        if (grade != "caught" && grade != "partial" && grade != "missed") {
            printf "bench-report: row %d has invalid grade \"%s\"\n", NR, grade > "/dev/stderr"; bad = 1; next
        }
        if (total !~ /^[0-9]+$/ || fp !~ /^[0-9]+$/) {
            printf "bench-report: row %d has non-numeric finding counts\n", NR > "/dev/stderr"; bad = 1; next
        }
        if (fp > total) {
            printf "bench-report: row %d has more false positives than findings\n", NR > "/dev/stderr"; bad = 1; next
        }
        n[mode]++
        g[mode "," grade]++
        f[mode] += total
        x[mode] += fp
    }
    END {
        if (bad) exit 3
        for (m = 1; m <= 2; m++) {
            mode = (m == 1 ? "zero" : "indexed")
            if (n[mode] == 0) continue
            printf "%s\t%d\t%d\t%d\t%d\t%d\t%d\n", mode, n[mode], \
                g[mode ",caught"] + 0, g[mode ",partial"] + 0, g[mode ",missed"] + 0, \
                f[mode] + 0, x[mode] + 0
        }
    }
' "$RESULTS")" || { echo "bench-report: results file has invalid rows — fix them and re-run" >&2; exit 2; }

[[ -n "$metrics" ]] || { echo "bench-report: no usable rows in $RESULTS" >&2; exit 1; }

pct() { awk -v a="$1" -v b="$2" 'BEGIN { if (b == 0) print "n/a"; else printf "%.0f%%", 100 * a / b }'; }
per() { awk -v a="$1" -v b="$2" 'BEGIN { if (b == 0) print "n/a"; else printf "%.1f", a / b }'; }

# Keep raw counts, not the rounded percentages: differencing two values that
# were each rounded to 1dp shifts the delta by up to 0.1pp.
declare -A CAUGHT_N
declare -A TOTAL_N
if [[ "$MARKDOWN" -eq 1 ]]; then
    echo "| Mode | N | Caught | Partial | Missed | Catch rate | Precision | Findings/PR |"
    echo "|---|---|---|---|---|---|---|---|"
else
    printf '%-9s %3s %7s %8s %7s %11s %10s %12s\n' MODE N CAUGHT PARTIAL MISSED CATCH PRECISION FINDINGS/PR
fi

while IFS=$'\t' read -r mode n caught partial missed total fp; do
    [[ -n "$mode" ]] || continue
    catch="$(pct "$caught" "$n")"
    prec="$(pct "$((total - fp))" "$total")"
    fppr="$(per "$total" "$n")"
    CAUGHT_N["$mode"]="$caught"
    TOTAL_N["$mode"]="$n"
    if [[ "$MARKDOWN" -eq 1 ]]; then
        echo "| $mode | $n | $caught | $partial | $missed | $catch | $prec | $fppr |"
    else
        printf '%-9s %3s %7s %8s %7s %11s %10s %12s\n' "$mode" "$n" "$caught" "$partial" "$missed" "$catch" "$prec" "$fppr"
    fi
done <<< "$metrics"

# The graph delta is the claim under test: does indexing actually move the
# catch rate? Report it even when it is zero or negative.
if [[ "${TOTAL_N[zero]:-0}" -gt 0 && "${TOTAL_N[indexed]:-0}" -gt 0 ]]; then
    delta="$(awk -v ic="${CAUGHT_N[indexed]}" -v it="${TOTAL_N[indexed]}" \
                 -v zc="${CAUGHT_N[zero]}"    -v zt="${TOTAL_N[zero]}" \
                 'BEGIN { printf "%+.1f", 100 * (ic / it - zc / zt) }')"
    echo ""
    if [[ "$MARKDOWN" -eq 1 ]]; then
        echo "**Graph delta:** ${delta} percentage points (indexed catch rate minus zero-setup)."
    else
        echo "Graph delta: ${delta} pp (indexed minus zero-setup catch rate)"
    fi
else
    echo ""
    echo "Graph delta: not computable — needs rows in both zero and indexed modes."
fi

echo ""
echo "Partial grades are excluded from the catch rate by design (see docs/internal/benchmark/README.md)."
