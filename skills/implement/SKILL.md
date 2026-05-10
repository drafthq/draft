---
name: implement
description: "Executes tasks from the current track's plan using TDD workflow (red-green-refactor). Implements one task at a time, commits after each, runs three-stage review at phase boundaries, and tracks progress in plan.md. Use when the user asks to implement the next task, start coding, continue a plan, run test-driven development, or says 'start implementing'."
---

# Implement Track

Implement tasks from the active track's plan following the TDD workflow.

## Red Flags - STOP if you're:

- Implementing without an approved spec and plan
- Skipping TDD cycle when workflow.md has TDD enabled
- Marking a task `[x]` without fresh verification evidence
- Batching multiple tasks into a single commit
- Proceeding past a phase boundary without running the three-stage review
- Writing production code before a failing test (when TDD is strict)
- Assuming a test passes without actually running it

**Verify before you mark complete. One task, one commit.**

## Constraints

Draft skills are designed for single-agent, single-track execution. Do not run multiple Draft commands concurrently on the same track.

---

## Step 1: Load Context

1. Find active track from `draft/tracks.md` (look for `[~] In Progress` or first `[ ]` track)
2. Read the track's `spec.md` for requirements
3. Read the track's `plan.md` for task list
4. Read `draft/workflow.md` for TDD and commit preferences
5. Read `draft/tech-stack.md` for technical context
6. Read `draft/guardrails.md` (if exists) for hard guardrails and learned conventions
7. **Check for architecture context:**
   - Track-level: `draft/tracks/<id>/architecture.md`
   - Project-level: `draft/.ai-context.md` (or legacy `draft/architecture.md`)
   - If either exists → **Enable architecture mode** (Story, Execution State, Skeletons)
   - If neither exists → Standard TDD workflow
8. **Load production invariants** (if `draft/.ai-context.md` exists):
   - Read the `## INVARIANTS` section (and `## CONCURRENCY` if present)
   - Identify which invariants reference files this task will modify (same file or same module)
   - Keep matching invariants as **active constraints** for this task — these govern code generation, not just review
   - If invariants reference lock ordering, fail-closed behavior, or data integrity rules: these are non-negotiable during implementation
9. **Load graph context** (if `draft/graph/schema.yaml` exists):
   - Read `draft/graph/hotspots.jsonl` — check if any files this task will modify appear as hotspots
   - If modifying a hotspot file (high fanIn), warn: "This task modifies {file} (fanIn={N}). Changes here affect many downstream files. Consider running a graph impact query."
   - Read `draft/graph/modules/<module>.jsonl` for the module(s) being modified — gives file-level dependency context
   - See `core/shared/graph-query.md` for on-demand query subroutines (callers, impact)
10. Update the track's entry in `draft/tracks.md` from `[ ]` to `[~]` In Progress

If no active track found:
- Tell user: "No active track found. Run `/draft:new-track` to create one."

**Architecture Mode Activation:**
- Automatically enabled when `.ai-context.md` or `architecture.md` exists (file-based, no flag needed)
- Track-level architecture.md created by `/draft:decompose`
- Project-level `.ai-context.md` created by `/draft:init`

## Step 1.5: Readiness Gate (Fresh Start Only)

**Skip if:** Any task in `plan.md` is already `[x]` — the track is in progress, this check has already passed.

Run once, before the first task of a new track:

### AC Coverage Check

For each acceptance criterion in `spec.md`:
- Verify at least one task in `plan.md` references or addresses it
- If an AC has no corresponding task, flag it: "⚠️ AC: '[criterion]' has no task in plan.md"

### Sync Check (if `.ai-context.md` exists)

Compare the `synced_to_commit` values in the YAML frontmatter of `spec.md` and `plan.md`.
- **Skip if** either file has no YAML frontmatter or no `synced_to_commit` field (quick-mode tracks omit it).
- If they differ: "⚠️ Spec and plan were synced to different commits — verify they are still aligned."

### Result

**Issues found:** List them, then ask:
```
Readiness issues found (see above). Proceed anyway or update first? [proceed/update]
```
- `proceed` → add a `## Notes` entry in `plan.md` listing the issues, then continue to Step 2
- `update` → stop here and let the user refine spec or plan before re-running

**No issues:** Print `Readiness check passed.` and continue to Step 2.

## Step 1.7: Testing Strategy Loading

Before starting TDD cycle for the first task:

1. Check for testing strategy:
   - Track-level: `draft/tracks/<id>/testing-strategy.md`
   - Project-level: `draft/testing-strategy.md` or `draft/testing-strategy-latest.md`
2. If found: load coverage targets, test boundaries, and strategy into TDD context
3. If not found and TDD is enabled: suggest "Run `/draft:testing-strategy` to define test approach"

### Bug Track Test Guardrail

If track type is `bugfix` (from metadata.json):
```
BEFORE writing any test file:
  ASK: "This is a bug fix track. Want me to write tests as part of the fix? [Y/n]"
  If declined: skip TDD cycle, note in plan.md: "Tests: developer-handled"
```

## Step 2: Find Next Task

Scan `plan.md` for the first uncompleted task:
- `[ ]` = Pending (pick this one)
- `[~]` = In Progress (resume this one)
- `[x]` = Completed (skip)
- `[!]` = Blocked (skip - requires manual intervention)

**IMPORTANT:** If blocked task found, notify user:
- "Task [task description] is marked `[!]` Blocked"
- Show the blocked task details and recovery message
- "Resolve the blockage manually before continuing implementation"
- Do NOT attempt to implement blocked tasks

If resuming `[~]` task, check for partial work.

## Step 2.5: Write Story (Architecture Mode Only)

**Activation:** Only runs when `.ai-context.md` or `architecture.md` exists (track-level or project-level).

When the next task involves creating or substantially modifying a code file:

1. **Check if file already has a Story comment** - If yes, skip this step
2. **Skip for trivial tasks** - Config files, type definitions, simple one-liners
3. **Write a natural-language algorithm description** as a comment block at the top of the target file

### Story Format

```
// Story: [Module/File Name]
//
// Input:  [what this module/function receives]
// Process:
//   1. [first algorithmic step]
//   2. [second algorithmic step]
//   3. [third algorithmic step]
// Output: [what this module/function produces]
//
// Dependencies: [what this module relies on]
// Side effects: [any mutations, I/O, or external calls]
```

Adapt comment syntax to the language (`#` for Python, `/* */` for CSS, etc.).

### CHECKPOINT (MANDATORY)

**STOP.** Present the Story to the developer for review.

- Developer may refine, modify, or rewrite the Story
- **Do NOT proceed to execution state or implementation until Story is approved**
- Developer can say "skip" to bypass this checkpoint for the current task

See `core/agents/architect.md` for story writing guidelines.

---

## Step 3: Execute Task

### Step 3.0: Design Before Code (Architecture Mode Only)

**Activation:** Only runs when `.ai-context.md` or `architecture.md` exists (track-level or project-level).
**Skip for trivial tasks** - Config updates, type-only changes, single-function tasks where the design is obvious.

#### 3.0a. Execution State Design

Study the control flow for the task and propose intermediate state variables:

1. Read the Story (from Step 2.5) to understand the Input -> Output path
2. Study similar patterns in the existing codebase
3. **Check `.ai-context.md` Data Lifecycle** — Align execution state with documented state machines (valid states/transitions), storage topology (which tier data targets), and data transformation chain (shape changes at boundaries)
4. **Check `.ai-context.md` Critical Paths** — Identify where this task sits in documented write/read/async paths. Note consistency boundaries and failure recovery expectations.
5. Propose execution state: input state, intermediate state, output state, error state

Present in this format:
```
EXECUTION STATE: [Task/Module Name]
─────────────────────────────────────────────────────────
Input State:
  - variableName: Type — purpose

Intermediate State:
  - variableName: Type — purpose

Output State:
  - variableName: Type — purpose

Error State:
  - variableName: Type — purpose
```

**CHECKPOINT (MANDATORY):** Present execution state to developer. Wait for approval. Developer may add, remove, or modify state variables. Developer can say "skip" to bypass.

#### 3.0b. Function Skeleton Generation

Generate function/method stubs based on the approved execution state:

1. Create stubs with complete signatures (all parameters, return types)
2. Include a one-line docstring describing purpose and when it's called
3. No implementation bodies — use `// TODO`, `pass`, `unimplemented!()`, etc.
4. Order functions to match control flow sequence
5. Follow naming conventions from `tech-stack.md`

**CHECKPOINT (MANDATORY):** Present skeletons to developer. Wait for approval. Developer may rename functions, change signatures, add/remove methods. Developer can say "skip" to bypass.

See `core/agents/architect.md` for execution state and skeleton guidelines.

---

### Step 3.0c: Production Robustness Patterns (REQUIRED)

**Applies to all code generation** — architecture mode or not. These patterns are generation directives, not a post-hoc checklist. Apply them **while writing code**, not after.

When your implementation hits any of these triggers, use the corresponding pattern. Do not write code that violates these and plan to "fix it later."

#### Atomicity

| Trigger | Required Pattern |
|---------|-----------------|
| Multi-step state mutation (DB + memory, multiple records) | Wrap in transaction or try/finally with rollback on failure |
| File write | Write to temp file + atomic rename to target path. Never write directly to the target. |
| DB write paired with in-memory state update | DB-first: persist to DB, update memory only on DB success. Never update memory optimistically. |
| Resource acquisition (locks, file handles, connections, capital) | Release in `finally` / `defer` / RAII — never rely on happy-path-only cleanup |

#### Isolation

| Trigger | Required Pattern |
|---------|-----------------|
| Method mutates shared/instance state | Acquire the class's or module's existing lock before mutation |
| Lifecycle operations (start/stop/reset/reconnect) | Use a dedicated lifecycle lock, separate from data locks |
| Returning internal state to callers | Return a deep copy or frozen snapshot — never a mutable reference to internal state |
| Acquiring a second lock while holding one | Follow documented lock ordering. If no ordering exists, do not nest locks — restructure to acquire sequentially. |
| DB I/O while holding a state lock | Move DB I/O outside the lock scope. Lock only the in-memory mutation, not the I/O. |

#### Durability

| Trigger | Required Pattern |
|---------|-----------------|
| Critical state that must survive crashes | Ensure state is recoverable from DB/disk alone — no reliance on in-memory-only state for recovery |
| Async DB write (fire-and-forget) | Await the write. Check return value or propagate exceptions. No fire-and-forget on data persistence. |
| Event log / audit trail / fill history | Use append-only pattern where specified by architecture |

#### Defensive Boundaries

| Trigger | Required Pattern |
|---------|-----------------|
| External numeric data used in arithmetic | Guard with `isFinite()` / `isnan()` / equivalent before any calculation |
| External API/webhook response consumed | Validate expected fields exist and have correct types before accessing nested properties |
| SQL query with dynamic values | Parameterized queries only — zero string interpolation for values |
| Dynamic column names, table names, or identifiers in SQL | Validate against an explicit allowlist — never pass user-controlled strings as identifiers |

#### Idempotency

| Trigger | Required Pattern |
|---------|-----------------|
| Operation that may be retried (network calls, queue consumers, webhook handlers) | Use a dedup key (UUID, request ID, fill ID) — check-before-write or upsert |
| State transition (status changes, lifecycle events) | Validate the transition is legal from the current state. Reject terminal→terminal transitions. |
| Alert / notification emission | Dedup on (alert_type, entity_id, time_window) to prevent re-firing on retries |

#### Fail-Closed

| Trigger | Required Pattern |
|---------|-----------------|
| Error path or exception handler that determines access/action | Default to the safe/restrictive/deny state — never default to permissive on error |
| Missing data, null, or undefined where a decision depends on it | Treat as deny/reject/skip — not as allow/proceed |
| Config or feature flag missing/unparseable | Use the restrictive default — system runs in safe mode, not open mode |

#### Resilience

| Trigger | Required Pattern |
|---------|-----------------|
| Any retry logic | Exponential backoff with jitter — never fixed-interval or immediate retries. Prevents retry storms. |
| Cache population under high concurrency | Cache stampede prevention: use probabilistic early expiration or request coalescing to prevent thundering herd |
| External dependency call (HTTP, RPC, DB to external service) | Circuit breaker pattern: track failure rate, open circuit on threshold, allow periodic probes to recover |
| Non-critical dependency failure | Graceful degradation: return cached/default/partial result rather than failing the entire request |

**Enforcement:** These patterns override convenience. If following a pattern makes the code more verbose, that's correct — the verbosity is the safety. If a pattern is genuinely N/A for the current task (e.g., no DB in a pure utility function), skip it — only apply relevant patterns.

**If project invariants were loaded in Step 1:** Cross-reference them here. Project-specific invariants (lock ordering, concurrency model, consistency boundaries) take precedence over these general patterns when they conflict.

---

### Step 3.1: Implement (TDD Workflow)

For each task, follow this workflow based on `workflow.md`. If skeletons were generated in Step 3.0b, fill them in using the TDD cycle below.

### Characterization Testing (Refactoring Existing Code Without Tests)

When refactoring code that lacks tests, write characterization tests first to capture current behavior as a baseline. Identify seams (interfaces for test doubles, swappable imports), record actual outputs for representative inputs, then proceed with the TDD cycle for new behavior.

### If TDD Enabled:

**Iron Law:** No production code without a failing test first.

**3a. RED - Write Failing Test**
```
1. Create/update test file as specified in task
2. Write test that captures the requirement
3. RUN test - VERIFY it FAILS (not syntax error, actual assertion failure)
4. Show test output with failure
5. Announce: "Test failing as expected: [failure message]"
```

**Test Quality Checklist (REQUIRED for every test):**
- No shared mutable state between test cases — each test sets up its own state
- Assertion density: every test must have at least one meaningful assertion (not just `assertTrue(true)`)
- No logic in tests: no conditionals, loops, or try/catch in test code — tests should be trivially readable
- DAMP over DRY: prefer descriptive and meaningful test names and setup over deduplication
- Test behavior, not implementation: verify observable outcomes, not internal method calls
- One behavior per test: each test should verify exactly one logical behavior
- Reference: Google SWE Book Ch. 12, Google Testing Blog "Test Behavior, Not Implementation"

**Property-Based Testing Checkpoint:**
After writing example-based tests, consider property-based tests for pure functions (algebraic properties, round-trip serialization, sort invariants). Not mandatory — skip if properties are not obvious.

**3b. GREEN - Implement Minimum Code**
```
1. Write MINIMUM code to make test pass (no extras)
2. RUN test - VERIFY it PASSES
3. Show test output with pass
4. Announce: "Test passing: [evidence]"
```

**Observability Prompts (consider during implementation):**
Structured logging at decision points, metrics for latency-sensitive ops, tracing at service boundaries, error classification (transient vs permanent). Use engineering judgment — not mandatory for every task.

**Contract Testing Checkpoint (Service Boundaries Only):**
For new API endpoints or service-to-service interfaces, suggest consumer-driven contract tests. Skip for purely internal modules.

**3c. REFACTOR - Clean with Tests Green**
```
1. Review code for improvements
2. Refactor while keeping tests green
3. RUN all related tests after each change
4. Show final test output
5. Announce: "Refactoring complete, all tests passing: [evidence]"
```

**Red Flags - STOP and restart the cycle if:**
- About to write code before test exists
- Test passes immediately (testing wrong thing)
- Thinking "just this once" or "too simple to test"
- Running tests mentally instead of actually executing

### If TDD Not Enabled:

**3a. Implement**
```
1. Implement the task as specified
2. Test manually or run existing tests
3. Announce: "Implementation complete"
```

### Implementation Chunk Limit (Architecture Mode Only)

**Activation:** Only when `.ai-context.md` or `architecture.md` exists (track-level or project-level).

If the implementation diff for a task exceeds **~200 lines**:

1. **STOP** after ~200 lines of implementation
2. Present the chunk for developer review
3. **CHECKPOINT (MANDATORY):** Wait for developer approval of the chunk
4. Commit the approved chunk: `feat(<track_id>): <task description> (chunk N)`
5. Continue with the next chunk
6. Repeat until the task is fully implemented

This prevents large, unreviewable code drops. Each chunk should be a coherent, reviewable unit.

---

## Step 4: Update Progress & Commit

**Iron Law:** Every completed task gets its own commit. No batching. No skipping.

After completing each task:

0. **Quick robustness scan** (30-second check before committing):
   - Scan the code you just wrote against the Step 3.0c triggers
   - If any trigger is present but the pattern wasn't applied: fix it now
   - This is a rapid pattern-match, not a full review — you should have applied these during generation, this catches anything missed

1. Commit FIRST (REQUIRED - non-negotiable):
   - Stage only files changed by this task (never `git add .`)
   - `git add <specific files>`
   - Verify staged changes exist before committing: `git diff --cached --quiet`. If nothing staged, skip the commit step.
   - `git commit -m "type(<track_id>): task description"` (Conventional Commits — see `core/shared/vcs-commands.md`)
   - If a Jira ticket is linked in `spec.md`, reference it in the commit body: `Refs: <JIRA_ID>`.
   - Get commit SHA: `git rev-parse --short HEAD`
   - Do NOT proceed to the next task without committing
   - Do NOT batch multiple tasks into one commit

2. Update `plan.md`:
   - Change `[ ]` to `[x]` for the completed task
   - Add the commit SHA next to the task: `[x] Task description (abc1234)`

3. Update `metadata.json`:
   - Increment `tasks.completed`
   - Update `updated` timestamp

4. **Verify state updates (CRITICAL):**
   - Read back `plan.md` - confirm task marked `[x]` with SHA
   - Read back `metadata.json` - confirm `tasks.completed` incremented
   - If EITHER verification fails:
     - Mark task as `[!]` Blocked in plan.md
     - Add recovery message: "State update failed after commit <SHA>. Recovery: manually edit plan.md line X to mark `[x]`, update metadata.json tasks.completed to Y"
     - HALT - require manual intervention before continuing

5. If `.ai-context.md` or `architecture.md` exists for the track:
   - Update module status markers (`[ ]` → `[~]` when first task in module starts, `[~]` → `[x]` when all tasks complete)
   - Fill in Story placeholders with the approved story from Step 2.5
   - If updating project-level `draft/.ai-context.md`: also update YAML frontmatter `git.commit` and `git.commit_message` to current HEAD. Update `draft/architecture.md` with structural changes, then run the Condensation Subroutine (defined in `core/shared/condensation.md`) to regenerate `draft/.ai-context.md`.

## Verification Gate (REQUIRED)

**Iron Law:** No completion claims without fresh verification evidence.

Before marking ANY task/phase/track complete:

1. **IDENTIFY:** What command proves this claim? (test, build, lint)
2. **RUN:** Execute the FULL command (fresh, complete run)
3. **READ:** Full output, check exit code
4. **VERIFY:** Does output confirm the claim?
   - If **NO**: Keep task as `[~]`, state actual status
   - If **YES**: Show evidence, then mark `[x]`

**Red Flags - STOP if you're thinking:**
- "Should pass", "probably works"
- Satisfaction before running verification
- About to mark `[x]` without fresh evidence from this session
- "I already tested earlier"
- "This is a simple change, no need to verify"

---

## Step 5: Phase Boundary Check

When all tasks in a phase are `[x]`:

1. Announce: "Phase N complete. Running three-stage review."

### Three-Stage Review (REQUIRED)

**Stage 1: Automated Validation**
- Fast static checks: architecture conformance, dead code, circular dependencies, performance anti-patterns. Review for common security anti-patterns (OWASP top 10). For automated checks, use language-specific tools (e.g., `npm audit` for JS, `bandit` for Python, `cargo audit` for Rust).
- **If critical issues found:** List them, return to implementation

**Stage 2: Spec Compliance** (only if Stage 1 passes)
- Load track's `spec.md`
- Verify all requirements for this phase are implemented
- Check acceptance criteria coverage
- **If gaps found:** List them, return to implementation

**Stage 3: Code Quality** (only if Stage 2 passes)
- Verify code follows project patterns (tech-stack.md)
- Check error handling is appropriate
- Verify tests cover real logic
- Classify issues: Critical (must fix) > Important (should fix) > Minor (note)

See `core/agents/reviewer.md` for detailed review process.

### Quick Review Alternative

At phase boundaries, offer the lightweight alternative:
```
"Phase {N} complete. Review options:
  1. Full three-stage review (recommended) — spec compliance + security + quality
  2. /draft:quick-review — lightweight 4-dimension check (faster)
  Choose [1/2, default: 1]:"
```
If quick-review chosen, invoke `/draft:quick-review` with the phase's changed files.

2. Run verification steps from plan (tests, builds)
3. Present review findings to user
4. If review passes (no Critical issues):
   - Update phase status in plan
   - Update `metadata.json` phases.completed
   - **Refresh blast-radius memory** (see "Impact Memory" subsection below)
   - Proceed to next phase
5. If Critical/Important issues found:
   - Document issues in plan.md
   - Fix before proceeding (don't skip)

### Impact Memory (blast-radius snapshot)

After a phase passes review, refresh `metadata.json.impact` so future tracks can detect overlap with this work.

1. **Compute touched files:** From `plan.md`, find the first commit SHA recorded for this track (earliest `[x]` line with `(<sha>)`). Run:
   ```bash
   git diff --name-only <first_sha>^..HEAD
   ```
   That is the `files_touched` list. Derive `modules_touched` as the unique top-level path segments (e.g. `auth/login.go` → `auth`).

2. **Compute downstream blast radius (graph-aware, optional):** If `draft/graph/schema.yaml` exists, for each file in `files_touched` query:
   ```bash
   graph --repo . --out draft/graph --query --file <path> --mode impact
   ```
   Aggregate across all files: `downstream_files` = total unique downstream files (deduped), `downstream_modules` = union of `affected_modules`, `max_depth` = max across queries, `by_category` = sum of each query's `by_category`. If the graph is absent, leave these fields as zeros / empty arrays — the snapshot still records the directly-touched files.

3. **Write metadata.json** with the populated `impact` block and `computed_at` set to the current timestamp.

This snapshot is consumed by `/draft:new-track` to surface overlap warnings when a new track touches the same modules as a recently completed track.

## Step 6: Track Completion

When all phases complete:

1. **Run review (if enabled):**
   - Read `draft/workflow.md` review configuration
   - Check if auto-review enabled:
     ```markdown
     ## Review Settings
     - [x] Auto-review at track completion
     ```
   - If enabled, run `/draft:review track <track_id>`
   - Check review results:
     - If block-on-failure enabled AND critical issues found → HALT, require fixes
     - Otherwise, document warnings and continue

2. Update `plan.md` status to `[x] Completed`
3. Update `metadata.json` status to `"completed"`
4. Update `draft/tracks.md`:
   - Move from Active to Completed section
   - Add completion date

5. **Verify completion state consistency (CRITICAL):**
   - Read back `plan.md` - confirm status `[x] Completed`
   - Read back `metadata.json` - confirm status `"completed"`
   - Read back `draft/tracks.md` - confirm track in Completed section with completion date
   - If ANY file shows inconsistent state:
     - ERROR: "Track completion partially failed"
     - Report: "plan.md: <status>, metadata.json: <status>, tracks.md: <section>"
     - Provide recovery: "Manually complete updates: [list specific edits needed]"
     - Do NOT announce completion until all three files verified consistent

6. Announce:
"Track <track_id> completed!

Summary:
- Phases: N/N
- Tasks: M/M
- Duration: [if tracked]

[If review ran:]
Review: PASS | PASS WITH NOTES | FAIL
Report: draft/tracks/<track_id>/review-report-latest.md

All acceptance criteria from spec.md should be verified.

Next: Run `/draft:status` to see project overview."

## Error Handling

**If blocked:**
- Mark task as `[!]` Blocked
- Add reason in plan.md
- **REQUIRED:** Follow systematic debugging process (see `core/agents/debugger.md`)
  1. **Investigate** - Read errors, reproduce, trace (NO fixes yet)
  2. **Analyze** - Find similar working code, list differences
  3. **Hypothesize** - Single hypothesis, smallest test
  4. **Implement** - Regression test first, then fix
- Do NOT attempt random fixes
- Document root cause when found

**Recommended:** Instead of inline debugging, invoke `/draft:debug` skill for a structured session:
```
"Task blocked: {description}. Run /draft:debug for structured investigation? [Y/n]"
```
The debug skill provides: Reproduce → Isolate → Diagnose → Fix methodology with debug report output.

**If test fails unexpectedly:**
- Don't mark complete
- Follow systematic debugging process above
- Announce failure details with root cause analysis
- Show evidence when resolved

**If unsure about implementation:**
- Ask clarifying questions
- Reference spec.md for requirements
- Don't proceed with assumptions

## Tech Debt Log

During implementation, track technical debt decisions in the track's plan.md:

When you encounter a shortcut, workaround, or known-imperfect solution during implementation:

1. Add an entry to the `## Tech Debt` section at the bottom of plan.md
2. Use this format:

```markdown
## Tech Debt

| ID | Location | Description | Severity | Payback Trigger |
|----|----------|-------------|----------|-----------------|
| TD-1 | `src/api/handler.ts:45` | Hardcoded timeout instead of config | Low | When adding config system |
| TD-2 | `src/auth/session.ts:12` | In-memory session store | Medium | Before horizontal scaling |
```

**Severity levels:**
- **Low** — Cosmetic or minor maintainability issue
- **Medium** — Will cause problems at scale or in specific scenarios
- **High** — Actively impeding development or risking production issues

**Payback Trigger** — The condition or event that should trigger debt repayment (e.g., "before launch", "when adding feature X", "before scaling past N users").

Only log genuine debt — intentional shortcuts with known consequences. Not everything imperfect is debt.

---

## Progress Reporting

After each task, report:
```
Task: [description]
Status: Complete
Phase Progress: N/M tasks
Overall: X% complete
```

---

## Cross-Skill Dispatch

### At Track Completion (Step 6)

After announcing track completion, suggest relevant follow-ups based on context:

**If track modifies production code:**
```
"Track complete! Consider:
  → /draft:deploy-checklist — Pre-deployment verification"
```

**If track added new APIs/services/components:**
```
  → /draft:documentation — Update documentation for new components"
```

**If implementation contains TODO/FIXME/HACK comments:**
```
  → /draft:tech-debt — Catalog any new technical debt introduced"
```

**If new patterns or dependencies not in tech-stack.md:**
```
  → /draft:adr — Document this design decision"
```

### Jira Sync at Completion

If Jira ticket linked, sync via `core/shared/jira-sync.md`:
- Post comment: "[draft] implementation-complete: All {n} tasks done. Ready for review."

### Bug Track with rca.md

If implementing a bug track and `draft/tracks/<id>/rca.md` exists:
- Load rca.md as context for the implementation
- Reference root cause, blast radius, and prevention items during fix
- After fix: update rca.md "Proposed Fix" section with actual fix details
