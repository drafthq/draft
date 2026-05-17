# Draft Command Reduction Plan

## Status

Strategic plan for reducing Draft's public command surface while preserving existing capabilities and backward compatibility.

Scope of this document:

- user-facing command reduction only
- routing and alias strategy
- rollout and migration plan

Out of scope:

- context-pack design
- runtime architecture changes
- deep implementation details for skill internals

---

## Why Reduce Commands

Draft currently exposes a broad top-level command surface:

- planning commands
- implementation commands
- multiple review/audit commands
- operations commands
- documentation/support commands
- integration commands

This breadth creates three problems:

1. **Discovery cost**: new users must choose among too many adjacent commands.
2. **Intent ambiguity**: multiple commands compete for the same job-to-be-done.
3. **Product dilution**: Draft feels like a toolbox of commands instead of one coherent workflow.

The product gets stronger if the public surface is small and the internal capability surface remains rich.

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

Not all of these should remain first-class entry points.

---

## Design Goals

1. Reduce visible top-level commands to a smaller, memorable set.
2. Preserve current functionality behind grouped commands and sub-modes.
3. Maintain backward compatibility during migration.
4. Keep user intent routing predictable and explicit.
5. Avoid breaking existing workflows abruptly.

## Non-Goals

1. Removing useful capabilities outright in the first pass.
2. Rewriting all skills immediately.
3. Forcing hidden automation when the user asked for a specific mode.

---

## Guiding Principle

Draft should expose **workflow verbs**, not every internal specialization.

Users should think in terms of:

- initialize context
- plan work
- implement work
- review work
- run ops workflows
- produce docs
- use integrations

Internal sub-modules can remain specialized. Public top-level entry points should be few.

---

## Proposed Public Command Taxonomy

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

- `learn` is the only borderline case. It is conceptually distinct, but it can also be folded under `review` or `docs` later if needed.

---

## Command Grouping

## 1. `/draft:init`

Purpose:

- repository onboarding
- project indexing
- refresh and discovery

Subcommands:

- `/draft:init`
- `/draft:init refresh`
- `/draft:init index`
- `/draft:init discover`

Current commands absorbed:

- `/draft:init`
- `/draft:index`
- `/draft:discover`

Rationale:

These all concern repo understanding and initialization of Draft context.

---

## 2. `/draft:plan`

Purpose:

- creating and evolving planned work
- decomposition
- architecture decisions

Subcommands:

- `/draft:plan new-track`
- `/draft:plan decompose`
- `/draft:plan change`
- `/draft:plan adr`

Current commands absorbed:

- `/draft:new-track`
- `/draft:decompose`
- `/draft:change`
- `/draft:adr`

Rationale:

These are all pre-implementation planning and design evolution activities.

---

## 3. `/draft:implement`

Purpose:

- execute planned work
- observe progress
- validate implementation completeness
- recover from mistakes

Subcommands:

- `/draft:implement`
- `/draft:implement status`
- `/draft:implement coverage`
- `/draft:implement revert`

Current commands absorbed:

- `/draft:implement`
- `/draft:status`
- `/draft:coverage`
- `/draft:revert`

Rationale:

These all sit on the implementation loop and do not need separate first-class commands.

---

## 4. `/draft:review`

Purpose:

- quality evaluation
- code review
- risk discovery
- audit depth selection

Subcommands:

- `/draft:review`
- `/draft:review quick`
- `/draft:review deep`
- `/draft:review bughunt`
- `/draft:review assist`

Current commands absorbed:

- `/draft:review`
- `/draft:quick-review`
- `/draft:deep-review`
- `/draft:bughunt`
- `/draft:assist-review`
- `/draft:impact`

Notes:

- `impact` should not remain a separate top-level public command.
- It should become a review/analysis mode:
  - `/draft:review impact`
  - or an internal primitive used by `review`, `bughunt`, and `deep`

Rationale:

These commands all answer some version of "analyze change risk or quality." Users should not have to distinguish five review verbs upfront.

---

## 5. `/draft:ops`

Purpose:

- incident workflows
- debugging
- deployment readiness
- activity summaries

Subcommands:

- `/draft:ops debug`
- `/draft:ops deploy-checklist`
- `/draft:ops incident-response`
- `/draft:ops standup`

Current commands absorbed:

- `/draft:debug`
- `/draft:deploy-checklist`
- `/draft:incident-response`
- `/draft:standup`

Rationale:

These belong to operational and support workflows, not to the core build-plan-review loop.

---

## 6. `/draft:docs`

Purpose:

- produce or analyze supporting engineering documentation
- explain systems
- define test and debt work

Subcommands:

- `/draft:docs documentation`
- `/draft:docs testing-strategy`
- `/draft:docs tech-debt`
- `/draft:docs tour`

Current commands absorbed:

- `/draft:documentation`
- `/draft:testing-strategy`
- `/draft:tech-debt`
- `/draft:tour`

Rationale:

These are all supporting-document or knowledge-transfer workflows.

---

## 7. `/draft:integrations`

Purpose:

- external system export and sync

Subcommands:

- `/draft:integrations jira-preview`
- `/draft:integrations jira-create`

Current commands absorbed:

- `/draft:jira-preview`
- `/draft:jira-create`

Rationale:

These are connectors, not core workflow verbs.

---

## What Stays Out of the Reduction Scope

## `/draft`

Keep `/draft` as the main overview/help/router entry point.

It should:

- explain the reduced command model
- show recommended flows
- route users to the right top-level command

## `/draft:learn`

Recommendation:

- keep it temporarily as its own top-level command
- reassess after command reduction lands

Why:

- it has a distinct pattern-learning and guardrail-maintenance role
- folding it immediately may make the first migration too disruptive

Longer-term options:

- move under `/draft:review learn`
- move under `/draft:docs learn`
- keep as advanced standalone command

---

## Routing Rules

The reduced surface should be explicit-first, routed-second.

## Rule 1: Explicit Subcommand Wins

If the user invokes:

- `/draft:review deep`
- `/draft:plan adr`
- `/draft:ops debug`

Draft should dispatch directly to that sub-module.

No auto-routing should override explicit intent.

## Rule 2: Top-Level Bare Commands Use Defaults

Examples:

- `/draft:plan` -> default to `new-track` help or guided planner intake
- `/draft:implement` -> implementation workflow
- `/draft:review` -> standard review
- `/draft:ops` -> show available ops modes or ask for target intent if ambiguous

## Rule 3: Compatibility Aliases Route to Canonical Form

Examples:

- `/draft:bughunt` -> `/draft:review bughunt`
- `/draft:deep-review` -> `/draft:review deep`
- `/draft:new-track` -> `/draft:plan new-track`

Aliases should continue to work during migration.

## Rule 4: Deprecation Message Is Visible

When an alias is used, Draft should say:

```text
`/draft:bughunt` is deprecated; routing to `/draft:review bughunt`.
```

This keeps the new model visible without breaking current users.

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

## Product Messaging Changes

The command reduction only works if the product story changes with it.

## Current Story

Draft advertises many commands and a broad lifecycle toolbox.

## Proposed Story

Draft should market a smaller workflow:

1. `/draft:init` — understand the repo
2. `/draft:plan` — define the work
3. `/draft:implement` — execute safely
4. `/draft:review` — catch risk before push

Supporting areas:

- `/draft:ops`
- `/draft:docs`
- `/draft:integrations`

This makes Draft easier to explain and easier to adopt.

---

## Rollout Plan

## Phase 1: Documentation-First Consolidation

Change:

- README command table
- methodology docs
- examples and walkthroughs

Actions:

1. Introduce the new top-level taxonomy in docs.
2. Keep old commands documented as compatibility aliases.
3. Update examples to use canonical commands first.

Success criteria:

- new users see only the reduced top-level taxonomy in primary docs
- old users can still find the old commands in migration notes

## Phase 2: Router Layer

Change:

- add explicit canonical routing in plugin instructions and integrations

Actions:

1. Implement alias dispatch messages.
2. Route old commands to new canonical command families.
3. Keep telemetry or lightweight logging on alias usage if available.

Success criteria:

- existing commands continue to function
- user-visible output reinforces canonical destinations

## Phase 3: Integration Surface Cleanup

Change:

- update integrations and generated command references

Actions:

1. Update `build-integrations.sh` metadata and triggers.
2. Prefer canonical forms in Copilot/Gemini/other generated files.
3. Move alias commands into a compatibility or legacy section.

Success criteria:

- generated integrations teach new command families first
- aliases remain available but no longer lead the product

## Phase 4: Soft Deprecation

Change:

- old commands remain functional but are clearly secondary

Actions:

1. Mark old commands as deprecated in docs.
2. Continue alias routing for at least one release cycle.
3. Gather user feedback before any hard removal.

Success criteria:

- the majority of examples and user flows use the reduced surface
- there is no major confusion or workflow breakage

## Phase 5: Hard Removal Decision

Not automatic.

Before any hard removal:

1. check alias usage
2. confirm integrations and docs are fully migrated
3. confirm that no major workflow depends on legacy naming

Recommendation:

- do not hard-remove legacy aliases until the reduced model has proven itself

---

## Risks

## 1. Over-Consolidation

Risk:

- users may lose a sense of specialized power if everything looks too generic

Mitigation:

- preserve rich subcommands
- keep explicit sub-mode invocation available

## 2. Migration Confusion

Risk:

- users may not know where old commands moved

Mitigation:

- explicit alias messages
- migration table in docs
- compatibility period

## 3. Documentation Drift

Risk:

- old and new command names may coexist inconsistently

Mitigation:

- canonical command audit across README, methodology, integrations, skills

## 4. Internal Coupling

Risk:

- grouped commands may be implemented inconsistently if the router layer is weak

Mitigation:

- define canonical destinations first
- keep internal sub-modules modular

---

## Success Criteria

The command reduction is successful if:

1. A new user can understand Draft from 4-7 top-level commands.
2. Existing capabilities remain reachable without functional regression.
3. Old commands still work during migration.
4. README and generated integrations teach the new taxonomy first.
5. Draft feels like a coherent workflow rather than a menu of unrelated commands.

---

## Recommendation

Proceed with the highest-value reductions first:

1. Consolidate all review-adjacent commands under `/draft:review`.
2. Consolidate all planning/design commands under `/draft:plan`.
3. Consolidate all implementation loop support under `/draft:implement`.
4. Consolidate all ops/support workflows under `/draft:ops`.
5. Consolidate docs/helping workflows under `/draft:docs`.
6. Consolidate Jira under `/draft:integrations`.

Keep `/draft`, `/draft:init`, and `/draft:learn` stable during the first migration wave.

This gives Draft a smaller and clearer public API without losing its existing depth.
