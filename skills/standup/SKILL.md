---
name: standup
description: Generate standup summary from git history, track progress, and Jira/GitHub activity. Read-only — makes no changes to the codebase.
---

# Standup

You are generating a standup summary from recent development activity. This is a **read-only** skill — it makes no changes to the codebase or track files.

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
git branch --show-current # Current branch name
git rev-parse --short HEAD # Current commit hash
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

**Preferred:** invoke `parse-git-log.sh` — it parses conventional commits into structured JSONL `{sha,type,scope,track_id,subject,author,timestamp,files_changed}`, eliminating ambiguity in `type(track-id): subject` parsing. Resolve via the canonical tool resolver (see [core/shared/tool-resolver.md](../../core/shared/tool-resolver.md)):

```bash
DRAFT_TOOLS="$(cat ~/.cache/draft/plugin-root 2>/dev/null)/scripts/tools"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$(ls -d ~/.claude/plugins/cache/*/draft/*/scripts/tools 2>/dev/null | sort -V | tail -1)"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$(ls -d ~/.claude/plugins/marketplaces/*draft*/scripts/tools 2>/dev/null | tail -1)"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$PWD/scripts/tools"
if [ -x "$DRAFT_TOOLS/parse-git-log.sh" ]; then
  bash "$DRAFT_TOOLS/parse-git-log.sh" --since "24 hours ago" --author "$(git config user.name)"
else
  # Fallback: raw git log
  git log --oneline --since="24 hours ago" --author="$(git config user.name)"
  git log --since="24 hours ago" --author="$(git config user.name)" --format="%h %s" --no-merges
fi
```

Parse commit messages for:
- Track IDs (from `type(track-id): description` convention — already extracted as `track_id` in JSONL)
- Task completions
- Bug fixes
- Feature additions

### Source 2: Track Progress (if draft context exists)

Read `draft/tracks.md` for active tracks:
- Current status and phase
- Tasks completed since last standup
- Blockers (tasks marked `[!]`)
- Scope (`metadata.json:scope_includes` / `scope_excludes`) — mention when
  two active tracks share a scope tag; surfaced by
  `scripts/tools/check-scope-conflicts.sh`. Schema:
  [core/shared/template-contract.md](../../core/shared/template-contract.md).

For each active track, read `plan.md` to determine:
- Tasks completed (count `[x]` with recent commit SHAs)
- Current task (first `[ ]` or `[~]`)
- Phase progress

### Source 3: Jira Activity (if MCP available)

If Jira MCP is available:
- Query recent ticket transitions (status changes)
- Check for new comments or assignments
- Pull sprint board status

### Source 4: GitHub Activity (if MCP available)

If GitHub MCP is available:
- Query open reviews authored by user
- Check for new review comments received
- Query recently merged changes

### Source 5: Skill Metrics (if `~/.draft/metrics.jsonl` exists)

```bash
tail -50 ~/.draft/metrics.jsonl 2>/dev/null
```

If the file exists and has records in the standup period, enrich the standup with skill activity:
- **implement** records: count tasks completed, note TDD pass/fail rate
- **review** records: note reviews run and their verdicts
- **bughunt** records: note bug hunts run and critical counts
- Include a brief "AI-Assisted Activity" line in the standup: `AI tools used: implement (N tasks), review (N times), bughunt (N hunts)`

If the file does not exist or has no records in the period, skip silently — this source is always optional.

## Step 3: Generate Standup

Format using the standard Yesterday/Today/Blockers structure:

```markdown
## Standup — {date}

**Author:** {git user.name}
**Period:** {time range}

### Completed
- [{track-id}] {task description} ({commit SHA})
- [{track-id}] {task description} ({commit SHA})
- Reviewed: {GitHub change ID / PR} (if applicable)

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
- **MCP integrations:** Jira MCP (ticket status), GitHub MCP (review activity)
- **No downstream dispatch** — this is a terminal, read-only skill

## Error Handling

**If no git history:** "No git commits found for {period}. Is this the right repository?"
**If no draft context:** Generate standup from git history only. Note: "Richer standups available after `/draft:init`."
**If no MCP available:** Skip Jira/GitHub sections, generate from local data only.
