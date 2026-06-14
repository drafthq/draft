---
project: "{PROJECT_NAME}"
module: "root"
generated_by: "draft:init"
generated_at: "{ISO_TIMESTAMP}"
---

# Technology Matrix

| Field | Value |
|-------|-------|
| **Branch** | `{LOCAL_BRANCH}` → `{REMOTE/BRANCH}` |
| **Commit** | `{SHORT_SHA}` — {COMMIT_MESSAGE} |
| **Generated** | {ISO_TIMESTAMP} |
| **Synced To** | `{FULL_SHA}` |

> Auto-generated. Do not edit directly.
> Re-run `/draft:init` to update.

---

## Org Standards

Technologies used by majority of services (>50%):

| Technology | Category | Usage | Services |
|------------|----------|-------|----------|
| [PostgreSQL] | Database | [X]% | [list] |
| [Redis] | Caching | [X]% | [list] |
| [Docker] | Container | [X]% | [list] |
| [GitHub Actions] | CI/CD | [X]% | [list] |

## Technology Distribution

### Languages

| Language | Services | Percentage | Notes |
|----------|----------|------------|-------|
| [Go] | [auth, users, gateway] | [45%] | Preferred for performance-critical |
| [TypeScript] | [billing, notifications] | [40%] | Preferred for rapid development |
| [Python] | [ml-service, analytics] | [15%] | ML/data workloads only |

### Databases

| Database | Services | Use Case |
|----------|----------|----------|
| PostgreSQL | [auth, billing, users] | Primary OLTP |
| MongoDB | [notifications, analytics] | Document store |
| Redis | [auth, gateway] | Cache, sessions |

### Frameworks

| Framework | Language | Services |
|-----------|----------|----------|
| [Gin] | Go | auth, users, gateway |
| [Express] | TypeScript | billing |
| [FastAPI] | Python | ml-service |

### Message Queues

| Queue | Services | Pattern |
|-------|----------|---------|
| [RabbitMQ] | notifications, reports | Pub/sub |
| [Kafka] | analytics | Event streaming |

## Variance Report

Services deviating from org standards:

| Service | Deviation | Standard | Justification |
|---------|-----------|----------|---------------|
| [ml-service] | Python | Go/TypeScript | ML ecosystem requirements |
| [analytics] | MongoDB | PostgreSQL | Time-series workload |
| [legacy-reports] | Java | Go/TypeScript | Legacy, migration planned |

## Shared Libraries

Internal libraries used across services:

| Library | Purpose | Version | Used By | Repo |
|---------|---------|---------|---------|------|
| [@org/auth-client] | Auth service client | 2.x | billing, gateway, notifications | [link] |
| [@org/logging] | Structured logging | 1.x | all services | [link] |
| [@org/errors] | Error handling | 1.x | auth, billing, users | [link] |

## Version Matrix

Current versions in production:

| Service | Language Version | Framework Version | Last Updated |
|---------|-----------------|-------------------|--------------|
| auth-service | Go 1.21 | Gin 1.9 | [date] |
| billing-service | Node 20 | Express 4.18 | [date] |
| user-service | Go 1.21 | Gin 1.9 | [date] |

<!-- MANUAL START -->
## Technology Roadmap

[Add planned technology changes, deprecations, or migrations here — preserved on re-index]

<!-- MANUAL END -->
