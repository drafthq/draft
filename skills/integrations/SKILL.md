---
name: integrations
description: "Canonical integrations parent command. Handles external system exports and syncs. Routes intent to jira-preview or jira-create based on context."
---

# Integrations Workflows

`/draft:integrations` is the **canonical integrations parent command**.

It handles connectors and exports to external systems like Jira.

Specialist integration workflows remain available as named modes:

- `/draft:jira preview` (or `/draft:integrations jira-preview`)
- `/draft:jira create` (or `/draft:integrations jira-create`)

## Step 1: Parse Intent and Route

Examine the user's input and route to the correct integrations workflow.

### Explicit Named Modes

If the user explicitly invokes a specialist mode, route directly:

- `/draft:integrations jira-preview` → follow `/draft:jira preview`
- `/draft:integrations jira-create` → follow `/draft:jira create`

### Intent Routing

If no explicit mode is specified, infer the intent from the user's prompt:

| Intent | Action | Route |
|--------|--------|-------|
| "Export to Jira", "Preview Jira issues", "Show me what you'll create in Jira" | Jira Preview | `/draft:jira preview` |
| "Create Jira issues", "Sync to Jira", "Make tickets" | Jira Create | `/draft:jira create` |

## Step 2: Bare Parent Command Fallback

If the user runs a bare `/draft:integrations` without clear intent, present a small integrations menu with a recommended default path:

```text
Draft Integrations Menu:
1. /draft:integrations jira-preview (Generate Jira export file for review)
2. /draft:integrations jira-create (Create Jira issues from export)

What integration action do you want to perform?
```

Do not automatically launch a specialist workflow without explicit or clear inferred intent.

## Compatibility Note

The legacy specialist commands remain supported during the migration period, but `/draft:integrations` is the canonical parent for integration tasks.
