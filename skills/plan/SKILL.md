---
name: plan
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
