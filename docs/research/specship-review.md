# SpecShip Review — and the Path to Autonomous Draft

**Subject:** [aws-samples/sample-specship](https://github.com/aws-samples/sample-specship) (Kiro Power, MIT)
**Reviewed against:** Draft 4.0.0 — goal of epic-to-PR autonomous development
**Date:** 2026-09-12

---

## Bottom line

SpecShip's value is not its pipeline. Draft already has every phase SpecShip has, plus better
inputs. SpecShip's value is that it made three things **machine-checkable** that Draft still
takes on the agent's word:

1. **Phase transitions** — `process-checker.js --phase plan|build|ship` exits non-zero and blocks.
2. **Validator independence** — a verdict must attest `independent: true` + a `method`, or it is not counted.
3. **Test evidence** — `tests: "pass"` without a `tests_command` and an on-disk `tests_log` is a hard FAIL.

Autonomy is an **enforcement** problem, not a prompting problem. Draft has 55 deterministic tools
and a knowledge graph; SpecShip has one 396-line Node script — and SpecShip is the one that can
run unattended, because its gates are exit codes and its state is on disk.

The work to take Draft autonomous is four tracks, and three of them are shell tools, not prose.

---

## What SpecShip actually is

A 5-phase pipeline (`recon → plan → build → validate → ship`) expressed as 21 Kiro steering files
plus one enforcement binary. The mechanisms worth naming:

| Mechanism | Implementation | Why it matters |
|---|---|---|
| **Deterministic phase gate** | `process-checker.js --phase <p>`, exit code + reasons | The agent cannot talk its way past a transition |
| **Externalized mission state** | `.specship/state.json`, canonical schema, temp-file+rename, `.bak` | Survives context compaction; `last_commit` detects a stale state file |
| **Typed verdicts** | `.specship/artifacts/verdicts/<name>.json` — `status`, `blocking_issues[]`, `evidence[]`, `independent`, `method` | Validation output is data, not prose — downstream code can decide on it |
| **Derived validator set** | `expected-validators.txt` written at build→validate handoff | "None were skipped" becomes checkable, not remembered |
| **Evidence corroboration** | `build-status.json` needs `tests_command` + an existing `tests_log`; strict by default | Kills the self-written green flag (their threat T17) |
| **Independence attestation** | verdict rejected unless `independent: true` and `method` non-empty | Kills the builder grading its own work (T18) |
| **Fan-out / fan-in** | one `subagent` call, N validator stages + an `aggregate` stage with `depends_on` | Parallel validation, single decision point |
| **Bounded recovery** | `recovery_attempts` cycle counter in state (explicitly *not* a git-log grep), `dispatch_budget` per task, max 3 | Loops terminate |
| **Refutation gate** | Design/low-confidence-Security FAILs get one skeptic pass before recovery | Bounds false-positive churn on the hallucination-prone classes |
| **Completeness critic** | On all-PASS, one pass asks which acceptance criterion *no validator covered* | Closes the false-PASS hole |
| **SCM boundary** | Rule 17: never push/merge without a fresh human yes; autonomous deliverable is a **PR** | Autonomy skips approval gates, never the credential boundary |
| **Injection defense** | Rule 19: ingested repo/web/issue text is data, never instruction | Necessary once tickets feed the loop |

Two of their design notes are worth stealing verbatim as *reasoning*, not just code:

- The recovery counter must be a **cycle counter in state**, never a count of `[fix]` commits — one
  6-issue cycle emits 6 commits and would falsely exhaust a budget of 3.
- Gap detection must **compute** `found/total`, not ask the agent to self-assess completeness.

---

## Where Draft already wins

| Capability | Draft | SpecShip |
|---|---|---|
| Structural understanding | `codebase-memory-mcp` + 13 `graph-*.sh` wrappers — real call graphs, blast radius, test edges | `grep` for marker terms |
| Determinism surface | 55 shell tools, 81 test suites | 1 Node checker + 1 verify script |
| Gate chain | 6-tool `verification-gates` chain, exit-code, `--json` | plan/build/ship artifact assertions |
| Citation integrity | `verify-citations.sh` — every `path:line` resolves against `synced_to_commit` | none |
| Scope collision | `check-scope-conflicts.sh` across adjacent tracks | no concept of concurrent missions |
| Brownfield context | discovery → architecture/OKF wiki → `.ai-context.md` → per-track `impact` block | one-shot reverse-engineering artifact |
| Issue tracker | real Jira MCP integration (`preview`/`create`/`review`) | none |

Draft's inputs are strictly better. Its **outputs are prose** — and prose cannot gate a loop.

---

## The five structural gaps

1. **No execution state.** `draft/.state/` holds init/refresh state (`freshness`, `signals`,
   `facts`, `run-memory`), not mission state. `metadata.json` counts phases and tasks but has no
   `next_task`, no `last_commit`, no `recovery_attempts`, and no atomic-write contract. Compaction
   mid-`/draft:implement` loses the run.

2. **Gates are advisory.** `metadata.json:pre_deploy_status` is a field the agent writes about
   itself. `/draft:deploy-checklist` then reads that field. Nothing proves the chain ran, and
   nothing carries the command or log that would prove it. This is exactly SpecShip's T17.

3. **Review is self-review.** `/draft:review` runs in the session that wrote the code, emits a
   markdown report, and sets `lastReviewVerdict`. There is no independence attestation, no
   per-validator artifact, and no machine-readable blocking-issue list. Nothing downstream can
   branch on it.

4. **No recovery loop.** Review surfaces issues to a human. There is no budgeted fix cycle, no
   escalation rule, no "3 strikes then stop."

5. **No inbound Jira path, and `parallel-fanout.md` is a stub.** Jira flows outward
   (`preview`/`create`); `jira review <ID>` reads a ticket and terminates in a report. The
   fan-out/fan-in primitive autonomy requires is an 8-line placeholder.

Underneath all five sits a stated stance — `core/methodology.md:162`: *"The AI becomes an executor
of pre-approved work, not an autonomous decision-maker."* That premise is correct and should
**not** be deleted. It should be re-scoped: approval moves from **per-task** to **per-contract**.
The human approves the spec and its acceptance criteria once; the loop executes against that
contract and stops at a draft PR.

---

## Proposed design — `/draft:auto`

```text
/draft:auto <JIRA-EPIC-ID> [--unattended] [--tracks <id,...>] [--resume]
```

**Pipeline:** `INTAKE → DECOMPOSE → CONTRACT ⟨human gate⟩ → BUILD → VALIDATE → RECOVER → SHIP`

The orchestrator writes **no logic of its own**. Every phase dispatches an existing skill:

| Phase | Dispatches | Gate to exit the phase |
|---|---|---|
| INTAKE | `jira review <EPIC>` | epic + child issues resolved; each story has acceptance criteria or is flagged |
| DECOMPOSE | `new-track` per story, then `decompose` | `spec.md` + `plan.md` + `metadata.json` exist per track; `check-scope-conflicts.sh` clean |
| CONTRACT | — | **human approval** (skipped only by `--unattended`, and then recorded in mission state) |
| BUILD | `implement` per phase | `gate-check.sh --phase build` — tests green **with evidence**, hygiene chain clean |
| VALIDATE | `review` + `bughunt` + `coverage` + `deep-review`, fanned out | every validator in `expected-validators` has a fresh, independent verdict |
| RECOVER | `debug` / `change`, one pass per blocking issue | budget not exhausted; re-validate |
| SHIP | `deploy-checklist`, PR | `gate-check.sh --phase ship` green; **draft PR only, never a push to a shared branch** |

### New primitives (tool-shaped, matching Draft's architecture)

| Artifact | Purpose |
|---|---|
| `draft/.state/mission.json` | Mission state: `mission_id`, `epic_key`, `phase`, `phase_status`, `tracks[]`, `current_track`, `next_task`, `last_commit`, `recovery_attempts`, `dispatch_budget`, `verdicts{}`, `handoff_notes{done,next,blocked}` |
| `scripts/tools/mission-state.sh` | Read/write/validate. Temp-file + JSON validation + `.bak` + atomic rename. `--assert-schema` rejects forbidden legacy field names |
| `scripts/tools/gate-check.sh --phase intake\|build\|validate\|ship` | The deterministic gate. Composes the existing 6-tool `verification-gates` chain and adds evidence + verdict checks. Exit code, `--json` |
| `scripts/tools/record-evidence.sh` | Runs a command, tees to `draft/.state/evidence/<phase>-<ts>.log`, records `{command, log, exit_code, commit}`. A `passing` status with no log, or a log whose recorded exit code is non-zero, fails the gate |
| `scripts/tools/expected-validators.sh` | Derives the validator set from **graph facts** (UI symbols present? HTTP handlers present? perf NFR in `spec.md`?) and writes it, so "none skipped" is checkable |
| `draft/tracks/<id>/verdicts/<validator>.json` | `{validator, status, blocking_issues[], evidence[], independent, method, reviewed_commit}` |
| `core/shared/verdict-contract.md` | Replaces the `parallel-fanout` stub: fan-out shape, independence rule, evidence rule, stale-verdict rule |

### Three places Draft should beat SpecShip rather than copy it

1. **Graph-backed completeness, not grep.** SpecShip greps marker terms and gates at
   `found/total ≥ 0.80`. Draft can resolve each acceptance criterion to symbols via
   `graph-search.sh`, confirm the symbol exists, and confirm `graph-tests.sh` shows a test edge
   reaching it. Require **100% of acceptance criteria addressed**, not 80% of lexical hits.

2. **Verdicts pinned to a commit.** `reviewed_commit` on every verdict, cross-checked with
   `verify-citations.sh`: a verdict whose `path:line` evidence no longer resolves is automatically
   stale and the gate rejects it. SpecShip tracks `last_commit` in state but never pins a verdict —
   so a stale PASS can survive a later commit. This is a real hole Draft can close for free.

3. **Computed surgical scope.** Recovery passes get their blast radius from
   `graph-impact.sh --symbol <x>` instead of being told "be surgical." Scope discipline becomes a
   bound, not an exhortation. And `check-scope-conflicts.sh` makes **parallel track execution**
   across one epic safe — two tracks with overlapping scope tags serialize. SpecShip has no
   concept of concurrent missions.

### What not to copy

- **The greenfield milestone template** (9 milestones, ~3.5 h, "table-stakes features from market
  research"). It is tuned for building demo apps from nothing. Draft's users have a brownfield repo
  and a ticket. Market research as a *gate* would be noise — and their own Rule 18 exists precisely
  because that gate opens an egress path.
- **Rule 15, "no unsolicited documentation."** It contradicts Draft's premise: the context files
  *are* the product.
- **The env-var bypass.** `SPECSHIP_LENIENT_GATE=1` silently downgrades the safety gate to warnings.
  In an unattended loop that is a footgun. If Draft has a bypass it must be recorded in
  `mission.json` with a reason — the pattern `metadata.json:bypass_reason` already establishes.

### What to copy verbatim

- **Rule 17 (SCM boundary).** Unattended mode's deliverable is a **draft PR**. Never a push to a
  shared branch, never a merge. Autonomy skips approval gates, never the credential boundary.
- **Rule 19 (ingested content is data).** Once a Jira epic feeds the loop, ticket descriptions,
  comments and linked pages become an instruction-shaped input surface. They are findings to
  report, never commands to run.

---

## Implementation plan

| Track | Scope | Verify |
|---|---|---|
| **T1 — State + gate** | `mission-state.sh`, `gate-check.sh`, `record-evidence.sh`; register in `TOOLS`; 3 test suites | `make test` (84 suites); gate rejects a `passing` with no evidence log |
| **T2 — Verdict contract** | verdict schema, `expected-validators.sh`, `core/shared/verdict-contract.md`, `/draft:review` emits verdict JSON, chain step 7 | gate rejects `independent: false`, a missing expected validator, and a verdict whose `reviewed_commit` ≠ HEAD |
| **T3 — Orchestrator** | `skills/auto/SKILL.md`, `jira auto <EPIC>` intake, `SKILL_ORDER` + `SKILL_META` registration | dry run on a fixture epic produces tracks + `mission.json`, halts at the contract gate |
| **T4 — Loop closure** | recovery budget, escalation matrix, ship phase, `--resume` | injected failing test drives recover → green → draft PR; budget exhaustion escalates instead of looping |

Each track ends with `make build && make test`. T1 and T2 change no skill prose — they are pure
enforcement and are independently valuable even if `/draft:auto` is never shipped.

---

## Honest limits

- **Autonomy multiplies the cost of a bad spec.** The contract gate is the highest-leverage human
  checkpoint in the pipeline. `--unattended` should skip it only with an explicit flag, and record
  that it did.
- **Independence is a convention, not an isolation boundary.** A subagent gets fresh context, not a
  different judge. Attestation raises the cost of self-certification; it does not eliminate it.
  SpecShip is honest about the same limit for its injection defense, and Draft should be too.
- **Graph coverage is not correctness.** A test edge reaching a symbol proves the symbol is
  exercised, not that the assertion is meaningful. The completeness critic still earns its place.
