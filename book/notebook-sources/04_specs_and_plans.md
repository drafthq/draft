# Chapter 4: Specs & Plans

Part II: Track Lifecycle· Chapter 4

6 min read

Your team just decided to redesign the authentication system. Someone opens a chat window, types "add OAuth2 support," and the AI starts generating code. Forty minutes later you have 2,000 lines across 15 files, none of which match your existing auth patterns, half of which introduce dependencies your team has never approved. The code works in isolation. It is completely unusable. Draft's track creation process exists to make this scenario structurally impossible.

## Starting a Track

Every unit of work in Draft — a feature, a bug fix, a refactor — begins with/draft:new-track. This command does not generate code. It starts acollaborative intake processbetween you and the AI, producing two artifacts that govern everything that follows: a specification and a plan.

The AI reads your project'sproduct.md,tech-stack.md,.ai-context.md, andworkflow.mdbefore asking a single question. It arrives at the conversation already understanding your architecture, your constraints, and your conventions. Then the intake begins.

## The Intake Conversation

Draft's intake is not a form. It is a structured dialogue where the AI acts as anexpert partner, not a passive recorder. For each question, the AI asks, listens, and then contributes — surfacing patterns you might not have considered, risks you haven't named, and trade-offs between approaches.

The conversation moves through five phases:

* Existing Documentation— Do you have a PRD, RFC, or design doc? The AI ingests it, extracts key points, and identifies gaps: "I've extracted the authentication flow and token lifecycle. I notice the doc doesn't cover token revocation."
* Problem Space— What problem are we solving? Why now? Who experiences the pain? What's the scope boundary? After each answer, the AI challenges assumptions with "why" questions and contributes domain knowledge.
* Solution Space— What's the simplest version? Why this approach over alternatives? The AI presents 2–3 alternative approaches with trade-offs, cross-references your architecture document for integration points, and suggests patterns from your tech stack to leverage.
* Risk & Constraints— What could go wrong? What dependencies exist? The AI surfaces risks you may not have considered, referencing OWASP guidelines, distributed systems fallacies, and known failure modes.
* Success Criteria— How do we know this is complete? The AI suggests measurable, testable acceptance criteria aligned with your product goals.
The AI never dumps a questionnaire. It asks one question, processes the answer, contributes its expertise, updates the draft specification, and then moves on. Each exchange builds on the last. This is a conversation, not a form submission.

Throughout the intake, the AI grounds its advice in vetted sources. When it recommends CQRS, it cites "DDIA, Ch. 11." When it warns about access control, it references "OWASP A01:2021." When it suggests a circuit breaker, it cites "Release It!" This is not decoration — it gives you a reference to evaluate the advice independently.

## Bug and RCA Intake

Bug tracks use a different intake flow, tighter in scope and focused on investigation. The AI walks through four phases:Symptoms & Context(exact error, who's affected, when it started),Reproduction(exact steps, environment, expected vs. actual),Blast Radius(what still works, where the failure boundary lies), andCode Locality(suspected location, entry and failure points). The result is a bug specification with reproduction steps, blast radius assessment, and a root cause hypothesis.

## The Elicitation Pass

Before the specification is finalized, the AI offers a quick stress-test — three challenge techniques selected based on the track type. For feature tracks, you can choose aPre-mortem("It's six months later and this feature failed — what went wrong?"), aScope Boundarycheck ("What's the smallest version that still achieves the core goal?"), or anEdge Case Stormthat surfaces five boundary conditions not yet in the acceptance criteria. This takes two minutes and often catches blind spots that would otherwise surface during implementation.

## What Gets Generated

The intake conversation produces two files and one metadata record, all stored indraft/tracks/<track-id>/.

### spec.md

The specification captures everything decided during intake: problem statement, background, functional and non-functional requirements, acceptance criteria, non-goals, technical approach, success metrics, stakeholder approvals, risk assessment, and deployment strategy. It includes YAML frontmatter linking the spec to the exact git commit at which it was created.

### plan.md

The plan breaks the specification intophases, and each phase intotasks. Tasks are ordered by dependency — the AI uses topological sorting to determine implementation order, placing leaf dependencies first.

Each task is designed to be completable in a focused session, produce testable output, and fit in a single commit. The Planner Agent explicitly rejects vague tasks like "implement the feature" — every task must have clear success criteria.

### metadata.json

The metadata file tracks machine-readable state: track type, status, timestamps, and progress counters.

## Status Markers

Every task in a plan carries a status marker that tracks its lifecycle:

* [ ]Pending— not yet started
* [~]In Progress— currently being implemented
* [x]Completed— implemented, tested, and committed
* [!]Blocked— cannot proceed, requires manual intervention
These markers are the source of truth for progress tracking. When a task completes, its commit SHA is recorded inline:[x] Task 1.1: Create OAuth provider schema (a1b2c3d). This creates a direct link between the plan and the git history.

## Quick Mode

Not every change needs a full intake ceremony. For hotfixes and small, isolated changes scoped to 1–3 hours, the--quickflag skips the collaborative conversation entirely.

Quick mode asks exactly two questions: "What exactly needs to change?" and "How will you know it's done?" It then generates a minimalspec.mdand a flatplan.mdwith a single phase. The metadata records"type": "quick"so the status display adjusts accordingly — no phase progress, just a flat task list.

Quick mode is appropriate for changes where the scope is already obvious: a one-line bug fix, a configuration update, a typo correction. If you find yourself wanting to explain context, trade-offs, or alternative approaches, use the full intake — those are signals that the work has hidden complexity.

## The Planner Agent

Behind the intake conversation is the Planner Agent, a specialized behavioral protocol tuned for requirement analysis and task decomposition. The Planner organizes work into phases following a consistent pattern:Foundation(data models, types, interfaces),Implementation(business logic, core features),Integration(wiring components, external APIs), andPolish(error handling, edge cases, documentation).

The Planner identifies dependencies between tasks and flags parallel execution opportunities. It writes acceptance criteria that are specific (one testable condition per criterion), observable (verifiable without reading implementation), and independent (no "after criterion 3 passes" dependencies). It rejects vague criteria like "system works correctly" or "code is clean" and demands measurable targets: "Response time under 200ms at p95," not "performance is good."

## Constraints from Project Context

The specification and plan are not created in a vacuum. During intake, the AI continuously references four project files that act as constraints:

* product.md— Product vision, user personas, goals, and guidelines. The AI aligns acceptance criteria with documented product goals and flags when proposed work contradicts the product direction.
* tech-stack.md— Languages, frameworks, accepted patterns, and code style. The AI suggests implementation approaches consistent with the stack and warns when a proposal would introduce an unapproved dependency.
* workflow.md— Team engineering workflow: TDD preference, commit strategy and frequency, code review checklists, phase verification procedures, and session management rules. Every Draft agent reads this file to determinehowwork should be done — when to run tests, how to structure commits, what review gates to enforce. This is not per-engineer preference; it is team-level engineering process stored in the repository.
* guardrails.md— Hard constraints, learned conventions, and known anti-patterns accumulated from previous tracks. The AI checks proposed work against these guardrails and flags violations before they enter the plan. Learned patterns are auto-discovered by/draft:learnduring initialization and refined by quality commands over time.
Draft refuses to implement without an approved specification and plan. This is by design. The most expensive bugs are not logic errors — they are building the wrong thing. A 30-minute intake conversation is cheap compared to a week of implementing the wrong feature.

With the specification finalized and the plan approved, the track is ready for implementation. The next chapter covers how/draft:implementexecutes the plan, one task at a time, with the same discipline that created it.
