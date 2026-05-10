---
name: incident-response
description: "Incident management lifecycle — triage, communicate, mitigate, postmortem. Three modes — new (start incident), update (status update), postmortem (blameless RCA report). Use when the user asks to 'start an incident', 'incident triage', 'write a postmortem', or says 'we're down', 'production is broken', 'page received'."
---

# Incident Response

Manage an incident through its full lifecycle using structured incident management practices.

## Red Flags — STOP if you're:

- Fixing before communicating (stakeholders must know first)
- Skipping severity classification
- Writing a postmortem with blame (blameless only)
- Closing an incident without prevention items
- Ignoring rollback as a mitigation option

**Communicate first. Fix second. Learn always.**

---

## Pre-Check

1. Check for Draft context:
```bash
ls draft/ 2>/dev/null
```

This skill works standalone — incidents don't wait for project setup.

2. If available, follow the base procedure in `core/shared/draft-context-loading.md`.

## Step 1: Parse Arguments

- `/draft:incident-response new <description>` — Start new incident
- `/draft:incident-response update <status>` — Post status update
- `/draft:incident-response postmortem` — Generate postmortem report
- `/draft:incident-response` (no args) — Interactive: ask which mode

---

## NEW Mode — Start Incident

### Step 2: Triage

Classify severity:

| Level | Response Time | Who | Examples |
|-------|--------------|-----|---------|
| **SEV1** | Immediate, all-hands | Entire team | Data loss, complete outage, security breach |
| **SEV2** | 15 minutes | On-call + team lead | Major feature broken, significant degradation |
| **SEV3** | 1 hour | On-call | Minor feature broken, workaround exists |
| **SEV4** | Next business day | Assigned engineer | Cosmetic issue, minor inconvenience |

Assess:
1. **What is broken?** (from description or Jira ticket)
2. **Who is affected?** (from `draft/product.md` user types if available)
3. **What is the blast radius?** (from `draft/.ai-context.md` service topology if available)
4. **Is data at risk?** (escalate to SEV1 if yes)

### Step 3: Communicate

Generate initial status update:

```
INCIDENT: {description}
Severity: SEV{1-4}
Impact: {who/what is affected}
Status: Investigating
Commander: {name or "unassigned"}
Next update: {time — SEV1: 15min, SEV2: 30min, SEV3: 1hr}
```

### Step 4: Gather Evidence

- If Jira ticket linked: pull details via MCP (`get_issue`, `get_issue_description`, `get_issue_comments`)
- Extract URLs and log paths from ticket
- Use `curl`/`wget` to fetch dashboards or error pages mentioned
- Use `ssh` to access remote log paths if mentioned
- If GitHub MCP / `gh` CLI available: check recent deployments and merged PRs (`gh pr list --state merged --search "merged:>2024-01-01"`)
- Record all evidence in incident timeline

### Step 5: Mitigate

Following `core/agents/ops.md` production-safety mindset:

1. **Can we rollback?** If yes and severity ≥ SEV2: recommend rollback first, investigate after
2. **Can we hotfix?** If rollback not possible: identify minimal fix
3. **Can we mitigate?** Feature flag, config change, traffic routing
4. **Need to escalate?** If none of above work, escalate severity

Document all actions taken with timestamps.

### Step 6: Save Incident File

Save to: `draft/incidents/incident-<timestamp>.md` or `draft/tracks/<id>/incident.md`

```markdown
# Incident: {description}

| Field | Value |
|-------|-------|
| **Severity** | SEV{N} |
| **Status** | {Investigating/Mitigating/Resolved} |
| **Started** | {timestamp} |
| **Commander** | {name} |

## Timeline
| Time | Action |
|------|--------|
| {time} | Incident detected |
| {time} | Triage: classified as SEV{N} |
| {time} | {mitigation action} |

## Evidence
| Source | Finding |
|--------|---------|
| {source} | {finding} |

## Status Updates
{chronological updates}
```

---

## UPDATE Mode

1. Read existing incident file
2. Add new timeline entry with timestamp
3. Update status field if changed
4. Update severity if changed (with justification)
5. Generate formatted status update for stakeholders

---

## POSTMORTEM Mode

### Step 2: Gather Timeline

- Read incident file for timeline and evidence
- `git log` for related commits during incident window
- If Jira MCP: pull ticket history and transitions
- If GitHub MCP / `gh` CLI: pull PRs submitted during/after incident

### Step 3: Root Cause Analysis

Reference `core/agents/rca.md` methodology:

1. **5 Whys Analysis:**
   - Why did {symptom} happen? → Because {cause 1}
   - Why {cause 1}? → Because {cause 2}
   - Continue until root cause reached (typically 3-5 levels)

2. **Root Cause Classification:**
   - Logic error | Race condition | Data corruption | Configuration error
   - Dependency failure | Capacity exceeded | Security exploit | Human error

3. **Detection Lag:** When was the bug introduced vs when was it detected?

4. **SLO Impact:** Which SLOs were affected and by how much?

### Step 4: Generate Postmortem

**MANDATORY: Include YAML frontmatter with git metadata.** Follow `core/shared/git-report-metadata.md`.

Save to: `draft/incidents/postmortem-<timestamp>.md` with symlink `postmortem-latest.md`
Or track-scoped: `draft/tracks/<id>/postmortem.md`

```markdown
# Postmortem: {incident title}

## Summary
{2-3 sentences: what happened, impact, duration}

## Impact
- **Duration:** {start} to {end} ({total time})
- **Users affected:** {count or percentage}
- **SLO impact:** {which SLOs, by how much}
- **Data impact:** {any data loss or corruption}

## Timeline
| Time | Event |
|------|-------|
| {time} | {event} |

## Root Cause
{1-2 sentence root cause statement}

### 5 Whys
1. Why? → {answer}
2. Why? → {answer}
...

### Classification
- **Type:** {classification}
- **Detection Lag:** {introduced} → {detected} = {gap}

## What Went Well
- {positive observations}

## What Went Wrong
- {things that made the incident worse}

## Action Items
| # | Action | Owner | Deadline | Status |
|---|--------|-------|----------|--------|
| 1 | {detection improvement} | {name} | {date} | [ ] |
| 2 | {process improvement} | {name} | {date} | [ ] |
| 3 | {code improvement} | {name} | {date} | [ ] |
```

### Step 5: Jira Sync

Follow `core/shared/jira-sync.md`:
- Attach postmortem to Jira ticket
- Post comment: "[draft] Postmortem complete. Root cause: {1-line summary}. {N} action items."

⚠️ **Test Writing Guardrail:** If postmortem identifies missing tests, ASK: "Want me to create regression test tasks? [Y/n]"

## Cross-Skill Dispatch

- **Triggered by:** `/draft:new-track` when incident keywords detected in description
- **Postmortem feeds into:** `git bisect` (find the breaking commit), `/draft:learn` (update guardrails)
- **Can create:** Bug track via `/draft:new-track` for the fix

## Error Handling

**If no incident file found (update/postmortem mode):** List available incidents, ask which one
**If no Jira ticket:** Proceed without sync, note: "Link a Jira ticket for automatic sync"
