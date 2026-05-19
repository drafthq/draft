---
name: ops
<<<<<<< HEAD
description: "Primary router for operations, deployment, incident, and lifecycle workflows. Analyzes intent and dispatches to deploy-checklist, incident-response, standup, status, revert. Use for pre-deploy verification, handling outages, daily summaries, progress checks, and safe rollbacks."
---

# Ops - Operations & Lifecycle Router

`/draft:ops` groups all operational, deployment, and runtime lifecycle commands.

## When to Use

- Preparing a deployment or release
- Responding to incidents or outages
- Generating team standup / activity summaries
- Checking overall project or track status
- Performing git-aware reverts or rollbacks

## Routing Logic

Intent keywords drive deterministic dispatch. Multi-intent requests are sequenced (e.g., status then incident).

| User Intent Keywords                     | Dispatches To              | Purpose |
|------------------------------------------|----------------------------|---------|
| deploy checklist, pre-deploy, release check, readiness | `/draft:deploy-checklist` | Pre-deployment verification with rollback triggers |
| incident, outage, sev, postmortem, triage | `/draft:incident-response` | Full incident lifecycle (triage → mitigate → postmortem) |
| standup, daily summary, what did I do, activity report | `/draft:standup` | Git activity standup summary (read-only) |
| status, progress, what's the state, track overview | `/draft:status` | Progress overview across tracks and git |
| revert, rollback, undo, git revert, restore | `/draft:revert` | Git-aware safe rollback of changes or tracks |

## Dispatch Examples

User: "run the deploy checklist for the auth track"

→ dispatches to `/draft:deploy-checklist [track auth]`

User: "we had an outage last night, start postmortem"

→ dispatches to `/draft:incident-response postmortem`

User: "give me today's standup"

→ dispatches to `/draft:standup`

User: "what's the current status of the project"

→ dispatches to `/draft:status`

User: "revert the last two commits on this branch safely"

→ dispatches to `/draft:revert`

## Integration Notes

Ops commands often read `draft/tracks.md`, `draft/*/plan.md`, and git metadata. They feed forward into documentation and jira flows when needed.

Direct invocation of the leaf skills continues to work for power users and scripts during the deprecation window.
=======
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
>>>>>>> a79c14023e16774c77463870ac3510b728e8a91c
