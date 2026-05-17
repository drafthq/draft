# Review Checks Guardrails

Numbered cross-cutting checks that every Draft review command must apply regardless of language, scope, or track type. These are the non-negotiable baseline. Language-specific and project-specific guardrails (`core/guardrails/language-standards.md`, `draft/guardrails.md`) are additive on top of this baseline.

**Referenced by:** `/draft:review`, `/draft:quick-review`, `/draft:bughunt`, `/draft:deep-review`, `/draft:assist-review`

**Security red lines** (RC-SEC-01…RC-SEC-10) are a subset of these checks and are treated as absolute — see `core/guardrails/security.md` for the full enforcement mechanism.

**Last updated:** 2026-05-16 
**Rule count:** 15

---

## Rules

### RC-001: No hardcoded secrets or credentials

- Source code must never contain passwords, API keys, tokens, private keys, or connection strings with credentials inline.
- **Detection:** Grep for common patterns: `password =`, `api_key =`, `secret =`, `-----BEGIN`, `token =` with non-variable RHS; entropy analysis on string literals.
- **Fix:** Use environment variables, secrets manager references, or config injection. Key name in code; value from environment.
- **Severity if violated:** Critical — blocks review approval.
- **Override:** `// SECURITY-OVERRIDE: <ticket> <justification>` annotation required if intentional (e.g., test fixture with non-real value clearly named `FAKE_KEY_FOR_TESTING`).
- **Source:** `core/guardrails/security.md` SEC-01; OWASP Top 10 A07

### RC-002: Parameterized queries for all database interactions

- String concatenation or interpolation in SQL, NoSQL, or search queries is never acceptable regardless of perceived input safety.
- **Detection:** Search for query string construction using `+`, f-strings, `%s %` (non-parameterized), template literals containing `SELECT`/`INSERT`/`UPDATE`/`DELETE`.
- **Fix:** Use the ORM's parameterized API, prepared statements, or the framework's query builder.
- **Severity if violated:** Critical.
- **Source:** `core/guardrails/security.md` SEC-03; OWASP Top 10 A03 — Injection

### RC-003: Validate and sanitize inputs at system boundaries

- All external input (HTTP requests, CLI args, message queue payloads, file contents, webhook bodies, environment variables consumed at runtime) must be validated and rejected before reaching business logic.
- **Detection:** Trace data flow from entry points to first use; check for schema validation, type coercion, and bounds checking.
- **Fix:** Add schema validation (JSON Schema, Pydantic, Joi, etc.) at the handler layer. Reject unknown fields by default.
- **Severity if violated:** High — blocking for new endpoints/handlers.
- **Source:** `core/guardrails/security.md` SEC-03; OWASP ASVS V5

### RC-004: TLS required for all external communication

- HTTP clients must not disable certificate verification. `verify=False`, `InsecureSkipVerify: true`, `rejectUnauthorized: false` in non-test code is a hard block.
- **Detection:** Search for the above patterns in changed files.
- **Severity if violated:** Critical.
- **Source:** `core/guardrails/security.md` SEC-04; OWASP Top 10 A02

### RC-005: Authentication and authorization checks close to resource access

- Access control checks must occur in the handler or service method, not only in middleware. Internal routes, background jobs, and direct service calls bypass middleware.
- **Detection:** Review new handlers and service methods for presence of auth check or explicit `// auth: not required because <reason>` annotation.
- **Severity if violated:** Critical for new endpoints; High for existing code paths.
- **Source:** `core/guardrails/security.md` SEC-10; OWASP Top 10 A01 — Broken Access Control

### RC-006: No PII or credentials in logs

- Logs must not contain passwords, tokens, API keys, full credit card numbers, SSNs, or other sensitive personal data. User IDs (non-guessable) are acceptable; email addresses, names, and health data are not.
- **Detection:** Search for log calls containing `password`, `token`, `secret`, `email`, `ssn`, `dob` as field names or in format strings.
- **Fix:** Apply a sanitize/redact step before logging. Log opaque identifiers (user_id, request_id) not raw personal data.
- **Severity if violated:** High.
- **Source:** `core/guardrails/security.md` SEC-05; GDPR / CCPA; OWASP Logging Cheat Sheet

### RC-007: Structured logging — no print or raw console statements in production code

- Production code must use the project's structured logging library. `print()`, `console.log()`, `fmt.Println()` in production paths produce unstructured, unparseable output.
- **Detection:** Grep for `print(`, `console.log(`, `console.error(`, `fmt.Print` in non-test files.
- **Exception:** Test files and one-shot scripts are exempt.
- **Severity if violated:** Medium.
- **Source:** `draft/tech-stack.md` — project logging library; Google SRE — observability

### RC-008: Handle errors explicitly — never swallow exceptions

- Catch-all error handlers that log and return success, empty catch blocks, and ignored error return values are blocking findings.
- **Detection:** Search for bare `catch {}`, `except: pass`, `_ = someFunc()` on error-returning calls, `err != nil` checks that only log without returning/propagating.
- **Fix:** Catch specific exceptions; log once at the handling point with context (CQ-006); return an actionable error upstream.
- **Severity if violated:** High — silent failures compound into data corruption.
- **Source:** `core/guardrails/code-quality.md` CQ-006; Release It! (Nygard) — stability patterns

### RC-009: Tests for new functionality — happy path and at least one failure path

- Every new function, handler, or module must have at minimum one passing test and one failure/edge-case test. Unhappy paths catch the bugs that matter most in production.
- **Detection:** Check for presence of test file changes alongside source changes. Flag if source-only diff adds exported behavior with zero test additions.
- **Exception:** Pure refactors with no behavior change (verify via diff) are exempt if existing tests still pass.
- **Severity if violated:** High for new public interfaces; Medium for internal helpers.
- **Source:** Growing Object-Oriented Software, Guided by Tests (Freeman, Pryce); `draft/workflow.md` — TDD preference

### RC-010: No dead code, commented-out blocks, or stale TODOs in submitted changes

- Unused functions, commented-out code blocks, and TODO/FIXME/HACK comments introduced by the current change must not be submitted.
- **Detection:** Grep the diff for `# TODO`, `// TODO`, `/* TODO`, `//commented`, `#commented`, large blocks of `//`-prefixed code.
- **Exception:** TODOs with a linked issue ID (`// TODO(#1234): ...`) are acceptable if the issue is open.
- **Severity if violated:** Low — non-blocking but must be listed.
- **Source:** `core/guardrails/code-quality.md` CQ-011; Clean Code (Martin)

### RC-011: Escape user content before rendering in UI

- User-controlled data must not be inserted into the DOM via `innerHTML`, `dangerouslySetInnerHTML`, `v-html`, or equivalent without sanitization.
- **Detection:** Search diff for those patterns with non-static content.
- **Fix:** Use framework's safe rendering (React JSX text nodes, Angular binding). If raw HTML is required, sanitize with a vetted library (DOMPurify).
- **Severity if violated:** Critical for user-facing content.
- **Source:** `core/guardrails/security.md` SEC-08-adjacent; OWASP Top 10 A03 — XSS

### RC-012: No breaking changes to public interfaces without a deprecation period

- Exported function signatures, API response shapes, error codes, and serialization formats (protobuf field numbers, JSON field names) must not change in a backward-incompatible way without a versioning or deprecation strategy.
- **Detection:** Compare exported symbol signatures and API contracts in the diff against the previous version.
- **Fix:** Add a new overloaded version, bump the API version, or run a deprecation period with the old interface forwarding to the new one.
- **Severity if violated:** Critical if consumed by other services; High for internal interfaces.
- **Source:** Building Microservices (Newman) — API versioning; `core/guardrails/design-norms.md` DN-002

### RC-013: Architecture boundary violations must be flagged

- New cross-module imports must follow the established dependency direction from `draft/graph/module-graph.jsonl` (when present) or `draft/.ai-context.md` §Component Map. Reverse-direction dependencies and direct imports across non-adjacent layers are blocking.
- **Detection:** For each new import in the diff, verify it does not invert an existing dependency edge.
- **Severity if violated:** High — architecture violations are cheap to fix when caught at review, expensive after they proliferate.
- **Source:** Clean Architecture (Martin) — Dependency Rule; `draft/.ai-context.md` §Cross-Module Integration Points

### RC-014: Dependency manifest changes trigger vulnerability check

- When a pull request modifies `package.json`, `requirements.txt`, `go.mod`, `Cargo.toml`, `pom.xml`, or `build.gradle`, a dependency vulnerability check must be run or recommended.
- **Detection:** Check diff for changes to the above files.
- **Action:** Run `npm audit`, `pip-audit`, `go list -m -json all | nancy`, `cargo audit`, or the project's configured scanner from `draft/tech-stack.md`. Include results in the review report.
- **Severity:** Based on CVSS score of findings (Critical ≥9.0, High ≥7.0).
- **Source:** `core/guardrails/security.md` — dependency triage; OWASP Top 10 A06 — Vulnerable Components

### RC-015: Observability coverage for new code paths

- New API endpoints, background jobs, event handlers, and scheduled tasks must include: at minimum one structured log at entry/exit and one metric emission point (or a comment explaining why observability is not applicable).
- **Detection:** Check new handler/service additions in diff for log statements and metric increments.
- **Severity if violated:** Medium.
- **Source:** Google SRE Book — SLOs; Netflix Full Cycle Developers — observability
