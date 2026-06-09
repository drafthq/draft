---
name: docs
description: "Primary router for authoring and documentation workflows. Analyzes intent and dispatches primarily to documentation (technical docs, readme, runbook, api, onboarding). Use when the user needs to generate or update project documentation."
---

# Docs - Authoring & Documentation Router

`/draft:docs` provides a single namespace for all documentation generation and maintenance tasks.

## When to Use

- Generating or refreshing README, API docs, runbooks, or onboarding guides
- Producing technical documentation from existing architecture and code context
- Keeping documentation in sync after implementation or review phases

## Routing Logic

Currently focused on the documentation specialist. Future expansion may include additional authoring helpers under the same router.

| User Intent Keywords                        | Dispatches To         | Purpose |
|---------------------------------------------|-----------------------|---------|
| write docs, documentation, readme, runbook, api docs, onboarding guide, generate docs | `/draft:documentation` | Technical documentation authoring (readme, runbook, api, onboarding) |

## Dispatch Examples

User: "write a README for the new service"

→ dispatches to `/draft:documentation readme`

User: "generate an API reference and runbook for the billing module"

→ dispatches to `/draft:documentation api runbook`

User: "create onboarding guide for new engineers"

→ dispatches to `/draft:documentation onboarding`

## Notes

The documentation command reads heavily from `draft/architecture.md`, `draft/.ai-context.md`, `draft/product.md`, and `draft/tech-stack.md` (plus graph artifacts when present).

Prefer `/draft:docs` going forward for all authoring requests. The legacy direct form remains for compatibility (see migration guidance).
