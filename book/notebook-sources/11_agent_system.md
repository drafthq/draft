# Chapter 11: The Agent System

Part III: How Draft Thinks· Chapter 11

5 min read

You asked your AI assistant to debug a failing test. It immediately changed the code, broke two other tests, reverted, tried something else, broke three more, and eventually produced a "fix" that suppressed the error without understanding it. This is what happens when an AI has capability without protocol. Draft's agent system gives each specialized role a defined process that prevents freelancing.

## Why Agents Exist

A general-purpose AI assistant has one mode: do whatever seems helpful. That is fine for answering questions. It is dangerous for structured engineering work. Architecture decomposition requires different thinking than debugging. Code review requires different discipline than planning. When a single AI operates without role boundaries, it blends these concerns — reviewing code while simultaneously refactoring it, or planning while already implementing.

Draft defines seven specialized agents, each with a behavioral protocol that constrains how the AI operates in that role. Agents are not separate AI instances. They are protocol documents that the AI loads and follows when a specific skill activates them. The Architect agent activates during/draft:decomposeand/draft:implement(architecture mode). The Reviewer agent activates during/draft:review. The Debugger agent activates when a task is marked blocked. They structure AI behavior the way a runbook structures incident response.

## Architect Agent

The Architect agent handles pre-implementation design: breaking systems into modules, documenting algorithms, designing execution state, and generating function skeletons. It enforces five rules for module decomposition:

* Single Responsibility— each module owns one concern
* Size Constraint— 1 to 3 files per module; if more, split further
* Clear API Boundary— every module has a defined public interface
* Minimal Coupling— modules communicate through interfaces, not internals
* Testable in Isolation— each module can be unit-tested independently
For each module, the Architect defines a name, a one-sentence responsibility, expected source files, the public API surface (with full type signatures in the project's language), dependencies on other modules, and a complexity rating. It then performs dependency analysis: identifying edges between modules, detecting circular dependencies, topologically sorting for implementation order, and identifying which modules can be built in parallel.

Before any code is written, the Architect writes aStory— a natural-language algorithm description placed at the top of each code file. Stories capture the Input to Output path and the algorithmic approach in 5 to 15 lines. They describe the algorithm ("sort by priority, then deduplicate"), not the implementation ("use Array.sort() with comparator"). Stories are the cheapest place to change direction — before skeletons and TDD lock in the design.

The Architect also designsexecution state— the intermediate variables your code will use during processing. This bridges the gap between the Story (algorithm) and Function Skeletons (code structure). Input state, intermediate state, output state, and error state are each named, typed, and documented before implementation begins.

Finally, the Architect generatesfunction skeletons: complete function signatures with parameter types, return types, and docstrings, but no implementation. The developer approves the structure before TDD begins. No code is written until the skeleton is approved.

## Planner Agent

The Planner agent creates specifications and phased implementation plans. It handles collaborative intake — structured dialogue to elicit requirements, identify risks, and define acceptance criteria. Specs come in three templates: feature specs (summary, requirements, acceptance criteria, non-goals, technical approach), bug specs (reproduction steps, root cause hypothesis, blast radius), and refactor specs (current state, target state, migration strategy).

Plans are organized into four phases:

Each task within a plan must be completable in a focused session, have clear success criteria, produce testable output, and fit in a single commit. "Implement the feature" is not a task. "Add validation middleware for CreateUserInput with email format and password strength checks" is a task.

The Planner identifies dependencies between tasks, parallel execution opportunities, and external blockers. It flags technical unknowns, performance concerns, and security considerations in the spec. When requirements are ambiguous, it does not proceed with assumptions — it documents the ambiguities with options and trade-off analysis, then asks the developer to decide.

## Reviewer Agent

The Reviewer agent performs three-stage code review at phase boundaries. The stages are sequential and gated — a failure at any stage stops the process.

Stage 1: Automated Validation.Objective, static checks against the diff: architecture conformance (no pattern violations, module boundaries respected, no unauthorized cross-layer imports), dead code detection, dependency cycle detection, security scan (OWASP checklist — no hardcoded secrets, no SQL injection risks, no XSS vulnerabilities), and performance anti-pattern detection (no N+1 queries, no blocking I/O in async functions, no unbounded queries). If Stage 1 fails, review stops. Structural issues must be fixed before anything else is evaluated.

Stage 2: Spec Compliance.Did the code implement what was specified? All functional requirements covered, all acceptance criteria met, no scope creep, edge cases from the spec handled. If requirements are missing, review stops. There is no point assessing code quality for code that builds the wrong thing.

Stage 3: Code Quality.Architecture, error handling, testing, and maintainability. No silent failures, no functions exceeding reasonable complexity, no deeply nested control flow beyond three levels.

When Stage 3 produces zero findings across all four dimensions, the Reviewer does not accept "clean" at face value. It runs an adversarial pass — seven explicit questions: Are all error paths handled? Are there untested boundary conditions? Does code assume inputs are always valid? Is anything hardcoded that will break at scale? Is there untested behavior? Do changes violate learned anti-patterns? Do changes violate critical invariants? Only after answering all seven with documented reasoning can a zero-finding review be accepted. This prevents lazy "LGTM" verdicts.

Issues are classified by severity:Critical(blocks release, must fix),Important(degrades quality, should fix before phase completes), andMinor(style, optimization, noted but does not block).

## Debugger Agent

The Debugger agent enforces one iron law:no fixes without root cause investigation first.When a task is marked as blocked ([!]status), the Debugger follows four phases in strict order.

* Investigate— Read the error, reproduce it, trace the data flow from input to failure point, document findings. No code changes allowed in this phase. If you are tempted to make a "quick fix," stop.
* Analyze— Find similar working code, list differences between working and failing cases, check assumptions, narrow to the smallest change that breaks. Language-specific debugging techniques are applied: async stack traces for Node.js, race detector for Go, sanitizers for C/C++,RUST_BACKTRACE=1for Rust.
* Hypothesize— Form a single hypothesis, predict the outcome if correct, run the smallest possible test. If wrong, return to Analyze. Do not try another random fix.
* Implement— Write the regression test first (fails before fix, passes after), implement the minimal fix addressing root cause only, run the full test suite, document the root cause.
The Debugger also includes a performance debugging path for latency regressions and memory growth: profile before guessing, compare against baseline, target the hot path, and benchmark before optimizing. The anti-pattern list is explicit: no optimizing without profiling data, no optimizing code that is not on the hot path, no micro-optimizing when the bottleneck is I/O.

## RCA Agent

The Root Cause Analysis agent extends the Debugger for bug tracks — production bugs, Jira incidents, and distributed system failures. It draws from Google SRE postmortem culture and adds practices the Debugger does not cover: blast radius analysis, SLO impact quantification, detection lag assessment, differential analysis, 5 Whys causal chains, and formal hypothesis tracking with evidence tables.

The RCA agent classifies every confirmed root cause: logic error, race condition, data corruption, config error, dependency issue, missing validation, state management, or resource exhaustion. Prevention items are categorized into detection improvements, process improvements, code improvements, and architecture improvements. Every claim must citefile:line— no hand-waving allowed.

Failed hypotheses are documented because they narrow the search space. After three failed cycles, the agent escalates rather than continuing to guess.

## Ops Agent

The Ops agent brings a production-safety mindset to deployment and incident management. Its iron law:never recommend a deployment without a rollback plan. It activates during/draft:deploy-checklist,/draft:incident-response, and/draft:standup.

The Ops agent enforces six principles: production-first thinking (every change is guilty until proven safe), blast-radius awareness (map dependencies before acting), rollback readiness (every deployment has a rollback plan), communicate early (stakeholders hear from you, not from customers), severity over speed (declare higher severity and downgrade), and blameless culture (focus on systems, not individuals).

Its severity classification system (SEV1 through SEV4) provides clear escalation criteria and response times. Rollback triggers are explicit: error rate exceeds 2x baseline, p95 latency exceeds 3x baseline, data corruption detected, or deployment stuck in partial state for more than 10 minutes.

## Writer Agent

The Writer agent handles technical documentation generation with audience-aware principles. Its iron law:write for the reader, not the writer. It activates during/draft:documentationacross four modes: readme, runbook, api, and onboarding.

The Writer agent follows six principles: audience first (identify the reader before writing), progressive disclosure (lead with essentials, add detail later), link don't duplicate (reference existing docs instead of copying), maintain don't create (every doc needs an owner and update trigger), examples over explanations (working code communicates more than prose), and scannable structure (headers, tables, code blocks over walls of text).

It adapts tone and detail level based on four audience profiles: new team members need step-by-step orientation, experienced developers need concise reference material, operators need action-oriented runbooks, and external integrators need complete API documentation with examples.

## How Agents Activate

Agents are not invoked directly. They are activated automatically by the skill that needs them:

The activation is seamless. When/draft:implementencounters a blocked task, it loads the Debugger protocol and follows the four phases. When/draft:reviewruns at a phase boundary, it loads the Reviewer protocol and executes all three stages. The developer does not need to know which agent is active — they see the structured output.

Agents do not replace human judgment. They structure AI behavior so that judgment happens at the right moments. The Architect presents module boundaries for approval. The Planner presents specs for review. The Reviewer flags issues for human decision. Every agent has escalation procedures for when it cannot resolve ambiguity — it documents what it knows, lists what is unclear, and asks. It does not guess.
