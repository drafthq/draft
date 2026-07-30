# Efficacy Benchmark — Protocol

Measures whether `/draft:review` catches defects that reached production, against pre-merge state, on a corpus we did not choose after seeing the results.

The central claim — three-stage review catches bugs a competent reviewer misses — is currently unfalsifiable. This makes it falsifiable. **Mediocre numbers published honestly beat no numbers**, and the protocol below is designed so that a bad result is still a publishable result.

## Design constraints

Five rules, each closing a way this benchmark could lie:

1. **Corpus frozen before any review runs.** Selection criteria are fixed, the corpus file is committed, and its commit precedes every run. Otherwise the corpus becomes a post-hoc filter for cases Draft happens to win.
2. **Pre-merge state only.** The review sees the PR head commit. The fix, the issue text, and the test that reproduces the bug are all in the future relative to that tree. `bench-checkout.sh` enforces this by checking out a detached head at the PR's merge-base child.
3. **The reviewer is blind.** Never paste the issue or the fix into the session that reviews. Grading happens afterward, from the review artifact.
4. **False positives counted, not discarded.** A tool with a 40% hit rate and 30 spurious findings per PR is not usable. Both numbers get published.
5. **Grading rubric fixed in advance.** See below. A finding either identifies the defect's mechanism or it does not; "sort of mentioned the area" is a miss.

## Corpus selection

Target: **20 merged PRs** with a known post-merge defect.

Inclusion criteria, all required:

- The PR merged, and a later commit fixed a defect introduced by it.
- The fix commit is linkable to the defect — a closing keyword, an issue reference, or a `Fixes:` trailer.
- The defect is in code, not in configuration, docs, or infrastructure.
- The PR diff is under ~800 changed lines. Larger PRs make attribution ambiguous.
- The repository builds and its tests run in a container without paid credentials.

Exclusion criteria:

- Defect found by a linter or type-checker that already ran in that repo's CI (nothing to prove).
- Defect reported more than 12 months after merge (attribution weakens).
- The fix also refactors, so the defect's mechanism cannot be isolated.

Sourcing: OSS repos with disciplined issue-to-commit links. Split the corpus across at least four repositories and three languages so the result is not one project's characteristics.

Record each entry in `corpus.tsv` (tab-separated, one PR per line):

```text
repo	pr	head_sha	fix_sha	issue	severity	one_line_defect_description
```

## Running

```bash
# 1. Freeze the corpus, then commit it before running anything.
git add docs/benchmark/corpus.tsv && git commit -m "bench: freeze 20-PR corpus"

# 2. Prepare a worktree per entry at pre-merge state.
scripts/benchmark/bench-checkout.sh --corpus docs/benchmark/corpus.tsv --out /tmp/bench

# 3. For each prepared worktree, run /draft:review in a fresh agent session and
#    save the report. This step is manual by necessity — the review is the model.
#    Save each as /tmp/bench/<repo>-<pr>/review.md
#
#    Run each entry twice: once zero-setup, once after /draft:init, so the graph's
#    contribution is measurable rather than assumed.

# 4. Grade. Interactive; writes results.tsv.
scripts/benchmark/bench-grade.sh --corpus docs/benchmark/corpus.tsv --runs /tmp/bench

# 5. Report.
scripts/benchmark/bench-report.sh --results docs/benchmark/results.tsv
```

## Grading rubric

For each corpus entry, classify the review's output:

| Grade | Meaning |
|---|---|
| `caught` | A finding names the defect's mechanism and its location. The reader of that finding would fix the bug. |
| `partial` | A finding flags the right lines but misattributes the cause, or flags the right cause without a location. |
| `missed` | No finding corresponds to the defect. |

Additionally, per entry:

- `findings_total` — every finding the review reported.
- `findings_fp` — findings that are wrong or that the project's own conventions accept. Judge against the repo's actual practice, not personal taste. When uncertain, count it as a false positive.

`partial` never counts toward the catch rate. It is reported separately because a partial hit still shortens debugging, but claiming it as a catch is the exact overreach this benchmark exists to avoid.

## Published metrics

```text
catch rate            = caught / N
partial rate          = partial / N
false-positive rate   = sum(findings_fp) / sum(findings_total)
precision             = 1 - false-positive rate
findings per PR       = sum(findings_total) / N
graph delta           = catch rate (indexed) - catch rate (zero-setup)
```

Publish all six, plus the corpus file and every review artifact. `graph delta` is the number that tests the moat: if indexing does not move the catch rate, the structural grounding claim needs revising, and that is worth knowing before a user discovers it.

## Threats to validity — state these in the writeup

- **Selection bias.** PRs with linkable post-merge fixes are not representative of all PRs; defects with clean issue links skew toward user-visible bugs.
- **Model variance.** The review is model-dependent. Record the model and date for every run; a result is a claim about a model version, not about markdown.
- **Grader bias.** The grader knows the defect. Mitigate by writing grades before reading the review's other findings, and by having a second grader re-grade a sample.
- **Repo familiarity.** Draft's own repo must not be in the corpus.
- **Single-shot runs.** One review per configuration under-samples a stochastic process. If the budget allows, run three and report the median.

## Status

Harness ready; corpus not yet collected. `corpus.tsv` and `results.tsv` are absent by design — committing a placeholder corpus would violate constraint 1.
