---
name: standup
description: "Generate standup summary from git history, track progress, and optional Jira/GitHub PR activity. Read-only — makes no changes to the codebase. Use when the user asks for 'a standup', 'daily summary', 'standup notes', or says 'what did I do yesterday', 'summarize my week'."
---

# Standup

Generate a standup summary from recent development activity. This is a **read-only** skill — it makes no changes to the codebase or track files.

## Red Flags — STOP if you're:

- Modifying any files (this is read-only)
- Fabricating activity that didn't happen
- Including sensitive information (credentials, internal URLs) in standup output
- Reporting on other people's commits without being asked

**Report facts. Fabricate nothing.**

---

## Pre-Check

### 0. Capture Git Context

Before starting, capture the current git state:

```bash
git branch --show-current    # Current branch name
git rev-parse --short HEAD   # Current commit hash
```

Store this for context. The standup reflects activity up to this specific commit.

### 1. Load Draft Context (if available)

```bash
ls draft/ 2>/dev/null
```

If `draft/` exists, read and follow `core/shared/draft-context-loading.md`.

## Step 1: Parse Arguments

Check for arguments:
- `/draft:standup` — Default: last 24 hours of activity
- `/draft:standup <days>` — Activity from last N days
- `/draft:standup weekly` — Full week summary (Monday-Friday)
- `/draft:standup --author <name>` — Filter to specific author

## Step 2: Gather Activity

### Source 1: Git History

```bash
# Last 24 hours by default (adjust with args)
git log --oneline --since="24 hours ago" --author="$(git config user.name)"
git log --since="24 hours ago" --author="$(git config user.name)" --format="%h %s" --no-merges
```

Parse commit messages for:
- Track IDs (from `type(track-id): description` convention)
- Task completions
- Bug fixes
- Feature additions

### Source 2: Track Progress (if draft context exists)

Read `draft/tracks.md` for active tracks:
- Current status and phase
- Tasks completed since last standup
- Blockers (tasks marked `[!]`)

For each active track, read `plan.md` to determine:
- Tasks completed (count `[x]` with recent commit SHAs)
- Current task (first `[ ]` or `[~]`)
- Phase progress

### Source 3: Jira Activity (if MCP available)

If Jira MCP is available:
- Query recent ticket transitions (status changes)
- Check for new comments or assignments
- Pull sprint board status

### Source 4: GitHub PR Activity (if MCP / `gh` CLI available)

If GitHub MCP or the `gh` CLI is available:
- Query open PRs authored by user (`gh pr list --author @me`)
- Check for new review comments received (`gh pr view <num> --comments`)
- Query recently merged PRs (`gh pr list --state merged --author @me`)

## Step 3: Generate Standup

Format using the standard Yesterday/Today/Blockers structure:

```markdown
## Standup — {date}

**Author:** {git user.name}
**Period:** {time range}

### Completed
- [{track-id}] {task description} ({commit SHA})
- [{track-id}] {task description} ({commit SHA})
- Reviewed: {PR number} (if applicable)

### Planned
- [{track-id}] Next task: {description} (from plan.md)
- [{track-id}] Continue: {in-progress task} (from plan.md)
- Review: {pending reviews} (if applicable)

### Blockers
- [{track-id}] {blocked task description} — {reason}
- Waiting on: {external dependency}

### Track Progress
| Track | Phase | Tasks | Status |
|-------|-------|-------|--------|
| {id} | {N}/{total} | {done}/{total} | {status} |
```

**If no activity found:** "No commits in the last {period}. Working on: {active track description from tracks.md or 'no active tracks'}."

## Step 4: Present Output

Present the standup summary directly in the conversation. Do not write to any file unless explicitly requested.

If the user asks to save:
- Save to `draft/standup-<date>.md`
- Symlink: `draft/standup-latest.md`

**If saving, MANDATORY: Include YAML frontmatter with git metadata.** Follow `core/shared/git-report-metadata.md`.

Include the report header table immediately after frontmatter:

```markdown
| Field | Value |
|-------|-------|
| **Branch** | `{LOCAL_BRANCH}` → `{REMOTE/BRANCH}` |
| **Commit** | `{SHORT_SHA}` — {COMMIT_MESSAGE} |
| **Generated** | {ISO_TIMESTAMP} |
| **Synced To** | `{FULL_SHA}` |
```

## Cross-Skill Dispatch

- **References:** `core/agents/ops.md` for operational context awareness
- **Reads from:** `/draft:status` data (tracks.md, plan.md, metadata.json)
- **MCP integrations:** Jira MCP (ticket status), GitHub MCP / `gh` CLI (PR activity)
- **No downstream dispatch** — this is a terminal, read-only skill

## Error Handling

**If no git history:** "No git commits found for {period}. Is this the right repository?"
**If no draft context:** Generate standup from git history only. Note: "Richer standups available after `/draft:init`."
**If no MCP available:** Skip Jira/PR sections, generate from local data only.
