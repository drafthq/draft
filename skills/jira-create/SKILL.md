---
name: jira-create
description: "Create Jira issues from jira-export-latest.md via MCP. Auto-generates export if missing. Use when the user asks to 'create Jira issues', 'push to Jira', 'sync track to Jira', or says 'file these as Jira tickets'."
---

# Create Jira Issues from Export

Create Jira epic, stories, and sub-tasks from `jira-export-latest.md` using MCP-Jira. If no export file exists, auto-generates one first.

## Red Flags - STOP if you're:

- Creating Jira issues without reviewing `jira-export-latest.md` first (run `/draft:jira-preview`)
- Proceeding when MCP-Jira is not configured
- Creating duplicate issues (check if jira-export-latest.md already has Jira keys)
- Not verifying the target Jira project before creation
- Skipping the export file update after issue creation

**Preview before you create. Never create duplicates.**

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
4. Check for `draft/tracks/<track_id>/jira-export-latest.md`

If no track found:
- Tell user: "No track found. Run `/draft:new-track` to create one, or specify track ID."

## Step 2: Ensure Export Exists

**If `jira-export-latest.md` exists:**
- Read and parse the export file (follows symlink to timestamped file)
- Proceed to Step 3

**If `jira-export-latest.md` missing:**
- Inform user: "No jira-export-latest.md found. Generating preview first..."
- Execute `/draft:jira-preview` logic to generate it
- Proceed to Step 3

## Step 3: Check MCP-Jira Availability

Attempt to detect MCP-Jira tools:
1. List available MCP tools and search for Jira-related ones. Known tool name variants: `mcp_jira_create_issue`, `jira_createIssue`, `create_jira_issue`, `jira-create-issue`. Use whichever is available.
2. If unavailable:
   ```
   MCP-Jira not configured.

   To create issues:
   1. Configure MCP-Jira server in your settings
   2. Run `/draft:jira-create` again

   Or manually import from:
     draft/tracks/<id>/jira-export-latest.md
   ```
   - Stop execution

## Step 4: Parse Export File

Extract from `jira-export-latest.md`:

### Epic
- Summary (from `**Summary:**` line)
- Description (from `{noformat}` block)
- Issue Type: Epic

### Stories
For each `## Story N:` section:
- Summary
- Story Points (from `**Story Points:**` line)
- Description (from `{noformat}` block)

### Sub-tasks
For each row in `### Sub-tasks` table:
- Task number (e.g., 1.1, 1.2)
- Summary
- Status (To Do, Done, In Progress, Blocked)

### Quality Findings (if present)
If export contains `## Quality Reports` section:
- Parse validation findings table (severity, category, location, issue, risk/impact, fix)
- Parse bughunt bug issues with all sections (location, confidence, code evidence, data flow trace, issue, impact, verification done, why not a false positive, fix, regression test)
- Extract all fields for each finding to populate Jira issue descriptions

## Step 4b: Resolve Project Key

Read `draft/workflow.md` and look for a `## Jira` section containing `Project Key: <KEY>`.

- **If found:** Use that key.
- **If not found:** Prompt the user: "No Jira project key configured. Enter your Jira project key (e.g., PROJ):"
  After the user provides the key, append the following to `draft/workflow.md`:
  ```markdown
  ## Jira

  Project Key: <KEY>
  ```
  This persists the key for all future `/draft:jira-create` and `/draft:jira-preview` invocations.

### Validate Project Key

Before creating issues, attempt to fetch project metadata via MCP to verify the project key exists. Fail fast with a clear error if invalid:

```
MCP call: get_project (or equivalent)
- project: [project key]
```

If the project key is invalid or not found:
- Error: "Jira project '[KEY]' not found. Verify the project key and try again."
- Stop execution.

## Step 5: Create Issues via MCP

**Pin the symlink target:** At the start of this step, resolve the symlink to its actual timestamped file path (e.g., via `readlink -f jira-export-latest.md`). Use the resolved path for all subsequent writes in this step to prevent data loss if the symlink is updated mid-run.

**Incremental persistence:** After creating each issue, immediately update the corresponding entry in the export file (via `jira-export-latest.md` symlink) with the Jira key. This ensures re-runs can skip already-created items even if the process fails mid-way.

**Note:** Some Jira configurations do not allow setting status during creation. If status setting fails, create in default status and log a warning.

### 5a. Create Epic
```
MCP call: create_issue
- project: [from config or prompt]
- issue_type: Epic
- summary: [Epic summary]
- description: [Epic description — MUST include signature, see jira-sync.md]
- labels: ["draft"]
```
- Capture epic key (e.g., PROJ-123)
- Report: "Created Epic: PROJ-123"

### 5b. Create Stories (one per phase)
For each story in export:
```
MCP call: create_issue
- project: [same as epic]
- issue_type: Story
- summary: [Story summary]
- description: [Story description — MUST include signature, see jira-sync.md]
- story_points: [from export]
- epic_link: [Epic key from step 5a]
- labels: ["draft"]
```
- Capture story key (e.g., PROJ-124)
- Report: "Created Story: PROJ-124 - Phase 1 (3 pts)"

### 5c. Create Sub-tasks (one per task)
For each sub-task under the story:
```
MCP call: create_issue
- project: [same as epic]
- issue_type: Sub-task
- parent: [Story key from step 5b]
- summary: [Task summary, e.g., "Task 1.1: Extract logging utilities"]
- status: [Map from export: To Do, In Progress, Done]
- labels: ["draft"]
```
- Capture sub-task key (e.g., PROJ-125)
- Report: "  - Sub-task: PROJ-125 - Task 1.1"

### 5d. Create Bug Issues (from Bug Hunt Report)

For **each bug** in the `## Bug Issues` section of jira-export-latest.md, create a separate Bug issue:

```
MCP call: create_issue
- project: [same as epic]
- issue_type: Bug
- summary: [Category] [Brief issue description]
- description: {noformat}
  h3. Location
  [file:line]

  h3. Confidence
  [CONFIRMED | HIGH | MEDIUM]

  h3. Code Evidence
  {code}
  [The actual problematic code snippet from bughunt-report-latest.md]
  {code}

  h3. Data Flow Trace
  [How data reaches this point: caller → caller → this function]

  h3. Issue
  [Full issue description]

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
- epic_link: [Epic key from step 5a]
- priority: [Map from severity]
- labels: ["draft"]
```

**Priority Mapping:**
| Severity | Jira Priority |
|----------|---------------|
| Critical | Highest |
| High | High |
| Medium | Medium |
| Low | Low |

- Capture bug key (e.g., PROJ-131)
- Report: "- Bug: PROJ-131 - [Critical] Correctness: Off-by-one error"

**All bugs from bughunt-report-latest.md get their own Bug issue.** They are linked to the Epic but separate from Stories (phases). This keeps implementation work (Stories/Sub-tasks) distinct from defect tracking (Bugs).

## Step 6: Finalize Tracking

The export file (via `jira-export-latest.md`) has already been updated incrementally during Step 5. Now update `plan.md` with the Jira keys:

1. **Update plan.md:**
   Add Jira keys to phase headers and tasks:
   ```markdown
   ## Phase 1: Setup [PROJ-124]
   ...
   - [x] **Task 1.1:** Extract logging utilities [PROJ-125]
   - [x] **Task 1.2:** Extract security utilities [PROJ-126]
   ```

2. **Set export file status to Created (in the timestamped file via jira-export-latest.md):**
   ```markdown
   **Status:** Created
   **Epic Key:** PROJ-123
   ```

## Step 7: Report

```
Jira Issues Created

Track: [track_id] - [title]
Project: [PROJ]

Created:
- Epic: PROJ-123 - [Track title]
- Story: PROJ-124 - Phase 1: [name] (3 pts)
  - Sub-task: PROJ-125 - Task 1.1
  - Sub-task: PROJ-126 - Task 1.2
  - Sub-task: PROJ-127 - Task 1.3
- Story: PROJ-128 - Phase 2: [name] (5 pts)
  - Sub-task: PROJ-129 - Task 2.1
  - Sub-task: PROJ-130 - Task 2.2
  [...]

Bugs (from Bug Hunt):
- Bug: PROJ-131 - [Critical] Correctness: Off-by-one error in pagination
- Bug: PROJ-132 - [High] Concurrency: Race condition in cache update
- Bug: PROJ-133 - [Medium] Security: Missing input validation

Total: 1 epic, N stories, M sub-tasks, B bugs, P story points
Label: 'draft' applied to all issues

Updated:
- plan.md (added issue keys to phases and tasks)
- jira-export-latest.md (marked as created with keys)
```

## Error Handling

**If MCP call fails:**
```
Failed to create [Epic/Story/Sub-task]: [error message]

Partial creation:
- Epic: PROJ-123 (created)
- Story 1: PROJ-124 (created)
  - Sub-task 1.1: PROJ-125 (created)
  - Sub-task 1.2: FAILED - [error]
- Story 2: (skipped)

Fix the issue and run `/draft:jira-create` again.
Already-created issues will be detected by keys in jira-export-latest.md.
```

**If export has existing keys:**
- Skip items that already have Jira keys
- Only create items without keys
- Report: "Skipped Story 1 (already exists: PROJ-124)"
- Still create sub-tasks if story exists but sub-tasks don't have keys

**If project not configured:**
- No `## Jira` section with `Project Key:` found in `draft/workflow.md`
- Prompt user: "No Jira project key configured. Enter your Jira project key (e.g., PROJ):"
- Save to `draft/workflow.md` under a `## Jira` section as `Project Key: <KEY>`

**If plan.md phases don't match export:**
- Warn: "Export has N stories but plan has M phases. Proceeding with export structure."
- Create based on export (user may have manually edited it)

**If sub-task creation not supported:**
- Some Jira configurations may not allow sub-tasks
- Fall back to adding tasks as checklist items in story description
- Warn: "Sub-tasks not supported in this project. Tasks added to story description."
