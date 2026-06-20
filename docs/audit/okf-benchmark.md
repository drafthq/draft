# OKF Taxonomy A/B Benchmark — Methodology & Results

Merge gate for making `DRAFT_INIT_MODE=okf` the default on `main`. The OKF
emitter (`skills/init/references/okf-emitter.md`) ships **opt-in**; it becomes
the default only when this benchmark shows `okf` ≥ baseline on task accuracy at
acceptable token cost. Source HLD: `hld-draft-init-okf-taxonomy.md` (§12–§13).

## Arms

Same repo, same commit, same model, same agent host.

- **Arm A — `monolith`**: `DRAFT_INIT_MODE=monolith` → `.ai-context.md`
  (condensed standalone). Clean baseline; current behavior untouched.
- **Arm B — `okf`**: `DRAFT_INIT_MODE=okf` → `ai-context.md` index root +
  `wiki/` taxonomy bundle.

```bash
# Arm A
DRAFT_INIT_MODE=monolith  /draft:init      # → draft/ baseline
# Arm B (separate worktree / clean draft/)
DRAFT_INIT_MODE=okf       /draft:init      # → draft/wiki/ bundle + index root
scripts/tools/okf-validate.sh draft/wiki \
  --path-index draft/.state/path-to-concept.json   # gate B before benchmarking
```

> **Note on output dir.** The OKF emitter always writes into `draft/`
> (`draft/wiki/`, `draft/architecture.md`, `draft/.ai-context.md`,
> `draft/wiki/web/index.html`). The `draft-okf/` path used in the run below was a
> **benchmark-only isolation** so Arm A's existing monolith `draft/` stayed intact
> for side-by-side comparison; it is not part of the product layout.

## Target repo & task suite

**Target:** `finbrainiac-platform` (multi-microservice trading platform). The
methodology is repo-agnostic; the task suite below is tailored to it. Fix the
suite (20–40 tasks) before running either arm.

| Class | Example tasks |
|-------|---------------|
| Broad-context | "summarize the service topology"; "which service owns order execution" |
| Focused | "what breaks if I change the broker adapter interface"; "add a field to the position/fill data model" |
| Cross-cutting | "trace an equity trade from signal generation → broker submission → TimescaleDB persistence" |

## Metrics (per task, per arm)

| Metric | Why |
|--------|-----|
| Task accuracy (rubric-scored, blind) | Primary — does navigation help or hurt correctness |
| Input tokens consumed | Cost of context assembly |
| Tool calls / file reads | Detects over-fetch (taxonomy read defeated) |
| Wall-clock to first action | Latency cost of navigation |
| Cross-link follow rate | Did the agent navigate vs. read-all |

## Decision rule

- Adopt `okf` as default **iff** accuracy ≥ baseline AND token cost is not
  materially worse on focused tasks.
- If the agent over-fetches (read-all behavior), the Synopsis-in-root fallback
  applies; **do not deprecate `monolith`.**
- One-time generation cost (`/draft:init` runtime) is tracked but is
  informational — not a merge gate.

## Results

### `finbrainiac-platform` @ `3d5ff5f6` (analysis synced to `25f9fb4c`) — 2026-06-19

**Setup.** 32,444-node / 191,521-edge graph (15 packages, 19 routes, 1,196 Py +
196 TS + 55 Rust files → Tier 5 / XL). Arm A = the existing monolith
`draft/.ai-context.md` (237 lines, condensed standalone). Arm B = a generated OKF
bundle `draft-okf/` decomposed from the **same** underlying analysis
(`draft/architecture.md`) + graph grounding — 30 concept pages (1,833 lines)
behind a 164-line `ai-context.md` index root. Decomposing from one analysis
isolates *packaging* as the only variable. Bundle passed `okf-validate.sh` (30
pages, 30 concepts, 0 dangles) including `--path-index` over a 67-entry
`path-to-concept.json`.

**Protocol.** 6 tasks × 2 arms = 12 isolated subagents. Each answered from **only**
its arm's context artifacts (no source-code reads), so the result measures the
artifact, not the agent's grep skill. Accuracy = rubric pre-defined per task
(required facts), scored against `draft/architecture.md` as ground truth. Tokens
= per-subagent total (note: ~24k is fixed agent overhead — system prompt + tool
defs — so only the *marginal* delta reflects context cost). Reads = tool_uses.

| Task | Class | A acc | B acc | A tok | B tok | A reads | B reads | Note |
|------|-------|-------|-------|-------|-------|---------|---------|------|
| B1 service topology | broad | 5/5 | 5/5 | 26,945 | 24,625 | 1 | 1 | B answered from Synopsis only; 164-line root < 237-line monolith → B cheaper |
| B2 execution owner + concurrency | broad | 5/5 | 5/5 | 26,146 | 28,503 | 1 | 3 | B navigated to 2 concept pages; richer (added OrderCircuitBreaker, DB-first idempotency) |
| F1 change BrokerPort blast radius | focused | 5/5 | 5/5 | 26,750 | 27,883 | 1 | 3 | parity; both named contracts/broker.py, factory, normalize, INV-001 |
| F2 add position/fill field | focused | 5/5 | 5/5 | 26,738 | 26,720 | 1 | 2 | even tokens; B added INV-013 close-has-fill + reconciler |
| C1 trace equity trade | cross | 6/6 | 6/6 | 26,072 | 33,347 | 1 | 6 | B opened 5 pages (high link-follow); much richer (two executors, Semaphore(20), shield) |
| C2 feed-down vs in-flight orders | cross | 5/5 | 5/5 | 26,837 | 29,994 | 1 | 4 | parity; B named StaleFractionTracker/_rest_fallback_refresh from the failure-modes page |

**Aggregate (mean tokens / mean reads):**

| Class | A tok | B tok | Δ tok | A reads | B reads |
|-------|-------|-------|-------|---------|---------|
| Broad | 26,546 | 26,564 | ~0% | 1.0 | 2.0 |
| Focused | 26,744 | 27,302 | +2.1% | 1.0 | 2.5 |
| Cross-cutting | 26,455 | 31,671 | +19.7% | 1.0 | 5.0 |

**Verdict — accuracy ≥ baseline ✔, but token cost materially worse on cross-cutting → keep `okf` opt-in (do NOT flip default yet).**

- **Accuracy: parity (100% both arms).** Every answer hit its rubric; neither arm
  hallucinated; both correctly flagged unanswerable sub-parts (e.g. "does the halt
  cancel resting orders" — not in either artifact). The two packagings are
  equally *correct*.
- **Navigation worked as designed.** Arm B opened only relevant pages (2–6,
  high cross-link-follow on the cross-cutting trace) — no read-all over-fetch
  defeating the taxonomy. The Synopsis-in-root fallback (R1) carried broad tasks
  at *lower* cost than the monolith (smaller root).
- **OKF's qualitative win: progressive disclosure surfaced richer, more specific
  detail** on focused/cross-cutting tasks (OrderCircuitBreaker, INV-013,
  StaleFractionTracker, the two-executor "never merge" rule) because a dedicated
  concept page carries more than a compressed monolith line.
- **But the decision rule is not met on this repo.** Token cost is ~even on
  focused but **+20% on cross-cutting** (each cross-link follow is another read).
  Per the rule ("token cost not materially worse"), that blocks making `okf` the
  default.

**Caveats that bound this result (and shape the re-run):**
1. **Adversarial-to-OKF baseline.** finbrainiac-platform is a *mature, AI-doc-
   optimized* repo (its own architecture.md §10 rates Context Quality "HIGH"); its
   237-line `.ai-context.md` is unusually dense and accurate, so the monolith is
   at its strongest. OKF's hypothesized win is on repos where the monolith is
   large/unwieldy and reading it whole is expensive — **not** demonstrated here
   because the baseline is already compact.
2. **No-source-read cap** maximizes the monolith's compactness advantage; a
   real agent that must grep source would shift the comparison toward whichever
   artifact better localizes the next read (OKF's `x-grounded-paths`).
3. **Tokens are overhead-dominated** (~24k fixed); the marginal context deltas
   are small in absolute terms and noisy.

**Next run to actually test the hypothesis:** a repo with a *large, sprawling*
monolith `architecture.md` (Tier 5 with a 600–900-line `.ai-context.md`, weaker
pre-existing docs), where Arm A must carry the whole file per task. That is the
regime where selective navigation should win on tokens at equal accuracy.
