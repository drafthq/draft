# Knowledge Base

AI guidance during track creation must be grounded in vetted sources. When providing advice, cite the source to ensure credibility and traceability.

---

## Books

### Architecture & Design

- **Domain-Driven Design** (Eric Evans) — Bounded contexts, ubiquitous language, aggregates, strategic design
- **Clean Architecture** (Robert Martin) — Dependency rule, boundaries, use cases, separation of concerns
- **Designing Data-Intensive Applications** (Martin Kleppmann) — Data models, replication, partitioning, consistency, stream processing
- **Building Evolutionary Architectures** (Ford, Parsons, Kua) — Fitness functions, incremental change, architectural governance

### Reliability & Operations

- **Release It!** (Michael Nygard) — Stability patterns, circuit breakers, bulkheads, timeouts, failure modes
- **Site Reliability Engineering** (Google) — SLOs, error budgets, toil reduction, incident response
- **The Phoenix Project** (Kim, Behr, Spafford) — Flow, feedback, continuous improvement

### Craft & Practice

- **The Pragmatic Programmer** (Hunt, Thomas, 20th Anniversary ed., 2019) — Tracer bullets, DRY, orthogonality, good enough software
- **Clean Code** (Robert Martin) — Naming, functions, error handling, code smells
- **Refactoring** (Martin Fowler, 2nd ed., 2018) — Code smells, refactoring patterns, incremental improvement
- **Working Effectively with Legacy Code** (Michael Feathers) — Seams, characterization tests, breaking dependencies

### Microservices & Distribution

- **Building Microservices** (Sam Newman, 2nd ed., 2021) — Service boundaries, decomposition, communication patterns
- **Microservices Patterns** (Chris Richardson) — Saga, CQRS, event sourcing, API gateway
- **Enterprise Integration Patterns** (Hohpe, Woolf) — Messaging, routing, transformation, endpoints

### Testing

- **Growing Object-Oriented Software, Guided by Tests** (Freeman, Pryce) — TDD outside-in, mock objects
- **Unit Testing Principles, Practices, and Patterns** (Khorikov) — Test pyramid, test doubles, maintainable tests

---

## Standards & Principles

### Security

- **OWASP Top 10** — Injection, broken auth, XSS, insecure deserialization, security misconfiguration
- **OWASP ASVS** — Application Security Verification Standard, security requirements
- **OWASP Cheat Sheets** — Specific guidance for auth, session management, input validation

### Design Principles

- **SOLID** — Single responsibility, open/closed, Liskov substitution, interface segregation, dependency inversion
- **12-Factor App** — Codebase, dependencies, config, backing services, build/release/run, processes, port binding, concurrency, disposability, dev/prod parity, logs, admin processes
- **KISS / YAGNI / DRY** — Simplicity, avoiding premature abstraction, avoiding duplication

### API Design

- **REST Constraints** — Stateless, cacheable, uniform interface, layered system
- **GraphQL Best Practices** — Schema design, resolvers, N+1 prevention
- **API Versioning Strategies** — URL, header, content negotiation

### Cloud Native

- **CNCF Patterns** — Containers, service mesh, observability, declarative configuration
- **GitOps Principles** — Declarative, versioned, automated, auditable

---

## Patterns

### Creational (GoF)

- Factory, Abstract Factory, Builder, Prototype, Singleton

### Structural (GoF)

- Adapter, Bridge, Composite, Decorator, Facade, Flyweight, Proxy

### Behavioral (GoF)

- Chain of Responsibility, Command, Iterator, Mediator, Memento, Observer, State, Strategy, Template Method, Visitor

### Resilience

- **Circuit Breaker** — Fail fast, prevent cascade failures
- **Bulkhead** — Isolate failures, limit blast radius
- **Retry with Backoff** — Transient failure recovery
- **Timeout** — Bound wait time, fail deterministically
- **Fallback** — Graceful degradation

### Data

- **CQRS** — Separate read/write models
- **Event Sourcing** — Append-only event log as source of truth
- **Saga** — Distributed transaction coordination
- **Outbox** — Reliable event publishing

### Integration (EIP)

- Message Channel, Message Router, Message Translator, Message Endpoint
- Publish-Subscribe, Request-Reply, Competing Consumers
- Dead Letter Channel, Wire Tap, Content-Based Router

---

## Anti-Patterns to Flag

### Distributed Systems

- **Fallacies of Distributed Computing** — Network reliability, zero latency, infinite bandwidth, secure network, topology stability, single admin, zero transport cost, homogeneous network
- **Distributed Monolith** — Microservices with tight coupling
- **Shared Database** — Services coupled through data

### Architecture

- **Big Ball of Mud** — No discernible structure
- **Golden Hammer** — Using one solution for everything
- **Cargo Cult** — Copying patterns without understanding
- **Premature Optimization** — Optimizing before measuring

### Code

- **God Class** — Class doing too much
- **Feature Envy** — Method more interested in other class's data
- **Shotgun Surgery** — Changes requiring many small edits across codebase
- **Leaky Abstraction** — Implementation details bleeding through interface

### Security

- **Security by Obscurity** — Hiding instead of securing
- **Trust on First Use** — Accepting unverified credentials
- **Hardcoded Secrets** — Credentials in source code

---

## Citation Format

When providing guidance, cite sources naturally:

> "Consider CQRS here (DDIA, Ch. 11) — separates read/write concerns which fits your high-read workload."
>
> "This violates the Dependency Rule (Clean Architecture) — domain shouldn't know about infrastructure."
>
> "Watch for N+1 queries (common GraphQL pitfall) — use DataLoader pattern."
>
> "Circuit breaker pattern (Release It!) would help here — fail fast instead of cascading timeouts."
