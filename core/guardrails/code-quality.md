<<<<<<< HEAD
# Guardrails — code-quality (Foundations Stub)

Generalized public Draft baseline. Full ruleset ported from internal systems in subsequent work.
See core/guardrails.md for entry point and loading rules.
=======
# Code Quality Guardrails

Numbered rules for code authoring, structure, and developer experience. Applied by all Draft generation and implementation commands. Loaded alongside `draft/guardrails.md` (project-level); project rules take precedence on conflict.

**Referenced by:** `/draft:implement`, `/draft:review`, `/draft:bughunt`, `/draft:deep-review`, `/draft:quick-review`

**Last updated:** 2026-05-16 
**Rule count:** 12

---

## Rules

### CQ-001: Follow the project's established style — never impose new conventions

- **Rationale:** Consistency with existing code reduces cognitive load and merge friction. Style divergence is noise in reviews.
- **Example:** If the project uses `snake_case` for functions, do not generate `camelCase`. Read existing files before generating.
- **Source:** Clean Code (Martin); `draft/tech-stack.md ## Accepted Patterns`

### CQ-002: One responsibility per function

- **Rationale:** Multi-purpose functions are hard to test, debug, and review independently. Long functions hide logic branches.
- **Example:** Extract validation, transformation, and persistence into separate functions rather than a single `processRequest()`.
- **Source:** Clean Code (Martin); SOLID — Single Responsibility Principle

### CQ-003: Prefer descriptive names over comments

- **Rationale:** Comments rot when code changes. Self-documenting names are always current and reduce maintenance burden.
- **Example:** Name a function `calculate_retry_backoff_ms` not `calc` with a comment explaining what it does.
- **Source:** The Pragmatic Programmer (Hunt, Thomas); Clean Code (Martin)

### CQ-004: Separate business logic from infrastructure

- **Rationale:** Mixing domain logic with HTTP handlers, database calls, or queue consumers makes both untestable and non-portable.
- **Example:** Domain functions accept plain types and return results. Handlers do transport parsing and response formatting. Never `SELECT` inside a route handler.
- **Source:** Clean Architecture (Martin); 12-Factor App — Backing Services

### CQ-005: Return early for preconditions — reduce nesting

- **Rationale:** Deeply nested code hides the happy path and increases cognitive load. Each nesting level doubles the mental stack.
- **Example:** Use guard clauses (`if err != nil { return err }`) at function entry rather than wrapping the entire body in conditionals.
- **Source:** Clean Code (Martin); The Pragmatic Programmer

### CQ-006: Include context in error messages

- **Rationale:** "Error occurred" is not actionable. Operators and developers need to know what failed, with what input, and why.
- **Example:** `fmt.Errorf("user %s not found in org %s: %w", userID, orgID, err)` — not `errors.New("not found")`.
- **Source:** Release It! (Nygard); Google SRE — on-call ergonomics

### CQ-007: Document the why, not the what

- **Rationale:** Code shows what happens. Comments should explain non-obvious trade-offs, constraints, and intent that future maintainers cannot infer from code alone.
- **Example:** `// Using retry=3: upstream API has ~2% transient failure rate (measured Q1 2026)` — not `// retry 3 times`.
- **Source:** The Pragmatic Programmer; Working Effectively with Legacy Code (Feathers)

### CQ-008: Update documentation alongside code in the same commit

- **Rationale:** Stale docs are worse than no docs — they actively mislead. Documentation drift compounds over time.
- **Example:** If changing an API endpoint signature, update the README, OpenAPI spec, and inline docstrings in the same commit.
- **Source:** The Pragmatic Programmer — Orthogonality; DRY principle

### CQ-009: Never expose internal stack traces in API responses

- **Rationale:** Stack traces leak implementation details — file paths, library versions, internal module names — that aid attackers.
- **Example:** Return `{"error": "internal_error", "message": "Request could not be processed"}` — not the raw exception with stack frames.
- **Source:** OWASP Top 10 — Security Misconfiguration; Clean Architecture

### CQ-010: Codebase analysis findings must be quantified

- **Rationale:** "The code has some tech debt" is not actionable. Numbers enable prioritization and progress tracking.
- **Example:** Report "23 functions exceed cyclomatic complexity 10" — not "high complexity detected."
- **Source:** `core/knowledge-base.md` — Anti-Patterns: Cargo Cult

### CQ-011: Remove imports and variables orphaned by your own changes

- **Rationale:** Dead imports and unused variables introduced by a change are noise and may cause compilation errors or linter failures.
- **Example:** If a refactor removes the only call to `parseToken()`, also remove the import of the token library in the same diff.
- **Source:** Clean Code (Martin) — Dead Code

### CQ-012: Changelogs and release notes must classify entries by type

- **Rationale:** Consumers need to quickly locate breaking changes, new features, and security fixes without reading every line.
- **Example:** Group entries under `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security` (Keep a Changelog format).
- **Source:** Keep a Changelog standard; Semantic Versioning
>>>>>>> a79c14023e16774c77463870ac3510b728e8a91c
