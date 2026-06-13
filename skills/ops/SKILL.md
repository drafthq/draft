---
name: ops
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
| upload for review, git upload, submit code, open PR | `/draft:upload` | Pre-upload gate: review, approvals, validators, then push |
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
