# Chapter 5: Implementation

Part II: Track Lifecycle· Chapter 5

6 min read

You have a specification your team approved and a plan broken into phases and tasks. In a conventional AI workflow, you'd paste the spec into a chat window and say "build it." The AI would generate everything at once — a single, massive, unreviewable code drop. Draft takes a fundamentally different approach./draft:implementexecutes the plan one task at a time, each task producing a single commit, each commit verified before the next task begins.

## How Implementation Works

When you run/draft:implement, the AI loads the track's specification and plan, reads your workflow preferences, and finds the first uncompleted task. It does not ask what to build — the plan already answered that. It does not choose an approach — the specification already decided. Implementation is pure execution against pre-approved constraints.

Before the first task begins, aReadiness Gateruns once per track. It verifies that every acceptance criterion inspec.mdhas at least one corresponding task inplan.md. If an acceptance criterion has no task, the AI flags it before any code is written. This catches spec-plan drift at the cheapest possible moment.

## TDD Workflow

When yourworkflow.mdhas TDD enabled, implementation follows the classic Red-Green-Refactor cycle — but with an iron law:no production code without a failing test first.

* RED— Write a test that captures the requirement. Run it. Verify it fails with an actual assertion failure, not a syntax error. The AI announces: "Test failing as expected: expected OAuth token to have expiry field."
* GREEN— Write the minimum code to make the test pass. Nothing extra. Run the test. Verify it passes. The AI announces: "Test passing: OAuth token includes expiry field."
* REFACTOR— Clean the code while keeping tests green. Run all related tests after each change. The AI announces: "Refactoring complete, all tests passing."
The AI is trained to stop itself if it's about to write code before a test exists, if a test passes immediately (testing the wrong thing), or if it's about to reason "just this once" or "too simple to test." These are explicit red flags in the implementation protocol.

Every test must meet a quality checklist: no shared mutable state between cases, at least one meaningful assertion, no logic (conditionals, loops, try/catch) in test code, descriptive names over DRY deduplication, and testing behavior rather than implementation details. The AI also considers property-based testing for pure functions — suggesting tools like Hypothesis (Python), fast-check (JavaScript), or proptest (Rust) when algebraic properties or round-trip invariants are applicable.

## Architecture Mode

When your project has an.ai-context.mdorarchitecture.mdfile — created by/draft:initor/draft:decompose— implementation automatically enablesArchitecture Mode. This adds three design steps before any code is written for each task.

### Story Writing

Before coding a file, the AI writes a natural-language algorithm description as a comment block at the top. The Story captures what the module receives, the algorithmic steps it performs, and what it produces — without any code syntax.

The AI presents the Story and waits for approval. You can refine it, rewrite it, or say "skip." The Story is the cheapest place to change direction — before execution state and skeletons lock in the design.

### Execution State Design

Next, the AI defines the intermediate state variables the code will use during processing. This bridges the gap between the algorithm (Story) and the code structure (skeletons).

Again, mandatory checkpoint. You approve, modify, or skip before proceeding.

### Function Skeleton Generation

Finally, the AI generates function stubs with complete signatures — all parameters, return types, and a one-line docstring describing purpose and call timing. No implementation bodies, just// TODOplaceholders. Functions appear in control flow order.

After you approve the skeletons, the TDD cycle fills them in. Each checkpoint — Story, Execution State, Skeletons — gives you veto power over the design before implementation begins.

## Production Robustness Patterns

Whether Architecture Mode is active or not, Draft enforces six categories of production robustness patterns during code generation. These are not a post-hoc checklist — they aregeneration directivesapplied while writing code.

* Atomicity— Multi-step state mutations are wrapped in transactions with rollback on failure. File writes go to a temp file first, then atomic rename. Database writes happen before in-memory state updates, never the reverse. Resource cleanup always runs infinallyblocks.
* Isolation— Methods that mutate shared state acquire locks before mutation. Returning internal state to callers produces a deep copy or frozen snapshot, never a mutable reference. Database I/O is moved outside lock scope.
* Durability— Critical state that must survive crashes is recoverable from disk or database alone, with no reliance on in-memory-only state. Async database writes are always awaited — no fire-and-forget on data persistence.
* Idempotency— Operations that may be retried use deduplication keys. State transitions validate that the transition is legal from the current state. Alert emissions are deduplicated on type, entity, and time window.
* Fail-Closed— Error paths default to the safe, restrictive, deny state. Missing data is treated as deny, not allow. Missing configuration uses the restrictive default — the system runs in safe mode, not open mode.
* Resilience— Retry logic uses exponential backoff with jitter, never fixed-interval retries. External dependency calls use circuit breakers. Non-critical dependency failures degrade gracefully, returning cached or default results instead of failing the entire request.
If following a pattern makes the code more verbose, that is correct — the verbosity is the safety. The AI is instructed to never write code that violates these patterns and plan to "fix it later." If a pattern is genuinely not applicable (no database in a pure utility function), it is skipped — only relevant patterns are applied.

## One Task, One Commit

After completing each task, the AI commits immediately. This is non-negotiable. Every task gets its own commit with a conventional message format:

The AI stages only files changed by the current task — nevergit add .. It then updatesplan.mdto mark the task complete with the commit SHA, increments the counter inmetadata.json, and verifies both writes succeeded. If either verification fails, the task is marked[!]Blocked with a recovery message specifying exactly which file needs manual correction.

This discipline creates a 1:1 mapping between plan tasks and git commits. You can revert a single task's work without touching anything else. You can trace any commit back to the plan task and specification requirement that motivated it.

## Phase Boundaries

When all tasks in a phase are complete, the AI runs athree-stage reviewbefore proceeding to the next phase. Stage 1 checks structural integrity (architecture conformance, dead code, circular dependencies, security). Stage 2 verifies spec compliance (requirements coverage, acceptance criteria). Stage 3 assesses code quality (patterns, error handling, testing, maintainability). Critical issues block the next phase — they must be fixed first.

This means every phase boundary is a quality gate. Problems are caught early, in small batches, not at the end of a 2,000-line code drop.

## Checkpoint and Resume

Implementation sessions can be interrupted and resumed. Because every completed task has a commit and an updated plan marker, the AI can detect exactly where work stopped. On resume, it readsplan.mdto find the first[~]or[ ]task, checksgit logto verify the last commit matches the last[x]entry, reconciles any mismatches, and continues from where it left off.

If a task was marked in progress ([~]) when the session ended, the AI checks for partial work — uncommitted changes, TODO markers, incomplete implementations. If the partial work is substantial and valid, it continues from the current state. If broken or minimal, it asks whether to continue or start fresh.

In Architecture Mode, if the implementation diff for a single task exceeds approximately 200 lines, the AI stops, presents the chunk for review, waits for approval, commits it, and continues with the next chunk. This prevents large, unreviewable code drops even within a single task.

## The Architect Agent

Architecture Mode is powered by the Architect Agent, a specialized protocol for pre-implementation design. The Architect decomposes systems into modules following strict rules: each module owns one concern, contains 1–3 files, has a defined public interface, communicates through interfaces rather than internals, and can be unit-tested in isolation. When circular dependencies are detected, the Architect applies a cycle-breaking framework — extracting shared interfaces, inverting dependencies, or merging artificially split modules.

The Architect does not make implementation decisions. It establishes boundaries, documents algorithms, and generates API surfaces. The developer approves each checkpoint. The TDD cycle handles the actual implementation. This separation keeps architectural decisions explicit and reviewable, rather than implicit in generated code.

## Tech Debt Tracking

During implementation, shortcuts sometimes happen. When the AI encounters a workaround or known-imperfect solution, it logs it in aTech Debtsection at the bottom ofplan.mdwith location, description, severity (Low/Medium/High), and a payback trigger — the condition that should prompt repayment. Only genuine debt is logged: intentional shortcuts with known consequences, not everything imperfect.

With implementation complete, the next step is review — a three-stage process that verifies everything the plan promised was actually delivered.
