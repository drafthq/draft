# Design Norms Guardrails

Numbered rules governing HLD and LLD artifact depth, content split, diagram placement, traceability, and secrets handling. Applied by `/draft:decompose`, `/draft:review`, and `/draft:implement` when interacting with design artifacts.

**Referenced by:** `/draft:decompose`, `/draft:implement`, `/draft:review`, `/draft:deep-review`, `/draft:change`

**Last updated:** 2026-05-16 
**Rule count:** 10

---

## Rules

### DN-001: HLD describes shape; LLD describes construction

- **HLD** answers *what*: system boundaries, major components, data movement at narrative level, UI architecture, technology choices, dependencies, rollout intent, observability goals. No database DDL, no full API schemas, no class-level interfaces.
- **LLD** answers *how*: modules, contracts, schemas, migrations, algorithms, error handling, configuration keys, test strategy, operational thresholds.
- **Rationale:** Conflating depth in HLD bloats it for approvers who need architecture decisions, not implementation details.
- **Source:** Clean Architecture (Martin); Designing Data-Intensive Applications (Kleppmann)

### DN-002: HLD API surface is boundary-only

- In HLD §Detailed Design, document boundary operations (REST paths, gRPC service/method names, event names) with one-line shape summaries only. Full request/response schemas, exhaustive error catalogs, and field-level constraints belong in LLD.
- **Rationale:** Full schemas in HLD duplicate LLD and create two sources of truth that diverge.
- **Source:** Building Microservices (Newman) — API boundary contracts

### DN-003: Diagram placement by audience

- **HLD §Architecture:** `flowchart`/container views showing system shape. No workflow sequence diagrams here.
- **HLD §Detailed Design:** Mermaid sequence diagrams for critical cross-team happy paths only.
- **LLD:** Sequences for non-trivial flows including material error branches, idempotency, and ordering. Split diagrams beyond ~12 steps.
- **Rationale:** Architects reviewing HLD need structure diagrams. Implementers need sequence detail. Mixing both in HLD forces architects to read implementation noise.
- **Source:** C4 Model (Brown) — level-appropriate diagrams

### DN-004: Traceability from acceptance criteria to design

- Link the track's `spec.md` acceptance criteria scorecard in design artifacts; do not paste the full spec body. Reference stable requirement IDs or AC labels in architecture summaries and component tables so reviewers can trace coverage.
- **Rationale:** Without traceability, approvers cannot verify the design satisfies the spec without re-reading both documents in full.
- **Source:** `draft/tracks/<id>/spec.md` — AC-linkage convention

### DN-005: No secrets, PII, or live endpoints in design documents

- Use placeholders (`<REDACTED>`, synthetic IDs, `<service-host>`). Diagrams and data model examples follow the same rule. Describe integration by system role and configuration key name — never production URLs, credentials, or real customer identifiers.
- **Rationale:** Design docs are shared broadly (approvers, reviewers, docs systems). Secrets in docs are effectively leaked.
- **Source:** OWASP — Sensitive Data Exposure; `core/guardrails/security.md` SEC-01

### DN-006: LLD requires an approved HLD anchor

- Before drafting LLD, verify an approved HLD exists for the same track. If none exists or approval is unclear, stop and list gaps and assumptions, or proceed only after explicit developer confirmation of a narrowed scope.
- If LLD would contradict the HLD, call out the conflict explicitly — do not hide it or silently pick one.
- **Rationale:** LLD written without an approved HLD optimizes implementation details before architecture decisions are settled — causing rework.
- **Source:** `draft/tracks/<id>/hld.md` §Approvals gate

### DN-007: HLD ↔ LLD mapping required

- LLD must include a traceability table mapping each HLD component or section to the LLD section(s) covering it.
- **Rationale:** Without explicit mapping, reviewers cannot verify LLD coverage of the HLD or detect scope gaps.
- **Source:** `core/templates/lld.md` — traceability section

### DN-008: LLD cites authoritative contract artifacts, not duplicates them

- In LLD, cite repo paths to OpenAPI/protobuf/GraphQL/schema files as source of truth for interface contracts. Avoid pasting entire specs; a minimal excerpt is acceptable only when the file is not in the repo.
- **Rationale:** Inlined specs diverge from the implementation faster than referenced ones.
- **Source:** DRY — The Pragmatic Programmer

### DN-009: Concurrency and ordering must be explicit in LLD

- LLD §Data Model states invariants (keys, state machines, consistency levels). Add §Concurrency and Ordering where relevant: locks, idempotency keys, event delivery semantics and ordering guarantees.
- **Rationale:** Concurrency bugs are the hardest to reproduce and the most expensive to fix in production. Documenting them forces explicit reasoning.
- **Source:** Designing Data-Intensive Applications (Kleppmann) — consistency and consensus

### DN-010: Observability detail belongs in LLD, intent belongs in HLD

- **HLD:** What must be observed for the feature — SRE-facing goals, key metric categories, alert intent.
- **LLD:** Concrete metric names, label dimensions, exemplar queries, thresholds where known.
- **Rationale:** Approvers need to know *that* the design is observable; implementers need to know *how* to instrument it. These are different audiences at different review stages.
- **Source:** Google SRE Book — SLO definition; `draft/tracks/<id>/hld.md` §Checklist / §Observability
