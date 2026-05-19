---
name: docs
<<<<<<< HEAD
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
=======
description: "Canonical documentation parent command. Produces engineering documentation, explains the system, defines testing strategy, captures technical debt, and provides project onboarding. Routes intent to documentation, testing-strategy, tech-debt, or tour based on context."
---

# Documentation Workflows

`/draft:docs` is the **canonical documentation parent command**.

It orchestrates the generation and maintenance of engineering documentation, absorbing the cognitive load of selecting the right specialist tool.

Specialist documentation workflows remain available as named modes:

- `/draft:docs documentation` (formerly `/draft:documentation`)
- `/draft:docs testing-strategy` (formerly `/draft:testing-strategy`)
- `/draft:docs tech-debt` (formerly `/draft:tech-debt`)
- `/draft:docs tour` (formerly `/draft:tour`)

## Step 1: Parse Intent and Route

Examine the user's input and route to the correct documentation workflow.

### Explicit Named Modes

If the user explicitly invokes a specialist mode, route directly:

- `/draft:docs documentation` → follow `/draft:documentation`
- `/draft:docs testing-strategy` → follow `/draft:testing-strategy`
- `/draft:docs tech-debt` → follow `/draft:tech-debt`
- `/draft:docs tour` → follow `/draft:tour`

### Intent Routing

If no explicit mode is specified, infer the intent from the user's prompt:

| Intent | Action | Route |
|--------|--------|-------|
| "Document this feature", "Write README", "Generate API docs" | Engineering Docs | `/draft:documentation` |
| "How should we test this?", "Create test plan", "Testing strategy" | Testing Strategy | `/draft:testing-strategy` |
| "Log technical debt", "We need to fix this later", "Track shortcuts" | Tech Debt | `/draft:tech-debt` |
| "How does this work?", "Walk me through the codebase", "Onboard me" | System Tour | `/draft:tour` |

**Ambiguous phrasing** (e.g., "document our testing approach" could match `documentation` or `testing-strategy`): do not guess. Ask the user one clarifying question — "Do you want (a) prose docs describing the existing tests, or (b) a test plan defining what to test next?" — then route.

## Step 2: Bare Parent Command Fallback

If the user runs a bare `/draft:docs` without clear intent, present a small documentation menu with a recommended default path based on the current context:

```text
Draft Documentation Menu:
1. /draft:docs documentation (Generate engineering docs)
2. /draft:docs testing-strategy (Define project testing approach)
3. /draft:docs tech-debt (Log or review technical debt)
4. /draft:docs tour (Onboarding walkthrough of the system)

What type of documentation do you need?
```

Do not automatically launch a specialist workflow without explicit or clear inferred intent.

## Compatibility Note

The legacy specialist commands remain supported during the migration period, but `/draft:docs` is the canonical parent for documentation tasks.
>>>>>>> a79c14023e16774c77463870ac3510b728e8a91c
