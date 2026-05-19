---
name: plan
<<<<<<< HEAD
description: "Primary router for planning, architecture, and track management workflows. Analyzes user intent and dispatches to new-track, decompose, adr, tech-debt, change (and related). Use for starting features, breaking down work, recording decisions, managing debt, or handling scope changes."
---

# Plan - Planning & Architecture Router

`/draft:plan` is the consolidated entry point for all planning and upfront architecture work in the Context-Driven Development lifecycle.

## When to Use

- Starting a new feature, bug fix, or refactor track
- Decomposing large modules or changes into dependency-aware units
- Recording Architecture Decision Records (ADRs)
- Cataloging and prioritizing technical debt
- Handling mid-track requirement or scope changes

## Routing Logic

The router parses intent from natural language and dispatches to the correct leaf skill. Ambiguous requests surface a short menu of options.

| User Intent Keywords                  | Dispatches To         | Purpose |
|---------------------------------------|-----------------------|---------|
| new feature, new track, start X, add Y, plan a refactor, fix the Z bug | `/draft:new-track` | Collaborative spec + plan creation for track |
| decompose, break into modules, dependency map | `/draft:decompose` | Module decomposition + graph |
| adr, architecture decision, record decision, design decision | `/draft:adr` | ADR authoring and evaluation |
| tech debt, technical debt, catalog debt, debt analysis | `/draft:tech-debt` | 6-dimension debt scan + prioritization |
| change, scope changed, requirements changed, update spec, mid-track pivot | `/draft:change` | Structured change impact & plan update |

## Dispatch Examples

User: "start a new feature for user profile editing"

→ dispatches to `/draft:new-track "user profile editing"`

User: "decompose the payment module"

→ dispatches to `/draft:decompose "payment module"`

User: "document our decision to use event sourcing"

→ dispatches to `/draft:adr "Use event sourcing for order processing"`

User: "find and prioritize our technical debt"

→ dispatches to `/draft:tech-debt`

User: "the requirements changed, we need to support multi-tenancy now"

→ dispatches to `/draft:change "add multi-tenancy support"`

## Relationship to Primary Workflow

`/draft:plan` augments but does not replace the core `/draft:new-track` and `/draft:implement` flow. Many planning activities are launched via `/draft:plan` for discoverability, then flow into the primary track lifecycle.

Direct leaf commands remain available during the transition period (see MIGRATION).

## Quality Gate

All planning dispatches should result in updated `draft/tracks/<id>/spec.md` or `plan.md` (or new ADR/debt artifacts) with proper metadata headers and citations back to product/tech-stack context.
=======
description: "Canonical planning entry point. Routes high-level planning intent to new-track, decompose, change, or adr, and provides a planning checkpoint when the next planning step depends on track state. Use when the user says 'plan this', 'scope this work', 'start a feature', 'continue planning', or wants one command to handle planning and design flow."
---

# Plan Work

`/draft:plan` is the **parent planning command**.

It exists to remove planning command soup from the developer experience.

Do not treat this command as a static menu. It must either:

- route to the correct planning workflow, or
- produce a useful planning checkpoint that tells the developer the next best planning action

Specialist planning skills remain available:

- `/draft:new-track`
- `/draft:decompose`
- `/draft:change`
- `/draft:adr`

But `/draft:plan` is now the canonical entry point for planning intent.

## Red Flags - STOP if you're:

- dumping a list of planning commands instead of routing
- creating a new track without reading existing Draft context
- mutating a track plan without first checking whether the request is actually a requirement change
- sending the user to `/draft:decompose` or `/draft:adr` without explaining why
- overriding explicit user intent for a named planning mode

**Route first. Explain why. Then execute the chosen planning workflow.**

---

## Parent Contract

`/draft:plan` owns four planning jobs:

1. **Create work** → `/draft:new-track`
2. **Break work into modules and architecture** → `/draft:decompose`
3. **Amend planned work safely** → `/draft:change`
4. **Capture a durable technical decision** → `/draft:adr`

The parent command should absorb the choice burden whenever the intent is obvious.

---

## Step 1: Parse Intent

Inspect `$ARGUMENTS` and classify the request into one of these buckets.

### Explicit Named Modes

If the command already names a specialist mode, route directly:

- `new-track`
- `decompose`
- `change`
- `adr`

Examples:

- `/draft:plan new-track add user auth`
- `/draft:plan decompose`
- `/draft:plan change support JSON export`
- `/draft:plan adr choose outbox pattern`

### High-Signal Natural Language

Route by intent when the user did not name the specialist command explicitly.

| Intent Pattern | Route To |
|---|---|
| "start a feature", "plan this feature", "scope this work", "I want to build X", "fix Y bug", "create a track" | `/draft:new-track` |
| "break into modules", "architecture this", "decompose", "design boundaries", "need HLD/LLD" | `/draft:decompose` |
| "requirements changed", "scope changed", "update the plan", "we also need X", "adjust the spec" | `/draft:change` |
| "document decision", "write an ADR", "record the tradeoff", "capture this architecture decision" | `/draft:adr` |

### Bare `/draft:plan`

If there are no meaningful arguments, do not fall back to a command list.

Instead, inspect Draft state and determine the next planning action.

---

## Step 2: Verify Draft Context

Run this check first:

```bash
ls draft/tracks.md 2>/dev/null
```

If `draft/` does not exist:

- If the user is trying to create new planned work, stop and say: `No Draft context found. Run /draft:init first.`
- Do not continue into planning without initialized context.

---

## Step 3: Inspect Current Planning State

For bare `/draft:plan`, or when intent is ambiguous, inspect current project state before routing.

### 3.1 Active Track Detection

Read `draft/tracks.md`.

Find:

- first `[~]` In Progress track
- otherwise first `[ ]` Pending track

If no track exists:

- default to `/draft:new-track`

Announce:

```text
Planning mode selected: new-track
Reason: no active Draft track exists yet.
```

Then follow the `/draft:new-track` workflow.

### 3.2 Track Artifact Inspection

For the active track, inspect:

- `draft/tracks/<id>/spec.md`
- `draft/tracks/<id>/plan.md`
- `draft/tracks/<id>/hld.md` if present
- `draft/tracks/<id>/lld.md` if present
- `draft/tracks/<id>/metadata.json` if present

Extract:

- track name and status
- whether architecture artifacts already exist
- whether the plan appears structurally complex
- whether there are recent planning amendments or unresolved scope drift

### 3.3 Complexity Signals

Treat these as signals that `/draft:decompose` is likely the next best planning step:

- plan spans multiple phases or modules
- spec mentions migrations, concurrency, background jobs, external systems, or multi-service boundaries
- work touches auth, payments, persistence, or public APIs
- user explicitly asks for module boundaries, interfaces, implementation order, HLD, or LLD
- `hld.md` is absent for clearly non-trivial work

### 3.4 Change Signals

Treat these as signals that `/draft:change` is likely the next step:

- user asks to revise scope of an existing active track
- user adds or removes acceptance criteria after planning already exists
- completed or in-progress work may be invalidated by a new requirement

### 3.5 ADR Signals

Treat these as signals that `/draft:adr` is likely the next step:

- a durable architecture decision is being proposed
- multiple viable options exist and the tradeoff matters long-term
- the team wants the rationale preserved independently of the track

---

## Step 4: Route Deterministically

Apply these routing rules in order.

### Rule 1: Explicit Mode Wins

If the user invoked:

- `/draft:plan new-track`
- `/draft:plan decompose`
- `/draft:plan change`
- `/draft:plan adr`

route directly and follow that specialist workflow.

### Rule 2: Requirement Drift Beats Architecture Work

If an active track exists and the request changes already-planned work, prefer `/draft:change` before `/draft:decompose` or `/draft:adr`.

Reason:

- spec/plan truth must be corrected before deeper design artifacts are regenerated

### Rule 3: Architecture Work Beats New Feature Intake

If a track already exists and complexity signals show the next planning bottleneck is structure, route to `/draft:decompose`.

### Rule 4: Decision Capture Is Explicit or Triggered by a Confirmed Tradeoff

Route to `/draft:adr` when:

- the user asked for an ADR, or
- planning analysis exposes a material architectural fork that should be recorded

### Rule 5: Otherwise Default to New Track Intake

If no stronger signal exists, route to `/draft:new-track`.

This is the default parent behavior for feature, bugfix, and refactor planning requests.

---

## Step 5: Announce the Selected Planning Mode

Before executing the chosen workflow, tell the user what `/draft:plan` decided.

Use this format:

```text
Planning mode selected: <mode>
Reason: <short reason grounded in track state or user intent>
```

Examples:

```text
Planning mode selected: new-track
Reason: this is a fresh feature request and no active matching track exists.
```

```text
Planning mode selected: change
Reason: an active track already exists and the request alters approved scope.
```

```text
Planning mode selected: decompose
Reason: the track is multi-phase, crosses service boundaries, and has no HLD yet.
```

---

## Step 6: Execute the Specialist Workflow

After routing, fully follow the corresponding specialist skill as the canonical implementation:

- `/draft:new-track` for intake, spec, plan, and metadata creation
- `/draft:decompose` for architecture/module decomposition
- `/draft:change` for scoped amendments to an existing track
- `/draft:adr` for decision records

Do not partially imitate those commands. Route, announce, then execute their workflow.

---

## Bare `/draft:plan` Fallback Output

If `/draft:plan` is bare and the next planning step is genuinely ambiguous even after inspecting context, produce a short planning checkpoint instead of a command list.

Format:

```text
Planning checkpoint: <track_id> - <track_name>
- Current state: <one-line summary>
- Next recommended planning action: <new-track|decompose|change|adr>
- Why: <short reason>
```

Then proceed with the recommended action unless the user objects.

The parent command should still move planning forward.

---

## Examples

### Example 1: Fresh feature request

Input:

```text
/draft:plan add user authentication
```

Route:

- `/draft:new-track`

### Example 2: Existing track got new scope

Input:

```text
/draft:plan we also need JSON export
```

Context:

- active track already exists for CSV export

Route:

- `/draft:change`

### Example 3: Complex track needs structure

Input:

```text
/draft:plan
```

Context:

- active track exists
- plan spans multiple modules
- no `hld.md`

Route:

- `/draft:decompose`

### Example 4: Decision needs durable record

Input:

```text
/draft:plan should we use the outbox pattern here?
```

If the tradeoff is real and decision-worthy:

- `/draft:adr`

Otherwise:

- discuss briefly during planning, then continue with the best planning workflow

---

## Compatibility Notes

The following specialist commands remain valid and should continue to work:

- `/draft:new-track`
- `/draft:decompose`
- `/draft:change`
- `/draft:adr`

`/draft:plan` is the canonical parent.

When helpful, reinforce the canonical form in output:

```text
`/draft:new-track` remains supported. Canonical parent: `/draft:plan new-track`.
```
>>>>>>> a79c14023e16774c77463870ac3510b728e8a91c
