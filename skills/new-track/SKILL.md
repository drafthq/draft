---
name: new-track
description: "Start a new feature or bug track. Collaborative intake process with structured questions, AI guidance, and progressive refinement before generating spec.md and plan.md. Use when the user asks to 'start a new track', 'create a feature track', 'add a bug fix track', or says 'I want to build X', 'fix the Y bug', 'plan a refactor'."
---

# Create New Track

Create a new track (feature, bug fix, or refactor) for Context-Driven Development. This is a **collaborative process** — be an active participant providing guidance, fact-checking, and expertise grounded in vetted sources.

**Feature Description:** $ARGUMENTS

## Red Flags - STOP if you're:

- Creating a track without reading existing Draft context (product.md, tech-stack.md, .ai-context.md)
- Asking questions without contributing expertise or trade-off analysis
- Rushing through intake without probing deeper with "why"
- Generating spec/plan without user confirmation at checkpoints
- Skipping risk identification
- Not citing sources when giving architectural advice

**Collaborative understanding, not speed.**

---

## Pre-Check

1. Verify Draft is initialized:
```bash
ls draft/product.md draft/tech-stack.md draft/workflow.md draft/tracks.md 2>/dev/null
```

If missing, tell user: "Project not initialized. Run `/draft:init` first."

2. Check for `--quick` flag in `$ARGUMENTS`:
   - If present: **strip `--quick` from `$ARGUMENTS` now** (before Step 1) and store the cleaned text as the working description for all subsequent steps. Proceed to Step 1, then go directly to **Step 1.5: Quick Mode**.
   - Quick mode is for: hotfixes, tiny isolated changes, work scoped to 1-3 hours

3. Load full project context (these documents ARE the big picture — every track must be grounded in them):
- Read `draft/product.md` — product vision, users, goals, constraints, guidelines (optional section)
- Read `draft/tech-stack.md` — languages, frameworks, patterns, code style, accepted patterns
- Read `draft/.ai-context.md` (if exists) — system map, modules, data flows, invariants, security architecture. Falls back to `draft/architecture.md` for legacy projects.
- Read `draft/workflow.md` — TDD preference, commit conventions, review process
- Read `draft/guardrails.md` (if exists) — hard guardrails, learned conventions, learned anti-patterns
- Read `draft/tracks.md` — existing tracks to check for overlap or dependencies
- **Scan recent track impact memory** (overlap detection): for each completed track in `draft/tracks/*/metadata.json` updated within the last 30 days, read the `impact` block (if present). Build a map `module → [recent_track_ids]`. After Step 4 (scope distillation), once the candidate modules for the new track are known, intersect them with this map. If overlap exists, surface it in the intake summary:
  ```
  Overlap warning: track <id> recently touched modules <A>, <B>.
  Review draft/tracks/<id>/metadata.json#impact before proceeding.
  ```
  This is informational, not blocking — the user decides whether to proceed, depend on the prior track, or rebase scope.

4. Load guidance references:
- Read `core/templates/intake-questions.md` — structured questions for intake
- Read `core/knowledge-base.md` — vetted sources for AI guidance

## Step 1: Generate Track ID

Create a short, kebab-case ID from the description (use the stripped description if `--quick` was present):
- "Add user authentication" → `add-user-auth`
- "Fix login bug" → `fix-login-bug`

Check if `draft/tracks/<track_id>/` already exists. If collision detected, append `-<ISO-date>` suffix (e.g., `feature-auth-2026-02-21`). Verify the suffixed path is also free before proceeding.

### Branch Creation (Toolchain-Aware)

See `core/shared/vcs-commands.md` for command conventions.

```bash
git checkout -b <track_id>
```

## Step 1.5: Quick Mode Path (`--quick` only)

**Skip if:** `--quick` was not present in `$ARGUMENTS`.

Skip all intake conversation. Ask only two questions:

1. "What exactly needs to change? (1-2 sentences)"
2. "How will you know it's done? (list acceptance criteria)"

Then generate both files directly:

```bash
mkdir -p draft/tracks/<track_id>
```

**`draft/tracks/<track_id>/spec.md`** (minimal — no YAML frontmatter needed):

```markdown
# Spec: [Title]

**Track ID:** <track_id>
**Type:** quick

## What

[description from question 1]

## Acceptance Criteria

- [ ] [from question 2, one per line]

## Non-Goals

- No scope expansion beyond what's described above
```

**`draft/tracks/<track_id>/plan.md`** (flat — single phase, no phases ceremony):

```markdown
# Plan: [Title]

**Track ID:** <track_id>

## Phase 1: Complete

**Goal:** [one-line summary from spec]
**Verification:** [how to confirm ACs are met — run tests / manual check]

### Tasks

- [ ] **Task 1:** [derived from AC 1]
- [ ] **Task N:** Verify — [run tests or check from AC]
```

Then execute **Step 8** (Create Metadata & Update Tracks) with these overrides for quick tracks:
- `"type": "quick"` (not `feature|bugfix|refactor`)
- `"phases": {"total": 1, "completed": 0}` (plan has exactly 1 phase)

Skip Steps 2–7.

After Step 8 completes, announce:
```
Quick track created: <track_id>

Files: spec.md (minimal), plan.md (flat)
Next: /draft:implement
```

---

## Step 2: Create Draft Files

Create the track directory and draft files immediately with skeleton structure:

### Create `draft/tracks/<track_id>/spec-draft.md`:

**MANDATORY: Include YAML frontmatter with git metadata.** Gather git info first:

```bash
git branch --show-current                    # LOCAL_BRANCH
git rev-parse --abbrev-ref @{upstream} 2>/dev/null || echo "none"  # REMOTE/BRANCH
git rev-parse HEAD                           # FULL_SHA
git rev-parse --short HEAD                   # SHORT_SHA
git log -1 --format=%ci HEAD                 # COMMIT_DATE
git log -1 --format=%s HEAD                  # COMMIT_MESSAGE
git status --porcelain | head -1 | wc -l     # 0 = clean, >0 = dirty
```

```markdown
---
project: "{PROJECT_NAME}"
module: "root"
track_id: "<track_id>"
generated_by: "draft:new-track"
generated_at: "{ISO_TIMESTAMP}"
git:
  branch: "{LOCAL_BRANCH}"
  remote: "{REMOTE/BRANCH}"
  commit: "{FULL_SHA}"
  commit_short: "{SHORT_SHA}"
  commit_date: "{COMMIT_DATE}"
  commit_message: "{COMMIT_MESSAGE}"
  dirty: {true|false}
synced_to_commit: "{FULL_SHA}"
---

# Specification Draft: [Title]

| Field | Value |
|-------|-------|
| **Branch** | `{LOCAL_BRANCH}` → `{REMOTE/BRANCH}` |
| **Commit** | `{SHORT_SHA}` — {COMMIT_MESSAGE} |
| **Generated** | {ISO_TIMESTAMP} |
| **Synced To** | `{FULL_SHA}` |

**Track ID:** <track_id>
**Status:** [ ] Drafting

> This is a working draft. Content will evolve through conversation.

## Context References
- **Product:** `draft/product.md` — [pending]
- **Tech Stack:** `draft/tech-stack.md` — [pending]
- **Architecture:** `draft/.ai-context.md` — [pending]

## Problem Statement
[To be developed through intake conversation]

## Background & Why Now
[To be developed through intake conversation]

## Requirements
### Functional
[To be developed through intake conversation]

### Non-Functional
[To be developed through intake conversation]

## Acceptance Criteria
[To be developed through intake conversation]

## Non-Goals
[To be developed through intake conversation]

## Technical Approach
[To be developed through intake conversation]

## Success Metrics
<!-- Remove metrics that don't apply -->

| Category | Metric | Target | Measurement |
|----------|--------|--------|-------------|
| Performance | [e.g., API response time] | [e.g., <200ms p95] | [e.g., APM dashboard] |
| Quality | [e.g., Test coverage] | [e.g., >90%] | [e.g., CI coverage report] |
| Business | [e.g., User adoption rate] | [e.g., 50% in 30 days] | [e.g., Analytics] |
| UX | [e.g., Task completion rate] | [e.g., >95%] | [e.g., User testing] |

## Stakeholders & Approvals
<!-- Add roles relevant to your organization -->

| Role | Name | Approval Required | Status |
|------|------|-------------------|--------|
| Product Owner | [name] | Spec sign-off | [ ] |
| Tech Lead | [name] | Architecture review | [ ] |
| Security | [name] | Security review (if applicable) | [ ] |
| QA | [name] | Test plan review | [ ] |

### Approval Gates
- [ ] Spec approved by Product Owner
- [ ] Architecture reviewed by Tech Lead
- [ ] Security review completed (if touching auth, data, or external APIs)
- [ ] Test plan reviewed by QA

## Risk Assessment
<!-- Score: Probability (1-5) × Impact (1-5). Risks scoring ≥9 require mitigation plans. -->

| Risk | Probability | Impact | Score | Mitigation |
|------|-------------|--------|-------|------------|
| [e.g., Third-party API instability] | 3 | 4 | 12 | [e.g., Circuit breaker + fallback cache] |
| [e.g., Data migration failure] | 2 | 5 | 10 | [e.g., Dry-run migration + rollback script] |
| [e.g., Scope creep] | 3 | 3 | 9 | [e.g., Strict non-goals enforcement] |

## Deployment Strategy
<!-- Define rollout approach for production delivery. For bug fixes and minor refactors, this section may be removed or marked N/A. -->

### Rollout Phases
1. **Canary** (1-5% traffic) — Validate core flows, monitor error rates
2. **Limited GA** (25%) — Expand to subset, watch performance metrics
3. **Full GA** (100%) — Complete rollout

### Feature Flags
- Flag name: `[feature_flag_name]`
- Default: `off`
- Kill switch: [yes/no]

### Rollback Plan
- Trigger: [e.g., error rate >1%, latency >500ms p95]
- Process: [e.g., disable feature flag, revert deployment]
- Data rollback: [e.g., migration revert script, N/A]

### Monitoring
- Dashboard: [link or name]
- Alerts: [e.g., PagerDuty rule for error rate spike]
- Key metrics: [e.g., error rate, latency, throughput]

## Open Questions
[Tracked during conversation]

## Conversation Log
> Key decisions and reasoning captured during intake.

[Conversation summary will be added here]
```

### Create `draft/tracks/<track_id>/plan-draft.md`:

**MANDATORY: Include YAML frontmatter with git metadata** (same git info as spec-draft.md):

```markdown
---
project: "{PROJECT_NAME}"
module: "root"
track_id: "<track_id>"
generated_by: "draft:new-track"
generated_at: "{ISO_TIMESTAMP}"
git:
  branch: "{LOCAL_BRANCH}"
  remote: "{REMOTE/BRANCH}"
  commit: "{FULL_SHA}"
  commit_short: "{SHORT_SHA}"
  commit_date: "{COMMIT_DATE}"
  commit_message: "{COMMIT_MESSAGE}"
  dirty: {true|false}
synced_to_commit: "{FULL_SHA}"
---

# Plan Draft: [Title]

| Field | Value |
|-------|-------|
| **Branch** | `{LOCAL_BRANCH}` → `{REMOTE/BRANCH}` |
| **Commit** | `{SHORT_SHA}` — {COMMIT_MESSAGE} |
| **Generated** | {ISO_TIMESTAMP} |
| **Synced To** | `{FULL_SHA}` |

**Track ID:** <track_id>
**Spec:** ./spec.md
**Status:** [ ] Drafting

> This is a working draft. Phases will be defined after spec is finalized.

## Overview
[To be developed after spec finalization]

## Phases
[To be developed after spec finalization]

## Notes
[Tracked during conversation]
```

Announce: "Created draft files. Let's build out the specification through conversation."

---

## Step 3: Collaborative Intake

Follow the structured intake from `core/templates/intake-questions.md`. You are an **active collaborator**, not just a questioner.

### Your Role as AI Collaborator

For each question:
1. **Ask** the question clearly
2. **Listen** to the user's response
3. **Contribute** your expertise:
   - Pattern recognition from industry experience
   - Trade-off analysis with citations from knowledge-base.md
   - Risk identification the user may not see
   - Fact-checking against project context (.ai-context.md, tech-stack.md)
   - Alternative approaches with pros/cons
4. **Update** spec-draft.md with what's been established
5. **Summarize** periodically: "Here's what we have so far..."

### Citation Style

Ground advice in vetted sources:
- "Consider CQRS here (DDIA, Ch. 11) — separates read/write concerns."
- "This could violate the Dependency Rule (Clean Architecture)."
- "Circuit breaker pattern (Release It!) would help prevent cascade failures."
- "Watch for OWASP A01:2021 — Broken Access Control."

### Red Flags - STOP if you're:

- Asking questions without contributing expertise
- Accepting answers without probing deeper with "why"
- Not citing sources when giving architectural advice
- Skipping risk identification
- Not updating drafts as conversation progresses
- Rushing toward generation instead of understanding
- Not referencing product.md, tech-stack.md, .ai-context.md

**The goal is collaborative understanding, not speed.**

---

## Step 3A: Intake Flow (Feature / Refactor)

### Phase 1: Existing Documentation
- "Do you have existing documentation for this work? (PRD, RFC, design doc, Jira ticket)"
- If yes: Ingest, extract key points, identify gaps
- AI contribution: "I've extracted [X, Y, Z]. I notice [gap] isn't covered yet."

### Phase 2: Problem Space
Walk through problem questions from intake-questions.md:
- What problem are we solving?
- Why does this problem matter now?
- Who experiences this pain?
- What's the scope boundary?

After each answer:
- Contribute relevant patterns, similar problems, domain concepts
- Challenge assumptions with "why" questions
- Update spec-draft.md Problem Statement section

**Checkpoint:** "Here's the problem as I understand it: [summary]. Does this capture it?"

### Phase 3: Solution Space
Walk through solution questions:
- What's the simplest version that solves this?
- Why this approach over alternatives?
- What are we explicitly NOT doing?
- How does this fit with current architecture?

After each answer:
- Present 2-3 alternative approaches with trade-offs
- Cross-reference .ai-context.md (or architecture.md) for integration points
- Suggest tech-stack.md patterns to leverage
- Update spec-draft.md Technical Approach and Non-Goals sections

**Checkpoint:** "The proposed approach is [summary]. I've identified these alternatives: [list]. Your reasoning for this choice is [X]. Correct?"

### Phase 4: Risk & Constraints
Walk through risk questions:
- What could go wrong?
- What dependencies or blockers exist?
- Why might this fail?
- Security or compliance considerations?

After each answer:
- Surface risks user may not have considered
- Reference OWASP, distributed systems fallacies, failure modes
- Fact-check assumptions against project context
- Update spec-draft.md with risks as Open Questions

**Checkpoint:** "Key risks identified: [list]. Are there others you're aware of?"

### Phase 5: Success Criteria
Walk through success questions:
- How do we know this is complete?
- How will we verify it works?
- What would make stakeholders accept this?

After each answer:
- Suggest measurable, testable acceptance criteria
- Recommend testing strategies appropriate to feature type
- Align with product.md goals
- Update spec-draft.md Acceptance Criteria section

**Checkpoint:** "Acceptance criteria so far: [list]. Missing anything?"

---

### Step 3A.5: Cross-Skill Integration (Feature/Refactor)

#### Refactor Tracks → Tech-Debt Offer

If track type is refactor:
```
"Want to run a tech-debt analysis to prioritize what to address?
  → /draft:tech-debt scans 6 debt categories with prioritization
  Run tech-debt analysis? [Y/n]"
```
If accepted: invoke `/draft:tech-debt`, use its prioritized output to scope the refactor spec.

#### Design Decision Detection → ADR Suggestion

If spec introduces technology not in `tech-stack.md` or changes service boundaries in `.ai-context.md`:
```
"This involves a significant design decision. Consider running:
  → /draft:adr to document the architectural decision"
```

---

## Step 3B: Intake Flow (Bug & RCA)

For bugs, incidents, or Jira-sourced issues. Tighter scope, investigation-focused.

### Phase 1: Symptoms & Context
- "What's the exact error or unexpected behavior?"
- "Who is affected? How often does this occur?"
- "When did this start? Any recent changes?"

AI contribution: Pattern recognition for common bug types, severity assessment.

### Phase 2: Reproduction
- "What are the exact steps to reproduce?"
- "What environment conditions are required?"
- "What's the expected vs actual behavior?"

AI contribution: Suggest additional reproduction scenarios, edge cases to check.

### Phase 3: Blast Radius
- "What still works correctly?"
- "Where does the failure boundary lie?"

AI contribution: Help narrow investigation scope, reference architecture.md for module boundaries.

### Phase 4: Code Locality
- "Where do you suspect the bug is?"
- "What's the entry point and failure point?"

AI contribution: Suggest investigation approach, reference debugging patterns.

Update spec-draft.md with bug-specific structure after gathering sufficient context.

### Step 3B.5: Auto-Triage Pipeline (Bug Tracks)

**Trigger:** Track type is bug/RCA AND any of: Jira ticket ID found, description contains "incident", "outage", "SEV", "regression", "crash".

When triggered, execute the auto-triage pipeline before proceeding to Step 4:

#### Triage Step 1: Gather External Context

If Jira ticket provided:
1. Pull ticket via Jira MCP: `get_issue()`, `get_issue_description()`, `get_issue_comments()`
2. Extract from ticket: URLs, log paths, stack traces, reproduction steps, affected services
3. Use `curl`/`wget` to fetch any URLs mentioned (dashboards, error pages, API responses)
4. Use `ssh` to access log locations on remote nodes (if paths like `/home/log/`, node IPs mentioned)
5. Collect all gathered data into a triage context bundle

#### Triage Step 2: Offer Debug Session

```
"Bug track detected with [Jira context / error description]. Run a structured debug session before writing the spec?
  → /draft:debug will help reproduce and isolate the issue
  Run debug session? [Y/n]"
```

If accepted:
- Invoke `/draft:debug` with gathered triage context
- Feed the Debug Report into spec-draft.md "Reproduction" and "Root Cause Hypothesis" sections

#### Triage Step 3: RCA Analysis

If debug session produced findings:
- Invoke RCA agent methodology from `core/agents/rca.md`
- Perform 5 Whys analysis using debug findings
- Assess blast radius from `.ai-context.md`
- Quantify SLO impact

#### Triage Step 4: Generate rca.md

Create `draft/tracks/<track_id>/rca.md` using the template from `core/templates/rca.md`:
- Include root cause, classification, timeline, evidence, prevention items
- Include YAML frontmatter with git metadata
- Link to debug report and gathered evidence

#### Triage Step 5: Sync to Jira

If Jira ticket linked, sync via `core/shared/jira-sync.md`:
- Attach `rca.md` to ticket
- Post comment: "[draft] rca-complete: Root cause identified — {1-line summary}. Prevention: {count} items."

#### Triage Step 6: Developer Checkpoint

```
"RCA complete. Findings:
  Root cause: {summary}
  Classification: {type}
  Blast radius: {affected modules}

  → Want me to write regression tests for this? [Y/n]
  → Ready to proceed with the fix? [Y/n]"
```

Only proceed to spec/plan generation after developer approval.

### Step 3B.6: Incident Context Detection

If track description contains "incident", "outage", "SEV", or "postmortem":
- Check for existing postmortem: `ls draft/tracks/*/incident-*.md 2>/dev/null`
- If none found, suggest: "Run `/draft:incident-response postmortem` first to capture incident context."
- If found, feed postmortem findings into spec-draft.md.

---

## Step 4: Draft Review & Refinement

After completing intake sections:

1. Present complete spec-draft.md summary
2. List any remaining Open Questions
3. Ask: "Want to refine any section, or ready to finalize?"

If refining:
- Continue conversation on specific sections
- Update drafts as discussion progresses
- Return to this step when ready

---

## Step 4.5: Elicitation Pass

Before finalizing, offer a quick spec stress-test. This takes 2 minutes and often surfaces blind spots.

Based on the track type (feature / bug / refactor), present 3 pre-selected challenge techniques:

**Feature tracks:**
1. **Pre-mortem** — "It's 6 months later and this feature failed. What went wrong?"
2. **Scope Boundary** — "What's the smallest version that still achieves the core goal?"
3. **Edge Case Storm** — Surface 5 boundary conditions not yet in the ACs

**Bug tracks:**
1. **Root Cause Depth** — "Is the reported symptom the real bug, or a symptom of something deeper?"
2. **Blast Radius** — "What else could this fix inadvertently break?"
3. **Regression Risk** — "What existing behavior might this change inadvertently affect?"

**Refactor tracks:**
1. **Behavior Preservation** — "List every externally visible behavior that must be identical before and after"
2. **Integration Impact** — "Which callers will break if this interface changes?"
3. **Rollback Complexity** — "If this refactor needs reverting mid-flight, what's the path?"

Present to the user:

```
Quick stress-test before finalizing — pick one or skip:

1. [Technique name] — [one-line prompt]
2. [Technique name] — [one-line prompt]
3. [Technique name] — [one-line prompt]

Enter 1–3, or "skip":
```

- **If a number is chosen:** Apply that technique to the current spec-draft.md. Show what it reveals. Update spec-draft.md if findings are significant (new ACs, revised non-goals, added risks).
- **If "skip":** Proceed directly to Step 5. No friction.

---

## Step 5: Finalize Specification

When user confirms spec is ready:

1. Finalize `spec-draft.md` → `spec.md`:
   1. Read `spec-draft.md` content.
   2. Write content to `spec.md`.
   3. Verify `spec.md` exists and has non-empty content.
   4. Delete `spec-draft.md`.
2. Update `spec.md` status to `[x] Complete`
3. Update Context References with specific connections to product.md, tech-stack.md, .ai-context.md
4. Add Conversation Log summary with key decisions and reasoning

Present final spec.md for acknowledgment.

---

## Step 6: Create Plan

Based on finalized spec, build out plan-draft.md:

### For Feature / Refactor:
Create phased breakdown:
- Phase 1: Foundation / Setup
- Phase 2: Core Implementation
- Phase 3: Integration & Polish

For each phase:
- Define Goal and Verification criteria
- Break into specific Tasks with file references
- Identify dependencies between tasks

AI contribution:
- Suggest task ordering based on dependencies
- Reference tech-stack.md for implementation patterns
- Identify testing requirements per task
- Flag integration points with .ai-context.md modules

### For Bug & RCA:
Use fixed 3-phase structure:
- Phase 1: Investigate & Reproduce
- Phase 2: Root Cause Analysis
- Phase 3: Fix & Verify

Reference `core/agents/rca.md` for detailed process.

### Conditional Plan Tasks (Auto-Embedded)

Based on track context, automatically include these tasks in the appropriate plan phase:

- **If track modifies production code:** Add final task in last phase:
  `- [ ] Run /draft:deploy-checklist before deploying`

- **If spec mentions new APIs, services, or components:** Add documentation task:
  `- [ ] Update documentation (run /draft:documentation api|runbook)`

- **If testing-strategy.md exists or TDD enabled:** Add in Phase 1:
  `- [ ] Verify testing strategy covers this track (run /draft:testing-strategy if not done)`

Present plan-draft.md for review.

---

## Step 7: Finalize Plan

When user confirms plan is ready:

1. Update plan-draft.md status to `[x] Complete`
2. Write final content to `plan.md`, then delete `plan-draft.md`
3. Validate phases against spec requirements
4. Ensure all acceptance criteria are covered by tasks

Present final plan.md for acknowledgment.

---

## Step 8: Create Metadata & Update Tracks

### Pre-Validation

Before creating metadata, verify final files exist:

```bash
ls draft/tracks/<track_id>/spec.md draft/tracks/<track_id>/plan.md 2>/dev/null
```

If either missing:
- ERROR: "Track creation incomplete. Missing files: [list missing]"
- "Expected: spec.md and plan.md in draft/tracks/<track_id>/"
- Halt - do not create metadata.json or update tracks.md

### Create `draft/tracks/<track_id>/metadata.json`:

```json
{
  "id": "<track_id>",
  "title": "[Title]",
  "type": "feature|bugfix|refactor",
  "status": "planning",
  "created": "[ISO timestamp]",
  "updated": "[ISO timestamp]",
  "phases": {
    "total": 3,
    "completed": 0
  },
  "tasks": {
    "total": "<count all `- [ ]` task lines in plan.md>",
    "completed": 0
  }
}
```

Count all `- [ ]` task lines in `plan.md` and set `tasks.total` in `metadata.json` accordingly instead of 0.

**Note:** ISO timestamps can use either `Z` or `.000Z` suffix (both valid ISO 8601). No format constraint enforced — both second precision (`2026-02-08T12:00:00Z`) and millisecond precision (`2026-02-08T12:00:00.000Z`) are acceptable.

### Verify metadata.json

Before updating tracks.md, verify metadata.json was written successfully:

```bash
cat draft/tracks/<track_id>/metadata.json | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null || echo "INVALID"
```

If invalid or missing:
- ERROR: "Failed to write valid metadata.json for track <track_id>"
- Halt - do not update tracks.md (prevents orphaned track entries)

### Update `draft/tracks.md`:

Add under Active:

```markdown
## Active

### [track_id] - [Title]
- **Status:** [ ] Planning
- **Created:** [date]
- **Phases:** 0/3
- **Path:** `./tracks/<track_id>/`
```

### Cleanup (Defensive)

Remove draft files if they still exist (defensive cleanup for failed renames):

```bash
rm -f draft/tracks/<track_id>/spec-draft.md
rm -f draft/tracks/<track_id>/plan-draft.md
```

The `-f` flag ensures idempotent cleanup whether files exist or not.

### Post-Validation

Verify tracks.md was updated successfully:

```bash
grep "<track_id>" draft/tracks.md
```

If not found:
- ERROR: "Failed to update tracks.md with new track entry"
- "Expected track_id '<track_id>' in draft/tracks.md Active section"
- Provide recovery: "Manually add track entry to draft/tracks.md or remove draft/tracks/<track_id>/ and retry"

---

## Completion

Announce:
"Track created: <track_id>

Created:
- draft/tracks/<track_id>/spec.md
- draft/tracks/<track_id>/plan.md
- draft/tracks/<track_id>/metadata.json

Updated:
- draft/tracks.md

Key decisions documented in spec.md Conversation Log.

Next: Review the spec and plan, then run `/draft:implement` to begin."

---

## Cross-Skill Dispatch

### Jira Sync at Completion

If Jira ticket is linked (from spec.md or metadata.json), sync via `core/shared/jira-sync.md`:
- Attach `spec.md` and `plan.md` to ticket
- Post comment: "[draft] spec-complete: Specification and plan generated for track {id}. {phase_count} phases, {task_count} tasks."

### Completion Suggestions

Based on track type, suggest relevant follow-ups:

**Bug tracks:**
```
"Track ready for implementation. Also consider:
  → /draft:incident-response postmortem — If this bug caused an incident
  → git bisect — Find the exact commit that introduced this bug"
```

**Feature tracks:**
```
"Track ready for implementation.
  Next: /draft:implement
  Also: /draft:testing-strategy — Define test approach for this feature"
```

**Refactor tracks:**
```
"Track ready for implementation.
  Next: /draft:implement
  Also: /draft:adr — Document refactoring decisions"
```
