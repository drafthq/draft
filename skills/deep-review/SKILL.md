---
name: deep-review
description: "Perform an exhaustive end-to-end lifecycle review of a service, component, or module. Evaluates ACID compliance, architectural resilience, and production-grade enterprise quality. Use when the user asks for a 'deep review', 'enterprise review', 'production-grade audit', 'lifecycle review', or says 'is this production-ready', 'review this for prod'."
---

# Deep Review — Production-Grade Module Audit

Perform an exhaustive end-to-end lifecycle review of a service, component, or module. Ensure ACID compliance and production-grade enterprise quality. Unlike standard review commands, this operates strictly at the module level.

## Red Flags - STOP if you're:

- Acting without reading the Draft context (`draft/.ai-context.md`, `draft/tech-stack.md`, `draft/product.md`)
- Modifying production code. This command is for auditing and reporting only. Fixes should be handled in a separate implementation track.
- Reviewing a module that was already reviewed recently, unless explicitly requested.

---

## Arguments

- `$ARGUMENTS` — Optional: explicit module/service/component name (directory) to review. If omitted, auto-select the next unreviewed module.

---

## Step 0: Verify Draft Context

```bash
ls draft/.ai-context.md 2>/dev/null
```

If `draft/` does not exist: **STOP** — "No Draft context found. Run `/draft:init` first. Deep review requires `draft/.ai-context.md` and `draft/tech-stack.md` to evaluate against project standards."

If `.ai-context.md` is missing, check for `draft/architecture.md` as a fallback (per `core/shared/draft-context-loading.md`).

---

## Module Selection

1. **Check review history:** Read `draft/deep-review-history.json` if it exists. This file tracks previously reviewed modules with timestamps.
2. **If `$ARGUMENTS` is provided:** Use that module. If it was previously reviewed, re-review it (the user explicitly requested it).
3. **If no argument:** Discover all modules using the following priority order:
   1. Use module definitions from `draft/.ai-context.md` if it exists (check `## Modules` or `## Module Catalog` sections).
   2. Use top-level directories under `src/` or equivalent source root.
   3. Use directories containing `__init__.py`, `package.json`, or `go.mod`.
   Document which heuristic was used in the report.
   Select the first module NOT present in the review history. If all have been reviewed, pick the one with the oldest review date.
4. **Announce selection:** State which module was selected and why before proceeding.

---

## Review Phases

### Phase 1: Context & Structural Analysis
- Load Draft context following the procedure in `core/shared/draft-context-loading.md`. Use loaded context to understand intended boundaries and critical invariants.
- **Load Learned Anti-Patterns** — If `draft/guardrails.md` exists, read the `## Learned Anti-Patterns` section before analysis begins. During the audit, when an issue matches a learned anti-pattern, prefix the finding with `[KNOWN-ANTI-PATTERN: {pattern name}]`. This separates newly discovered issues from documented recurring patterns and allows the report to recommend systemic remediation rather than isolated fixes.
- Map the module's full dependency graph (imports, injected services, external calls)
- Trace the complete lifecycle: initialization → processing → persistence → cleanup
- Identify all entry points and exit paths
- Catalog all state mutations and side effects
- **API Contract Drift Detection:** Compare the module's actual code interfaces against documented contracts (OpenAPI/Swagger specs, Protobuf/gRPC definitions, GraphQL schema files, TypeScript type exports). Flag drift: endpoints that exist in code but not in the spec (or vice versa). Flag type mismatches between spec and implementation. Reference: Amazon, Google large-scale changes.

### Phase 2: ACID Compliance Audit
- **Atomicity:** Verify all multi-step operations are wrapped in transactions. Partial failure must not leave corrupt state. Check for missing rollback paths.
- **Consistency:** Validate all invariants, constraints, and business rules are enforced before and after every state transition. Check schema validation, data type enforcement, and boundary conditions.
- **Isolation:** Check for race conditions, shared mutable state, concurrent access without locking/synchronization. Verify transaction isolation levels where databases are involved.
- **Durability:** Confirm committed data survives crashes. Check for fire-and-forget patterns, missing flush/sync calls, and inadequate error handling around persistence.
- **Event Sourcing:** Are events immutable? Is event replay idempotent? Is the event store append-only?
- **CQRS:** Are read/write models eventually consistent? Is consistency lag acceptable for the use case?
- **Saga Pattern:** Are compensating transactions defined for each step? What happens on partial saga failure?
- **Eventual Consistency:** Are there convergence guarantees? How is conflict resolution handled (LWW, CRDT, manual)? Reference: Amazon distributed systems.

### Phase 3: Production-Grade Assessment

**Applicability note:** Skip categories that are not applicable to the module type (e.g., circuit breakers and backpressure are backend-specific; skip for frontend/CLI modules).

- **Resilience:** Graceful degradation, circuit breakers, timeout handling, backpressure
- **Observability:** Logging coverage (not excessive), structured log fields, correlation IDs, metric emission points
  - **Structured logging:** Are logs structured (JSON/key-value) vs free-form strings?
  - **Log level correctness:** Are ERROR/WARN/INFO/DEBUG used appropriately? Are expected conditions logged at DEBUG, not ERROR?
  - **PII leakage:** Do logs or error messages expose personally identifiable information, tokens, or credentials?
  - **Tracing spans:** Are spans created at service boundaries? Do spans include relevant attributes (user_id, request_id)?
  - **Metric cardinality:** Are metric labels bounded? Unbounded labels (e.g., user_id as label) cause metric explosion.
  - **Alerting coverage:** Are critical failure modes covered by alerts? Are there runbooks linked to alerts?
  - Reference: Netflix Full Cycle Developers, Google SRE.
- **Configuration:** Hardcoded values that should be configurable, missing environment variable validation
- **State Lifecycle:** Memory accumulation, zombie processes, dropped messages
- **SLO/SLA Alignment:**
  - Does the module's observed/expected error rate match defined SLOs?
  - **Latency profiles:** Are p50, p95, p99 latency targets defined and achievable?
  - **Error budget:** What percentage of the error budget has been consumed? Is the module in "protect" or "innovate" mode?
  - **Availability:** Does the module's uptime target (99.9%, 99.99%) match its actual architecture?
  - If no SLOs are defined, recommend defining them. Reference: Google SRE (https://sre.google/sre-book/service-level-objectives/).
- **Database Schema Analysis:**
  - **Missing indexes:** Queries filtering/joining on unindexed columns.
  - **Wide table scans:** SELECT * or queries without WHERE clauses on large tables.
  - **Schema constraints:** Missing NOT NULL, UNIQUE, FOREIGN KEY constraints.
  - **Migration safety:** Can migrations run without downtime? Are they backward-compatible?
  - **N+1 at schema level:** Relationships that require multiple queries instead of joins.
  - Reference: Google large-scale changes.

### Phase 4: Identify Actionable Fixes (Spec Generation)
Instead of mutating the source code, translate all findings into clear, actionable requirements that a developer (or agent) can implement via Test-Driven Development.

### Phase 5: Resilience & Chaos Engineering Assessment

**Applicability note:** Skip categories not applicable to the module type (e.g., network partitions are irrelevant for purely local CLI tools).

- **Dependency failure scenarios:** What happens when each external dependency (database, cache, message queue, external API) is unavailable? Are there timeouts, fallbacks, circuit breakers?
- **Timeout analysis:** Are all external calls bounded by timeouts? Are timeout values appropriate (not too long, not too short)?
- **Disk/resource exhaustion:** What happens when disk fills, memory is exhausted, file descriptors run out?
- **Clock skew:** Does the module make assumptions about clock synchronization? Are distributed timestamps handled correctly?
- **Network partitions:** How does the module behave during partial network failures? Split-brain scenarios?
- **Retry behavior:** Does retry logic use exponential backoff with jitter? Is there a retry budget to prevent retry storms?
- **Graceful degradation:** Can non-critical features be disabled without affecting core functionality?
- **Load shedding:** Under extreme load, does the module shed excess requests gracefully?
- **Capacity/Load Modeling:**
  - What happens at 10x current traffic? 100x?
  - Identify bottlenecks: connection pools, thread pools, rate limits, queue depth.
  - Are there horizontal scaling capabilities?
  - What is the theoretical maximum throughput?
- Reference: Netflix Chaos Monkey, Netflix Simian Army, Amazon GameDay.

---

## Update Review History

After completing the review, update `draft/deep-review-history.json`:

```json
{
  "reviews": [
    {
      "module": "<module-name>",
      "path": "<module-path>",
      "timestamp": "<ISO-8601>",
      "issues_found": <count>,
      "summary": "<one-line summary>"
    }
  ]
}
```

Create the file in the `draft/` directory if it does not exist. Append to the `reviews` array if it does. Do NOT save to `.claude/` or `.gemini/`.

---

## Final Report Generation

Output a structured summary and detailed "Implementation Spec" for any needed fixes.

**File to create:** `draft/deep-review-reports/<module-name>.md`

Create the `draft/deep-review-reports/` directory if it does not exist.

**MANDATORY: Include YAML frontmatter with git metadata.** Follow the procedure in `core/shared/git-report-metadata.md` to gather git info and generate the frontmatter. Use `generated_by: "draft:deep-review"` and set `module` to the reviewed module name.

Additional deep-review fields beyond the standard template:

```yaml
module_path: "<module-path>"
reviewer: "{model name from runtime}"
```

**Module reviewed:** name and path
**Issues by category:** ACID | Resilience | Observability
**Verdict:** PASS / CONDITIONAL PASS / FAIL

**Verdict criteria:**
- **FAIL** = any Critical issue found.
- **CONDITIONAL PASS** = no Critical issues but Important issues exist.
- **PASS** = only Minor issues or no issues.

Format findings as actionable tasks:
```markdown
### [Critical/Important/Minor] Issue Name
**File:** path/to/file:line
**Description:** What's wrong conceptually (e.g., Transaction lacks rollback on Exception XYZ).
**Proposed Fix Specification:**
- Add `try/except` block catching Exception XYZ.
- Explicitly call `db.rollback()`.
- Emit structured log with correlation ID.
```

**Constraints:**
- Do not refactor code yourself.
- Flag ambiguous fixes for human review instead of guessing.
- If the module is too large, decompose it and review sub-modules sequentially.

---

## Pattern Learning

Skip pattern learning if the analysis found zero findings.

After generating the report, execute the pattern learning phase from `core/shared/pattern-learning.md` to update `draft/guardrails.md` with patterns discovered during this module audit. Module-level reviews often reveal architecture and concurrency conventions that are valuable for future analysis.

---

## Cross-Skill Dispatch

### Suggestions at Completion

After deep-review audit completion:

**If architecture debt found:**
```
"Architecture debt identified in module audit. Consider:
  → /draft:tech-debt — Catalog and prioritize the architecture debt
  → /draft:adr — Document undiscovered design decisions found during review"
```

**If documentation gaps found:**
```
  → /draft:documentation runbook — Generate operational runbook for this module"
```
