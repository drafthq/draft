---
name: jira-preview
description: "Generate Jira export file from track plan for review before creating issues. Use when the user asks to 'preview Jira export', 'review Jira issues before creating', 'see the Jira draft', or says 'what would Jira creation look like'."
---

# Preview Jira Issues from Track Plan

Generate a timestamped `jira-export-<timestamp>.md` (with `jira-export-latest.md` symlink) from the track's plan for review and editing before creating actual Jira issues.

## Red Flags - STOP if you're:

- Generating a preview without an approved plan.md
- Assigning story points inconsistent with task count
- Missing sub-tasks that exist in plan.md
- Not including quality findings when review/bughunt reports exist
- Overwriting a reviewed jira-export without warning the user

**Plan first, then preview. Accuracy over speed.**

---

## Standard File Metadata

**The generated `jira-export-<timestamp>.md` MUST include the standard YAML frontmatter.** This enables traceability and sync verification.

### Gathering Git Information

Before generating the export file, run these commands to gather metadata:

```bash
# Project name (from manifest or directory)
basename "$(pwd)"

# Git branch
git branch --show-current

# Git remote tracking branch
git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null || echo "none"

# Git commit SHA (full)
git rev-parse HEAD

# Git commit SHA (short)
git rev-parse --short HEAD

# Git commit date
git log -1 --format="%ci"

# Git commit message (first line)
git log -1 --format="%s"

# Check for uncommitted changes
git status --porcelain | head -1
```

### Metadata Template

Insert this YAML frontmatter block at the **top of the timestamped `jira-export-<timestamp>.md`**:

```yaml
---
project: "{PROJECT_NAME}"
module: "root"
track_id: "{TRACK_ID}"
generated_by: "draft:jira-preview"
generated_at: "{ISO_TIMESTAMP}"
git:
  branch: "{LOCAL_BRANCH}"
  remote: "{REMOTE/BRANCH or 'none'}"
  commit: "{FULL_SHA}"
  commit_short: "{SHORT_SHA}"
  commit_date: "{COMMIT_DATE}"
  commit_message: "{FIRST_LINE_OF_COMMIT_MESSAGE}"
  dirty: {true|false}
synced_to_commit: "{FULL_SHA}"
---
```

> **Note**: `generated_by` uses `draft:command` format (not `/draft:command`) for cross-platform compatibility.

---

## Mapping Structure

| Draft Concept | Jira Entity |
|---------------|-------------|
| Track | Epic |
| Phase | Story |
| Task | Sub-task (under story) |

## Step 1: Load Context

1. **Capture git context first:**
   ```bash
   git branch --show-current    # Current branch name
   git rev-parse --short HEAD   # Current commit hash
   ```
2. Find active track from `draft/tracks.md` (look for `[~] In Progress` or first `[ ]` track)
3. If track ID provided as argument, use that instead
4. Read the track's `plan.md` for phases and tasks
5. Read the track's `metadata.json` for title and type
6. Read the track's `spec.md` for epic description
7. Check for quality reports:
   - `draft/tracks/<id>/review-report-latest.md` — review findings (from `/draft:review`)
   - `draft/tracks/<id>/bughunt-report-latest.md` — defect findings

If no track found:
- Tell user: "No track found. Run `/draft:new-track` to create one, or specify track ID."

## Step 2: Parse Plan Structure

Extract from `plan.md`:

### Epic (from track)
- **Summary:** Track title from metadata.json or first `# Plan:` heading
- **Description:** Overview section from spec.md
- **Type:** Feature (from metadata.json type: feature|bugfix|refactor)

### Stories (from phases)
For each `## Phase N: [Name]` section:
- **Summary:** Phase name
- **Goal:** Extract from `**Goal:**` line
- **Verification:** Extract from `**Verification:**` line

### Sub-tasks (from tasks)
For each `- [ ] **Task N.M:**` within a phase:
- **Summary:** Task description (text after `**Task N.M:**`)
- **Parent:** The phase's story
- **Status:** Map `[ ]` → To Do, `[x]` → Done, `[~]` → In Progress, `[!]` → Blocked

### Story Points Calculation
Count tasks per phase and assign points to the **story**:

| Task Count | Story Points |
|------------|--------------|
| 1-2 tasks  | 1 point      |
| 3-4 tasks  | 2 points     |
| 5-6 tasks  | 3 points     |
| 7+ tasks   | 5 points     |

## Step 3: Extract Quality Findings (if reports exist)

If `review-report-latest.md` or `bughunt-report-latest.md` exists in the track directory:

### From `bughunt-report-latest.md`

1. Parse findings by severity (Critical, High, Medium, Low)
2. Extract **all sections** for each bug:
   - **Location** — file path and line number
   - **Confidence** — CONFIRMED, HIGH, or MEDIUM
   - **Code Evidence** — the actual problematic code snippet
   - **Data Flow Trace** — how data reaches the bug location
   - **Issue** — precise technical description
   - **Impact** — user-visible effect or system failure mode
   - **Verification Done** — checklist of verification steps completed
   - **Why Not a False Positive** — explicit reasoning
   - **Fix** — minimal code change or mitigation
   - **Regression Test** — test case that would catch this bug
3. Group by severity for the export

### From `review-report-latest.md`

1. Parse findings from review report stages — Stage 1: Automated Validation (Architecture Conformance, Dead Code, Dependency Cycles, Security Scan, Performance), Stage 2: Spec Compliance, Stage 3: Code Quality (Architecture, Error Handling, Testing, Maintainability)
2. Extract for each finding:
   - **Severity** — Critical (✗) or Warning (⚠)
   - **Category** — which validator produced it
   - **Location** — file path and line number
   - **Issue** — description of the violation
   - **Risk/Impact** — what could go wrong
   - **Fix** — recommended remediation
3. Group by severity for the export

**Critical/High findings** should be highlighted — consider suggesting additional stories or tasks to address them before the track is complete.

## Step 4: Generate Export File

Generate the timestamped filename and create the export file with symlink:

```bash
TIMESTAMP=$(date +%Y-%m-%dT%H%M)
EXPORT_FILE="draft/tracks/<track_id>/jira-export-${TIMESTAMP}.md"
SYMLINK="draft/tracks/<track_id>/jira-export-latest.md"
```

Create `${EXPORT_FILE}` and then create/update the symlink:

```bash
ln -sf "jira-export-${TIMESTAMP}.md" "${SYMLINK}"
```

File contents for `${EXPORT_FILE}`:

```markdown
---
project: "{PROJECT_NAME}"
module: "root"
track_id: "{TRACK_ID}"
generated_by: "draft:jira-preview"
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

# Jira Export: [Track Title]

| Field | Value |
|-------|-------|
| Generated | {ISO_TIMESTAMP} |
| Track ID | {TRACK_ID} |
| Branch | {LOCAL_BRANCH} |
| Commit | {SHORT_SHA} |
| Status | Ready for review |

> Edit this file to adjust story points, descriptions, or sub-tasks before running `/draft:jira-create`.

---

## Epic

**Summary:** [Track Title]
**Issue Type:** Epic
**Labels:** draft
**Description:**
{noformat}
[Spec overview - first 2-3 paragraphs]

---
🤖 Generated by Draft
Branch: [branch-name] | Commit: [short-hash]
{noformat}

---

## Story 1: [Phase 1 Name]

**Summary:** Phase 1: [Phase Name]
**Issue Type:** Story
**Story Points:** [calculated based on task count]
**Labels:** draft
**Epic Link:** (will be set on creation)

**Description:**
{noformat}
h3. Goal
[Phase goal]

h3. Verification
[Phase verification criteria]

---
🤖 Generated by Draft
Branch: [branch-name] | Commit: [short-hash]
{noformat}

### Sub-tasks

| # | Summary | Status |
|---|---------|--------|
| 1.1 | [Task 1.1 description] | To Do |
| 1.2 | [Task 1.2 description] | Done |
| 1.3 | [Task 1.3 description] | To Do |

---

## Story 2: [Phase 2 Name]

**Summary:** Phase 2: [Phase Name]
**Issue Type:** Story
**Story Points:** [calculated]
**Labels:** draft
**Epic Link:** (will be set on creation)

**Description:**
{noformat}
h3. Goal
[Phase goal]

h3. Verification
[Phase verification criteria]

---
🤖 Generated by Draft
Branch: [branch-name] | Commit: [short-hash]
{noformat}

### Sub-tasks

| # | Summary | Status |
|---|---------|--------|
| 2.1 | [Task 2.1 description] | To Do |
| 2.2 | [Task 2.2 description] | To Do |

---

[Continue for all phases...]

---

## Quality Reports

### Review Findings (informational)

| Severity | Category | Location | Issue | Risk/Impact | Fix |
|----------|----------|----------|-------|-------------|-----|
| Critical | Security | src/auth.ts:45 | Hardcoded API key | Secret exposed in version control | Move to environment variable |
| Warning | Architecture | src/utils.ts:12 | Layer boundary violation | UI importing from database layer | Use API service layer instead |

> Review findings are from `/draft:review` and `/draft:bughunt`. Include in Epic description for awareness.
> Critical findings should also be created as Bug issues (same as bughunt bugs) to ensure they are tracked and resolved.

---

## Bug Issues (from Bug Hunt Report)

Each bug from `bughunt-report-latest.md` becomes a separate **Bug** issue linked to the Epic.

### Bug 1: [CRITICAL] Off-by-one error in pagination

**Summary:** [Correctness] Off-by-one error in pagination
**Issue Type:** Bug
**Priority:** Highest
**Labels:** draft
**Epic Link:** (will be set on creation)

**Description:**
{noformat}
h3. Location
src/calc.ts:78

h3. Confidence
CONFIRMED

h3. Code Evidence
{code}
// The actual problematic code from bughunt-report-latest.md
{code}

h3. Data Flow Trace
[How data reaches this point: caller → caller → this function]

h3. Issue
[Full description from bughunt-report-latest.md]

h3. Impact
[User-visible or system failure mode]

h3. Verification Done
[Checklist of verification steps completed, e.g.:]
- Traced code path from entry point
- Checked .ai-context.md — not intentional
- Verified framework doesn't handle this
- No upstream guards found

h3. Why Not a False Positive
[Explicit reasoning from bughunt-report-latest.md]

h3. Fix
[Minimal code change or mitigation from report]

h3. Regression Test
[Test case from bughunt-report-latest.md, or "N/A" with reason]

---
🤖 Generated by Draft (Bug Hunt)
Branch: [branch-name] | Commit: [short-hash]
{noformat}

---

### Bug 2: [HIGH] Race condition in cache update

**Summary:** [Concurrency] Race condition in cache update
**Issue Type:** Bug
**Priority:** High
**Labels:** draft
**Epic Link:** (will be set on creation)

**Description:**
{noformat}
h3. Location
src/api.ts:92

h3. Confidence
HIGH

h3. Code Evidence
{code}
// The actual problematic code from bughunt-report-latest.md
{code}

h3. Data Flow Trace
[How data reaches this point: caller → caller → this function]

h3. Issue
[Full description from bughunt-report-latest.md]

h3. Impact
[User-visible or system failure mode]

h3. Verification Done
[Checklist of verification steps completed]

h3. Why Not a False Positive
[Explicit reasoning from bughunt-report-latest.md]

h3. Fix
[Fix recommendation from report]

h3. Regression Test
[Test case from bughunt-report-latest.md, or "N/A" with reason]

---
🤖 Generated by Draft (Bug Hunt)
Branch: [branch-name] | Commit: [short-hash]
{noformat}

---

[Continue for all bugs from bughunt-report-latest.md...]

> **Priority Mapping:** Critical → Highest, High → High, Medium → Medium, Low → Low
> All bugs are linked to the Epic but are separate from Stories (phases).
```

## Step 5: Report

```
Jira Preview Generated

Track: [track_id] - [title]
Export: draft/tracks/<id>/jira-export-<timestamp>.md
Symlink: draft/tracks/<id>/jira-export-latest.md

Summary:
- 1 epic
- N stories (phases)
- M sub-tasks (tasks)
- P total story points
- B bugs (from bughunt-report-latest.md)

Breakdown:
- Phase 1: [name] - X pts, Y tasks
- Phase 2: [name] - X pts, Y tasks
- Phase 3: [name] - X pts, Y tasks

Bugs (if bughunt-report-latest.md exists):
- X critical bugs
- Y high bugs
- Z medium/low bugs

Next steps:
1. Review and edit the export file via jira-export-latest.md (adjust points, descriptions, sub-tasks, bug priorities)
2. Run `/draft:jira-create` to create issues in Jira
```

## Error Handling

**If plan.md has no phases:**
- Tell user: "No phases found in plan.md. Run `/draft:new-track` to generate a proper plan."

**If spec.md missing:**
- Use plan.md overview for epic description
- Warn: "spec.md not found, using plan overview for epic description."

**If jira-export-latest.md already exists:**
- Check if the target file has been manually modified (look for user-added content not matching generated patterns — e.g., edited descriptions, added rows, changed story points from generated values)
- If modifications detected, prompt user: "Existing jira-export appears to have manual edits. Overwrite? [y/N]"
- If unmodified (matches generated patterns), proceed with regeneration (new timestamped file + updated symlink)

**If phase has no tasks:**
- Create story with 1 story point
- Add note: "No sub-tasks defined for this phase"
