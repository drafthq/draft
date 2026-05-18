---
name: draft
description: "Lists Draft's canonical workflow commands, explains the Context-Driven Development flow (init, plan, implement, review), and recommends the appropriate next step. Use when the user asks about available Draft commands, needs help choosing a workflow step, or says 'what can Draft do', 'help', or 'show commands'."
---

# Draft - Context-Driven Development

Draft is a methodology for structured software development: **Context → Spec & Plan → Implement**

## Red Flags - STOP if you're:

- Jumping straight to implementation without reading existing Draft context
- Suggesting `/draft:implement` before a track has an approved spec and plan
- Not checking `draft/tracks.md` for existing active tracks before creating new ones
- Skipping the recommended command and going freeform
- Ignoring existing .ai-context.md, product.md, tech-stack.md, or workflow.md context

**Read context first. Follow the workflow.**

---

## Workflow Commands

### Canonical Workflow
```
init → plan → implement → review
               ↑            |
               └────────────┘  (review auto-invoked at phase boundaries)
```

| Command | Purpose | Default Behavior |
|---------|---------|------------------|
| `/draft:init` | Initialize project context | Analyzes repo, creates context, or routes to `index`/`discover` modes |
| `/draft:plan` | Canonical planning entry point | Routes to `new-track`, `decompose`, `change`, or `adr` |
| `/draft:implement` | Canonical implementation entry point | Continues active task and routes/escalates to `status`, `coverage`, or `revert` when appropriate |
| `/draft:review` | Canonical review entry point | Runs baseline review and routes/escalates to `quick`, `bughunt`, `deep`, or `assist` when appropriate |
| `/draft:ops` | Canonical operations entry point | Routes to `debug`, `deploy-checklist`, `incident-response`, or `standup` |
| `/draft:docs` | Canonical documentation entry point | Routes to `documentation`, `testing-strategy`, `tech-debt`, or `tour` |
| `/draft:integrations` | Canonical integrations entry point | Routes to `jira-preview` or `jira-create` |

### Planning Modes

Use `/draft:plan` first. These specialist planning commands remain available:

| Command | Purpose |
|---------|---------|
| `/draft:new-track` | Create feature/bug track with spec and plan |
| `/draft:decompose` | Module decomposition with dependency mapping |
| `/draft:change` | Handle mid-track requirement changes |
| `/draft:adr` | Architecture Decision Records |

### Specialist Commands

**Setup & Navigation:**
| Command | Purpose |
|---------|---------|
| `/draft` | This overview |
| `/draft:index` | Monorepo service aggregation |
| `/draft:discover` | Discover features and patterns |

**Planning & Architecture Beyond `/draft:plan`:**
| Command | Purpose |
|---------|---------|
| `/draft:tech-debt` | Technical debt analysis across 6 dimensions |

**Code Quality:**
| Command | Purpose |
|---------|---------|
| `/draft:review quick` | Parent-routed lightweight review for small ad-hoc scopes |
| `/draft:review bughunt` | Parent-routed defect-focused sweep |
| `/draft:review deep` | Parent-routed module production audit |
| `/draft:review assist` | Parent-routed reviewer handoff summary |
| `/draft:quick-review` | Lightweight 4-dimension code review (~2 min) |
| `/draft:bughunt` | Exhaustive 14-dimension bug hunt |
| `/draft:deep-review` | Module lifecycle audit (ACID compliance) |
| `/draft:coverage` | Code coverage report (target 95%+) |
| `/draft:testing-strategy` | Test plan design with coverage targets |
| `/draft:learn` | Discover coding patterns and update guardrails |

**Implementation Helpers Behind `/draft:implement`:**
| Command | Purpose |
|---------|---------|
| `/draft:implement status` | Parent-routed progress inspection |
| `/draft:implement coverage` | Parent-routed coverage measurement |
| `/draft:implement revert` | Parent-routed rollback flow |
| `/draft:status` | Detailed progress overview |
| `/draft:coverage` | Code coverage report (target 95%+) |
| `/draft:revert` | Git-aware rollback |

**Debugging:**
| Command | Purpose |
|---------|---------|
| `/draft:debug` | Structured debugging (reproduce → isolate → diagnose → fix) |

**Operations:**
| Command | Purpose |
|---------|---------|
| `/draft:deploy-checklist` | Pre-deployment verification with rollback triggers |
| `/draft:incident-response` | Incident lifecycle (triage → communicate → mitigate → postmortem) |
| `/draft:standup` | Git activity standup summary (read-only) |
| `/draft:status` | Show progress overview |
| `/draft:revert` | Git-aware rollback |

**Authoring:**
| Command | Purpose |
|---------|---------|
| `/draft:documentation` | Technical docs (readme, runbook, api, onboarding) |

**Integration:**
| Command | Purpose |
|---------|---------|
| `/draft:jira-preview` | Generate Jira export for review |
| `/draft:jira-create` | Push issues to Jira via MCP |


## Quick Start

1. **First time?** Run `/draft:init` to initialize your project
2. **Starting planned work?** Run `/draft:plan "your feature description"`
3. **Ready to code?** Run `/draft:implement` to execute tasks
4. **Check progress?** Run `/draft:status`

## Core Workflow

Every feature follows this lifecycle:
1. **Setup** - Initialize project context (once per project)
2. **Plan** - Create or evolve specification, breakdown, and architecture
3. **Implement** - Execute tasks with TDD workflow
4. **Verify** - Confirm acceptance criteria met
5. **Quality** - Run quality commands (see guide below)

**Planning note:** `/draft:plan` routes to the right planning mode by intent and track state. Fresh work usually becomes `/draft:new-track`; complexity often escalates to `/draft:decompose`; scope drift routes to `/draft:change`; durable technical decisions route to `/draft:adr`.

**Review note:** `/draft:review` is the parent review command. Small ad-hoc scopes can route to quick-review. High-risk changes can attach bughunt. Single-module structural risk can justify deep-review escalation. Completed-track handoffs can attach assist-review.

**Implementation note:** `/draft:implement` is the parent execution command. In the normal loop it should carry progress forward without making the developer switch to separate commands for status or coverage. `revert` stays explicit unless the implementation state clearly requires rollback guidance.

**Auto-invocations:** The workflow has built-in quality gates — `/draft:implement` auto-invokes `/draft:review` at phase boundaries, and `/draft:review` auto-invokes `/draft:coverage` when TDD is enabled.

## Quality Commands — When to Use Which

Four commands form an **audit spectrum** from quick to narrow to broad to deep:

| Command | Scope | Time | Question It Answers | Output |
|---------|-------|------|-------------------|--------|
| `/draft:quick-review` | File/PR/diff | ~2 min | "Any obvious issues in this change?" | 4-dimension findings with severity |
| `/draft:review` | Change-scoped (track, diff, commits) | ~10 min | "Does this change meet spec and quality gates?" | Three-stage review report with verdict |
| `/draft:bughunt` | Codebase-scoped (repo, paths, track) | ~20 min | "What bugs exist in this code?" | Severity-ranked bug report + regression tests |
| `/draft:deep-review` | Module-scoped (single service/component) | ~30 min | "Is this module production-ready?" | ACID compliance audit + implementation spec |

### Decision Guide

- **Quick sanity check?** → `/draft:quick-review` — fast 4-dimension review, no track context needed
- **Just finished a track?** → `/draft:review` — validates against spec, checks quality gates
- **Suspicious of bugs across the codebase?** → `/draft:bughunt` — 14-dimension sweep with verification protocol
- **Shipping a module to production?** → `/draft:deep-review` — ACID compliance, resilience, observability audit
- **Want everything?** → `/draft:review full` (includes bughunt), then `/draft:deep-review` for critical modules

### Relationship to Built-in Bug Hunt Agents

Some AI tools provide built-in bug hunt agents (e.g., Claude Code's `bughunt` agent). These are **complementary** to `/draft:bughunt` — the built-in agents offer fast parallel sweeps with auto-fix, while Draft's bughunt adds context-aware analysis using your architecture, tech-stack, and product context for better false-positive elimination. For maximum coverage, run both.

## Context Files

When `draft/` exists, these files guide development:
- `draft/architecture.md` - Source of truth: comprehensive human-readable engineering reference
- `draft/.ai-context.md` - Derived from architecture.md: token-optimized AI context (200-400 lines)
- `draft/product.md` - Product vision and goals
- `draft/tech-stack.md` - Technical constraints
- `draft/workflow.md` - TDD and commit preferences
- `draft/guardrails.md` - Hard guardrails, learned conventions, learned anti-patterns
- `draft/tracks.md` - Active work items

## Status Markers

Used throughout plan.md files:

| Marker | Meaning |
|--------|---------|
| `[ ]` | Pending |
| `[~]` | In Progress |
| `[x]` | Completed |
| `[!]` | Blocked |

## Intent Mapping

You can also use natural language:

| Say this... | Runs this |
|-------------|-----------|
| "set up the project" | `/draft:init` |
| "plan this", "scope this work", "start a feature" | `/draft:plan` |
| "index services", "aggregate context" | `/draft:index` |
| "discover features", "discover patterns" | `/draft:discover` |
| "new feature", "add X" | `/draft:plan` |
| "continue planning" | `/draft:plan` |
| "start implementing" | `/draft:implement` |
| "continue this task", "implement the next step" | `/draft:implement` |
| "what's the status" | `/draft:implement status` |
| "check coverage", "coverage for this work" | `/draft:implement coverage` |
| "undo", "revert" | `/draft:implement revert` |
| "break into modules" | `/draft:decompose` |
| "deep review", "module audit", "production audit" | `/draft:deep-review` |
| "quick review", "fast review" | `/draft:review quick` |
| "hunt bugs", "find bugs" | `/draft:bughunt` |
| "review code", "review track", "check quality" | `/draft:review` |
| "review handoff", "help me review this PR" | `/draft:review assist` |
| "document decision", "create ADR" | `/draft:adr` |
| "requirements changed", "scope changed", "update the spec" | `/draft:change` |
| "learn patterns", "update guardrails", "discover conventions" | `/draft:learn` |
| "preview jira", "export to jira" | `/draft:jira-preview` |
| "create jira", "push to jira" | `/draft:jira-create` |
| "debug this", "investigate bug" | `/draft:debug` |
| "deploy checklist", "pre-deploy" | `/draft:deploy-checklist` |
| "test strategy", "testing plan" | `/draft:testing-strategy` |
| "tech debt", "catalog debt" | `/draft:tech-debt` |
| "standup", "what did I do" | `/draft:standup` |
| "incident", "outage", "post-mortem" | `/draft:incident-response` |
| "write docs", "documentation", "runbook" | `/draft:documentation` |


## Need Help?

- Run `/draft` (this command) for overview
- Run `/draft:status` to see current state
- Check `draft/tracks/<track_id>/spec.md` for requirements
- Check `draft/tracks/<track_id>/plan.md` for task details
