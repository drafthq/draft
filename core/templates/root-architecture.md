---
project: "{PROJECT_NAME}"
module: "root"
generated_by: "draft:init"
generated_at: "{ISO_TIMESTAMP}"
---

# Architecture: [Org/Product Name]

| Field | Value |
|-------|-------|
| **Branch** | `{LOCAL_BRANCH}` → `{REMOTE/BRANCH}` |
| **Commit** | `{SHORT_SHA}` — {COMMIT_MESSAGE} |
| **Generated** | {ISO_TIMESTAMP} |
| **Synced To** | `{FULL_SHA}` |

> Synthesized from [X] service contexts.
> This is a **system-of-systems** view. For service internals, see individual service contexts.
> Re-running `/draft:init` will update auto-generated sections but preserve manual edits.

---

## System Overview

**Key Takeaway:** [One paragraph synthesizing overall system purpose from service summaries — what this platform does, who it serves, and its primary value proposition]

### System Topology

```mermaid
graph TD
    subgraph "External"
        Users[Users/Clients]
        ThirdParty[Third-Party Services]
    end

    subgraph "Edge Layer"
        Gateway[API Gateway]
    end

    subgraph "Core Services"
        ServiceA[Service A]
        ServiceB[Service B]
    end

    subgraph "Data Layer"
        DB[(Database)]
        Cache[(Cache)]
    end

    Users --> Gateway
    Gateway --> ServiceA
    Gateway --> ServiceB
    ServiceA --> DB
    ServiceB --> Cache
```

> Diagram auto-generated from service dependencies. Edit to add context.

## Service Directory

| Service | Responsibility | Tech | Status | Details |
|---------|---------------|------|--------|---------|
| [service-name] | [One-line responsibility] | [Primary tech] | ✓ Active | [→ architecture](../services/[name]/draft/.ai-context.md) |

> **Status:** ✓ Active = initialized and maintained, ○ Legacy = initialized but deprecated, ? = not initialized

## Shared Infrastructure

<!-- Extracted from common external dependencies across services -->

| Component | Purpose | Used By |
|-----------|---------|---------|
| [PostgreSQL] | [Primary datastore] | [service-a, service-b] |
| [Redis] | [Caching, sessions] | [service-a, service-c] |
| [RabbitMQ] | [Async messaging] | [service-b, service-d] |

## Cross-Service Patterns

<!-- Extracted from common conventions across service .ai-context.md (or architecture.md) files -->

| Pattern | Description | Services |
|---------|-------------|----------|
| [JWT Auth] | [All services validate JWT via auth-service] | [all] |
| [Event-Driven] | [Async events via message queue] | [notifications, reports] |

## Data Flows

### [Primary Flow Name]

```mermaid
sequenceDiagram
    participant Client
    participant Gateway
    participant ServiceA
    participant ServiceB
    participant DB

    Client->>Gateway: Request
    Gateway->>ServiceA: Route
    ServiceA->>ServiceB: Internal call
    ServiceB->>DB: Query
    DB-->>ServiceB: Result
    ServiceB-->>ServiceA: Response
    ServiceA-->>Gateway: Response
    Gateway-->>Client: Response
```

> Add primary cross-service data flows here.

<!-- MANUAL START -->
## Architectural Decisions

[Document key architectural decisions, trade-offs, and rationale here — preserved on re-index]

### ADR-001: [Decision Title]

**Context:** [Why this decision was needed]
**Decision:** [What was decided]
**Consequences:** [Impact of the decision]

<!-- MANUAL END -->

## Notes

- For detailed service architecture, navigate to individual service contexts via the Details column
- This file is regenerable via `/draft:init`
- Manual edits between `<!-- MANUAL START -->` and `<!-- MANUAL END -->` are preserved
