---
name: ops
description: "Canonical operations parent command. Handles debugging, deployments, incident response, and operational summaries. Routes intent to debug, deploy-checklist, incident-response, or standup based on context."
---

# Operations Workflows

`/draft:ops` is the **canonical operations parent command**.

It provides a unified entry point for debugging, deployment readiness, incident handling, and daily summaries, absorbing the cognitive load of selecting the right specialist tool.

Specialist operations workflows remain available as named modes:

- `/draft:ops debug` (formerly `/draft:debug`)
- `/draft:ops deploy-checklist` (formerly `/draft:deploy-checklist`)
- `/draft:ops incident-response` (formerly `/draft:incident-response`)
- `/draft:ops standup` (formerly `/draft:standup`)

## Step 1: Parse Intent and Route

Examine the user's input and route to the correct operations workflow.

### Explicit Named Modes

If the user explicitly invokes a specialist mode, route directly:

- `/draft:ops debug` → follow `/draft:debug`
- `/draft:ops deploy-checklist` → follow `/draft:deploy-checklist`
- `/draft:ops incident-response` → follow `/draft:incident-response`
- `/draft:ops standup` → follow `/draft:standup`

### Intent Routing

If no explicit mode is specified, infer the intent from the user's prompt:

| Intent | Action | Route |
|--------|--------|-------|
| "I have a bug", "Help me fix this error", "Why is this failing?" | Debugging | `/draft:debug` |
| "Ready to ship", "Are we good to deploy?", "Go live check" | Deploy readiness | `/draft:deploy-checklist` |
| "Site is down", "Production error", "Sev 1" | Incident handling | `/draft:incident-response` |
| "What did I do yesterday?", "Write my update", "Summarize work" | Standup summary | `/draft:standup` |

## Step 2: Bare Parent Command Fallback

If the user runs a bare `/draft:ops` without clear intent, present a small ops menu with a recommended default path:

```text
Draft Operations Menu:
1. /draft:ops debug (Structured debugging session)
2. /draft:ops deploy-checklist (Pre-deployment verification)
3. /draft:ops incident-response (Production incident handling)
4. /draft:ops standup (Generate daily summary)

How can I help you operate the system today?
```

Do not automatically launch a specialist workflow without explicit or clear inferred intent, unless an ongoing incident is already active.

## Compatibility Note

The legacy specialist commands remain supported during the migration period, but `/draft:ops` is the canonical parent for operational tasks.
