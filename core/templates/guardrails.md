---
type: Guardrails
project: "{PROJECT_NAME}"
module: "root"
generated_by: "draft:init"
generated_at: "{ISO_TIMESTAMP}"
---

# Guardrails

| Field | Value |
|-------|-------|
| **Branch** | `{LOCAL_BRANCH}` → `{REMOTE/BRANCH}` |
| **Commit** | `{SHORT_SHA}` — {COMMIT_MESSAGE} |
| **Generated** | {ISO_TIMESTAMP} |
| **Synced To** | `{FULL_SHA}` |

---

This file defines project-level guardrails and learned coding patterns. All quality commands (`/draft:bughunt`, `/draft:deep-review`, `/draft:review`) read this file and enforce its rules.

- **Hard Guardrails** — Human-defined constraints. Violations are always flagged.
- **Learned Conventions** — Auto-discovered patterns that are intentional. Quality commands skip these.
- **Learned Anti-Patterns** — Auto-discovered patterns that are problematic. Quality commands always flag these.

Run `/draft:learn` to scan the codebase and update learned patterns. Quality commands also update this file incrementally after each run.

---

## Hard Guardrails

<!-- Hard constraints that must never be violated. Check [x] to enable enforcement. -->

### Git & Version Control
- [ ] No direct commits to main/master
- [ ] No force push to shared branches
- [ ] PR required for all changes

### Code Quality
- [ ] No console.log/print statements in production code
- [ ] No commented-out code blocks
- [ ] No TODO comments without linked issue

### Security
- [ ] No secrets/credentials in code
- [ ] No disabled security checks without documented exception
- [ ] Dependencies must pass security audit

### Testing
- [ ] Tests required before merge
- [ ] No skipped tests without documented reason
- [ ] Coverage must not decrease

### C++/Systems — Object Lifecycle & Memory Safety
<!-- From core/guardrails.md — C++ Hard Guardrails. Pre-checked for all C++ projects. -->
- [x] G1.1: No temporary `.c_str()` in Printf-style trace APIs (dangling pointer)
- [x] G1.2: No dangling references/pointers after object destruction
- [x] G1.3: No capture-all-by-reference `[&]` in async lambdas
- [x] G1.4: Every async functor must be wrapped with `callback_muter_`
- [x] G1.5: Never wrap op's own `done_cb` in ClosureRunner when extracting result via raw pointer
- [x] G1.6: ClosureRunner/CallbackMuter must be wrapped in correct order (`callback_muter_` first, then `cr_`)
- [x] G1.7: Every async functor must be wrapped with `cr_`
- [x] G1.8: No op member access after potential op destruction in loops
- [x] G1.9: Always return immediately after `Finish()` — no code execution post-Finish
- [x] G1.10: No unintended deep copies via `auto` (use `auto&` or `const auto&` for map lookups)
- [x] G1.11: std::move discipline — always move expensive objects; never use after move
- [x] G1.12: No `shared_ptr` binding to non-trivial objects (EventDriver holders) in callbacks

### C++/Systems — Concurrency & Locking
- [x] G2.1: No mutable operations under shared/read locks
- [x] G2.2: Always release spinlock before invoking callbacks or `Finish()`
- [x] G2.3: No expensive object destruction under spinlock protection
- [x] G2.4: Never sacrifice locking correctness for performance optimization
- [x] G2.5: No synchronous waits (`Trigger::Wait`) in async code paths

### C++/Systems — Control Flow & Error Handling
- [x] G3.1: Always `return` after `Finish()` in conditional blocks
- [x] G3.2: CHECKs for internal consistency only — never for external input validation
- [x] G3.3: No side-effecting expressions inside DCHECK
- [x] G3.4: CHECK/DCHECK/LOG(DFATAL) selection per severity matrix

### C++/Systems — Format & API Correctness
- [x] G4.1: Printf format specifiers must match argument types
- [x] G4.2: MemTracer Print vs Printf selection (lazy construction vs immediate materialization)
- [x] G4.3: Use Maybe-prefixed MemTracer variants only when op may be finished
- [x] G4.4: No string + integer (pointer arithmetic, not concatenation) — use `StringPrintf`
- [x] G4.5: `boost::optional<bool>` tests presence, not value — use `*xx` or `.value_or()`

### C++/Systems — GFlags & Runtime Configuration
- [x] G5.1: Snapshot gflag values at op start — never depend on flag stability mid-op

### C++/Systems — Performance
- [x] G6.1: Avoid `ByteSize()` on proto objects in hot paths
- [x] G6.2: Prefer repeated fields over map fields in proto for serialization-sensitive paths
- [x] G6.3: No inline execution in `SpawnWorkersAndJoin` `done_cb`

> Check the guardrails that apply to this project. Unchecked items are not enforced. Quality commands flag violations of checked guardrails only.
> **C++/Systems guardrails** are pre-checked and enforced by default. See `core/guardrails.md` for full descriptions and fix guidance. Uncheck only if the project does not contain C++ code.

---

## Learned Conventions

<!-- Auto-discovered coding patterns verified as intentional. Quality commands skip these. -->
<!-- Each entry is added by /draft:learn or by quality commands during post-analysis. -->
<!-- Format: pattern name, category, confidence, evidence, description. -->

<!-- No learned conventions yet. Run /draft:learn or a quality command to discover patterns. -->

---

## Learned Anti-Patterns

<!-- Auto-discovered patterns verified as problematic. Quality commands always flag these. -->
<!-- Each entry is added by /draft:learn or by quality commands during post-analysis. -->
<!-- Entry format:
### [Anti-Pattern Name]
- **Category:** security | reliability | performance | correctness | concurrency
- **Severity:** critical | high | medium
- **graph_severity:** critical | high | medium | low | unresolved (fanIn-derived; "unresolved" if no graph data)
- **high_fanin_files:** `path/file.go` (fanIn:12) (omit if none meet fanIn ≥ 5)
- **Evidence:** Found in N files — `path/file.ext:line`
- **Discovered at:** YYYY-MM-DD
- **Established at:** YYYY-MM-DD
- **Last verified:** YYYY-MM-DD
- **Last active:** YYYY-MM-DD
- **Discovered by:** draft:[command] on YYYY-MM-DD
- **Description:** [What the pattern is and why it's problematic]
- **Suggested fix:** [Brief description of the correct approach]
-->

<!-- No learned anti-patterns yet. Run /draft:learn or a quality command to discover patterns. -->

---

## Pattern Promotion

Learned patterns with `confidence: high` and consistent evidence across multiple quality runs are candidates for promotion:

- **Convention → Accepted Pattern**: Promote to `tech-stack.md ## Accepted Patterns` for technology-level decisions
- **Convention → Hard Guardrail**: Promote to Hard Guardrails above if the team wants enforcement
- **Anti-Pattern → Hard Guardrail**: Promote to Hard Guardrails above for mandatory enforcement

Run `/draft:learn promote` to review candidates.
