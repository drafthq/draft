# Draft — Full Command Reference

33 skills, two tiers. The README covers the five you need on day one; this is everything.

Run `/draft` in your agent for the interactive intent map.

## Primary workflow

The commands that carry the methodology. Start here.

| Command | What it does |
|---|---|
| **`/draft:review`** | 3-stage review — validation + spec compliance + code quality. Runs with zero setup on an un-indexed repo; adds blast radius, caller enumeration, hotspot ranking, and cycle detection once the repo is indexed. |
| **`/draft:init`** | Index the codebase: build the knowledge graph and generate `product.md`, `tech-stack.md`, `workflow.md`, `guardrails.md`, `architecture.md`, `.ai-context.md`, `.ai-profile.md`. Scope-aware — run at the repo root or inside a sub-module. |
| **`/draft:new-track`** | Collaborative intake for a feature, bug, or refactor. Produces `spec.md` + `plan.md`. |
| **`/draft:implement`** | Execute the active track task-by-task under TDD with verification gates. |
| **`/draft:graph`** | Build or refresh the knowledge-graph snapshot on its own. |

## Routers

Five routers dispatch to the specialists by intent, so you rarely need to remember a specialist name.

| Router | Covers |
|---|---|
| **`/draft:plan`** | Planning, architecture, track management → `new-track`, `decompose`, `adr`, `tech-debt`, `change` |
| **`/draft:discover`** | Discovery, debugging, investigation, quality → `debug`, `bughunt`, `quick-review`, `deep-review`, `coverage`, `testing-strategy`, `learn`, `tour`, `impact`, `assist-review` |
| **`/draft:ops`** | Operations, deployment, incidents, lifecycle → `deploy-checklist`, `incident-response`, `standup`, `status`, `revert` |
| **`/draft:docs`** | Authoring and documentation → `documentation` (readme, runbook, api, onboarding) |
| **`/draft:jira`** | Jira workflows → `preview`, `create`, `review <JIRA-ID>` (qualification pipeline) |

## Review depths

Four review commands with different costs and scopes. `/draft:review` escalates to these automatically when the diff justifies it; invoke one directly when you already know the depth you want.

| Command | Scope | Use when |
|---|---|---|
| **`/draft:review`** | Track or arbitrary diff | Default. The gate before you push. |
| **`/draft:quick-review`** | Any file, diff, or PR | One-off sanity check, no track context needed. Four dimensions. |
| **`/draft:bughunt`** | Codebase or track | Exhaustive 14-dimension defect discovery with taint tracking. |
| **`/draft:deep-review`** | One module or service | Production-readiness audit — ACID, resilience, observability. |
| **`/draft:assist-review`** | Someone else's PR | Prepping to review another engineer's work; isolates structural changes from trivial ones. |

## Planning and architecture

| Command | What it does |
|---|---|
| **`/draft:decompose`** | Module decomposition with dependency mapping. Generates `hld.md`, and `lld.md` for high-complexity modules. |
| **`/draft:adr`** | Architecture Decision Records — create, evaluate proposals, or run a design pass. |
| **`/draft:tech-debt`** | Debt identification and prioritization across seven dimensions, with remediation plans. |
| **`/draft:change`** | Mid-track requirement changes: impact analysis, then amendments to `spec.md` and `plan.md`. |
| **`/draft:testing-strategy`** | Test plan design with coverage targets. Auto-loaded by `implement` before TDD. |

## Quality and investigation

| Command | What it does |
|---|---|
| **`/draft:debug`** | Structured debugging: reproduce, isolate, diagnose, fix. |
| **`/draft:coverage`** | Coverage measurement for the active track or a module; targets 95%+. |
| **`/draft:learn`** | Scan the codebase for conventions and anti-patterns; update `draft/guardrails.md`. |
| **`/draft:tour`** | Interactive onboarding walkthrough of the codebase. |
| **`/draft:impact`** | Delivery telemetry — pace, phase duration, completion rate, friction hotspots. |

## Operations and lifecycle

| Command | What it does |
|---|---|
| **`/draft:status`** | Track progress, phases, completion percentages, blocked items. |
| **`/draft:standup`** | Standup summary from git history and track progress. Read-only. |
| **`/draft:deploy-checklist`** | Pre-deployment verification with rollback triggers, customized to the detected stack. |
| **`/draft:upload`** | Pre-upload handoff gate: review status, HLD approvals, checklist, validator chain. |
| **`/draft:incident-response`** | Incident lifecycle — triage, communicate, mitigate, blameless postmortem. |
| **`/draft:revert`** | Git-aware rollback at task, phase, or track level. |

## Documentation and integrations

| Command | What it does |
|---|---|
| **`/draft:documentation`** | Technical docs — readme, runbook, api, onboarding. |
| **`/draft:integrations`** | External system exports and syncs. |
| **`/draft:draft`** (`/draft`) | Intent map: lists commands and recommends the next step. |

## Deterministic helpers

Beneath the skills sit 53 shell helpers in [`scripts/tools/`](../scripts/tools/) that do the mechanical work markdown cannot — graph queries, git metadata extraction, coverage runs, validators. Skills call them; you can too.

```bash
scripts/tools/graph-impact.sh --repo . --file src/auth/login.go   # blast radius
scripts/tools/graph-callers.sh --repo . --symbol validateToken    # downstream callers
scripts/tools/hotspot-rank.sh --repo .                            # fan-in ranking
scripts/tools/cycle-detect.sh --repo .                            # dependency cycles
```

## Further reading

- [Methodology](../core/methodology.md) — the full Context-Driven Development specification
- [The Draft Book](https://getdraft.dev/book/) — 22 chapters on the methodology and its rationale
- [CONTRIBUTING.md](../CONTRIBUTING.md) — build, test, and skill-authoring conventions
