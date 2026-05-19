---
shared: jira:review
applies_to: /draft:jira review <JIRA_ID>
---

# Jira Review Pipeline

Qualify any Jira ticket — Epic, Story, Bug, or Sub-task — by running a mandatory pipeline: collect Jira data, fetch documents (design doc, test plan), gather code changes (Gerrit/GitHub/GitLab), audit quality via Draft commands, analyze test coverage, and produce a gap-analysis report with qualification verdict.

**Input:** `$ARGUMENTS` = Jira ID (e.g., `ENG-446236`, `PROJ-1234`).

**Invoked via:** `/draft:jira review <JIRA_ID>`. The router in [SKILL.md](SKILL.md) dispatches here.

## Red Flags — STOP if you're:

- Skipping Phase 0 prerequisites — MCP servers and `draft/` context are **required**.
- Treating `context.md` as the final report — it's intermediate input for quality analysis.
- Running `draft:deep-review` or `draft:bughunt` without `draft/` context existing.
- Reporting a verdict without synthesizing deep-review AND bughunt AND test gap findings.
- Ignoring unresolved stories or stories without code changes.
- Skipping document collection — design docs and test plans are qualification inputs.
- Generating the report via `draft:new-track` — write the report **directly** using the inline templates.
- Omitting YAML metadata headers from generated files — every file in `draft/` requires them.

---

## Issue Type Adaptation

This pipeline runs against any Jira ticket. Behavior adapts based on `issuetype` fetched in Phase 0:

| Issue Type | Phase 1 Fan-Out | Scope | Verdict Wording |
|------------|----------------|-------|-----------------|
| **Epic** | Yes — discover child stories via `Epic Link` / `parent` JQL | Multi-story qualification | "All code stories resolved" |
| **Story** | No — treat the story itself as the only "story" record | Single-story qualification | "Story resolved" |
| **Bug** | No — treat the bug itself as the only "story" record | Single-bug qualification (fix code changes, regression test) | "Bug resolved with regression test" |
| **Sub-task** | No — fetch parent for context, but qualify the sub-task scope | Sub-task qualification (note parent in report) | "Sub-task resolved" |
| **Task** (non-code) | No fan-out, no code analysis | Minimal report explaining qualification doesn't apply to non-code tasks | "Non-code task — qualification N/A" |

Throughout the rest of this document, "story" means "child story (epic mode) OR self (non-epic mode)" — the data model is the same.

---

## Pipeline Overview

```
Phase 0: Prerequisites & MCP Discovery       ← fail-fast, verify ALL MCPs, branch on issuetype
Phase 1: Issue & Story Collection             (Jira MCP) — fan-out for Epic, self-only otherwise
Phase 2: Document Collection & Synthesis      (WebFetch / configured MCPs)
Phase 3: Code Change Collection               (Gerrit/GitHub/GitLab MCP)
Phase 4: Context Synthesis                    (generate context.md)
Phase 5: Quality Analysis                     (draft:deep-review, draft:bughunt, draft:coverage)
Phase 6: Test Gap Analysis                    (TestRail + coverage + acceptance criteria)
Phase 7: Report Generation                    (qualification-report.md + remediation-plan.md)
```

Every phase is mandatory. Each consumes output from previous phases.

---

## File Metadata Convention

**Every generated file** under `draft/jira-review/<JIRA_ID>/` must include this YAML frontmatter:

```yaml
---
project: "{PROJECT_NAME}"
jira_id: "{JIRA_ID}"
issue_type: "{Epic | Story | Bug | Sub-task | Task}"
generated_by: "draft:jira:review"
generated_at: "{ISO_TIMESTAMP}"
phase: "{phase number that generated this file}"
mcp_servers:
  jira: true
  code_review: "{gerrit|github|gitlab|none}"
  testrail: {true|false}
previous_run: "{path to previous qualification-report.md or null}"
---
```

Git state (branch, commit, dirty, synced_to_commit) is read from `draft/metadata.json` — include a human-readable summary table in the report body but do not embed git fields in frontmatter.

Gather git metadata at pipeline start from `draft/metadata.json`:
```bash
python3 -c "import json; d=json.load(open('draft/metadata.json')); print(d['git']['branch'], d['git']['commit_short'], d['synced_to_commit'])"
```
Fallback if `draft/metadata.json` absent:
```bash
git branch --show-current
git rev-parse HEAD
git rev-parse --short HEAD
git log -1 --format="%ci"
git status --porcelain | head -1
```

---

## Phase 0: Prerequisites & MCP Discovery

### 0.1 Validate Input

Parse `$ARGUMENTS` as a Jira issue key:
- If matches `<PROJECT>-<NUMBER>` (e.g., `ENG-446236`, `PROJ-1234`): use as-is.
- If numeric-only (e.g., `446236`): prompt user for project prefix — do NOT assume.
- If invalid format: **STOP** with usage example.

### 0.2 MCP Server Verification

Verify all required servers upfront:

| Server | Required? | Verification Call | On Failure |
|--------|-----------|-------------------|------------|
| Jira MCP | **Required** | `get_issue(key=<JIRA_ID>, prune_mode="minimal")` | **STOP**: "Jira MCP required." |
| Code Review MCP | **Required** | See detection table below | **DEGRADE**: skip Phase 3 code review checks, cap verdict at PARTIALLY QUALIFIED |
| TestRail MCP | Optional | Check if TestRail tools exist in environment | **DEGRADE**: flag as gap |
| Other MCPs | Optional | Discovered per-URL in Phase 2 | **DEGRADE**: fall back to WebFetch |

**Code Review MCP Detection** — try in order, use the first that responds:

| MCP | Detection Call | Confirms |
|-----|---------------|----------|
| Gerrit MCP | `get_change_details("1", options=[])` — expect error, confirms server responds | Gerrit code review |
| GitHub MCP | Check for GitHub tools (e.g., `get_pull_request`) in environment | GitHub PRs |
| GitLab MCP | Check for GitLab tools (e.g., `get_merge_request`) in environment | GitLab MRs |

Record the detected Code Review MCP type — Phase 3 adapts its calls accordingly. If none detected, Phase 3 collects file changes from Jira comments and direct codebase access only (no review quality metrics).

### 0.3 Draft Context Verification

The working directory **must** have Draft context. `draft:deep-review`, `draft:bughunt`, and `draft:coverage` depend on it.

```
IF draft/.ai-context.md AND draft/architecture.md exist:
  → Use existing context
  → Read synced_to_commit from draft/metadata.json (fallback: draft/.ai-context.md YAML frontmatter for pre-migration installs)
  → Compare to current HEAD: git log --oneline <synced_to_commit>..HEAD -- . ':!draft/'
  → If >20 commits since sync: warn "Draft context may be stale — consider draft:init refresh"

ELSE:
  → Run draft:init to establish full project context
  → Wait for init to complete before proceeding — this is blocking
```

### 0.4 Issue Type Detection & Branching

After validating input and verifying MCPs, fetch the issue's type:

```
get_issue(key=<JIRA_ID>, prune_mode="minimal")
  → record issue_type, parent (for sub-tasks)
```

Branch based on `issue_type`:
- **Epic** → enable Phase 1.3 fan-out (collect child stories).
- **Story / Bug** → skip Phase 1.3 fan-out; treat self as the only story record.
- **Sub-task** → skip Phase 1.3 fan-out; treat self as the only story record; fetch parent for context.
- **Task** → if labels/description suggest non-code (documentation, design, config, process), produce minimal report at Phase 7 (skip code-analysis phases). Otherwise treat as Story.

Announce: "Reviewing {issue_type} `<JIRA_ID>` — {fan-out enabled | self-only scope}"

### 0.5 Check for Previous Runs

```bash
ls draft/jira-review/<JIRA_ID>/qualification-report.md 2>/dev/null
```

If a previous run exists:
- Note its `generated_at` timestamp for delta comparison in Phase 7.
- Do NOT delete — the new run overwrites.

### 0.6 Create Output Directory

```bash
mkdir -p draft/jira-review/<JIRA_ID>
```

Announce: "Starting Jira Review Pipeline for `<JIRA_ID>`"

---

## Phase 1: Issue & Story Collection

### 1.1 Issue Metadata

```
get_issue(key=<JIRA_ID>, prune_mode="full")
get_issue_description(issue_key=<JIRA_ID>)
get_issue_comments(issue_key=<JIRA_ID>, prune_mode="default")
```

From the full issue, extract and store: key, summary, status, assignee, priority, type, created, updated, labels, components, fix versions.

For **Sub-task** type, also fetch the parent:
```
get_issue(key=<PARENT_KEY>, prune_mode="minimal")
```
Record parent key and summary — included in the report for context, not qualified itself.

### 1.2 Extract Artifact Links

Scan issue description, custom fields, and comments for:

| Artifact | URL Patterns | Jira Field Names to Check |
|----------|-------------|---------------------------|
| Design Doc | `docs.google.com`, `confluence`, `sharepoint`, `notion`, `*.docx` attachments | "Design Doc Link", "Design Document", "Design Spec" |
| Test Plan | `testrail`, `confluence/test`, `testplan` | "Test Plan Link", "QA Plan", "Test Plan", "Validation Plan" |
| TestRail Results | TestRail URLs, embedded pass/fail data | "TestRail: Results", "Test Results", "QA Results" |

Also check:
- `get_linked_issues(issue_key=<JIRA_ID>)` for documentation-type tickets.
- Jira attachments (design docs uploaded directly to the issue).

For each artifact: record URL, type, and hold for Phase 2.

### 1.3 Story Discovery (Epic only)

**Skip this step for Story / Bug / Sub-task / Task** — the issue itself is the single "story" record. Proceed to 1.4 with `stories = [self]`.

For **Epic**:

```
get_issues(jql="\"Epic Link\" = <JIRA_ID>", max_results=100, prune_mode="default")
```

**Pagination:** If `truncated: true`, increase `max_results` or make follow-up calls. Do not silently drop stories.

**Fallbacks** (try in order, stop when results found):
1. `get_issues(jql="parent = <JIRA_ID>", max_results=100)` — Jira Cloud uses `parent` instead of `Epic Link`.
2. `get_linked_issues(issue_key=<JIRA_ID>, relationship_type="epic child")`.
3. `get_linked_issues(issue_key=<JIRA_ID>)` — all links, filter child/subtask types.

If all return zero: flag "no stories found", produce minimal report.

### 1.4 Story Enrichment

Per story (or per the single self-record for non-Epic):
```
get_issue(key=<STORY_ID>, prune_mode="default")
get_issue_comments(issue_key=<STORY_ID>, prune_mode="default")
```

Collect: key, summary, status, type, assignee, priority, created, updated, labels.
Extract from description: acceptance criteria (numbered list).
Extract from comments: code-review URLs / change IDs (see Phase 3.1 for patterns).
Extract from fields: "TestRail: Results" if present.

### 1.5 Sub-Task Collection

Per story, check for sub-tasks:
```
get_linked_issues(issue_key=<STORY_ID>, relationship_type="subtask")
```

Or parse the `subtasks` field from `get_issue(key=<STORY_ID>, prune_mode="full")`.

For each sub-task:
- Collect its code-review links from comments (same extraction as stories).
- Roll up sub-task code changes into the parent story's change set.
- Do NOT treat sub-tasks as independent stories for gap analysis.

### 1.6 Story Classification

| Classification | Criteria | Code Changes Expected? |
|----------------|----------|--------------------------|
| Code-deliverable | Default for Story/Bug types | Yes |
| Non-code | Type=Task AND (labels contain "documentation"/"design"/"config-only"/"process" OR description states no code change) | No |
| Excluded | Status ∈ {Won't Do, Duplicate, Won't Fix, Cancelled}; or explicitly moved to different epic | No — excluded from gap analysis |

### 1.7 Verify Resolution

Check each code-deliverable story status:

| Status Category | Statuses | Flag |
|-----------------|----------|------|
| Resolved | Resolved, Done, Closed | None — passing |
| In Progress | In Progress, In Review, In QA | "IN PROGRESS — partial implementation, verify code changes" |
| Unresolved | Open, New, To Do, Reopened, Backlog | "UNRESOLVED — gap" |
| Blocked | Blocked, Impediment | "BLOCKED — escalation needed" |

Additional flags:
- No description or acceptance criteria → "INCOMPLETE SPEC — gap".
- Code-deliverable + no code-review links in comments → "NO CODE CHANGES — verify in Phase 3".

---

## Phase 2: Document Collection & Synthesis

### 2.1 Design Document

**Access strategy** (try in order, stop on first success — local-first):

1. **Local Draft artifacts (preferred):** For each story, check whether the corresponding track has `draft/tracks/<track_id>/hld.md` (and `lld.md`). When present, treat these as the canonical design doc for that story. Story → track mapping comes from spec.md frontmatter `track_id` or from a comment on the Jira story linking to the track. Multiple stories can share one HLD.
2. Google Doc + Google Drive MCP available → use MCP.
3. Confluence page + Confluence MCP available → use MCP.
4. WebFetch with the URL.
5. Jira attachment → download via Jira MCP if supported.
6. All fail → record URL + "could not access" + flag as process gap.

**If content retrieved from local Draft artifacts**, synthesis pulls directly:
- §Background → Goals and scope.
- §High Level Design (Architecture, Key Design Decisions, Alternatives Considered) → Architecture / design decisions, key trade-offs.
- §Detailed Design → API changes.
- LLD §Data Model → data model changes.
- §Checklist → Non-functional requirements (Performance, Scale, Security, Resiliency, Multi-tenancy).
- §Approvals signed/unsigned → process compliance signal.

**If content retrieved from external doc**, synthesize and write to `draft/jira-review/<JIRA_ID>/design-doc-synthesis.md` (with metadata header):
- Goals and scope.
- Architecture / design decisions.
- API changes, data model changes.
- Key trade-offs and alternatives considered.
- Non-functional requirements (performance, security, scalability).

**Process gap signals** to flag:
- Track exists in `draft/tracks/` but no `hld.md` AND no external design doc — qualification gap.
- HLD exists but Approvals table fully unsigned — review-process gap (track was implemented without sign-off).
- HLD `synced_to_commit` is older than the latest merged code change for the track — drift gap (design and code diverged).

### 2.2 Test Plan & TestRail Data

**Test Plan document** — same access strategy as 2.1. Synthesize test strategy and coverage goals.

**TestRail integration** (if TestRail MCP available):
- Extract test suite/run IDs from: Test Plan URL path segments, Jira "TestRail: Results" field, or story-level TestRail references.
- Fetch: test case ID, title, status (passed/failed/blocked/untested), mapped story.
- Fetch: test run results, pass rate summary.

**If TestRail MCP not available:**
- WebFetch on TestRail URLs.
- Parse "TestRail: Results" Jira field for embedded data (pass/fail counts, test case references).

**Write to** `draft/jira-review/<JIRA_ID>/test-data-synthesis.md` (with metadata header):
- Total test cases with pass/fail/blocked/untested counts.
- Test cases mapped to specific stories.
- Stories without test cases (test gaps).

---

## Phase 3: Code Change Collection

### 3.1 Extract Code-Review Change IDs

From story and sub-task comments (Phase 1.4, 1.5), extract code-review identifiers. Patterns depend on the MCP detected in Phase 0.2:

**Gerrit patterns:**

| Pattern | Example | Extract |
|---------|---------|---------|
| Full Gerrit URL | `https://gerrit.example.com/c/project/+/12345` | `12345` |
| Legacy Gerrit URL | `https://gerrit.example.com/#/c/12345/` | `12345` |
| Short Gerrit URL | `https://gerrit.example.com/12345` | `12345` |
| Change-Id in text | `Change-Id: I8473b95a1f...` | `I8473b95a1f...` |
| Gerrit link markdown | `[Gerrit](https://gerrit.example.com/c/project/+/12345)` | `12345` |

**GitHub patterns:**

| Pattern | Example | Extract |
|---------|---------|---------|
| Full PR URL | `https://github.com/<org>/<repo>/pull/123` | `123` (with repo) |
| Short PR ref | `#123` (when issue references repo via Jira project mapping) | `123` |

**GitLab patterns:**

| Pattern | Example | Extract |
|---------|---------|---------|
| Full MR URL | `https://gitlab.com/<org>/<repo>/-/merge_requests/45` | `45` (with repo) |

**Extraction approach:** scan comment bodies for URLs containing the configured code-review host domain. Extract numeric IDs. Also scan for `Change-Id:` patterns in commit-formatted comments.

Group result: `{STORY_ID: [change_id_1, change_id_2, ...]}`. Include sub-task changes rolled up under the parent story.

### 3.2 Code-Review MCP Per Change

For each change ID (Gerrit example shown; adapt calls for GitHub/GitLab):

```
get_change_details(change_id, options=["ALL_REVISIONS", "MESSAGES", "REVIEWERS"])
  → status (NEW/MERGED/ABANDONED), owner, reviewers, labels, branch,
    insertions/deletions, patchset count (_number from revisions)

list_change_files(change_id, revision_id="current")
  → file paths, status (ADDED/MODIFIED/DELETED/RENAMED), lines_inserted, lines_deleted

get_commit_message(change_id, revision_id="current")
  → subject, body, author {name, email, date}, committer {name, email, date}

list_change_comments(change_id)
  → per-file comments with: message, author, unresolved (boolean), patch_set
```

For GitHub/GitLab the equivalents are `get_pull_request`, `list_pr_files`, `get_pr_commits`, `list_pr_review_comments` and analogous calls.

### 3.3 Verification Checks

Per code change, evaluate:

| Check | Pass | Fail (= gap) | Severity |
|-------|------|---------------|----------|
| Change status | MERGED | NEW → "not merged"; ABANDONED → "abandoned" | Critical |
| Code-Review approval | +2 (Gerrit) / Approved (GitHub/GitLab) | None, or -1/-2 / Changes Requested | High |
| Verified / CI label | +1 / Green | Missing or red | High |
| Unresolved comments | Zero | Count > 0 | Medium |
| Patchset count | Informational | >5 = risk signal (note, not auto-fail) | Low |

### 3.4 Consolidated Change Set

After all stories + sub-tasks processed:

- **Deduplicated file list** grouped by top-level module/directory, with per-file change status (ADDED/MODIFIED/DELETED).
- **All code changes** with story attribution (one change may map to multiple stories via sub-tasks).
- **Unique authors** and **unique reviewers**.
- **Review quality summary**: total changes, count MERGED with approval, count without approval, count with unresolved comments, average patchset count.
- **Scope metrics**: total files changed, total insertions, total deletions.
- **Test file classification**: classify every file in the change set as **test** or **production**:

  | Language | Test File Patterns |
  |----------|--------------------|
  | Go | `*_test.go` |
  | Python | `test_*.py`, `*_test.py`, files under `tests/` |
  | Java/Kotlin | `*Test.java`, `*Tests.java`, `*Spec.kt`, files under `src/test/` |
  | JavaScript/TypeScript | `*.test.ts`, `*.spec.ts`, `*.test.js`, `*.spec.js`, files under `__tests__/` |
  | C/C++ | `*_test.cc`, `*_test.cpp`, `*_unittest.cc`, files under `test/` or `tests/` |
  | Rust | `#[cfg(test)]` modules, files under `tests/` |
  | General | Files under directories named `test/`, `tests/`, `testing/`, `spec/` |

  Also check `draft/tech-stack.md` for project-specific test conventions that override defaults.

  Per story, record:
  - Count of production files changed.
  - Count of test files changed.
  - **Test file ratio**: test files / total files (0% = no tests shipped with code).

### 3.5 Issue-Level Changes (Epic mode only)

Extract code-review links from **issue-level comments** (Phase 1.1). These are changes referencing the epic directly, not a specific story. Reconcile with per-story results — flag any issue-level changes not attributed to a story.

### 3.6 No Changes for Code Story

If a code-deliverable story has **no code changes** (including sub-tasks):
- Check issue-level changes for commit messages mentioning the story ID.
- If still none: flag "implementation gap — no code changes found".

---

## Phase 4: Context Synthesis

Generate `draft/jira-review/<JIRA_ID>/context.md` (with metadata header) combining all data from Phases 1-3.

### Context Document Structure

```markdown
# Jira Review Context: <JIRA_ID> — <Summary>

## Pipeline Execution
| Field | Value |
|-------|-------|
| Qualification Date | <ISO timestamp> |
| Issue Type | <Epic | Story | Bug | Sub-task | Task> |
| Scope | <fan-out | self-only> |
| Git Branch | <branch> |
| Git Commit | <short SHA> |
| Jira MCP | Available |
| Code Review MCP | <gerrit|github|gitlab|none> |
| TestRail MCP | Available / Not Available |
| Previous Run | <timestamp or "First run"> |

## Issue Metadata
| Field | Value |
|-------|-------|
| Jira ID | <JIRA_ID> |
| Issue Type | <type> |
| Parent | <parent key + summary, if sub-task> |
| Summary | <summary> |
| Status | <status> |
| Assignee | <name> |
| Priority | <priority> |
| Created | <date> |
| Updated | <date> |
| Labels | <labels> |
| Components | <components> |

## Artifacts
| Artifact | URL | Access Method | Accessible | Synthesis File |
|----------|-----|---------------|------------|----------------|
| Design Doc | <URL or "Not found"> | <MCP name / WebFetch / N/A> | Yes / No | design-doc-synthesis.md |
| Test Plan | <URL or "Not found"> | <method> | Yes / No | test-data-synthesis.md |
| TestRail | <URL or field data> | <method> | Yes / No | test-data-synthesis.md |

## Design Document Synthesis
(Inline from design-doc-synthesis.md: goals, architecture, API changes, trade-offs.
 If not accessible: "Design doc not accessible — <URL>. Flagged as process gap.")

## Test Plan Summary
(Inline from test-data-synthesis.md: strategy, coverage goals.
 TestRail summary if available:)

| Metric | Count |
|--------|-------|
| Total Test Cases | <N> |
| Passed | <N> |
| Failed | <N> |
| Blocked | <N> |
| Untested | <N> |

## WH Analysis

### What — Goal and Scope
(What problem, what deliverable, what scope boundary — from description + design doc)

### Why — Motivation and Business Need
(Why needed, why now, business impact if not done — from description + comments)

### Who — People
| Role | Names |
|------|-------|
| Issue Owner | <name> |
| Story Assignees | <names> |
| Code Authors | <names from code review> |
| Code Reviewers | <names from code review> |

### When — Timeline
| Milestone | Date |
|-----------|------|
| Issue Created | <date> |
| First Story Resolved | <date> |
| Last Story Resolved | <date> |
| First Code Change Merged | <date> |
| Last Code Change Merged | <date> |

### Where — Codebase Impact
(Files grouped by module from consolidated change set:)
```
module_a/ (N files)
  - file1.cc (MODIFIED)
  - file2.h (ADDED)
module_b/ (N files)
  - file3.py (MODIFIED)
```

### How — Technical Approach
(Per-module: 2-3 sentences summarizing what the code changes do. Derived from commit
 subjects and design doc, not just "files were changed".)

## Stories Status
| # | Story ID | Summary | Type | Classification | Status | Assignee | Code Changes | Sub-Tasks | Tests | Resolved |
|----|----------|---------|------|----------------|--------|----------|--------------|-----------|-------|----------|
| 1 | <ID> | <summary> | Story | Code | Done | <name> | 3 | 1 | 5 | Yes |
| 2 | <ID> | <summary> | Bug | Code | In Progress | <name> | 1 | 0 | 0 | No |

**Totals**: <N> stories, <M> resolved, <K> in progress, <J> code-deliverable,
<L> with code changes, <P> with test cases

### Story Classification Summary
| Classification | Count | Description |
|----------------|-------|-------------|
| Code-deliverable | <N> | Stories/Bugs with expected code changes |
| Non-code | <N> | Tasks: documentation, design, config, process |
| Excluded | <N> | Won't Do, Duplicate, moved to other epic |

### Unresolved Stories
(Each unresolved code-deliverable story: ID, summary, current status, why it matters)

### In Progress Stories
(Each in-progress code-deliverable story: ID, summary, code change status, what remains)

### Stories Without Code Changes
(Each code-deliverable story with no code changes. Note: expected for non-code, gap for code)

### Stories Without Test Cases
(Stories with no TestRail test cases mapped)
```

### Per-Story Detail

For each story, include under `## Per-Story Detail`:

```markdown
### <STORY_ID>: <Summary>

#### Story Info
| Field | Value |
|-------|-------|
| Type | Story / Bug / Task |
| Classification | Code / Non-code / Excluded |
| Status | <status> |
| Assignee | <name> |
| Priority | <priority> |
| Created | <date> |
| Updated | <date> |
| Sub-Tasks | <count> |

#### Acceptance Criteria
1. <criterion from description>
2. <criterion from description>

#### Story Learnings
```

### Learnings Narrative Per Story

For **bug-fix stories** (5 sections):
1. **What was the issue** — symptoms, scope, observables, impact. Generalize using patterns rather than raw ticket IDs.
2. **RCA** — primary cause, contributing factors. Incorporate code-review insights from `list_change_comments` if relevant.
3. **Resolution** — fix type, change ID, branch, merge status, who reviewed. Reference patchset count.
4. **Journey** — timeline: triage → investigation → fix → review iterations → merge → verification.
5. **Learnings** — technical, operational, process takeaways. Test gaps.

For **feature stories** (5 sections):
1. **What was the requirement** — goal, user need, scope, acceptance criteria. Cross-reference design doc synthesis.
2. **Technical approach** — design decisions, patterns, integration points.
3. **Implementation** — key files from `list_change_files`, change scope (insertions/deletions).
4. **Journey** — dev timeline, patchset iteration count, review feedback themes, testing.
5. **Learnings** — reusable patterns, pitfalls, test coverage observations.

**Data sources:**

| Section | Primary | Supporting |
|---------|---------|-----------|
| What/requirement | `get_issue_description` | Design doc synthesis |
| RCA/approach | Pinned Jira comments, `get_linked_issues` | `list_change_comments` |
| Resolution/implementation | `list_change_files`, `get_commit_message` | Jira resolution field |
| Journey | Jira comments + code-review patchset history | TestRail execution timeline |
| Learnings | Derived from all above | Reviewer feedback, test gaps |

### Per-Story Detail (continued)

```markdown
#### Story Code Changes
| # | Change ID | Subject | Author | Branch | Status | Approval | Files | +Lines | -Lines |
|----|-----------|---------|--------|--------|--------|----------|-------|--------|--------|
| 1 | <ID> | <subject> | <name> | <branch> | MERGED | +2 | 5 | 120 | 30 |

Files changed:
  - path/to/file (MODIFIED, +10 -5)
  - path/to/new_file (ADDED, +50)

Review quality:
  - Reviewers: <names>
  - Unresolved comments: <count>
  - Patchset iterations: <count>

#### Story Sub-Task Changes
(If sub-tasks exist: same code change table, rolled up from sub-tasks)

#### Story Test Cases (if TestRail available)
| Test Case ID | Title | Status | Last Run |
|-------------|-------|--------|----------|
| TC-1001 | <title> | Passed | <date> |
```

### Consolidated Changes

```markdown
## Consolidated Changes

### All Files Changed
| Module | File | Status | Stories | Insertions | Deletions |
|--------|------|--------|---------|------------|-----------|
| module_a | file1.cc | MODIFIED | ENG-111, ENG-222 | 45 | 12 |

### All Code Changes (Chronological)
| # | Change ID | Subject | Author | Date | Story | Branch | Status | Approval | Link |
|----|-----------|---------|--------|------|-------|--------|--------|----------|------|

### All Authors and Reviewers
| Role | Name | Story Count | Change Count |
|------|------|-------------|-------------|

### Review Quality Summary
| Metric | Value |
|--------|-------|
| Total Code Changes | <N> |
| MERGED with Approval | <N> |
| Without Approval | <N> |
| With Unresolved Comments | <N> |
| Average Patchset Count | <N> |

## Preliminary Gap Indicators
| Gap Type | Count | IDs |
|----------|-------|-----|
| Unresolved code stories | <N> | <IDs> |
| In Progress code stories | <N> | <IDs> |
| Code stories without code changes | <N> | <IDs> |
| Code changes NOT MERGED | <N> | <change IDs> |
| Changes without approval | <N> | <change IDs> |
| Changes with unresolved comments | <N> | <change IDs> |
| Missing design doc | Yes/No | |
| Missing test plan | Yes/No | |
| Stories without test cases | <N> | <IDs> |
```

---

## Phase 5: Quality Analysis

All three commands use the `draft/` context established in Phase 0.

### 5.1 /draft:deep-review

Run per changed module. Module selection follows deep-review's own priority:
1. Check `draft/.ai-context.md` for `## Modules` or `## Module Catalog` — match against modules from the consolidated change set.
2. If no module catalog: use top-level directories from the consolidated file list.
3. Run once per affected module:

```
draft:deep-review <module-name-or-directory>
```

**Output**: `draft/deep-review-reports/<module-name>.md` (deep-review manages its own output path).

**Reads**: `draft/.ai-context.md`, `draft/product.md`, `draft/tech-stack.md`.

Produces per-module: ACID compliance, resilience, observability, configuration assessment with per-finding severity and file:line references.

### 5.2 /draft:bughunt

Run scoped to specific file paths from the consolidated change set.

**Invocation protocol:** bughunt prompts for scope type when invoked. Pre-answer the prompt:
1. Select **"Specific paths"** when bughunt asks for scope.
2. Supply the consolidated file list from Phase 3.4 as the target paths.
3. If bughunt asks for track context, respond: "No track — running as part of /draft:jira review pipeline".

```
/draft:bughunt
→ (scope prompt) → "Specific paths"
→ (paths prompt) → <consolidated file list from Phase 3.4>
```

**Output**: `draft/bughunt-report-latest.md` (bughunt manages its own output path).

**Reads**: `draft/.ai-context.md`, `draft/tech-stack.md`, `draft/product.md`, `draft/workflow.md`.

Produces: severity-ranked bug list (Critical/High/Medium/Low) with code evidence, data flow traces, and optional regression tests.

### 5.3 /draft:coverage

Run with explicit path argument per changed module:

```
/draft:coverage <module-directory>
```

Coverage reads `coverage_target` from `draft/workflow.md` (default: **95%** if absent).

**Track requirement workaround:** `/draft:coverage` expects an active track and writes to `draft/tracks/<id>/coverage-report.md`. Since `jira review` does not create a track:
1. Coverage will look for an active track from `draft/tracks.md` — if none exists, it will warn.
2. Capture coverage output directly from the tool's console/response text.
3. Record the coverage percentages, gap analysis, and uncovered files in the review context document (Phase 4).
4. Reference coverage results by captured output, not by file path.

**If no test framework is detected:** coverage will report this. Record "No test framework detected" in the report — this itself is a gap finding.

### 5.4 Partial Completion Handling

If any Phase 5 command fails:
- Record which commands completed and which failed.
- Continue with remaining commands — do NOT abort the pipeline.
- In Phase 7, note failed analyses: "draft:coverage — FAILED: no test framework detected" etc.
- Verdict must account for missing data: if bughunt failed, verdict cannot be QUALIFIED (insufficient evidence).

---

## Phase 6: Test Gap Analysis & Test Suggestions

Testing is a **first-class qualification signal**. This phase combines codebase test discovery, coverage analysis, and bughunt findings to identify every gap — then produces actionable, framework-specific test suggestions.

### 6.1 Codebase Test Discovery

For each changed **production** file from the consolidated change set (Phase 3.4):

1. **Find companion test files** in the codebase using conventions from `draft/tech-stack.md` and the patterns in Phase 3.4.
   - Example: `src/handler.go` → look for `src/handler_test.go`.
   - Example: `src/utils/parser.ts` → look for `src/utils/parser.test.ts`, `src/utils/parser.spec.ts`, `src/utils/__tests__/parser.test.ts`.

2. **If companion test file exists:** read it. Record:
   - Number of test functions/cases.
   - What behaviors are tested (function names, describe blocks, test names).
   - Whether changed functions/methods have corresponding test cases.
   - Last modified date (via code-review or git log) — stale tests are a signal.

3. **If no companion test file exists:** flag `"NO TEST FILE — <production_file>"`.

4. **Cross-module test files:** some tests live in separate directories (e.g., `integration_tests/`, `e2e/`). Scan for test files that import or reference changed production files.

Build a **test inventory** per story:

| Production File | Companion Test File | Test Functions | Changed Functions Covered | Gap |
|----------------|--------------------|--------------:|:-------------------------:|-----|
| src/handler.go | src/handler_test.go | 8 | 3/5 | 2 uncovered |
| src/parser.go | — | — | — | No test file |

### 6.2 Test Presence in Code Changes

From Phase 3.4 test file classification:

| Signal | Meaning |
|--------|---------|
| Story ships test files + production files | Developer tested their changes — positive |
| Story ships only production files, companion tests exist unchanged | Developer modified code but didn't update tests — **stale test risk** |
| Story ships only production files, no companion tests in codebase | No tests at all — **critical gap** |
| Story ships only test files | Test-only change (backfill, refactor) — positive signal |

Per story, assign a **Test Shipping Status**:
- **TESTED**: code changes include test files covering the production changes.
- **PARTIALLY TESTED**: some production files have companion tests (unchanged or in different changes).
- **UNTESTED**: no test files shipped, no companion tests in codebase.
- **TEST BACKFILL**: test-only changes (positive).

### 6.3 Acceptance Criteria → Test Mapping

Per code-deliverable story:
1. Extract acceptance criteria (from Phase 1.4).
2. Map to **codebase tests** discovered in 6.1 (test function names that exercise the criterion).
3. Map to **TestRail test cases** (from Phase 2.2, if available) — if TestRail unavailable, leave column blank and weight codebase tests + coverage higher.
4. Map to **bughunt findings** that exercise the same code path.
5. Identify criteria with **no test coverage at all** — these are the highest-priority gaps.

**Without TestRail:** AC → test mapping relies entirely on codebase test discovery (6.1) and coverage data (5.3). This is still valid — many enterprise teams have comprehensive unit/integration tests that never appear in TestRail. The TestRail column becomes N/A in all tables.

| # | Story | Acceptance Criterion | Codebase Tests | TestRail Cases | Bughunt Overlap | Status |
|----|-------|---------------------|:--------------:|:--------------:|:---------------:|--------|
| 1 | ENG-111 | "User can reset password" | 2 tests | TC-1001 | — | Covered |
| 2 | ENG-111 | "Email sent within 30s" | 0 | — | — | **GAP** |

### 6.4 Code Coverage Gap Identification

From draft:coverage (Phase 5.3) and codebase discovery (6.1):

1. **Changed files below coverage target** (from `draft/workflow.md`, default 95%).
2. **Newly ADDED files** (status: ADDED) with zero or no test coverage.
3. **Critical modules** flagged by deep-review that also have low coverage — highest severity.
4. **Production files with no companion test file** at all in the codebase (from 6.1).
5. **Changed functions without test coverage** — map specific function/method changes (from code-review diff) to test function inventory.

### 6.5 Regression Tests from Bughunt Findings

For **each Critical and High severity finding** from draft:bughunt (Phase 5.2):

1. Identify the vulnerable code path and entry points.
2. Determine what input/state triggers the bug.
3. Design a regression test that:
   - Reproduces the exact scenario that would trigger the bug.
   - Asserts the correct behavior after the fix.
   - Includes negative cases (malformed input, boundary values, race conditions).

This ensures bugs found by bughunt don't ship — and if they're already in code, they get caught on the next change.

### 6.6 Test Suggestions

Read `draft/tech-stack.md` for: test framework, assertion library, mocking patterns, test directory conventions.
Read `draft/workflow.md` for: TDD preferences, coverage targets, test execution commands.
Read `draft/.ai-context.md` for: existing test patterns, module boundaries, data flows.

Generate **framework-specific, copy-pasteable test suggestions** for every identified gap.

#### Unit Tests — for uncovered production code

For each production file/function without adequate test coverage:

```
Test:     <descriptive_test_function_name>
Type:     Unit
Priority: Critical / High / Medium
Story:    <STORY_ID>
Gap:      <what's untested — specific function, branch, error path>
File:     <target test file path — companion location>
Tests:    <what behavior/scenario this validates>
Why:      <which gap from 6.1/6.3/6.4 this closes>

Sketch:
```<language>
<actual test function using project's framework, assertion library, and conventions>
<include setup/teardown if needed>
<test the specific changed function with meaningful assertions>
```
```

**Focus areas** (in priority order):
1. Changed functions with zero test coverage.
2. Error handling paths — every error return/throw in changed code needs a test.
3. Boundary conditions — nil/null, empty, max values, off-by-one.
4. Concurrency paths flagged by deep-review (race conditions, deadlocks).
5. Input validation — changed code that processes external input.

#### Regression Tests — for bughunt findings

For each Critical/High bughunt finding (from 6.5):

```
Test:     regression_<bug_description>
Type:     Regression
Priority: Critical (matches bughunt severity)
Story:    <STORY_ID>
Bug:      <bughunt finding reference>
File:     <target test file path>
Tests:    <reproduces the exact bug scenario>
Why:      Prevents regression of <bughunt finding>

Sketch:
```<language>
<test that sets up the vulnerable state>
<triggers the code path that had the bug>
<asserts correct behavior — the bug does NOT manifest>
```
```

#### Integration Tests — for cross-module changes

When code changes span multiple modules (from Phase 3.4 consolidated change set):

```
Test:     integration_<module_a>_<module_b>_<scenario>
Type:     Integration
Priority: High
Stories:  <STORY_IDs that touch both modules>
File:     <integration test directory>/test_<scenario>.<ext>
Tests:    <interaction between modules — data flow, API contract, event handling>
Why:      Cross-module changes risk breaking integration points

Sketch:
```<language>
<set up both modules with test fixtures>
<exercise the integration point changed by the issue>
<assert end-to-end behavior across module boundary>
```
```

**Trigger conditions** for integration test suggestions:
- Stories whose code changes touch files in 2+ modules.
- Changes to interface/API boundary files identified in `draft/.ai-context.md`.
- Data model changes that propagate across modules.
- Event/message producer-consumer pairs where both sides changed.

### 6.7 Test Adequacy Score

Compute a composite score from all discovery and analysis:

| Metric | Value | Weight | Score |
|--------|-------|--------|-------|
| Stories with test files in code changes | X/Y | 25% | |
| Production files with companion test files | X/Y | 20% | |
| Acceptance criteria with test coverage | X/Y | 20% | |
| Code coverage vs target | X% vs Y% | 15% | |
| Bughunt Critical/High with regression tests | X/Y | 10% | |
| New files (ADDED) with test coverage | X/Y | 10% | |

**Test Adequacy = weighted sum (0-100%)**

| Rating | Range | Meaning |
|--------|-------|---------|
| **Strong** | ≥80% | Tests ship with code, high coverage, gaps are minor |
| **Adequate** | 60-79% | Most code tested, some gaps in new/changed code |
| **Weak** | 40-59% | Significant test gaps — many stories without tests |
| **Critical Gap** | <40% | Insufficient testing — blocks qualification |

---

## Phase 7: Report Generation

Generate outputs **directly** to `draft/jira-review/<JIRA_ID>/`. Do NOT use `draft:new-track`.

### 7.1 Verdict Logic

The verdict criteria are the same regardless of issue type — for single-story scopes (Story/Bug/Sub-task) the "all code stories" criterion collapses to "the single story is resolved" (N=1).

| Verdict | Criteria |
|---------|----------|
| **QUALIFIED** | All code stories ∈ {Resolved, Done, Closed} + all code changes MERGED with Approval + zero Critical/High bugs + design doc accessible (local hld.md preferred, external fallback) + HLD Approvals table signed for tracks with `criticality ≥ standard` + test plan accessible + zero unresolved review comments on critical changes + coverage at target + Test Adequacy ≥80% (Strong) |
| **PARTIALLY QUALIFIED** | Minor gaps: Medium bugs only, non-critical artifacts missing, 1-2 stories In Progress with merged changes, some unresolved comments, coverage below target but >70%, Test Adequacy 40-79% (Adequate/Weak) |
| **NOT QUALIFIED** | Any: unresolved code stories with no changes, code changes not merged, Critical bugs, missing design doc AND test plan, requirements not traced to code, critical module FAIL in deep-review, Phase 5 commands failed, Test Adequacy <40% (Critical Gap) |

**If Phase 5 partially failed:** verdict cannot exceed PARTIALLY QUALIFIED due to insufficient evidence.

**Non-code Task verdict:** for non-code Task issue types (Phase 0.4 branch), Phase 5–7 do not apply. Report records type as `Non-code Task — qualification N/A` and stops after Phase 2 (artifact collection).

### 7.2 Qualification Report

Write `draft/jira-review/<JIRA_ID>/qualification-report.md` (with metadata header):

```markdown
# Jira Review Report: <JIRA_ID> — <Summary>

## Qualification Verdict

| Field | Value |
|-------|-------|
| Verdict | QUALIFIED / PARTIALLY QUALIFIED / NOT QUALIFIED |
| Date | <ISO timestamp> |
| Issue | <JIRA_ID> — <Summary> |
| Issue Type | <Epic | Story | Bug | Sub-task | Task> |
| Pipeline | Jira → Documents → Code Review → deep-review → bughunt → coverage → gap analysis |
| MCP Servers | Jira (yes), Code Review (<type> yes/no), TestRail (yes/no) |
| Git State | <branch> @ <short SHA> |
| Previous Run | <date or "First qualification"> |

### Verdict Criteria Checklist

| # | Criterion | Status | Source | Detail |
|----|-----------|--------|--------|--------|
| 1 | All code stories resolved | PASS/FAIL | Jira | <N>/<M> resolved |
| 2 | All code changes MERGED | PASS/FAIL | Code Review | <N>/<M> merged |
| 3 | Approval on all changes | PASS/FAIL | Code Review | <N> without approval |
| 4 | No unresolved review comments | PASS/FAIL | Code Review | <N> unresolved |
| 5 | No Critical/High bugs | PASS/FAIL | bughunt | <N> Critical, <M> High |
| 6 | Module quality | PASS/FAIL | deep-review | <N> modules FAIL |
| 7 | Test coverage at target | PASS/FAIL | coverage | <X>% vs <Y>% target |
| 8 | Test adequacy | PASS/FAIL | Phase 6 | <X>% — <Rating> |
| 9 | Design doc accessible | PASS/FAIL | Phase 2 | <status> |
| 10 | Test plan accessible | PASS/FAIL | Phase 2 | <status> |

## Executive Summary
(2-3 paragraphs: what the issue aimed to achieve, what was delivered, qualification status
 and key findings. Reference design doc synthesis where applicable.)

## Requirements Traceability Matrix
| # | Requirement | Story | Code Changes | Key Files | Deep-Review | Bughunt | Tests | Status |
|----|-------------|-------|--------------|-----------|-------------|---------|-------|--------|
| 1 | <text> | ENG-111 | 12345, 12346 | file.cc | PASS | Clean | 3 pass | Covered |
| 2 | <text> | ENG-222 | — | — | — | — | 0 | Gap |

Coverage: <X>/<Y> requirements traced to code changes (<Z>%)

## WH Summary
(What achieved, Why matters, Who contributed, When delivered, Where landed, How implemented
 — full tables as specified in Phase 4 context document)

## Design Document Summary
| Field | Value |
|-------|-------|
| URL | <URL or "Not found"> |
| Accessible | Yes / No |
| Access Method | <MCP name / WebFetch / N/A> |

Key Findings: (goals, architecture decisions, API changes, trade-offs — from synthesis)

## Quality Assessment (from draft:deep-review)
| Module | ACID | Resilience | Observability | Config | Verdict |
|--------|------|------------|---------------|--------|---------|
| <name> | PASS | PASS | ISSUE | PASS | CONDITIONAL PASS |

### Critical Findings
(Each Critical/Important issue: file:line, description, recommended fix)

## Bug Assessment (from draft:bughunt)
| Severity | Count |
|----------|-------|
| Critical | <N> |
| High | <N> |
| Medium | <N> |
| Low | <N> |

### Critical/High Bugs
(Each: location file:line, issue, impact, suggested fix, confidence level)

### Bug Distribution by Module
| Module | Critical | High | Medium | Low |
|--------|----------|------|--------|-----|

## Code Review Quality
| Metric | Value |
|--------|-------|
| Total Code Changes | <N> |
| MERGED with Approval | <N> |
| Without Approval | <N> |
| With Unresolved Comments | <N> |
| Average Patchset Count | <N.N> |
| Changes >5 Patchsets | <N> |

### Unresolved Review Comments
| Change ID | Story | File | Comment | Author |
|-----------|-------|------|---------|--------|

### Unreviewed Changes
| Change ID | Story | Subject | Author | Status |
|-----------|-------|---------|--------|--------|

## Test Assessment

### Test Adequacy Score
| Metric | Value | Weight | Score |
|--------|-------|--------|-------|
| Stories with test files in code changes | X/Y | 25% | |
| Production files with companion test files | X/Y | 20% | |
| Acceptance criteria with test coverage | X/Y | 20% | |
| Code coverage vs target | X% vs Y% | 15% | |
| Bughunt Critical/High with regression tests | X/Y | 10% | |
| New files (ADDED) with test coverage | X/Y | 10% | |
| **Test Adequacy** | | | **X% — <Rating>** |

### Test Shipping Status by Story
| Story ID | Summary | Code-Change Test Files | Companion Tests | Test Shipping Status |
|----------|---------|:----------------------:|:---------------:|---------------------|
| <ID> | <summary> | 2 | 5 | TESTED |
| <ID> | <summary> | 0 | 0 | UNTESTED |

### Code Coverage (from draft:coverage)
| Module | Line Coverage | Target | Status |
|--------|-------------|--------|--------|
| <module> | <X>% | <Y>% | PASS / BELOW TARGET |

### Codebase Test Inventory
| Production File | Companion Test File | Test Functions | Changed Functions Covered | Gap |
|----------------|--------------------|--------------:|:-------------------------:|-----|
| src/handler.go | src/handler_test.go | 8 | 3/5 | 2 uncovered |
| src/parser.go | — | — | — | No test file |

### TestRail Results (if available)
| Metric | Count |
|--------|-------|
| Total Test Cases | <N> |
| Passed | <N> |
| Failed | <N> |
| Blocked | <N> |
| Untested | <N> |
| Pass Rate | <X>% |

## Test Gap Analysis

### Untested Acceptance Criteria
| # | Story | Acceptance Criterion | Codebase Tests | TestRail Cases | Status |
|----|-------|---------------------|:--------------:|:--------------:|--------|
| 1 | <ID> | <criterion> | 0 | — | **GAP** |

### Production Files Without Tests
| # | File | Change Type | Story | Module | Lines Changed |
|----|------|-------------|-------|--------|--------------|
| 1 | src/parser.go | ADDED | <ID> | module_a | +250 |

### Stale Tests (code changed, tests not updated)
| # | Production File | Test File | Last Test Update | Production Changed In |
|----|----------------|-----------|------------------|----------------------|
| 1 | src/handler.go | src/handler_test.go | 6 months ago | Change 12345 |

## Suggested Tests

### Unit Tests
| # | Story | Test Name | Priority | Target File | Gap Closed |
|----|-------|-----------|----------|-------------|------------|
| 1 | <ID> | <descriptive_name> | Critical | <test_file_path> | <which gap> |

(Each with framework-specific code sketch below the table)

### Regression Tests (from bughunt findings)
| # | Bughunt Finding | Severity | Story | Test Name | Target File |
|----|----------------|----------|-------|-----------|-------------|
| 1 | <finding ref> | Critical | <ID> | regression_<desc> | <test_file_path> |

(Each with code sketch that reproduces the vulnerable scenario and asserts correct behavior)

### Integration Tests
| # | Stories | Modules | Test Name | Target File |
|----|---------|---------|-----------|-------------|
| 1 | <IDs> | mod_a ↔ mod_b | integration_<scenario> | <test_file_path> |

(Each with code sketch testing the cross-module interaction)

### Test Suggestion Summary
| Type | Count | Critical | High | Medium |
|------|------:|:--------:|:----:|:------:|
| Unit | <N> | <N> | <N> | <N> |
| Regression | <N> | <N> | <N> | <N> |
| Integration | <N> | <N> | <N> | <N> |
| **Total** | **<N>** | **<N>** | **<N>** | **<N>** |

## Gap Analysis

### Implementation Gaps
| # | Gap | Story | Severity | Detail |
|----|-----|-------|----------|--------|
| 1 | Requirement not traced to code | <ID> | High | <detail> |
| 2 | Code story without code changes | <ID> | High | <detail> |
| 3 | Code change not MERGED | <change> | Critical | <detail> |

### Quality Gaps
| # | Source | Severity | Finding | Location |
|----|--------|----------|---------|----------|

### Process Gaps
| # | Gap | Detail |
|----|-----|--------|
| 1 | Unresolved stories | <count>: <IDs> |
| 2 | In Progress stories | <count>: <IDs> |
| 3 | Missing design doc | <status> |
| 4 | Missing test plan | <status> |
| 5 | Unreviewed changes | <count>: <change IDs> |
| 6 | Unresolved review comments | <count>: <change IDs> |
| 7 | Stories without tests | <count>: <IDs> |
| 8 | Failed quality analyses | <which Phase 5 commands failed> |

## Artifacts
| Artifact | Location | Status |
|----------|----------|--------|
| Design Doc | <URL> | Accessible / Not found |
| Test Plan | <URL> | Accessible / Not found |
| Design Doc Synthesis | draft/jira-review/<JIRA_ID>/design-doc-synthesis.md | Generated / N/A |
| Test Data Synthesis | draft/jira-review/<JIRA_ID>/test-data-synthesis.md | Generated / N/A |
| Context Document | draft/jira-review/<JIRA_ID>/context.md | Generated |
| Deep Review Reports | draft/deep-review-reports/ | Generated / Failed |
| Bughunt Report | draft/bughunt-report-latest.md | Generated / Failed |
| Coverage Report | Per module | Generated / Failed / No framework |
| Draft Architecture | draft/architecture.md | Pre-existing / Generated by init |

## Recommendations
### Must-Fix (blocks qualification)
1. <item with file references and change IDs>

### Should-Fix (improves qualification)
1. <item>

### Test Improvements
1. <suggested test from Phase 6>

### Nice-to-Have
1. <item>

## All Code Changes
| # | Change ID | Subject | Author | Story | Branch | Status | Approval | Link |
|----|-----------|---------|--------|-------|--------|--------|----------|------|

Total: <N> changes across <M> stories

## All Files Changed
(Deduplicated, grouped by module:)
```
module_a/ (N files)
  - file1.cc (MODIFIED, stories: ENG-111, ENG-222)
  - file2.h (ADDED, stories: ENG-111)
```
Total: <N> files across <M> modules
```

### 7.3 Remediation Plan

If verdict ≠ QUALIFIED, write `draft/jira-review/<JIRA_ID>/remediation-plan.md` (with metadata header):

```markdown
# Remediation Plan: <JIRA_ID> Qualification Gaps

**Issue**: <JIRA_ID> — <Summary>
**Issue Type**: <Epic | Story | Bug | Sub-task>
**Verdict**: PARTIALLY QUALIFIED / NOT QUALIFIED
**Date**: <ISO timestamp>

## Phase 1: Critical Quality and Bug Issues
- [ ] Fix <Critical bug description> in <file:line> (source: bughunt)
- [ ] Fix <ACID violation> in <module> (source: deep-review)

## Phase 2: Unresolved Stories and Unmerged Changes
- [ ] Resolve <STORY_ID> — <summary> (status: <current>)
- [ ] Merge code change <change_id> for <STORY_ID> (status: NEW)
- [ ] Address <N> unresolved comments on change <change_id>

## Phase 3: Missing Artifacts and Process Gaps
- [ ] Create or link design document
- [ ] Create or link test plan
- [ ] Complete Approval for changes: <change IDs>

## Phase 4: Test Coverage Gaps
- [ ] Write test for: <untested acceptance criterion> (story: <ID>)
- [ ] Add unit tests for <file> — currently at <X>% (target: <Y>%)
- [ ] Create TestRail test cases for stories: <IDs without tests>
```

### 7.4 Delta from Previous Run

If Phase 0.5 found a previous `qualification-report.md`, include at the end of the new report:

```markdown
## Delta from Previous Qualification

| Metric | Previous (<date>) | Current | Change |
|--------|-------------------|---------|--------|
| Verdict | <old> | <new> | Improved / Unchanged / Regressed |
| Unresolved Stories | <N> | <M> | <diff> |
| Unmerged Changes | <N> | <M> | <diff> |
| Critical/High Bugs | <N> | <M> | <diff> |
| Test Coverage | <X>% | <Y>% | <diff> |
| Process Gaps | <N> | <M> | <diff> |
```

---

## Error Handling

| Condition | Action |
|-----------|--------|
| Jira MCP unavailable | **STOP** — cannot proceed |
| Code Review MCP unavailable | **DEGRADE** — skip Phase 3 code review checks, cap verdict at PARTIALLY QUALIFIED |
| TestRail MCP unavailable | **DEGRADE** — skip TestRail, flag as gap |
| Document URL inaccessible | **DEGRADE** — record URL, flag as process gap |
| No stories found (Epic, all fallbacks) | Flag, produce minimal report |
| Story not RESOLVED | Include in gaps, still collect code changes |
| Story In Progress | Flag separately from Unresolved, collect available changes |
| Code change not found | Flag per-story, continue with other changes |
| No changes for code story | Flag "implementation gap" |
| draft:init fails | **STOP** — context required for quality analysis |
| draft/ exists but stale | Warn, proceed (note in report) |
| draft:deep-review fails | **DEGRADE** — record failure, continue pipeline, cap verdict at PARTIALLY QUALIFIED |
| draft:bughunt fails | **DEGRADE** — record failure, continue pipeline, cap verdict at PARTIALLY QUALIFIED |
| draft:coverage fails / no framework | **DEGRADE** — record, flag "no coverage data" as gap |
| 50+ stories (Epic) | Process in batches of 25, warn about duration |
| Jira MCP rate limit / timeout | Back off with exponential delay, retry up to 3 times per call |
| Numeric-only input | Prompt for project prefix — do NOT assume |
| Issue type is Sub-task | Fetch parent for context, qualify sub-task scope, note parent in report |
| Issue type is non-code Task | Skip Phase 3–6, produce minimal report explaining qualification N/A |

---

## Output Files Summary

All generated artifacts and their locations:

| File | Path | Phase |
|------|------|-------|
| Design Doc Synthesis | `draft/jira-review/<JIRA_ID>/design-doc-synthesis.md` | 2 |
| Test Data Synthesis | `draft/jira-review/<JIRA_ID>/test-data-synthesis.md` | 2 |
| Context Document | `draft/jira-review/<JIRA_ID>/context.md` | 4 |
| Qualification Report | `draft/jira-review/<JIRA_ID>/qualification-report.md` | 7 |
| Remediation Plan | `draft/jira-review/<JIRA_ID>/remediation-plan.md` | 7 (if gaps) |
| Deep Review Reports | `draft/deep-review-reports/<module>.md` | 5 (managed by deep-review) |
| Bughunt Report | `draft/bughunt-report-latest.md` | 5 (managed by bughunt) |
| Coverage Reports | Per coverage command output | 5 (managed by coverage) |
