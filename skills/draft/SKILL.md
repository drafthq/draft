---
name: draft
description: "Lists all Draft CLI commands, explains the Context-Driven Development workflow (init, new-track, implement, review), and recommends the appropriate next step. Use when the user asks about available Draft commands, needs help choosing a workflow step, or says 'what can Draft do', 'help', or 'show commands'."
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

## Two-Tier Command Architecture

### Primary Workflow (4 commands)
```
init → new-track → implement → review
                       ↑           |
                       └───────────┘  (auto-invoked at phase boundaries)
```

| Command | Purpose | Auto-Invokes |
|---------|---------|-------------|
| `/draft:init` | Initialize project context | -- |
| `/draft:new-track` | Create feature/bug track with spec and plan | debug (bug tracks), tech-debt (refactor tracks) |
| `/draft:implement` | Execute tasks from plan with TDD | review (phase boundaries), testing-strategy (TDD context) |
| `/draft:review` | Three-stage code review | coverage (if TDD enabled), bughunt (with --full) |

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

**Setup & Navigation:**
| `/draft` | This overview | `/draft:index` | Monorepo service aggregation |
|---------|---------|---------|---------|

**Planning & Architecture:**
| Command | Purpose |
|---------|---------|
| `/draft:decompose` | Module decomposition with dependency mapping |
| `/draft:adr` | Architecture Decision Records (record, evaluate, design) |
| `/draft:tech-debt` | Technical debt analysis across 6 dimensions |
| `/draft:change` | Handle mid-track requirement changes |

**Code Quality:**
| Command | Purpose |
|---------|---------|
| `/draft:quick-review` | Lightweight 4-dimension code review (~2 min) |
| `/draft:bughunt` | Exhaustive 14-dimension bug hunt |
| `/draft:deep-review` | Module lifecycle audit (ACID compliance) |
| `/draft:coverage` | Code coverage report (target 95%+) |
| `/draft:testing-strategy` | Test plan design with coverage targets |
| `/draft:learn` | Discover coding patterns and update guardrails |

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
| `/draft:jira` | Unified Jira workflows (preview / create / review) |


## Quick Start

1. **First time?** Run `/draft:init` to initialize your project
2. **Starting a feature?** Run `/draft:new-track "your feature description"`
3. **Ready to code?** Run `/draft:implement` to execute tasks
4. **Check progress?** Run `/draft:status`

## Core Workflow

Every feature follows this lifecycle:
1. **Setup** - Initialize project context (once per project)
2. **New Track** - Create specification and plan
3. **Implement** - Execute tasks with TDD workflow
4. **Verify** - Confirm acceptance criteria met
5. **Quality** - Run quality commands (see guide below)

**Auto-invocations:** The primary workflow has built-in quality gates — `/draft:implement` auto-invokes `/draft:review` at phase boundaries, and `/draft:review` auto-invokes `/draft:coverage` when TDD is enabled.

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

You can also use natural language. Prefer the 5 router commands (`/draft:plan`, `/draft:ops`, `/draft:docs`, `/draft:discover`, `/draft:jira`) for grouped access; they analyze intent and dispatch.

| Say this... | Runs this |
|-------------|-----------|
| "plan the work", "new feature", "start X", "tech debt", "adr", "decompose", "scope changed" | `/draft:plan` (routes to new-track / decompose / adr / tech-debt / change) |
| "ops task", "deploy", "incident", "standup", "status", "revert" | `/draft:ops` (routes to deploy-checklist / incident-response / standup / status / revert) |
| "write docs", "documentation", "runbook", "api docs" | `/draft:docs` (routes to documentation) |
| "discover", "debug", "review code", "hunt bugs", "coverage", "learn patterns", "index", "tour", "impact" | `/draft:discover` (routes to debug / bughunt / quick-review / deep-review / coverage / testing-strategy / learn / index / tour / impact / assist-review) |
| "jira", "jira preview", "jira create", "jira review" | `/draft:jira` (unified Jira router) |
| "set up the project" | `/draft:init` |
| "index services", "aggregate context" | `/draft:index` |
| "new feature", "add X" | `/draft:new-track` |
| "start implementing" | `/draft:implement` |
| "what's the status" | `/draft:status` |
| "undo", "revert" | `/draft:revert` |
| "break into modules" | `/draft:decompose` |
| "check coverage" | `/draft:coverage` |
| "deep review", "module audit", "production audit" | `/draft:deep-review` |
| "hunt bugs", "find bugs" | `/draft:bughunt` |
| "review code", "review track", "check quality" | `/draft:review` |
| "document decision", "create ADR" | `/draft:adr` |
| "requirements changed", "scope changed", "update the spec" | `/draft:change` |
| "learn patterns", "update guardrails", "discover conventions" | `/draft:learn` |

| "quick review", "fast review" | `/draft:quick-review` |
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
