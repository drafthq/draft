---
name: jira
description: Unified Jira entry point. Routes to preview (default), create, or review subcommands.
---

# Jira

Single entry point for all Jira workflows: preview Draft tracks as Jira issues, create them via MCP (default = 1 Story per track; --epic = 1 Epic + 1-3 Stories), and review any Jira ticket (epic, story, bug, sub-task) end-to-end.


## Subcommand Routing

Parse `$ARGUMENTS` and dispatch:

| User Intent | Subcommand | Behavior |
|-------------|------------|----------|
| `(no args)`, `preview`, `preview <track-id>` | **preview** (default) | Generate `jira-export-<timestamp>.md` — **one Story** containing all phases/tasks |
| `preview --epic ...` | **preview --epic** | Generate rich export: 1 Epic + 1–3 Stories (max) |
| `create`, `create <track-id>` | **create** | Create **1 Story** (default) via MCP |
| `review <JIRA_ID>` | **review** | Full qualification review of any Jira ticket — delegates to [references/review.md](references/review.md) |

- `preview` is the default when no subcommand is supplied.
- `review` requires a Jira ID as the next argument. Validate format `<PROJECT>-<NUMBER>` (e.g., `ENG-446236`). If numeric-only, prompt for project prefix — do NOT assume.

---

## Jira Configuration (Shared)

All subcommands read project-level Jira configuration from `draft/workflow.md` under a `## Jira` section:

```markdown
## Jira

Project Key: <KEY>
Integration: jira-mcp
Team: <team-name>
Component: <component-name>
Swimlane: <swimlane-name>
Assignee Display Name: <assignee-name>
```

- **Project Key** — required for `create`. If missing, prompt and persist.
- **Integration** — informational; defaults to `jira-mcp` if absent.
- **Team / Component / Swimlane / Assignee Display Name** — applied as defaults to every issue created by `create`. Empty values are skipped (Jira ignores blank fields).

If a value is missing when needed:
1. Prompt the user for it.
2. Append to (or create) the `## Jira` section in `draft/workflow.md` so subsequent runs reuse it.

---

## Jira Content Hygiene (Mandatory)

When writing any text that will go into Jira (descriptions, summaries, bug details):

- Be **minimal, concise, and precise**.
- Do **not** dump full plans, long task lists, verbose context, or Draft-internal reasoning into Jira.
- Use short summaries + key outcomes only.
- Structured content (phases, tasks) may be included as compact markdown, but keep it brief.
- Never pollute Jira with excessive text.

This rule applies to both `preview` generation and `create` descriptions.

---

# Subcommand: preview

Generate a timestamped `jira-export-<timestamp>.md` (with `jira-export-latest.md` symlink) from the active track's plan for review and editing before creating Jira issues.

**Flag handling:** Check `$ARGUMENTS` for `--epic` at the very start of this section. If present, set `EPIC_MODE=true` and remove the flag from the working arguments. This flag changes the entire output structure (see Step 2).

## Red Flags — STOP if you're:

- Generating a preview without an approved plan.md
- Assigning story points inconsistent with task count
- Missing sub-tasks that exist in plan.md
- Not including quality findings when review/bughunt reports exist
- Overwriting a reviewed jira-export without warning the user

**Plan first, then preview. Accuracy over speed.**

---

## Standard File Metadata

The generated `jira-export-<timestamp>.md` MUST include the standard YAML frontmatter for traceability and sync verification.

### Gathering Git Information

```bash
basename "$(pwd)"                                                # Project name
git branch --show-current                                        # Local branch
git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null || echo "none"
git rev-parse HEAD                                               # Full SHA
git rev-parse --short HEAD                                       # Short SHA
git log -1 --format="%ci"                                        # Commit date
git log -1 --format="%s"                                         # Commit subject
git status --porcelain | head -1                                 # Dirty check
```

### Metadata Template

```yaml
---
project: "{PROJECT_NAME}"
module: "root"
track_id: "{TRACK_ID}"
generated_by: "draft:jira:preview"
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

---

## Mapping Structure


### Default behavior (recommended)

- Every track becomes **exactly 1 Story**.
- All phases and their tasks are included **inside the Story description** (as markdown sections).
- No child Jira issues are created.

This keeps Jira clean and keeps the export focused on root issues by default.

### Opt-in rich hierarchy (`--epic`)

Use `/draft:jira preview --epic` or `/draft:jira create --epic` when you want an Epic.

**Splitting rule (simple):**
- 5 or fewer phases → **1 Story** under the Epic
- More than 5 phases → split across **2 or 3 Stories** (maximum)

All detailed tasks remain inside the Story descriptions — we never create Jira Tasks or Sub-tasks.

### Summary of mappings

| Flag       | Root Issue | Child Issues          | Where phases/tasks live                     |
|------------|------------|-----------------------|---------------------------------------------|
| (default)  | 1 Story    | None                  | Inside the single Story description         |
| `--epic`   | 1 Epic     | 1–3 Stories (max)     | Distributed across the Story descriptions   |

## Step 1: Load Context

1. Capture git context (commands above).
2. Find the active track from `draft/tracks.md` (look for `[~] In Progress` or first `[ ]`). If a track ID is provided in `$ARGUMENTS`, use that instead.
3. Read the track's `plan.md` for phases and tasks.
4. Read the track's `metadata.json` for title and type.
5. Read the track's `spec.md` for root-issue description.
6. Check for quality reports:
   - `draft/tracks/<id>/review-report-latest.md` — review findings (from `/draft:review`)
   - `draft/tracks/<id>/bughunt-report-latest.md` — defect findings
7. Read `draft/workflow.md` → `## Jira` section for shared config (see Jira Configuration above).

If no track found: tell the user "No track found. Run `/draft:new-track` to create one, or specify track ID."

## Step 2: Determine Export Mode, Count Phases, and Group Content

### 2.1 Detect Mode
- If `EPIC_MODE=true` (from `--epic` flag), use Epic + Stories mode.
- Otherwise, use **default single-Story mode**.

### 2.2 Count Phases and Decide Story Count (Epic Mode Only)
Count the number of `## Phase` sections in `plan.md`.

**Splitting guideline (when using --epic):**
- Phases ≤ 5  → 1 Story under the Epic
- Phases 6–12 → 2 Stories under the Epic
- Phases > 12 → 3 Stories under the Epic (hard cap)

Store the target number of stories: `TARGET_STORIES`.

### 2.3 Group Phases (for Epic Mode)
Divide the phases as evenly as possible across `TARGET_STORIES`.

Example grouping (store this in memory):
- Story 1 gets phases 1..K
- Story 2 gets phases K+1..M
- Story 3 gets remaining phases

In **default mode**, ignore grouping — everything goes under one Story.

### 2.4 Build Data Structures
For every phase:
- Capture Phase name, Goal, Verification
- Collect all its tasks (with status)

Calculate total story points using the existing simple table (1-2 tasks = 1pt, 3-4=2pt, 5-6=3pt, 7+=5pt). This total goes on the root issue (or split across stories in epic mode if desired — default is to put total on the first Story).

### 2.5 Root Issue Data
- Summary = Track title
- Description base = content from `spec.md` (first 2-3 paragraphs) + later the full structured plan
- Issue Type = "Story" (default) or "Epic" (--epic)

## Step 3: Extract Quality Findings (if reports exist)

If `review-report-latest.md` or `bughunt-report-latest.md` exists in the track directory:

### From `bughunt-report-latest.md`

1. Parse findings by severity (Critical, High, Medium, Low).
2. Extract all sections for each bug: Location, Confidence, Code Evidence, Data Flow Trace, Issue, Impact, Verification Done, Why Not a False Positive, Fix, Regression Test.
3. Group by severity for the export.

### From `review-report-latest.md`

1. Parse findings from review report stages — Stage 1: Automated Validation (Architecture Conformance, Dead Code, Dependency Cycles, Security Scan, Performance), Stage 2: Spec Compliance, Stage 3: Code Quality (Architecture, Error Handling, Testing, Maintainability).
2. Extract for each finding: Severity (Critical ✗ / Warning ⚠), Category, Location, Issue, Risk/Impact, Fix.
3. Group by severity for the export.

**Critical/High findings** should be highlighted — consider suggesting additional stories or tasks to address them before the track is complete.

## Step 4: Generate the Export File

```bash
TIMESTAMP=$(date +%Y-%m-%dT%H%M)
EXPORT_FILE="draft/tracks/<track_id>/jira-export-${TIMESTAMP}.md"
SYMLINK="draft/tracks/<track_id>/jira-export-latest.md"
```

Create the file and the `latest` symlink.

### 4.1 Write Frontmatter + Header
Use the standard YAML frontmatter.
Add a `mode: default` or `mode: epic` field.

Write a clean summary table.

### 4.2 Write Root Issue Section

**Jira Content Rule:** Keep the description **minimal and focused**. Use short paragraphs. Do not dump full plans or verbose reasoning. Structured phases/tasks must be compact.

**Always start with:**

```markdown
## Root Issue

**Summary:** [Track Title]
**Issue Type:** Story          # or Epic when --epic
**Labels:** draft
**Description:**
{noformat}
[First 2-3 paragraphs from spec.md]

## Plan
```

Then render the plan content **concisely**:

- In **default mode**: Render **all** phases as `### Phase X: Name` headings, with Goal, Verification, and a compact task checklist under each.
- In **--epic mode**: If this is the root Epic section, put a short overview only.

Include the Draft signature at the bottom of the description.

### 4.3 Write Story Sections (only in --epic mode)

**Jira Content Rule:** Keep every Story description **short and scannable**. Use compact headings and minimal text.

If `mode: epic`:
- Emit 1 to 3 `## Story N: [Short Title]` blocks (using the grouping decided in Step 2).
- Under each Story, put the phases assigned to it as `### Phase ...` + **compact** task checklists.
- Each Story gets its share of the total story points (or put the total on the first one — simple is fine).

### 4.4 Write Bug Issues Section (always)

Use the existing high-quality bug export format from `bughunt-report-latest.md`.
These will become real Bug issues linked to the root (Epic or the main Story).

### 4.5 Final Notes in the Export
Add at the top:

> Default = 1 Story. Use `--epic` for 1 Epic + 1-3 Stories.

Update the symlink.

## Step 5: Report

```
Jira Preview Generated

Track:   [track_id] - [title]
Mapping: [story-rooted | epic-rooted]   (phases: N)
Export:  draft/tracks/<id>/jira-export-<timestamp>.md
Symlink: draft/tracks/<id>/jira-export-latest.md

Summary:
- 1 root issue ({Story | Epic})
- N mid-level issues ({Tasks | Stories})
- M leaf issues (Sub-tasks)
- P total story points
- B bugs (from bughunt-report-latest.md)

Breakdown:
- Phase 1: [name] - X pts, Y tasks
- Phase 2: [name] - X pts, Y tasks
- ...

Bugs (if bughunt-report-latest.md exists):
- X critical bugs
- Y high bugs
- Z medium/low bugs

Next steps:
1. Review and edit the export via jira-export-latest.md (adjust points, descriptions, leaf issues, bug priorities)
2. Run `/draft:jira create` to create issues in Jira
```

## Error Handling (preview)

**plan.md has no phases:**
- Tell user: "No phases found in plan.md. Run `/draft:new-track` to generate a proper plan."

**spec.md missing:**
- Use `plan.md` overview for root-issue description.
- Warn: "spec.md not found, using plan overview for root-issue description."

**jira-export-latest.md already exists:**
- Check if the target file has been manually modified (user-added content not matching generated patterns — edited descriptions, added rows, changed story points from generated values).
- If modifications detected, prompt: "Existing jira-export appears to have manual edits. Overwrite? [y/N]"
- If unmodified, proceed with regeneration (new timestamped file + updated symlink).

**Phase has no tasks:**
- Create mid-level issue with 1 story point.
- Add note: "No leaf issues defined for this phase."

---

# Subcommand: create

Create Jira issues from `jira-export-latest.md` using MCP-Jira. If no export file exists, auto-generates one first by running the `preview` subcommand.

## Red Flags — STOP if you're:

- Creating Jira issues without reviewing `jira-export-latest.md` first (run `/draft:jira preview`)
- Proceeding when MCP-Jira is not configured
- Creating duplicate issues (check if jira-export-latest.md already has Jira keys)
- Not verifying the target Jira project before creation
- Skipping the export file update after issue creation

**Preview before you create. Never create duplicates.**

**Default = 1 Story only.** Use `--epic` when you want an Epic + 1–3 Stories. We never create Jira Tasks or Sub-tasks.

---

## Step 1: Load Context

1. Capture git context (commands above).
2. Find the active track from `draft/tracks.md`. If a track ID is provided in `$ARGUMENTS`, use that.
3. Check for `draft/tracks/<track_id>/jira-export-latest.md`.

If no track found: tell user "No track found. Run `/draft:new-track` to create one, or specify track ID."

## Step 2: Ensure Export Exists

**If `jira-export-latest.md` exists:** read and parse it (follow the symlink to the timestamped file). Proceed to Step 3.

**If missing:** inform user "No jira-export-latest.md found. Generating preview first..." then execute the `preview` subcommand. Proceed to Step 3.

## Step 3: Check MCP-Jira Availability

Detect MCP-Jira tools. Known tool name variants: `mcp_jira_create_issue`, `jira_createIssue`, `create_jira_issue`, `jira-create-issue`. Use whichever is available.

If unavailable:

```
MCP-Jira not configured.

To create issues:
1. Configure MCP-Jira server in your settings
2. Run `/draft:jira create` again

Or manually import from:
  draft/tracks/<id>/jira-export-latest.md
```

Stop execution.

## Step 4: Parse Export File (Export Format)

Read the `mode` field from frontmatter:
- `default` → expect 1 root Story
- `epic`   → expect 1 Epic + 1–3 Stories

### Root Issue(s)
- Parse the `## Root Issue` (and any `## Story N:` sections if mode=epic).
- For each Story section: Summary, Description (which now contains the phases and task checklists), story points if present.

### Bug Issues
Parse the `## Bug Issues` section completely (same as before). These are always created as separate Bug issues.

**Important:** There are no longer "Mid-Level" or "Leaf Issues" tables that become separate Jira Tasks/Sub-tasks. All work items live inside the Story description(s).

## Step 4b: Resolve Jira Configuration

Read `draft/workflow.md` → `## Jira` section. Required fields and behavior:

| Field | Required? | Behavior if missing |
|-------|-----------|---------------------|
| Project Key | Yes | Prompt user; append to `## Jira` section |
| Integration | No | Defaults to `jira-mcp` |
| Team | No | Skip — not applied to issues |
| Component | No | Skip |
| Swimlane | No | Skip |
| Assignee Display Name | No | Skip |

When prompting for a missing field, append to `draft/workflow.md`:

```markdown
## Jira

Project Key: <KEY>
Integration: jira-mcp
Team: <team-name>
Component: <component-name>
Swimlane: <swimlane-name>
Assignee Display Name: <assignee-name>
```

### Validate Project Key

Before creating issues, attempt to fetch project metadata via MCP to verify the project key exists:

```
MCP call: get_project (or equivalent)
- project: [project key]
```

If invalid: "Jira project '[KEY]' not found. Verify the project key and try again." Stop execution.

### Resolve Assignee

If `Assignee Display Name` is provided, resolve to an account ID via MCP user search (e.g., `find_users(query=<display_name>)`). Cache the resolved ID for the session. If resolution fails, warn and create issues unassigned rather than failing.

## Step 5: Create Issues via MCP

**Pin the symlink target:** At the start of this step, resolve the symlink to its actual timestamped file path (e.g., via `readlink -f jira-export-latest.md`). Use the resolved path for all subsequent writes to prevent data loss if the symlink is updated mid-run.

**Incremental persistence:** After creating each issue, immediately update the corresponding entry in the export file with the Jira key. This ensures re-runs can skip already-created items even if the process fails mid-way.

**Note:** Some Jira configurations do not allow setting status during creation. If status setting fails, create in default status and log a warning.

### Shared field defaults

Apply these to every `create_issue` call (omit any that resolved to empty in Step 4b):

```
- project: [Project Key]
- labels: ["draft"]
- component: [Component if set]
- assignee: [Resolved account ID if set]
- custom_field_swimlane: [Swimlane if set]   # field ID is Jira-config specific
- custom_field_team: [Team if set]         # field ID is Jira-config specific
```

> Swimlane and Team are often custom fields. If your Jira project uses different field IDs, configure your MCP server's field mapping. Unknown fields will be rejected — log the rejection and continue without them.

### 5a. Create Root Issue(s)

- If mode = default: Create **1 Story**.
- If mode = epic: Create **1 Epic**, then create the 1–3 Stories (using the sections from the export file) and link them to the Epic.

For each Story/Epic:
**Jira Content Rule (strict):** The description sent to Jira must be concise. Use short summaries and compact structured sections only. Do not include long reasoning or exhaustive lists.

```
MCP call: create_issue
- issue_type: Story or Epic
- summary: ...
- description: [concise content — phases as compact sections, tasks as short checklists]
+ shared field defaults
```
Capture the keys.

### 5b. Create Bug Issues (from Bug Hunt Report)

For every bug parsed in Step 4, create a real **Bug** issue:

```
MCP call: create_issue
- issue_type: Bug
- summary: ...
- description: [full bughunt evidence]
- parent / epic_link: [link to the root Story or Epic]
- priority: [from severity]
+ shared field defaults
```

**Detailed work lives inside the root issue description(s) by default.** All detailed work lives inside the Story descriptions.

## Step 6: Finalize Tracking

Export file has already been updated incrementally during Step 5. Now update `plan.md` with the Jira keys:

```markdown
## Phase 1: Setup [PROJ-124]
...
- [x] **Task 1.1:** Extract logging utilities [PROJ-125]
- [x] **Task 1.2:** Extract security utilities [PROJ-126]
```

Set export file status to Created (via `jira-export-latest.md`):

```markdown
**Status:** Created
**Root Key:** PROJ-123
```

## Step 7: Report (new simplified format)

```
Jira Issues Created

Track:   [track_id] - [title]
Project: [PROJ]
Mode:    {default → 1 Story | --epic → 1 Epic + 1-3 Stories}

Created:
- {Story | Epic}: PROJ-123 - [Track title]
  (All phases and tasks are inside the Story description)

Bugs (from Bug Hunt) — always created as separate issues:
- Bug: PROJ-131 - [Critical] Correctness: Off-by-one error in pagination   (linked to PROJ-123)
- Bug: PROJ-132 - [High] ...

Total: 1 root issue + B bugs
Label: "draft" applied to all issues

Updated:
- plan.md (added root Jira key)
- jira-export-latest.md (marked as created)
```

## Error Handling (create)

**MCP call fails:**
```
Failed to create [issue type]: [error message]

Partial creation:
- {Story | Epic}: PROJ-123 (created)
- Mid-level 1: PROJ-124 (created)
  - Leaf 1.1: PROJ-125 (created)
  - Leaf 1.2: FAILED - [error]
- Mid-level 2: (skipped)

Fix the issue and run `/draft:jira create` again.
Already-created issues will be detected by keys in jira-export-latest.md.
```

**Export has existing keys:** skip items that already have keys; only create items without keys. Report "Skipped Mid-level 1 (already exists: PROJ-124)". Still create leaves if mid-level exists but leaves don't have keys.

**Project not configured:** see Step 4b.

**plan.md phases don't match export:** warn "Export has N mid-level issues but plan has M phases. Proceeding with export structure." Create based on export.


---

# Subcommand: review

See [review.md](review.md) for the full epic/story/bug/sub-task qualification pipeline. The router delegates to that file when the user invokes `/draft:jira review <JIRA_ID>`.

The review subcommand:
- Accepts any Jira issue ID (epic, story, bug, sub-task) and adapts its depth to the issue type.
- Runs a 7-phase pipeline: prerequisites → epic/story collection → document/test-plan synthesis → code change collection (Gerrit/GitHub/GitLab) → context synthesis → quality analysis (deep-review + bughunt + coverage) → test gap analysis → report.
- Produces `draft/jira-review/<JIRA_ID>/qualification-report.md` and (if gaps exist) `remediation-plan.md`.
- Verdict: QUALIFIED / PARTIALLY QUALIFIED / NOT QUALIFIED.
