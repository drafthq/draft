---
project: "{PROJECT_NAME}"
module: "root"
generated_by: "draft:init"
generated_at: "{ISO_TIMESTAMP}"
---

# Tech Stack: [Org/Product Name]

| Field | Value |
|-------|-------|
| **Branch** | `{LOCAL_BRANCH}` → `{REMOTE/BRANCH}` |
| **Commit** | `{SHORT_SHA}` — {COMMIT_MESSAGE} |
| **Generated** | {ISO_TIMESTAMP} |
| **Synced To** | `{FULL_SHA}` |

> Synthesized from [X] service contexts.
> This defines **org-wide standards**. Service-specific additions are in their local tech-stack.md.
> Re-running `/draft:init` will update auto-generated sections but preserve manual edits.

---

## Org Standards

### Languages

- **Primary**: [Most common language] — [X]% of services
- **Secondary**: [Second most common] — [Y]% of services
- **Specialized**: [Other languages] — approved for specific use cases

### Frameworks

| Purpose | Standard | Alternatives |
|---------|----------|--------------|
| HTTP API | [Framework] | [Approved alternatives] |
| Background Jobs | [Framework] | - |
| Testing | [Framework] | - |

### Data Storage

| Type | Standard | When to Use |
|------|----------|-------------|
| OLTP | PostgreSQL | Default for relational data |
| Document | MongoDB | Approved for specific use cases |
| Cache | Redis | Session, cache, rate limiting |
| Search | Elasticsearch | Full-text search requirements |

### Messaging

| Pattern | Standard |
|---------|----------|
| Async Events | RabbitMQ |
| Event Streaming | Kafka (approved for high-volume) |

### Infrastructure

| Component | Standard |
|-----------|----------|
| Container | Docker |
| Orchestration | Kubernetes |
| CI/CD | GitHub Actions |
| Registry | [Container registry] |
| Secrets | [Secrets manager] |

## Approved Variances

Services may deviate from standards with documented justification:

| Service | Variance | Standard | Justification |
|---------|----------|----------|---------------|
| [ml-service] | Python | Go/TypeScript | ML ecosystem requirements |
| [analytics] | MongoDB | PostgreSQL | Time-series workload |

> Add new variances via PR to this file. Variances without justification will be flagged.

## Shared Libraries

Internal libraries all services should use:

| Library | Purpose | Current Version |
|---------|---------|-----------------|
| @org/auth-client | Auth service integration | 2.x |
| @org/logging | Structured logging | 1.x |
| @org/errors | Error handling patterns | 1.x |
| @org/config | Configuration management | 1.x |

## Code Patterns

Org-wide conventions:

| Pattern | Standard | Reference |
|---------|----------|-----------|
| Error Handling | [Custom error classes with codes] | @org/errors |
| Logging | [Structured JSON, correlation IDs] | @org/logging |
| API Versioning | [URL path: /v1/, /v2/] | API guidelines |
| Authentication | [JWT validation via auth-service] | Auth spec |

<!-- MANUAL START -->
## Technology Decisions

[Document org-wide technology decisions and rationale here — preserved on re-index]

### TDR-001: [Decision Title]

**Context:** [Why this decision was needed]
**Decision:** [What was decided]
**Services Affected:** [Which services]

<!-- MANUAL END -->

## Compliance

| Requirement | Standard | Enforcement |
|-------------|----------|-------------|
| Secrets | Never in code, use secrets manager | CI scan |
| Dependencies | Weekly vulnerability scan | Dependabot |
| Containers | Base images from approved list | CI policy |
