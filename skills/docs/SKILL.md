---
name: docs
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
