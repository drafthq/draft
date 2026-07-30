#!/usr/bin/env bash
# bench-grade.sh
#
# Walks prepared benchmark entries and records a grade per review run.
#
# Grading is human judgment; this only enforces the order of operations the
# protocol depends on. It shows the review report BEFORE the fix diff, because
# reading the fix first makes every vague finding look prescient. Appends rows
# in the exact shape bench-report.sh consumes.
#
# Usage:
#   scripts/benchmark/bench-grade.sh --corpus <corpus.tsv> --runs /tmp/bench
#   scripts/benchmark/bench-grade.sh --corpus <f> --runs <d> --out results.tsv
#
# Exit codes:
#   0  grading session completed
#   1  nothing to grade
#   2  usage / runtime error

set -euo pipefail

usage() {
    cat <<'EOF'
bench-grade.sh — record grades for prepared benchmark runs

Options:
  --corpus <file>  Corpus TSV used by bench-checkout.sh (required)
  --runs <dir>     Directory bench-checkout.sh wrote to (required)
  --out <file>     Results TSV to append to (default: <corpus dir>/results.tsv)
  --help, -h       Show this message

Per entry you are asked for: grade (caught|partial|missed), total findings, and
false positives. Reviews are shown before fixes, per protocol.
EOF
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    usage
    exit 0
fi

CORPUS=""
RUNS=""
OUT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --corpus) [[ -n "${2:-}" ]] || { echo "bench-grade: --corpus requires a value" >&2; exit 2; }; CORPUS="$2"; shift 2 ;;
        --runs)   [[ -n "${2:-}" ]] || { echo "bench-grade: --runs requires a value" >&2; exit 2; };   RUNS="$2"; shift 2 ;;
        --out)    [[ -n "${2:-}" ]] || { echo "bench-grade: --out requires a value" >&2; exit 2; };    OUT="$2"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) echo "bench-grade: unknown argument '$1'" >&2; usage >&2; exit 2 ;;
    esac
done

[[ -n "$CORPUS" ]] || { echo "bench-grade: --corpus is required" >&2; exit 2; }
[[ -n "$RUNS" ]]   || { echo "bench-grade: --runs is required" >&2; exit 2; }
[[ -f "$CORPUS" ]] || { echo "bench-grade: no such corpus file: $CORPUS" >&2; exit 2; }
[[ -d "$RUNS" ]]   || { echo "bench-grade: no such runs directory: $RUNS" >&2; exit 2; }

if [[ -z "$OUT" ]]; then
    OUT="$(dirname "$CORPUS")/results.tsv"
fi
if [[ ! -f "$OUT" ]]; then
    printf '# repo\tpr\tmode\tgrade\tfindings_total\tfindings_fp\n' > "$OUT"
fi

graded=0
skipped=0

while IFS=$'\t' read -r repo pr head_sha fix_sha issue severity desc; do
    [[ -z "${repo:-}" || "$repo" == \#* ]] && continue

    slug="$(printf '%s' "$repo" | tr '/:@' '---' | tr -s '-')-pr$pr"
    worktree="$RUNS/$slug"

    for mode in zero indexed; do
        report="$worktree/review-$mode.md"
        if [[ ! -f "$report" ]]; then
            echo "SKIP $repo#$pr [$mode] — no $report"
            skipped=$((skipped + 1))
            continue
        fi
        if grep -qP "^\Q$repo\E\t\Q$pr\E\t\Q$mode\E\t" "$OUT" 2>/dev/null; then
            echo "SKIP $repo#$pr [$mode] — already graded in $OUT"
            skipped=$((skipped + 1))
            continue
        fi

        echo ""
        echo "════════════════════════════════════════════════════════"
        echo " $repo#$pr  [$mode]   severity=${severity:-?}"
        echo "════════════════════════════════════════════════════════"
        echo ""
        echo "--- REVIEW REPORT (read this first) --------------------"
        "${PAGER:-less -R}" "$report" </dev/tty || cat "$report"

        echo ""
        echo "--- KNOWN DEFECT --------------------------------------"
        echo "${desc:-(no description in corpus)}"
        echo "issue: ${issue:-n/a}"
        echo ""
        echo "--- FIX DIFF ------------------------------------------"
        if [[ -d "$worktree/.git" ]]; then
            git -C "$worktree" show --stat "$fix_sha" 2>/dev/null || echo "(fix commit not fetched into this clone)"
        fi

        echo ""
        grade=""
        while [[ ! "$grade" =~ ^(caught|partial|missed)$ ]]; do
            printf 'grade (caught|partial|missed): '
            read -r grade </dev/tty
        done
        total=""
        while [[ ! "$total" =~ ^[0-9]+$ ]]; do
            printf 'total findings reported: '
            read -r total </dev/tty
        done
        fp=""
        while [[ ! "$fp" =~ ^[0-9]+$ ]] || [[ "$fp" -gt "$total" ]]; do
            printf 'of those, false positives (<= %s): ' "$total"
            read -r fp </dev/tty
        done

        printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$repo" "$pr" "$mode" "$grade" "$total" "$fp" >> "$OUT"
        graded=$((graded + 1))
        echo "recorded -> $OUT"
    done
done < "$CORPUS"

echo ""
echo "Graded $graded run(s), skipped $skipped."
if [[ "$graded" -gt 0 ]]; then
    echo "Report: scripts/benchmark/bench-report.sh --results $OUT"
fi

[[ "$graded" -gt 0 || "$skipped" -gt 0 ]] || exit 1
exit 0
