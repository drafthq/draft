# Chapter 9: Architecture Decision Records

Part II: Track Lifecycle· Chapter 9

3 min read

Code captures what you built. Tests capture what it should do. But neither captures why you built it that way. Why PostgreSQL instead of MongoDB? Why event-driven instead of synchronous? Why this pattern over that one? These decisions have context that evaporates the moment the conversation ends. Architecture Decision Records preserve it.

## Why ADRs Matter

Every project accumulates decisions. Some are deliberate: the team evaluated three message brokers and chose RabbitMQ. Some are accidental: someone picked a library in a rush and it stuck. Without documentation, both look the same six months later — unexplained choices baked into the codebase.

ADRs solve this by capturing the decision, the context that drove it, the alternatives that were rejected, and the consequences of the choice. When a new team member asks "why don't we use GraphQL?", the answer is not a Slack archaeology expedition — it is ADR-003, which documents that REST was chosen because the client team needed cacheable endpoints and the read patterns were simple enough not to justify the schema overhead.

## The /draft:adr Command

Draft's/draft:adrcommand creates and manages ADRs as markdown files indraft/adrs/. It supports four modes:

Each ADR is saved asdraft/adrs/<number>-<kebab-case-title>.mdwith auto-incremented, zero-padded numbers (001, 002, 003).

## ADR Structure

Every ADR follows a consistent structure designed to capture the full decision context:

* Title and Number—ADR-003: Use RabbitMQ for async messaging
* Status— Current lifecycle state (Proposed, Accepted, Deprecated, Superseded)
* Context— What forces are driving this decision? Technical constraints, business requirements, organizational factors
* Decision— The actual decision, stated in active voice: "We will use RabbitMQ for all asynchronous message passing between services"
* Alternatives Considered— Each alternative with explicit pros, cons, and the specific reason it was rejected
* Consequences— Positive outcomes, negative trade-offs, and risks with mitigations
* References— Links to related discussions, RFCs, documentation, and other ADRs
The Consequences section is the most valuable part. Decisions without documented consequences are just announcements. Consequences force the author to think through the second-order effects: "We gain message durability, but we add an infrastructure dependency that requires ops knowledge to maintain."

## The ADR Lifecycle

ADRs move through a defined lifecycle:

* Proposed— The decision is documented and awaiting review. This is the initial state for every new ADR.
* Accepted— The decision has been approved and is in effect. The team is expected to follow it.
* Deprecated— The decision is no longer relevant because the context has changed. The original reasoning is preserved for historical reference.
* Superseded— A newer decision has replaced this one. The old ADR links to the new one, and the new ADR links back, creating a traceable chain of evolving decisions.

## When to Create an ADR

Not every decision warrants an ADR. Variable naming and code formatting do not. The threshold is: would a new team member reasonably ask "why?" and would the answer require more than one sentence?

Good candidates for ADRs:

* Technology choices— Selecting a database, message broker, framework, or library
* Pattern decisions— Choosing CQRS over simple CRUD, event sourcing over state mutation, REST over GraphQL
* Trade-off resolutions— Accepting eventual consistency for performance, choosing simplicity over extensibility
* Architectural boundaries— Defining module ownership, API contracts between services, data flow directions
* Security decisions— Authentication strategy, encryption approach, secret management

## ADR Evaluation

ADRs are not write-once documents. As the codebase evolves, decisions may drift from implementation./draft:adrsupports evaluation mode to check whether existing code still aligns with recorded decisions, surfacing violations and drift before they become systemic.

Running/draft:adr evaluatescans the codebase for patterns that contradict accepted ADRs. For example, if ADR-003 mandates RabbitMQ for async messaging but a new service uses Redis Pub/Sub instead, the evaluation flags the violation with file locations and the originating ADR number. This catches architectural drift before it compounds across teams and services.

## ADRs and Tracks

A track (a feature, fix, or refactor managed by Draft) may generate one or more ADRs during its lifecycle. When/draft:new-tracksurfaces a technology choice or/draft:decomposereveals an architectural trade-off, those decisions are ADR candidates.

ADRs created during a track reference the track in their context section. This creates bidirectional traceability: the ADR explains why a decision was made, and the track's spec or plan references the ADR number for any reader who wants the full context.

## Superseding Decisions

Decisions change. What was correct six months ago may be wrong today because the constraints have shifted. Draft handles this through explicit supersession rather than silent overwriting.

When you run/draft:adr supersede 3, Draft updates ADR-003's status to "Superseded by ADR-007" and adds a reference link. The new ADR-007 includes "Supersedes ADR-003" in its references. Both documents are preserved. The old reasoning is not lost — it becomes historical context that explains the evolution of the system's architecture.

When an ADR introduces a new technology, Draft suggests updatingdraft/tech-stack.md. When an ADR changes architectural patterns, Draft suggests updatingdraft/architecture.md(which triggers regeneration of.ai-context.mdvia the Condensation Subroutine). ADRs feed back into the living context that constrains future AI interactions.
