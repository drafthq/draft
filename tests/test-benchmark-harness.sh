#!/usr/bin/env bash
# Test suite for scripts/benchmark/ (the efficacy-benchmark harness).
#
# What this tests:
# - The protocol doc exists and references only scripts that exist
# - bench-checkout.sh refuses a corpus row whose fix is reachable from the
#   reviewed tree (the assertion the whole benchmark rests on)
# - A valid row produces a detached checkout that does NOT contain the fix
# - bench-report.sh computes catch rate / precision / graph delta correctly
# - bench-report.sh rejects invalid grades, modes, and impossible FP counts
# - No committed corpus/results (protocol constraint 1: freeze before running)
#
# Usage:
#   ./tests/test-benchmark-harness.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BENCH="$ROOT_DIR/scripts/benchmark"
PROTOCOL="$ROOT_DIR/docs/internal/benchmark/README.md"

source "$SCRIPT_DIR/test-helpers.sh"
cd "$ROOT_DIR"

echo "=== Benchmark harness tests ==="
echo ""

echo "## Scripts present and well-formed"
for s in bench-checkout.sh bench-grade.sh bench-report.sh; do
    assert "$s exists and is executable" "$([[ -x "$BENCH/$s" ]] && echo true || echo false)"
    assert "$s parses" "$(bash -n "$BENCH/$s" 2>/dev/null && echo true || echo false)"
    assert "$s uses 'set -euo pipefail'" "$(grep -q '^set -euo pipefail' "$BENCH/$s" && echo true || echo false)"
    assert "$s supports --help" "$("$BENCH/$s" --help >/dev/null 2>&1 && echo true || echo false)"
done

echo ""
echo "## Protocol doc"
assert "protocol doc exists" "$([[ -f "$PROTOCOL" ]] && echo true || echo false)"
assert "states the 20-PR target" "$(grep -q '20 merged PRs' "$PROTOCOL" && echo true || echo false)"
assert "requires the corpus frozen before runs" "$(grep -qi 'frozen before any review runs' "$PROTOCOL" && echo true || echo false)"
assert "commits to counting false positives" "$(grep -qi 'False positives counted' "$PROTOCOL" && echo true || echo false)"
assert "lists threats to validity" "$(grep -q 'Threats to validity' "$PROTOCOL" && echo true || echo false)"
# Every script the protocol tells a reader to run must exist.
missing=""
while IFS= read -r ref; do
    [[ -f "$ROOT_DIR/$ref" ]] || missing="$missing $ref"
done < <(grep -oE 'scripts/benchmark/[a-z-]+\.sh' "$PROTOCOL" | sort -u)
if [[ -n "$missing" ]]; then
    assert "protocol references only existing scripts" "false"
    echo "  missing:$missing"
else
    assert "protocol references only existing scripts" "true"
fi

echo ""
echo "## Pre-merge isolation (the load-bearing guard)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
(
    cd "$tmp" && mkdir synth && cd synth
    git init -q .
    git config user.email t@t.t
    git config user.name t
    echo v1 > a.txt;     git add -A; git commit -qm base
    echo buggy > a.txt;  git add -A; git commit -qm "pr head"
    git rev-parse HEAD > "$tmp/head_sha"
    echo fixed > a.txt;  git add -A; git commit -qm fix
    git rev-parse HEAD > "$tmp/fix_sha"
) >/dev/null 2>&1
head_sha="$(cat "$tmp/head_sha")"
fix_sha="$(cat "$tmp/fix_sha")"

printf 'file://%s/synth\t1\t%s\t%s\t#1\tP1\tbug in a.txt\n' "$tmp" "$head_sha" "$fix_sha" > "$tmp/good.tsv"
printf 'file://%s/synth\t1\t%s\t%s\t#1\tP1\tinverted\n'     "$tmp" "$fix_sha" "$head_sha" > "$tmp/bad.tsv"

if "$BENCH/bench-checkout.sh" --corpus "$tmp/good.tsv" --out "$tmp/good" >"$tmp/good.log" 2>&1; then
    assert "valid corpus row prepares a worktree" "true"
else
    assert "valid corpus row prepares a worktree" "false"
    tail -n 5 "$tmp/good.log"
fi
content="$(cat "$tmp/good"/*-pr1/a.txt 2>/dev/null || true)"
assert "reviewed tree holds the pre-fix content ('$content')" \
    "$([[ "$content" == "buggy" ]] && echo true || echo false)"
wt="$(find "$tmp/good" -maxdepth 1 -name '*-pr1' -type d | head -n 1)"
assert "checkout is detached (no branch)" \
    "$([[ -n "$wt" ]] && [[ -z "$(git -C "$wt" symbolic-ref --quiet HEAD || true)" ]] && echo true || echo false)"
assert "metadata file written for the grader" \
    "$([[ -f "$tmp/good/$(basename "$wt").meta" ]] && echo true || echo false)"
assert "metadata records the fix sha" \
    "$(grep -q "fix_sha=$fix_sha" "$tmp/good/$(basename "$wt").meta" && echo true || echo false)"

set +e
"$BENCH/bench-checkout.sh" --corpus "$tmp/bad.tsv" --out "$tmp/bad" >"$tmp/bad.log" 2>&1
bad_rc=$?
set -e
assert "row whose fix precedes head is rejected (exit $bad_rc)" \
    "$([[ "$bad_rc" -eq 1 ]] && echo true || echo false)"
assert "rejection explains the leak" \
    "$(grep -q 'the tree contains the answer' "$tmp/bad.log" && echo true || echo false)"

echo ""
echo "## Metric computation"
cat > "$tmp/results.tsv" <<'EOF'
# repo	pr	mode	grade	findings_total	findings_fp
a/b	1	zero	caught	10	2
a/b	2	zero	missed	10	3
a/b	3	zero	partial	10	5
a/b	1	indexed	caught	10	1
a/b	2	indexed	caught	10	1
a/b	3	indexed	partial	10	2
EOF
report="$("$BENCH/bench-report.sh" --results "$tmp/results.tsv")"
# zero: 1 caught / 3 = 33%; FP 10/30 -> precision 67%
# indexed: 2 caught / 3 = 67%; FP 4/30 -> precision 87%
assert "zero-setup catch rate is 33%" \
    "$(grep -E '^zero' <<< "$report" | grep -q '33%' && echo true || echo false)"
assert "indexed catch rate is 67%" \
    "$(grep -E '^indexed' <<< "$report" | grep -q '67%' && echo true || echo false)"
assert "zero-setup precision is 67%" \
    "$(grep -E '^zero' <<< "$report" | grep -q '67%' && echo true || echo false)"
assert "indexed precision is 87%" \
    "$(grep -E '^indexed' <<< "$report" | grep -q '87%' && echo true || echo false)"
assert "graph delta is reported" \
    "$(grep -q 'Graph delta: +33.3 pp' <<< "$report" && echo true || echo false)"
assert "partial exclusion is stated in the output" \
    "$(grep -qi 'Partial grades are excluded' <<< "$report" && echo true || echo false)"
# Capture first: `| grep -q` closes the pipe early, and under pipefail that
# surfaces as a SIGPIPE failure of the producer rather than a clean match.
md_report="$("$BENCH/bench-report.sh" --results "$tmp/results.tsv" --markdown)"
assert "markdown mode emits a table" \
    "$(grep -q '^| Mode |' <<< "$md_report" && echo true || echo false)"

echo ""
echo "## Invalid results are fatal, not silently dropped"
for row in \
    'a/b	1	zero	bogus	3	1' \
    'a/b	1	sideways	caught	3	1' \
    'a/b	1	zero	caught	x	1' \
    'a/b	1	zero	caught	3	9'
do
    printf '%s\n' "$row" > "$tmp/one.tsv"
    set +e
    "$BENCH/bench-report.sh" --results "$tmp/one.tsv" >/dev/null 2>&1
    rc=$?
    set -e
    assert "rejects row '$(cut -f4,5,6 <<< "$row" | tr '\t' '/')' (exit $rc)" \
        "$([[ "$rc" -eq 2 ]] && echo true || echo false)"
done

set +e
: > "$tmp/empty.tsv"
"$BENCH/bench-report.sh" --results "$tmp/empty.tsv" >/dev/null 2>&1
rc=$?
set -e
assert "empty results exit 1" "$([[ "$rc" -eq 1 ]] && echo true || echo false)"

echo ""
echo "## Usage errors exit 2"
for args in "--results /nonexistent.tsv" "--bogus"; do
    set +e
    # shellcheck disable=SC2086  # intentional word splitting
    "$BENCH/bench-report.sh" $args >/dev/null 2>&1
    rc=$?
    set -e
    assert "bench-report '$args' exits 2" "$([[ "$rc" -eq 2 ]] && echo true || echo false)"
done
set +e
"$BENCH/bench-checkout.sh" --out "$tmp/x" >/dev/null 2>&1
rc=$?
set -e
assert "bench-checkout without --corpus exits 2" "$([[ "$rc" -eq 2 ]] && echo true || echo false)"

echo ""
echo "## Corpus is not pre-committed (protocol constraint 1)"
assert "no committed corpus.tsv" \
    "$(git ls-files --error-unmatch docs/internal/benchmark/corpus.tsv >/dev/null 2>&1 && echo false || echo true)"
assert "no committed results.tsv" \
    "$(git ls-files --error-unmatch docs/internal/benchmark/results.tsv >/dev/null 2>&1 && echo false || echo true)"

finish_test "benchmark harness"
