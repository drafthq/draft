---
name: draft
description: "Lists Draft's canonical workflow commands, explains the Context-Driven Development flow (init, plan, implement, review), and recommends the appropriate next step. Use when the user asks about available Draft commands, needs help choosing a workflow step, or says 'what can Draft do', 'help', or 'show commands'."
---

# Draft - Context-Driven Development

Draft is a methodology for structured software development: **Context → Spec & Plan → Implement → Verify**

## Red Flags - STOP if you're:

- Jumping straight to implementation without reading existing Draft context
- Suggesting `/draft:implement` before a track has an approved spec and plan
- Not checking `draft/tracks.md` for existing active tracks before creating new ones
- Skipping the recommended command and going freeform
- Ignoring existing `.ai-context.md`, `product.md`, `tech-stack.md`, or `workflow.md` context

**Read context first. Follow the workflow.**

---

## Workflow Commands

### Canonical Workflow
```
init → plan → implement → review → upload
               ↑            |
               └────────────┘  (review auto-invoked at phase boundaries)
```

### Primary Workflow (Parent) Commands
These 7 canonical parent commands coordinate and orchestrate the entire development lifecycle, automatically routing to specialist subcommands when appropriate.

### Routed Core Workflows (5 routers)
The 5 router commands provide intent-based dispatch into the 20+ specialist commands. Use the router form for discoverability; leaf commands remain supported for compatibility.

| Router | Scope | Dispatches To (examples) |
|--------|-------|--------------------------|
| `/draft:plan` | Planning & architecture | new-track, decompose, adr, tech-debt, change |
| `/draft:ops` | Operations & lifecycle | deploy-checklist, incident-response, standup, status, revert |
| `/draft:docs` | Authoring | documentation |
| `/draft:discover` | Investigation & quality | debug, bughunt, quick/deep-review, coverage, testing-strategy, learn, index, tour, impact, assist-review |
| `/draft:jira` | Jira integration (preview, create, review) | - |

### Specialist Commands (leaf skills, invoked via routers or directly)

---

### Specialist & Subcommands
These commands remain available for targeted, specialist execution outside parent command orchestration. **Every command below appears exactly once in this reference.**

#### 1. Planning & Architecture
* `/draft:new-track` - Create a new feature/bug track with structured `spec.md` and `plan.md`
* `/draft:decompose` - Perform module-level decomposition with dependency mapping
* `/draft:change` - Safely manage and document mid-track requirement changes and plan updates
* `/draft:adr` - Write Architecture Decision Records to capture permanent technical choices

#### 2. Quality & Testing
* `/draft:quick-review` - Fast, lightweight 4-dimension code review for staged changes or diffs
* `/draft:bughunt` - Exhaustive 14-dimension codebase-wide bug hunt with verification protocol
* `/draft:deep-review` - Rigorous module-scoped lifecycle audit (ACID compliance, resilience)
* `/draft:coverage` - Measure and report code coverage (targeting 95%+ for changed code)
* `/draft:testing-strategy` - Design testing plan and identify coverage/mocking strategies
* `/draft:learn` - Discover coding patterns from recent Git diffs and update `draft/guardrails.md`

#### 3. Operations & Debugging
* `/draft:status` - Display a comprehensive overview of active track phases, tasks, and modules
* `/draft:revert` - Safely roll back active tasks or commits using Git-aware tracking
* `/draft:debug` - Structured 4-stage debugging flow (reproduce → isolate → diagnose → fix)
* `/draft:standup` - Summarize git activity and file changes for standup reporting
* `/draft:deploy-checklist` - Pre-deployment checklist verification with automated rollback triggers
* `/draft:upload` - Pre-upload gate: review, HLD approvals, validator chain, then git upload/PR
* `/draft:incident-response` - Coordinate incident lifecycle (triage → mitigate → postmortem)

#### 4. Setup & Documentation
* `/draft` - Display this command overview and help reference
* `/draft:index` - Aggregate multi-service context in monorepo structures
* `/draft:discover` - Phase 0 code-spike report (hotspots, mode flags, open questions) before spec freeze
* `/draft:documentation` - Generate structured codebase documentation (API, Onboarding, Runbooks)
* `/draft:tech-debt` - Audit technical debt across 6 key dimensions

**Integration:**
| Command | Purpose |
|---------|---------|
| `/draft:jira` | Unified Jira workflows (preview / create / review) |

---

## Core Workflow: Validation & Recovery Loop

To maintain code quality and delivery velocity, the Core Workflow operates as a closed-loop feedback system with explicit validation checkpoints and recovery actions.

```mermaid
flowchart TD
    A[Start: /draft:init] --> B[Plan: /draft:plan /new-track]
    B --> C{Plan Valid?}
    C -- "No (Revise Plan)" --> B
    C -- "Yes (Approve Spec)" --> D[Implement: /draft:implement]

    D --> E{Tests Pass & Spec Met?}
    E -- "No (Debug/Fix)" --> D
    E -- "Yes (Verify)" --> F[Review: /draft:review]

    F --> G{Quality Gates Passed?}
    G -- "No (Reject)" --> H[Analyze Feedback & Recover]
    H -- "If Blocked" --> I[Mark Blocked [!] / ADR / Decompose]
    H -- "If Scope Drifted" --> J[Run /draft:change]
    H -- "If Code Defects" --> D

    G -- "Yes (Ship)" --> K[Ops: /draft:ops /deploy-checklist]
```

### Validation Checkpoints & Recovery Actions

| Checkpoint | Criteria | Recovery |
|---|---|---|
| **1. Planning** | Track ID in `draft/tracks.md`; `scope_includes`/`scope_excludes` set; acceptance criteria stated; task checklist in `plan.md` with `[ ]` markers. | Requirements or design drifted → `/draft:change`. |
| **2. Implementation / TDD** | Code compiles; unit + integration tests pass; coverage ≥95% for changed lines. | Blocked by external/architectural constraints → mark task `[!]`, then `/draft:adr` or `/draft:decompose`. Build/test failure → `/draft:debug` (do not bypass). |
| **3. Quality Gate / Review** | All change-scoped gates in `/draft:review` pass; when TDD is on, coverage gate auto-runs. | Review failed → fix flagged items, run `/draft:bughunt` if structural issues suspected, then re-run `/draft:review`. |

---

## Actionability: Command Invocation Examples

### Example 1: `/draft:status`
Parses active tracks, phases, tasks, and module mappings:

```
PROJECT: Bookshelf API Service

[track-042] OAuth2 Integration  —  [~] In Progress  (Phase 2/3, 4/9 tasks)
  [x] 1.1 Design OAuth database schema
  [x] 1.2 Generate migration files
  [~] 2.1 Implement token generation endpoint   ← CURRENT
  [ ] 2.2 Add authorization middleware
  [!] 2.3 Integrate third-party providers       (Blocked: API key pending)
```

### Example 2: `/draft:implement`
Reads `plan.md`, picks the current incomplete task, and continues it (TDD-aware):

```
Active track: [track-042] OAuth2 Integration
Current task: [~] 2.1 Implement token generation endpoint
TDD: on  →  writing tests/auth/token_generation_test.go (Red stage)
Test failed as expected → proceeding to implementation.
```

---

## Status Markers

Used throughout `plan.md` files and referenced by the validation checkpoints above:

| Marker | Meaning |
|--------|---------|
| `[ ]` | Pending |
| `[~]` | In Progress |
| `[x]` | Completed |
| `[!]` | Blocked |

---

You can also use natural language. Prefer the 5 router commands (`/draft:plan`, `/draft:ops`, `/draft:docs`, `/draft:discover`, `/draft:jira`) for grouped access; they analyze intent and dispatch.

* **[quality-guide.md](./quality-guide.md)** — Quality Audit Spectrum, command choices, and coordination with external bug-hunting tools.
* **[context-files.md](./context-files.md)** — Schema, role, and usage of each file inside the `draft/` context directory.
* **[intent-mapping.md](./intent-mapping.md)** — Maps natural language phrasing to precise Draft commands for conversational AI usage.

---

## Need Help?

- Run `/draft` (this command) for a high-level overview.
- Run `/draft:status` to inspect current tracks and task completion rates.
- Check `draft/tracks/<track_id>/spec.md` for functional requirements.
- Check `draft/tracks/<track_id>/plan.md` for technical task details.
