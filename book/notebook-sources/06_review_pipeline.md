# Chapter 6: Review Pipeline

Part II: Track Lifecycle· Chapter 6

6 min read

The code is written. Tests pass. The plan shows every task marked[x]. You could merge now and move on. But "tests pass" is a low bar — it tells you the code does what the tests check, not that it does what the specification requires, not that it's secure, not that it follows your architecture, and not that it handles the edge cases nobody thought to test. Draft's review pipeline exists to close these gaps systematically.

## The Three Stages

/draft:reviewruns a sequential, three-stage review process. Each stage acts as a gate — if it fails, the review stops and sends you back to fix the structural problem before wasting effort on higher-order concerns. You don't check code quality on structurally broken code, and you don't check structure on code that doesn't meet the spec.

## Stage 1: Automated Validation

The first stage is fast, objective, and mechanical. It answers one question:is the code structurally sound and secure?

The reviewer scans the diff for five categories of issues:

* Architecture Conformance— Checks for pattern violations documented in your.ai-context.md. A database import in a React component, a direct service-to-service call bypassing the message bus, a controller containing business logic — these are structural violations caught before anyone reads the code.
* Dead Code Detection— Searches for newly exported functions or classes in the diff that have zero references anywhere in the codebase. Code that nothing calls is either incomplete work or a maintenance burden.
* Dependency Cycle Detection— Traces import chains for new imports to ensure no circular dependencies (A imports B, B imports C, C imports A) are introduced. Circular dependencies indicate poor module boundaries.
* Security Scanning (OWASP)— Scans the diff for hardcoded secrets and API keys, SQL injection risks (string concatenation in queries), and XSS vulnerabilities (innerHTMLor raw DOM insertion).
* Performance Anti-Patterns— Detects N+1 database queries (loops containing queries), blocking synchronous I/O within async functions, and unbounded queries lacking pagination.

### Context-Specific Checks

Stage 1 also identifies the primary domain of changed files and applies targeted checks. If the diff touches authentication files, the reviewer checks for timing-safe comparisons, constant-time operations, and secure random generation. Database migrations get checked for backward compatibility, index coverage, and zero-downtime safety. API endpoints get checked for input validation, rate limiting, and authentication guards. Configuration changes are scanned for exposed secrets and missing startup validation.

Stage 1 checks for changes to public API surfaces: modified function signatures, removed or renamed exports, changed error types, and altered serialization formats. A breaking change with no deprecation period or version bump is classified asCritical— it blocks the review immediately.

### STRIDE Threat Modeling

For new endpoints or data mutations, Stage 1 applies the STRIDE framework — six threat categories evaluated systematically:

* Spoofing— Can the caller's identity be faked? (authentication check)
* Tampering— Can request data be modified in transit? (integrity check)
* Repudiation— Are actions logged for audit? (logging check)
* Information Disclosure— Does the response leak internal details? (error message check)
* Denial of Service— Can the endpoint be abused? (rate limiting, resource limits)
* Elevation of Privilege— Are authorization checks in place? (RBAC/ABAC check)
If Stage 1 fails— any critical issue found — the review stops. The report lists the structural failures, and you fix them before proceeding. There is no point checking spec compliance on code with a SQL injection vulnerability.

### SAST Tool Recommendations

After completing Stage 1, the reviewer recommends appropriate static analysis tools based on yourtech-stack.md: ESLint witheslint-plugin-securityfor JavaScript, Bandit for Python, gosec for Go,cargo clippyandcargo auditfor Rust, and Semgrep or CodeQL for multi-language projects. If these tools are not already in your CI pipeline, the recommendation appears in the report.

## Stage 2: Spec Compliance

Stage 2 answers the most important review question:did they build what was specified?This stage only runs for track-level reviews where aspec.mdexists.

The reviewer loads the specification's acceptance criteria and systematically verifies each one against the diff:

* Requirements Coverage— For every functional requirement inspec.md, the reviewer finds evidence in the diff that it was implemented. Each requirement maps to specific files and line numbers.
* Acceptance Criteria Verification— Each criterion is checked against the diff. If TDD is enabled, the reviewer verifies that test coverage exists for each criterion.
* Scope Adherence— The reviewer checks for missing features (spec items not implemented) and for scope creep (extra work not in the spec). Both directions are flagged.
If Stage 2 fails— any requirement missing or acceptance criterion not met — the review stops. Stage 3 does not run. You go back to implementation and close the gaps before the review continues. Checking code quality on code that doesn't meet the spec is a waste of time.

## Stage 3: Code Quality

Stage 3 is the semantic review — the part that requires judgment, not just pattern matching. It evaluates four dimensions:

* Architecture— Does the code follow project patterns fromtech-stack.md? Appropriate separation of concerns? Critical invariants from.ai-context.mdhonored?
* Error Handling— Errors handled at the appropriate level? User-facing errors helpful? No silent failures?
* Testing— Tests verify real logic, not implementation details? Edge cases have coverage?
* Maintainability— Code readable without excessive comments? Consistent naming and style? No functions exceeding cognitive complexity thresholds? No deeply nested control flow beyond three levels?
For each flagged function, the report includes file path, function name, estimated complexity, and a recommended action: split, extract, or simplify.

## The Adversarial Pass

When Stage 3 produces zero findings across all four dimensions, the reviewer does not accept "clean" at face value. Instead, it runs anadversarial pass— explicitly asking probing questions designed to find what a lazy review would miss:

* Error paths— Is every error or exception handled? Are any failure modes silently swallowed?
* Edge cases— Are there boundary conditions (empty input, max values, concurrent access) not covered by tests?
* Implicit assumptions— Does the code assume inputs are always valid, services always up, or state always consistent?
* Future brittleness— Is anything hardcoded that will break on scale or configuration change?
* Missing coverage— Is there behavior that should be tested but isn't?
If the adversarial pass still finds nothing, the report documents it explicitly with a one-sentence explanation per question. This prevents lazy LGTM verdicts — when the reviewer claims "nothing to find," it has to prove the claim.

The three-stage sequence is not arbitrary. Running all checks simultaneously produces a noisy report where security vulnerabilities sit next to naming suggestions. The sequential design ensures you fix structural problems first, then verify spec compliance, then polish quality. Each stage builds on the confidence that the previous stage provides.

## Issue Classification

Every finding is classified by severity, and severity determines the required action:

* Critical— Blocks release. Breaks functionality or creates a security issue. Must fix before proceeding.
* Important— Degrades quality or introduces technical debt. Should fix before the phase is complete.
* Minor— Style, optimization, nice-to-have. Noted for later. Does not block.
Each issue includes the file and line number, a description of the impact, and a suggested fix. The reviewer never auto-fixes — it reports, and the developer decides.

## Review Scopes

While track-level review is the primary workflow,/draft:reviewsupports several scopes:

* /draft:review— Auto-detects the active track and reviews it (all three stages)
* /draft:review track add-oauth2— Reviews a specific track by ID
* /draft:review project— Reviews uncommitted changes (Stage 1 and 3 only, no spec)
* /draft:review files "src/**/*.ts"— Reviews specific file patterns
* /draft:review commits main...HEAD— Reviews a commit range
Project-level reviews skip Stage 2 (spec compliance) since there is no specification to check against. They run automated validation and code quality only.

## Thewith-bughuntModifier

For comprehensive reviews, addingwith-bughuntorfullcombines the three-stage review with Draft's deep bug hunting capability. The bug hunter looks for logic errors, race conditions, and edge cases that static analysis misses, producing regression tests for each finding. Results are aggregated into the review report with deduplication — if both the reviewer and bug hunter flag the same file and line, the finding with the highest severity is kept and attributed to both tools.

Each review creates a timestamped report file. Areview-report-latest.mdsymlink always points to the most recent one. Previous reports are preserved, so you can compare findings across review iterations and track how issues were resolved.

The review report updatesmetadata.jsonwith the review verdict, timestamp, and a running review count. This metadata feeds into/draft:status, giving you a project-wide view of which tracks have been reviewed and which still need attention.

With code reviewed and issues resolved, the track nears completion. The next chapter covers the operational commands that manage tracks throughout their lifecycle — monitoring progress, handling mid-stream requirement changes, and safely rolling back work when needed.
