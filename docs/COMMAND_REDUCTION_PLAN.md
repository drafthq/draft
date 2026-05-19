# Draft Command Reduction Plan

## Status

Strategic plan for reducing Draft's public command surface while preserving depth.

This revision sharpens one product rule:

- parent commands own orchestration
- specialist commands remain available as explicit modes or compatibility aliases
- developers should not have to memorize command soup to get high-quality outcomes

Scope of this document:

- user-facing command reduction
- parent-command orchestration model
- alias and routing strategy
- rollout and messaging changes

Out of scope:

- skill-internal implementation details
- context-pack redesign
- runtime architecture changes outside routing/orchestration

---

## Problem

Draft currently presents a long list of top-level commands in README and integrations. Even when each command is useful, the product asks the developer to pick the right specialist up front.

That creates four problems:

1. **Discovery cost**: new users must scan a large menu before they can act.
2. **Intent burden**: users have to translate "I want a safe review" into "should I run review, quick-review, deep-review, bughunt, impact, or assist-review?"
3. **Workflow fragmentation**: Draft feels like a toolbox, not a system.
4. **Capability underuse**: lower-level analyzers stay unused unless the developer already knows they exist.

The reduction plan should not just rename commands. It should move orchestration responsibility from the developer to Draft.

---

## Core Thesis

Draft should expose a small set of **workflow parents**.

Each parent command should:

- accept the user's high-level intent
- invoke the right lower-level analyzers, checks, and helpers in the right order
- escalate depth when signals justify it
- still allow explicit specialist invocation when the user asks for it

In short:

- **public surface stays small**
- **internal capability surface stays rich**
- **defaults get smarter**

---

## Design Goals

1. Reduce visible top-level commands to a small, memorable set.
2. Preserve existing capability depth behind parent workflows.
3. Make bare parent commands useful enough that most developers never need the specialist list.
4. Keep routing explicit and predictable when a user names a specialist mode.
5. Maintain backward compatibility during migration.

## Non-Goals

1. Removing useful capabilities in the first pass.
2. Hiding all specialist behavior from advanced users.
3. Replacing explicit expert workflows with opaque automation.
4. Rewriting every skill before the routing model is defined.

---

## Product Rule

**A parent command must be better than a command directory.**

That means `/draft:review` should not merely say "available modes: quick, deep, bughunt..."

It should perform an opinionated review workflow that composes the right primitives by default.

Likewise:

- `/draft:plan` should coordinate planning primitives
- `/draft:implement` should coordinate implementation, progress, and recovery primitives
- `/draft:ops` should coordinate debugging and operational workflows

If a parent command does not orchestrate real work, developers will keep falling back to the long command list.

---

## Current Public Commands

Current top-level user-facing commands include:

- `/draft`
- `/draft:init`
- `/draft:index`
- `/draft:new-track`
- `/draft:decompose`
- `/draft:implement`
- `/draft:coverage`
- `/draft:review`
- `/draft:quick-review`
- `/draft:deep-review`
- `/draft:bughunt`
- `/draft:assist-review`
- `/draft:learn`
- `/draft:adr`
- `/draft:status`
- `/draft:revert`
- `/draft:change`
- `/draft:debug`
- `/draft:deploy-checklist`
- `/draft:testing-strategy`
- `/draft:tech-debt`
- `/draft:standup`
- `/draft:incident-response`
- `/draft:documentation`
- `/draft:jira-preview`
- `/draft:jira-create`
- `/draft:tour`
- `/draft:impact`
- `/draft:discover`

Not all of these should remain first-class public entry points.

---

## Proposed Public Taxonomy

## Keep as Top-Level

These become the primary public commands:

- `/draft`
- `/draft:init`
- `/draft:plan`
- `/draft:implement`
- `/draft:review`
- `/draft:ops`
- `/draft:docs`
- `/draft:integrations`

Optional later:

- `/draft:learn`

Rationale:

- this is a small enough set to remember
- each command maps to a clear developer job-to-be-done
- the taxonomy reflects workflow stages, not internal implementation details

---

## Public vs Internal Surface

The command model should split into three layers.

## Layer 1: Primary Public Commands

These appear in README, install flows, and generated integrations:

- `/draft:init`
- `/draft:plan`
- `/draft:implement`
- `/draft:review`
- `/draft:ops`
- `/draft:docs`
- `/draft:integrations`

## Layer 2: Named Specialist Modes

These remain callable, but are taught as subcommands of a parent:

- `/draft:review deep`
- `/draft:review bughunt`
- `/draft:plan adr`
- `/draft:implement coverage`
- `/draft:ops debug`

## Layer 3: Compatibility Aliases

These continue to work during migration, but should not lead product messaging:

- `/draft:deep-review`
- `/draft:bughunt`
- `/draft:new-track`
- `/draft:coverage`
- `/draft:debug`

This separation is important. The goal is not to delete sophistication. The goal is to stop leading with it.

---

## Orchestration Model

## Principle

Bare parent commands should perform a **progressive workflow**, not a shallow wrapper.

Progressive workflow means:

1. start with the default happy-path analysis
2. invoke specialist helpers automatically when they add clear value
3. escalate only when evidence or user intent justifies extra depth
4. summarize what ran and why

## Rules

1. Explicit user intent always wins.
2. Bare parent commands should choose a sensible default workflow.
3. Specialist helpers may run automatically inside the parent workflow.
4. Automatic escalation must be explainable in output.
5. Advanced modes remain directly invocable.

Example output shape:

```text
Running /draft:review
- Baseline review
- Impact scan
- Escalated to deep review because high-risk files and auth boundary changes were detected
```

That gives the user the best result without making them choose the stack manually.

---

## Parent Command Contracts

Each parent command needs a clear contract: what it owns, what it may call, and what a developer should expect by default.

## 1. `/draft:init`

Purpose:

- repository onboarding
- context generation
- discovery and refresh
- monorepo aggregation when relevant

Default behavior:

- initialize repo context
- discover repo shape
- refresh stale generated context if needed
- suggest indexing when monorepo signals are detected

Named modes:

- `/draft:init`
- `/draft:init refresh`
- `/draft:init index`
- `/draft:init discover`

Current commands absorbed:

- `/draft:init`
- `/draft:index`
- `/draft:discover`

Parent orchestration expectation:

- a developer should not need to decide between "init" and "discover" just to get started
- `/draft:init` should own the startup flow and call discovery/index helpers when appropriate

## 2. `/draft:plan`

Purpose:

- define the work
- break it down
- evolve it safely when requirements change
- capture architecture decisions

Default behavior:

- start or continue a track plan
- create or refine task breakdown
- surface architecture decision points when needed
- route to change handling when an existing track is being modified

Named modes:

- `/draft:plan`
- `/draft:plan new-track`
- `/draft:plan decompose`
- `/draft:plan change`
- `/draft:plan adr`

Current commands absorbed:

- `/draft:new-track`
- `/draft:decompose`
- `/draft:change`
- `/draft:adr`

Parent orchestration expectation:

- a developer saying "plan this work" should get track creation plus decomposition support without needing to pick separate verbs
- ADR generation should be an escalation or explicit mode, not a separate product entrance

## 3. `/draft:implement`

Purpose:

- execute the plan
- track progress
- validate completeness
- recover safely when implementation goes off track

Default behavior:

- continue the next task in the active track
- run implementation workflow and verification gates
- update task/progress state
- surface coverage gaps or revert guidance only when needed

Named modes:

- `/draft:implement`
- `/draft:implement status`
- `/draft:implement coverage`
- `/draft:implement revert`

Current commands absorbed:

- `/draft:implement`
- `/draft:status`
- `/draft:coverage`
- `/draft:revert`

Parent orchestration expectation:

- a developer should not need to manually switch to `/draft:status` or `/draft:coverage` in the common path
- `/draft:implement` should own those checks where they materially improve the implementation loop

## 4. `/draft:review`

Purpose:

- evaluate change quality
- detect risk
- choose appropriate review depth
- prepare reviewers with the right context

Default behavior:

- run baseline review
- run impact analysis automatically
- escalate to deeper review when risk signals justify it
- include reviewer-assist summarization when useful

Named modes:

- `/draft:review`
- `/draft:review quick`
- `/draft:review deep`
- `/draft:review bughunt`
- `/draft:review assist`
- `/draft:review impact`

Current commands absorbed:

- `/draft:review`
- `/draft:quick-review`
- `/draft:deep-review`
- `/draft:bughunt`
- `/draft:assist-review`
- `/draft:impact`

Parent orchestration expectation:

- most developers should be able to run `/draft:review` and trust Draft to apply the right stack
- specialist modes remain available for explicit intent, CI hooks, or power users

Recommended default review stack:

1. baseline review
2. impact scan
3. escalate to deep review on structural-risk signals
4. escalate to bughunt on defect-risk signals
5. attach assist-review style summary when the output is likely to be consumed by another reviewer

Possible escalation signals:

- high fan-in or hotspot files
- auth, money, persistence, concurrency, or migration paths
- large blast radius
- broad interface changes
- weak or missing tests
- generated diff patterns historically correlated with defects

This is the clearest example of the new product model: `/draft:review` should be the orchestrator, not just one peer in a list of review commands.

## 5. `/draft:ops`

Purpose:

- debugging
- incident handling
- deploy readiness
- operational summaries

Default behavior:

- if user intent is clear, route directly
- if intent is broad, present a small ops menu with recommended default path
- reuse debugging or incident helpers without forcing command memorization

Named modes:

- `/draft:ops debug`
- `/draft:ops deploy-checklist`
- `/draft:ops incident-response`
- `/draft:ops standup`

Current commands absorbed:

- `/draft:debug`
- `/draft:deploy-checklist`
- `/draft:incident-response`
- `/draft:standup`

## 6. `/draft:docs`

Purpose:

- produce engineering documentation
- explain the system
- define testing strategy
- capture debt and onboarding material

Default behavior:

- route to the relevant documentation workflow based on request intent
- reuse architecture/tour/test-strategy helpers as internal specialists

Named modes:

- `/draft:docs documentation`
- `/draft:docs testing-strategy`
- `/draft:docs tech-debt`
- `/draft:docs tour`

Current commands absorbed:

- `/draft:documentation`
- `/draft:testing-strategy`
- `/draft:tech-debt`
- `/draft:tour`

## 7. `/draft:integrations`

Purpose:

- external system export and sync

Named modes:

- `/draft:integrations jira-preview`
- `/draft:integrations jira-create`

Current commands absorbed:

- `/draft:jira-preview`
- `/draft:jira-create`

Rationale:

- integrations are connectors, not core workflow verbs

---

## What Stays Out of Scope

## `/draft`

Keep `/draft` as the overview, help, and intent router.

It should:

- explain the reduced workflow model
- show canonical commands only
- route to the right parent command
- point to compatibility aliases separately, not in the main flow

## `/draft:learn`

Recommendation:

- keep temporarily as top-level or advanced standalone
- reassess after the new parent-command model lands

Why:

- it has a distinct pattern-learning role
- folding it immediately adds migration risk without much simplification benefit

Longer-term options:

- `/draft:review learn`
- `/draft:docs learn`
- advanced standalone command outside the primary onboarding path

---

## Routing Rules

## Rule 1: Explicit Specialist Intent Wins

If the user invokes:

- `/draft:review deep`
- `/draft:plan adr`
- `/draft:ops debug`

Draft dispatches directly to that mode.

No auto-routing should override explicit intent.

## Rule 2: Bare Parent Commands Run Canonical Workflows

Examples:

- `/draft:init` -> initialization flow with discovery/refresh as needed
- `/draft:plan` -> guided planning plus decomposition support
- `/draft:implement` -> implementation workflow with progress/verification
- `/draft:review` -> review stack with automatic impact scan and risk-based escalation

## Rule 3: Compatibility Aliases Route to Canonical Form

Examples:

- `/draft:bughunt` -> `/draft:review bughunt`
- `/draft:deep-review` -> `/draft:review deep`
- `/draft:new-track` -> `/draft:plan new-track`

Aliases should continue to work during migration.

## Rule 4: Automatic Orchestration Must Be Visible

When parent commands invoke specialist helpers, Draft should say so briefly.

Example:

```text
Running /draft:review
- baseline review complete
- impact analysis triggered automatically
- deep review triggered because 3 hotspot files changed
```

## Rule 5: Deprecation Message Is Visible

When a legacy alias is used, Draft should say:

```text
`/draft:bughunt` is deprecated; routing to `/draft:review bughunt`.
```

This keeps the canonical model visible without breaking current usage.

---

## Proposed Alias Map

| Current Command | Canonical Destination |
|-----------------|-----------------------|
| `/draft:index` | `/draft:init index` |
| `/draft:discover` | `/draft:init discover` |
| `/draft:new-track` | `/draft:plan new-track` |
| `/draft:decompose` | `/draft:plan decompose` |
| `/draft:change` | `/draft:plan change` |
| `/draft:adr` | `/draft:plan adr` |
| `/draft:status` | `/draft:implement status` |
| `/draft:coverage` | `/draft:implement coverage` |
| `/draft:revert` | `/draft:implement revert` |
| `/draft:quick-review` | `/draft:review quick` |
| `/draft:deep-review` | `/draft:review deep` |
| `/draft:bughunt` | `/draft:review bughunt` |
| `/draft:assist-review` | `/draft:review assist` |
| `/draft:impact` | `/draft:review impact` |
| `/draft:debug` | `/draft:ops debug` |
| `/draft:deploy-checklist` | `/draft:ops deploy-checklist` |
| `/draft:incident-response` | `/draft:ops incident-response` |
| `/draft:standup` | `/draft:ops standup` |
| `/draft:documentation` | `/draft:docs documentation` |
| `/draft:testing-strategy` | `/draft:docs testing-strategy` |
| `/draft:tech-debt` | `/draft:docs tech-debt` |
| `/draft:tour` | `/draft:docs tour` |
| `/draft:jira-preview` | `/draft:integrations jira-preview` |
| `/draft:jira-create` | `/draft:integrations jira-create` |

---

## README and Messaging Changes

The command reduction only works if the product story changes with it.

## Current Story

README currently emphasizes breadth:

- "`/draft:review` is the wedge"
- "27 more commands"
- a long "What You Get" table

That messaging proves power, but it also reinforces the burden we are trying to remove.

## Proposed Story

Lead with the workflow:

1. `/draft:init` — understand the repo
2. `/draft:plan` — define the work
3. `/draft:implement` — execute safely
4. `/draft:review` — catch risk before push

Supporting families:

- `/draft:ops`
- `/draft:docs`
- `/draft:integrations`

Messaging rule:

- primary docs should market parent commands
- specialist modes should appear as "what the parent can do" or "advanced modes"
- legacy aliases should live in migration/reference sections only

## Recommended README change

Replace "27 more commands" framing with:

- "7 workflow commands"
- "specialist modes built in"
- "advanced review, bug hunting, impact analysis, debugging, and documentation workflows are invoked through these parents"

This better matches the product we want developers to experience.

---

## Rollout Plan

## Phase 1: Documentation-First Realignment

Change:

- README
- command reference
- generated integration docs
- examples and walkthroughs

Actions:

1. Introduce the reduced parent taxonomy in primary docs.
2. Reframe specialist commands as modes/helpers, not peers.
3. Add orchestration language to parent command descriptions.
4. Keep legacy commands documented as compatibility aliases.

Success criteria:

- new users primarily encounter 4-7 workflow parents
- the docs explain that parent commands compose deeper checks automatically

## Phase 2: Canonical Routing Layer

Change:

- define canonical destinations for every old command
- define default workflows for each bare parent command

Actions:

1. Implement alias dispatch messages.
2. Implement parent-command default routing behavior.
3. Expose short "what ran" summaries when orchestration triggers specialist helpers.

Success criteria:

- legacy commands still work
- bare parent commands do real work
- output teaches the canonical model implicitly

## Phase 3: Integration Surface Cleanup

Change:

- update integrations and generated command references

Actions:

1. Update integration metadata to prefer canonical parent commands.
2. Teach Copilot/Gemini/other generated files to recommend parent workflows first.
3. Move aliases into compatibility sections.

Success criteria:

- generated integrations stop advertising the full legacy command soup
- specialist capabilities remain reachable without dominating the surface

## Phase 4: Soft Deprecation

Change:

- old commands remain functional but clearly secondary

Actions:

1. Mark old commands as deprecated in docs.
2. Continue alias routing for at least one release cycle.
3. Gather feedback on where parent orchestration still feels too shallow.

Success criteria:

- most examples use the reduced command model
- developers trust parent commands to choose the right depth in common cases

## Phase 5: Hard Removal Decision

Not automatic.

Before any hard removal:

1. check alias usage
2. confirm integrations and docs are migrated
3. confirm parent workflows cover the old common paths
4. confirm specialist access is still available where expert users need it

Recommendation:

- do not hard-remove aliases until the parent-command experience is clearly superior

---

## Risks

## 1. Over-Automation

Risk:

- parent commands may become unpredictable if they trigger too much hidden behavior

Mitigation:

- keep explicit modes available
- explain automatic escalation in output
- use clear heuristics for when specialist helpers are invoked

## 2. Shallow Parents

Risk:

- if parent commands only rename groups without meaningful orchestration, users will keep using the old commands

Mitigation:

- define parent-command contracts
- require bare parent commands to own a useful default workflow

## 3. Migration Confusion

Risk:

- users may not know where old commands moved

Mitigation:

- alias routing messages
- migration table
- compatibility period

## 4. Documentation Drift

Risk:

- old and new command names may coexist inconsistently

Mitigation:

- canonical command audit across README, methodology, integrations, and skills

---

## Success Criteria

The reduction is successful if:

1. A new user can understand Draft from 4-7 top-level commands.
2. Bare parent commands are sufficient for most common workflows.
3. Existing capabilities remain reachable without regression.
4. Old commands still work during migration.
5. README and integrations teach parent workflows first.
6. Draft feels like a coherent workflow engine, not a command directory.

---

## Recommendation

Proceed with reduction as an orchestration project, not just a taxonomy cleanup.

Priority order:

1. Consolidate review-adjacent commands under `/draft:review`.
2. Make `/draft:review` automatically compose impact and risk-based depth selection.
3. Consolidate planning commands under `/draft:plan`.
4. Consolidate implementation-loop support under `/draft:implement`.
5. Consolidate ops, docs, and integrations under their respective parents.
6. Update README so parent workflows lead and specialist modes support them.

Keep `/draft`, `/draft:init`, and `/draft:learn` stable during the first migration wave.

The target outcome is simple:

- developers remember a few commands
- Draft chooses the right specialist helpers most of the time
- power users still have explicit depth controls when they want them
