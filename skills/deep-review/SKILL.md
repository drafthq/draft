---
name: deep-review
description: Single-module production readiness audit (ACID, resilience, observability). Use to audit one service/module end-to-end — NOT for diff/PR review (use review / quick-review) or bug-finding sweeps (use bughunt).
---

# Deep Review — Production-Grade Module Audit

Perform an exhaustive end-to-end lifecycle review of a service, component, or module. Ensure ACID compliance and production-grade enterprise quality. Unlike standard review commands, this operates strictly at the module level.

## MANDATORY GRAPH LOOKUP (read before Phase 1)

When `draft/graph/schema.yaml` exists, this skill **must** follow the graph-first lookup contract in [core/shared/graph-query.md](../../core/shared/graph-query.md) §Mandatory Lookup Contract. Deep-review uses the graph to **narrow review scope** — a key 30–50% scope reduction:

1. Use `scripts/tools/graph-impact.sh`/`graph-callers.sh` and `scripts/tools/graph-arch.sh --repo .` for the audited module's structure — do not enumerate via `find`.
2. Run `scripts/tools/graph-impact.sh --repo . --file <each-changed-file>` per file in the diff (or per file in the module if no diff) to obtain the affected module set deterministically.
3. Run `scripts/tools/cycle-detect.sh --repo .` and flag any cycle that includes the audited module as Architecture Resilience finding.
4. Run `scripts/tools/hotspot-rank.sh --repo .` to identify high-fanIn files inside the module — these get deeper inspection.

Filesystem `grep` is reserved for source-text scans (API contract strings, secret patterns, log message audits). Module enumeration and caller tracing go through the graph.

## Red Flags - STOP if you're:

See [shared red flags](../../core/shared/red-flags.md) — applies to all code-touching skills.

Skill-specific:
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
- **Load track HLD/LLD if any track owns this module.** Scan `draft/tracks/*/hld.md` for §Detailed Design components matching the module path. When found, extract claims from §High-Level Design / Key Design Decisions, §Checklist (Performance/Scale/Security/Resiliency/Multi-tenancy/Upgrade/Cost), §Observability, §Deployment, and any LLD §Classes and Interfaces invariants and §Error Handling policies. These claims become the design contract this audit measures against (HLD claims vs code reality).
- **Load Learned Anti-Patterns** — If `draft/guardrails.md` exists, read the `## Learned Anti-Patterns` section before analysis begins. During the audit, when an issue matches a learned anti-pattern, prefix the finding with `[KNOWN-ANTI-PATTERN: {pattern name}]`. This separates newly discovered issues from documented recurring patterns and allows the report to recommend systemic remediation rather than isolated fixes.
- Map the module's full dependency graph (imports, injected services, external calls)
- Trace the complete lifecycle: initialization → processing → persistence → cleanup
- Identify all entry points and exit paths
- Catalog all state mutations and side effects
- **API Contract Drift Detection:** Compare the module's actual code interfaces against documented contracts (OpenAPI/Swagger specs, Protobuf/gRPC definitions, GraphQL schema files, TypeScript type exports). Flag drift: endpoints that exist in code but not in the spec (or vice versa). Flag type mismatches between spec and implementation. Reference: Amazon, Google large-scale changes.

### Phase 2: ACID Compliance Audit

> Rule references: `[CQ-006, CQ-007, CQ-008]` error/exception context, `[SEC-03]` SQL parameterization, `[RC-004, RC-005]` data integrity & concurrency. Cite the rule ID in each finding.

Every ACID finding ("missing rollback", "fire-and-forget write", "race condition", "no isolation guarantee") must cite the closest applicable rule range (e.g., `[RC-004..RC-005]` for data integrity, `[CQ-006..CQ-008]` for error context, `[SEC-03]` for SQL safety).

**Evidence requirement (Ground-Truth Discipline G1, G4):** Every ACID finding ("missing rollback", "fire-and-forget write", "race condition", "no isolation guarantee") must cite `file:line` AND include a quoted code snippet showing the issue. A finding that says "no transactions found in module X" without quoting the code site is a graph-metadata claim, not an audit result — discard it. "Verify" and "Check" below mean *Read the candidate sites*, not "scan for keywords."

- **Atomicity:** Verify all multi-step operations are wrapped in transactions. Partial failure must not leave corrupt state. Check for missing rollback paths. `[RC-004]`
- **Consistency:** Validate all invariants, constraints, and business rules are enforced before and after every state transition. Check schema validation, data type enforcement, and boundary conditions. `[CQ-006, RC-003]`
- **Isolation:** Check for race conditions, shared mutable state, concurrent access without locking/synchronization. Verify transaction isolation levels where databases are involved. `[RC-005]`
- **Durability:** Confirm committed data survives crashes. Check for fire-and-forget patterns, missing flush/sync calls, and inadequate error handling around persistence. `[CQ-007, CQ-008]`
- **Event Sourcing:** Are events immutable? Is event replay idempotent? Is the event store append-only?
- **CQRS:** Are read/write models eventually consistent? Is consistency lag acceptable for the use case?
- **Saga Pattern:** Are compensating transactions defined for each step? What happens on partial saga failure?
- **Eventual Consistency:** Are there convergence guarantees? How is conflict resolution handled (LWW, CRDT, manual)? Reference: Amazon distributed systems.

### Phase 3: Production-Grade Assessment

**Applicability note:** Skip categories that are not applicable to the module type (e.g., circuit breakers and backpressure are backend-specific; skip for frontend/CLI modules).

> Rule references: `[RC-008, RC-009, RC-010]` observability & logging, `[SEC-04, SEC-06]` network/process boundaries, `[SEC-05]` secrets, `[RC-015]` config validation, `[CQ-006..CQ-008]` error context. Cite the rule ID in each finding.

Every finding in this phase must cite the relevant rule range (e.g., `[RC-008..RC-010]` for observability, `[SEC-04, SEC-06]` for network/process boundaries, `[RC-015]` for configuration).

- **Resilience:** Graceful degradation, circuit breakers, timeout handling, backpressure `[RC-005]`
- **Observability:** Logging coverage (not excessive), structured log fields, correlation IDs, metric emission points `[RC-008, RC-009, RC-010]`
  - **Structured logging:** Are logs structured (JSON/key-value) vs free-form strings?
  - **Log level correctness:** Are ERROR/WARN/INFO/DEBUG used appropriately? Are expected conditions logged at DEBUG, not ERROR?
  - **PII leakage:** Do logs or error messages expose personally identifiable information, tokens, or credentials? `[SEC-05, RC-010]`
  - **Tracing spans:** Are spans created at service boundaries? Do spans include relevant attributes (user_id, request_id)?
  - **Metric cardinality:** Are metric labels bounded? Unbounded labels (e.g., user_id as label) cause metric explosion.
  - **Alerting coverage:** Are critical failure modes covered by alerts? Are there runbooks linked to alerts?
  - Reference: Netflix Full Cycle Developers, Google SRE.
- **Configuration:** Hardcoded values that should be configurable, missing environment variable validation `[RC-015, SEC-05]`
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

### Phase 3.5: HLD/LLD Claims vs Code Reality (when HLD found in Phase 1)

> Rule references: `[RC-012]` API/contract drift, `[SEC-01..SEC-10]` for §Security claims, `[RC-005, RC-013]` for §Resiliency/§Architecture claims. Cite the rule ID alongside `[HLD-DRIFT: §<section>]`.

Cite the most specific rule range applicable to the drift (e.g., `[RC-012]` for API changes, `[SEC-01..SEC-10]` for security claims).

For each HLD claim extracted in Phase 1, validate it against code:

- **HLD §Performance** claims (e.g., "p95 < 200ms", "QPS = 10k") — search for benchmarks, load tests, or APM dashboard evidence. If absent, surface as Important: "HLD claims X but no measurement evidence in code/CI."
- **HLD §Scale** claims (horizontal scaling, vertical scaling, bottlenecks named) — verify deployment config (replicas, autoscaler), connection pools, queue capacities support the claim.
- **HLD §Security** claims (RBAC, encryption, credential protection) — verify the cited middleware/guard exists and is invoked on the documented surface.
- **HLD §Resiliency** claims (graceful degradation, circuit breakers, timeouts) — verify cited code paths implement the claim.
- **HLD §Multi-tenancy** claims (tenant isolation, predictable performance, migration path) — verify query partitioning, RBAC scope, migration tooling.
- **HLD §Upgrade** claims (backward compat, dependent service order) — verify schema migration policy, API version handling.
- **HLD §Cost** claims — flag if codebase introduces new cloud resources not reflected in HLD.
- **LLD §Classes/Interfaces invariants** (thread safety, idempotency, ordering) — search for violations: shared state without locks, non-idempotent retry paths, ordering assumptions broken by concurrency.
- **LLD §Error Handling policy** — verify retry/backoff/circuit-breaker thresholds in code match the LLD table.

Surface gaps as findings with prefix `[HLD-DRIFT: §<section>]` (Important if the gap is documentation-vs-implementation drift; Critical if the code violates a stated invariant or security claim).

### Phase 4: Identify Actionable Fixes (Spec Generation)
Instead of mutating the source code, translate all findings into clear, actionable requirements that a developer (or agent) can implement via Test-Driven Development.

### Phase 5: Resilience & Chaos Engineering Assessment

**Applicability note:** Skip categories not applicable to the module type (e.g., network partitions are irrelevant for purely local CLI tools).

> Rule references: `[RC-005]` concurrency & retries, `[SEC-04]` network boundaries, `[CQ-008]` timeouts/cleanup, `[RC-015]` capacity/config bounds. Cite the rule ID in each finding.

Cite relevant rule ranges for resilience findings (e.g., `[RC-005]` for retries, `[CQ-008]` for timeouts).

- **Dependency failure scenarios:** What happens when each external dependency (database, cache, message queue, external API) is unavailable? Are there timeouts, fallbacks, circuit breakers? `[RC-005, CQ-008]`
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
### [Critical/Important/Minor] Issue Name `[RC-### or CQ-### or SEC-## if applicable]`
**File:** path/to/file:line
**Description:** What's wrong conceptually (e.g., Transaction lacks rollback on Exception XYZ).
**Proposed Fix Specification:**
- Add `try/except` block catching Exception XYZ.
- Explicitly call `db.rollback()`.
- Emit structured log with correlation ID.
```

Cite the most specific rule ID from `core/guardrails/review-checks.md` (RC-###), `core/guardrails/security.md` (SEC-##), or `core/guardrails/code-quality.md` (CQ-###) that governs the finding. If no numbered rule applies, omit — the finding stands.

**For Phase 3 (Security):** Load `core/guardrails/security.md` and apply the 5-step security reasoning chain. Hard red line violations (SEC-01…SEC-10) are always Critical. Run `core/guardrails/dependency-triage.md` procedure for any dependency manifest files in the module's scope `[RC-014]`.

**Constraints:**
- Do not refactor code yourself.
- Flag ambiguous fixes for human review instead of guessing.
- If the module is too large, decompose it and review sub-modules sequentially.

---

## Pattern Learning

Skip pattern learning if the analysis found zero findings.

After generating the report, execute the pattern learning phase from `core/shared/pattern-learning.md` to update `draft/guardrails.md` with patterns discovered during this module audit. Module-level reviews often reveal architecture and concurrency conventions that are valuable for future analysis.

---

## Report Closing: Next Actions (REQUIRED)

Every deep-review report must end with a `## Next Actions` section listing the smallest set of follow-ups in execution order. Use this exact shape:

```markdown
## Next Actions

| # | Action | Owner | Blocker? | Skill / Command |
|---|---|---|---|---|
| 1 | <imperative one-liner> | <author\|on-call\|TBD> | yes/no | `/draft:<skill> <args>` or `n/a` |
```

Rules:
- Production-blocking findings (`[SEC-*]`, ACID violations, unbounded resource use) produce blocker rows.
- Suggest `/draft:adr` for structural changes, `/draft:new-track` for multi-week remediation, `/draft:incident-response` for hot issues, `/draft:tech-debt` for systemic items.
- Cap at 10 actions; group related fixes under one row.

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

## Mandatory Self-Check (before final report)

Before printing the final report, internally verify and report:

1. **Graph files queried** — JSONL files loaded plus any live graph query-tool invocations (especially `impact` per file in scope).
2. **Layer 1 files deliberately skipped** — list any context sections skipped.
3. **Filesystem grep fallback justification** — for every `grep`/`find` run, name the concept it searched for. Source-text scans for API contract strings, secrets, or log audits are exempt.

If `draft/graph/schema.yaml` does not exist, set `Graph files queried: NONE` and use justification `graph data unavailable`.

## Graph Usage Report (append to report)

Emit the canonical footer from [core/shared/graph-usage-report.md](../../core/shared/graph-usage-report.md) §Canonical footer. The lint hook `scripts/tools/check-graph-usage-report.sh` validates the section on save.
## Skill Telemetry

As the last step after saving the deep-review report, emit a metrics record. Best-effort — never block.

**Payload fields:**
```json
{
  "skill": "deep-review",
  "module": "<module path or name>",
  "phases_completed": <N>,
  "critical_count": <N>,
  "important_count": <N>,
  "sec_violations": <N>,
  "acid_violations": <N>,
  "graph_queries": <N>,
  "fallback_grep_count": <N>
}
```

**Emit call:**
```bash
DRAFT_TOOLS="${DRAFT_PLUGIN_ROOT:-$HOME/.claude/plugins/draft}/scripts/tools"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$HOME/.cursor/plugins/local/draft/scripts/tools"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$PWD/scripts/tools"
[ -x "$DRAFT_TOOLS/emit-skill-metrics.sh" ] && bash "$DRAFT_TOOLS/emit-skill-metrics.sh" \
  '{"skill":"deep-review","module":"<module>","phases_completed":<N>,"critical_count":<N>,"important_count":<N>,"sec_violations":<N>,"acid_violations":<N>,"graph_queries":<N>,"fallback_grep_count":<N>}'
```
