# Chapter 14: Deep Review

Part IV: Quality· Chapter 12

5 min read

Your team is two weeks from launch. The feature works in staging, passes all tests, and the product manager is satisfied. Then someone asks: "What happens if the database connection drops mid-transaction?" Silence. Nobody knows. A standard code review checked that the code is clean, follows conventions, and handles the expected cases. But nobody audited whether the system survives the unexpected ones. That is the gap/draft:deep-reviewfills — a production-readiness audit that goes beyond correctness into resilience, durability, and operational maturity.

## Beyond Code Review

Standard code review asks: "Is this code correct?" Deep review asks: "Will this code survive production?" These are fundamentally different questions. Correct code can still lose data during crashes, deadlock under concurrent load, or silently corrupt state when a downstream service goes down.

/draft:deep-reviewoperates at themodule level, not the pull-request level. It audits an entire service, component, or module against production-grade criteria. The command auto-selects the next unreviewed module from your project, or you can target one explicitly:

Each completed review is logged todraft/deep-review-history.jsonwith the module name, timestamp, issue count, and summary. Subsequent runs automatically pick the next unreviewed module, or the one with the oldest review date if all have been covered.

## The ACID Compliance Audit

Deep review borrows from database theory. ACID properties — Atomicity, Consistency, Isolation, Durability — are not just database concerns. They apply to any system that manages state. Every service that writes data, updates records, or coordinates multi-step operations must answer these questions.

ACID compliance is evaluated for every state-changing operation in the module, not just database transactions. An HTTP handler that updates a cache, sends a notification, and writes to a database is a multi-step operation that can fail partway through. Deep review audits each such operation for atomicity, consistency, isolation, and durability guarantees.

The audit extends beyond classical ACID into distributed system patterns. If the module uses event sourcing, deep review checks whether events are immutable and replay is idempotent. If it uses CQRS, it evaluates whether the consistency lag between read and write models is acceptable. If sagas coordinate multi-service operations, it verifies that compensating transactions are defined for every step.

## Production Robustness Patterns

Passing tests does not mean surviving production. Deep review evaluates a set of production robustness patterns that separate "works on my machine" from "works at 3 AM when the cache cluster is down."

### Resilience

Does the module degrade gracefully when dependencies fail? Deep review looks for circuit breakers on external calls, timeout handling on every outbound request, and backpressure mechanisms that prevent cascade failures. It checks what happens at 10x and 100x current traffic, identifies bottlenecks in connection pools and thread pools, and evaluates whether the module can shed excess load without crashing.

### Idempotency and Retry Safety

Can operations be safely retried without side effects? If a payment charge is retried after a network timeout, does the user get double-charged? Deep review traces retry logic to ensure exponential backoff with jitter is used and that retry budgets exist to prevent retry storms.

### Fail-Closed Behavior

When something unexpected happens, does the system fail into a safe state or an unsafe one? An authorization check that defaults to "allow" on error is fail-open — a security vulnerability. Deep review identifies every error path and evaluates whether the default behavior is safe.

## Observability Assessment

Production systems that cannot be observed cannot be debugged. Deep review evaluates observability across multiple dimensions:

* Structured logging— Are logs structured (JSON/key-value) or free-form strings? Are log levels used correctly (ERROR for actual errors, not expected conditions)?
* Correlation IDs— Can a request be traced across service boundaries? Are tracing spans created at service boundaries with relevant attributes?
* Metric cardinality— Are metric labels bounded? Unbounded labels likeuser_idcause metric explosion that crashes monitoring infrastructure.
* PII leakage— Do logs or error messages expose personally identifiable information, tokens, or credentials?
* Alerting coverage— Are critical failure modes covered by alerts? Are there runbooks linked to those alerts?
A common production failure: a developer addsuser_idas a metric label. With 100,000 users, every metric now has 100,000 time series. Prometheus runs out of memory. Grafana dashboards timeout. The monitoring system itself becomes the outage. Deep review catches unbounded label patterns before they reach production.

## SLO Evaluation

Deep review checks whether the module has defined service-level objectives and whether the architecture can actually deliver them. A module claiming 99.99% availability (52 minutes of downtime per year) while depending on a single database instance without failover is making a promise its architecture cannot keep.

The evaluation covers latency profiles (p50, p95, p99 targets), error budgets, and the gap between stated availability targets and actual architectural capabilities. If no SLOs are defined, the review recommends establishing them — because a system without SLOs has no definition of "good enough."

Deep review audits all dimensions for every module — ACID compliance, observability, resilience, SLOs — regardless of service type. The review is most valuable when it has concrete targets to check against. SRE and platform engineers should document actual SLO targets (availability, latency percentiles, error budgets), observability requirements (what must be logged, required metrics, alerting thresholds), and security posture expectations inworkflow.mdor your team's runbook. Without defined targets, the review can only flag the absence of SLOs — it cannot tell you whether your architecture delivers on the promises your team has made.

## Database-Specific Analysis

For modules that interact with databases, deep review performs targeted analysis that generic code review misses:

## The Report

Deep review produces a structured report saved todraft/deep-review-reports/<module-name>.md. Every finding is classified by severity and formatted as an actionable specification — not a vague suggestion, but a concrete description of what to fix and how:

The report ends with a verdict:PASS(only minor issues),CONDITIONAL PASS(no critical issues, but important ones exist), orFAIL(at least one critical issue found). A FAIL verdict means the module is not production-ready.

## API Contract Drift Detection

A subtle class of production bugs comes from drift between documented API contracts and actual implementations. Deep review compares the module's code interfaces against OpenAPI/Swagger specs, Protobuf definitions, GraphQL schemas, or TypeScript type exports. It flags endpoints that exist in code but not in the spec, types that differ between spec and implementation, and undocumented endpoints that external consumers may be relying on.

## When to Use Deep Review

Deep review is expensive in terms of time and token usage. It is not meant for every commit or every pull request. Use it for:

* Pre-launch audits— Before shipping a new service or major feature to production
* Critical path changes— When modifying payment processing, authentication, or data integrity code
* Compliance requirements— When security or regulatory review requires documented evidence of production-readiness assessment
* Post-incident review— After a production incident, to audit the affected module for related issues
Regular/draft:reviewchecks whether code matches the spec, follows conventions, and passes quality gates. Deep review assumes the code is correct and asks whether it will survive the conditions that production imposes: failures, load, concurrency, crashes, and the slow degradation that happens over months of operation. They complement each other — review for development quality, deep review for operational readiness.

After completing the audit, deep review runs the pattern learning phase, updatingdraft/guardrails.mdwith architecture and concurrency conventions discovered during the module analysis. These patterns feed back into future reviews and implementations, making each subsequent deep review more precise.
