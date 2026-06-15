# Chapter 21: Philosophy & References

Part VII: Closing· Chapter 21

6 min read

Draft is built on a premise: AI coding assistants are powerful but undirected, and structure is the missing piece. This chapter traces that premise to its foundations — the philosophy that drives Draft's design, the production robustness patterns it enforces, and the vetted knowledge base that informs its recommendations.

## The Core Philosophy

The gap between what AI can generate and what production systems require is not a capability gap. It is a direction gap. An AI assistant can write a complete authentication system in thirty seconds. It can also write the wrong authentication system in thirty seconds. The difference is not in the model's ability but in the constraints it operates under.

Draft's philosophy follows from this observation:if you want better output from AI, don't write better prompts — build better structure.

Prompt engineering is fragile. It depends on phrasing, context window position, model version, and conversational state. A prompt that works today may not work tomorrow. Structural constraints are durable. Atech-stack.mdfile that says "PostgreSQL, not MongoDB" constrains every interaction, every session, every model version. The constraint is not a suggestion embedded in natural language — it is a versioned, reviewable artifact in the repository.

This is what Draft means by Context-Driven Development: making the context that shapes AI behavior explicit, managed, and permanent. Every decision captured in a Draft document is a decision the AI doesn't have to guess at.

## Production Robustness as a First-Class Concern

Most AI-generated code works. It passes the tests the AI also wrote. It handles the happy path. What it frequently lacks is production robustness — the defensive patterns that keep systems running when things go wrong.

Draft treats robustness not as an afterthought but as a mandatory dimension of code generation. During/draft:implement, six production robustness patterns are always active, triggered automatically by code patterns without manual opt-in:

### 1. Atomicity

All-or-nothing mutations. Atomic file writes (write to temp, then rename). Database-first state updates. If an operation produces multiple side effects, either all succeed or none do. The AI does not generate code that can leave the system in a half-updated state.

### 2. Isolation

Lock-guarded shared state. Deep-copy returns to prevent callers from mutating internal data. No database I/O while holding locks. Each component's failure boundary is contained — a crash in one operation does not corrupt another's state.

### 3. Durability

Crash-recoverable state. No fire-and-forget writes. If the process dies between two operations, the system must be recoverable. State that matters is persisted before the operation is acknowledged.

### 4. Defensive Boundaries

Numeric validation on all user inputs. API response validation before processing. Parameterized SQL without exception. Every boundary where data enters the system is treated as hostile — validated, sanitized, and constrained before it reaches business logic.

### 5. Idempotency

Deduplication keys on operations that might be retried. Legal state transitions only (no invalid state jumps). Alert deduplication to prevent notification storms. If an operation is executed twice with the same input, the system state is identical to executing it once.

### 6. Fail-Closed

Deny on error. Deny on missing data. When the system cannot determine whether an operation is safe, it refuses rather than guessing. This is the opposite of fail-open, where errors are swallowed and execution continues with potentially corrupt state.

When project-specific invariants exist in.ai-context.md— lock ordering, concurrency models, consistency boundaries — they take precedence over the general patterns. The robustness framework adapts to each project's constraints rather than applying a one-size-fits-all ruleset.

## Why Explicit Context Beats Prompt Engineering

Prompt engineering and structural context both aim to improve AI output. They differ fundamentally in durability and reliability:

A prompt says "remember to use PostgreSQL." A context file says "PostgreSQL is the primary datastore, connection pooling via PgBouncer, migrations via Prisma." The first is a verbal instruction that might be forgotten. The second is a structural constraint that is loaded every time.

## The Knowledge Base

Draft's agents do not operate from general training data alone. They draw on a curated knowledge base (core/knowledge-base.md) of vetted sources across architecture, reliability, craft, and security. When an agent makes a recommendation during planning or review, it cites the source.

### Architecture & Design

* Designing Data-Intensive Applications(Martin Kleppmann) — Data models, replication, partitioning, consistency, stream processing. Cited for distributed systems decisions: "Consider CQRS here (DDIA, Ch. 11) — separates read/write concerns which fits your high-read workload."
* Clean Architecture(Robert Martin) — Dependency rule, boundaries, use cases, separation of concerns. Cited for module boundary violations: "This violates the Dependency Rule (Clean Architecture) — domain shouldn't know about infrastructure."
* Domain-Driven Design(Eric Evans) — Bounded contexts, ubiquitous language, aggregates, strategic design
* Building Evolutionary Architectures(Ford, Parsons, Kua) — Fitness functions, incremental change, architectural governance
### Reliability & Operations

* Release It!(Michael Nygard) — Stability patterns, circuit breakers, bulkheads, timeouts, failure modes. Cited for resilience recommendations: "Circuit breaker pattern (Release It!) would help here — fail fast instead of cascading timeouts."
* Site Reliability Engineering(Google SRE Book) — SLOs, error budgets, toil reduction, incident response. The operational mindset that informs Draft's emphasis on production robustness.
* The Phoenix Project(Kim, Behr, Spafford) — Flow, feedback, continuous improvement
### Craft & Practice

* Working Effectively with Legacy Code(Michael Feathers) — Seams, characterization tests, breaking dependencies. Essential for brownfield projects where Draft analyzes existing code before proposing changes.
* The Pragmatic Programmer(Hunt, Thomas) — Tracer bullets, DRY, orthogonality, good enough software
* Refactoring(Martin Fowler) — Code smells, refactoring patterns, incremental improvement
### Testing

* Growing Object-Oriented Software, Guided by Tests(Freeman, Pryce) — TDD outside-in, mock objects. Informs Draft's TDD workflow and the test-first cycle in/draft:implement.
* Unit Testing Principles, Practices, and Patterns(Khorikov) — Test pyramid, test doubles, maintainable tests
### Security

* OWASP Top 10— Injection, broken auth, XSS, insecure deserialization, security misconfiguration. Referenced during review and bughunt for security-dimension findings.
* OWASP ASVS— Application Security Verification Standard for security requirements
* OWASP Cheat Sheets— Specific guidance for auth, session management, input validation
### Resilience & Chaos

* Netflix chaos engineering— Principles of deliberately injecting failures to build confidence in system resilience. Informs Draft's emphasis on failure-mode analysis during planning and review.
## How References Are Cited

Draft's agents cite sources naturally during planning and review, not as footnotes but as inline reasoning:

> "Consider CQRS here (DDIA, Ch. 11) — separates read/write concerns which fits your high-read workload."

"Consider CQRS here (DDIA, Ch. 11) — separates read/write concerns which fits your high-read workload."

> "This violates the Dependency Rule (Clean Architecture) — domain shouldn't know about infrastructure."

"This violates the Dependency Rule (Clean Architecture) — domain shouldn't know about infrastructure."

> "Circuit breaker pattern (Release It!) would help here — fail fast instead of cascading timeouts."

"Circuit breaker pattern (Release It!) would help here — fail fast instead of cascading timeouts."

Citations serve two purposes. They make recommendations credible by grounding them in established practice rather than model opinion. And they give developers a trail to follow — if the recommendation seems wrong, the developer can read the source and decide for themselves.

## The Future of Context-Driven Development

Draft's current architecture treats context as static documents that are loaded at invocation time. The methodology works because those documents are comprehensive enough to constrain most decisions. But the trajectory points toward richer context systems:

* Tiered context loading— Draft already implements three tiers (.ai-profile.mdat 20-50 lines,.ai-context.mdat 200-400 lines,architecture.mdat full size). Future iterations may add relevance scoring that loads only the sections needed for a specific task.
* Cross-session memory— Draft's.state/run-memory.jsonalready provides continuity data across sessions. The natural extension is richer state that captures what was tried, what failed, and what patterns were learned during development.
* Team-scale context—/draft:initbuilds cross-module context through its scope-aware root-link mechanism, connecting per-module graphs to a shared root. Future work may extend this to team-level conventions, cross-team dependency negotiation, and organizational standards enforcement.
The underlying principle will remain constant: better structure produces better AI output. The documents may evolve. The methodology may expand. But the insight — that explicit, managed, versioned context is the most reliable way to direct AI behavior — is the foundation everything else builds on.

The knowledge base does not only catalog good patterns. It also catalogs anti-patterns that agents actively watch for: distributed monoliths, shared databases between services, God classes, leaky abstractions, security by obscurity, hardcoded secrets, and the eight fallacies of distributed computing. These anti-patterns are flagged during review and bughunt when detected in the codebase.

