---
name: change
description: "Handle mid-track requirement changes. Analyzes impact on completed and pending tasks, proposes amendments to spec.md and plan.md before applying. Use when the user asks to 'change the spec', 'amend the plan', 'modify requirements mid-track', or says 'we need to add X to this track', 'requirements changed'."
---

# Course Correction

Handle a mid-track requirement change using Draft's Context-Driven Development methodology.

## Red Flags - STOP if you're:

- Applying changes to spec.md or plan.md without showing the user what will change first
- Invalidating `[x]` completed tasks without flagging them explicitly
- Proceeding past the CHECKPOINT without user confirmation
- Editing files when the user said "no" or "edit"

**Show impact before applying. Always confirm.**

---

## Step 0: Verify Draft Context

```bash
ls draft/tracks.md 2>/dev/null
```

If `draft/` does not exist: **STOP** — "No Draft context found. Run `/draft:init` first."

---

## Step 1: Parse Arguments

Extract from `$ARGUMENTS`:

- **Change description** — free text describing what needs to change (required)
- **Track specifier** — optional `track <id>` prefix to target a specific track

### Default Behavior

If no `track <id>` specified:
- Auto-detect the active `[~]` In Progress track from `draft/tracks.md`
- If no `[~]` track, find the first `[ ]` Pending track
- Display: `Auto-detected track: <id> - <name>` before proceeding

If no change description provided:
- Error: "Usage: `/draft:change <description>` or `/draft:change track <id> <description>`"

---

## Step 2: Load Context

1. Read `draft/tracks/<id>/spec.md` — extract requirements and acceptance criteria
2. Read `draft/tracks/<id>/plan.md` — extract all tasks with their current status (`[ ]`, `[~]`, `[x]`, `[!]`)
3. Read `draft/tracks/<id>/metadata.json` — for track type and status

---

## Step 3: Analyze Spec Impact

Analyze the change description against the loaded spec.

For each requirement and acceptance criterion, classify the effect:

| Classification | Meaning |
|---|---|
| **Added** | New requirement or AC introduced by this change |
| **Modified** | Existing requirement or AC needs updating |
| **Removed** | Existing requirement or AC is no longer needed |
| **Unaffected** | No change needed |

Produce a concise impact list. Example:
```
Spec impact:
- AC #2 "User can export to CSV" → Modified (now also requires JSON format)
- AC #5 "Export limited to 1000 rows" → Removed (no row limit)
- NEW: AC #6 "Export progress indicator for large datasets"
```

---

## Step 4: Map Impact to Plan Tasks

For each task in `plan.md`, determine if the spec change affects it:

- **`[x]` completed tasks** that are now invalidated by the change → flag as:
  `⚠️ [task description] — may need rework`

- **`[ ]` pending tasks** that need updating → show the proposed new task text

- **`[~]` in-progress tasks** that are affected → flag as:
  `⚠️ IN PROGRESS: [task description] — review before continuing`

- **`[!]` blocked tasks** that are affected → flag as:
  `⚠️ BLOCKED: [task description] — re-evaluate; requirement change may alter blocking condition or resolution path`

- **Unaffected tasks** — skip, do not mention

---

## Step 5: Present Impact Summary

Display a clear summary before proposing any file changes:

```
Change: [change description]
Track:  <track_id> — <track_name>

Spec impact:
  - [classification] [requirement/AC]
  - [classification] [requirement/AC]

Plan impact:
  - ⚠️ [N] completed task(s) may need rework
  - [M] pending task(s) need updating
  - [K] in-progress task(s) need review
  - [B] blocked task(s) need re-evaluation

Completed tasks that may need rework:
  - [x] [task description] (commit: abc1234)

Pending tasks with proposed changes:
  Before: - [ ] [original task text]
  After:  - [ ] [proposed new task text]
```

---

## Step 6: Show Proposed Amendments

Display only the changed sections of each file (not full rewrites):

### Proposed spec.md changes

Show the diff as before/after for each modified section. Do not rewrite unchanged sections.

### Proposed plan.md changes

Show each task that would be modified as before/after. Do not rewrite the full plan.

---

## Step 7: CHECKPOINT

```
Apply these changes to spec.md and plan.md? [yes / no / edit]
```

- **`yes`** — proceed to Step 8
- **`no`** — discard all proposed changes, announce "No changes applied." and stop
- **`edit`** — let the user describe adjustments to the proposed amendments, then revise and re-present the CHECKPOINT again. The loop continues until the user selects `yes` or `no`.

---

## Step 8: Apply Changes and Log

1. Apply the agreed amendments to `spec.md` and `plan.md`

2. Update `draft/tracks/<id>/metadata.json`:
   - Set `updated` to current ISO timestamp
   - Recalculate `tasks.total` by counting all `- [ ]`, `- [~]`, `- [x]`, and `- [!]` lines in the updated `plan.md`. Update `tasks.completed` by counting only `- [x]` lines.

3. Append a Change Log entry (with current git SHA (obtain via `git rev-parse --short HEAD`) and timestamp) to `plan.md`. If a `## Change Log` section does not exist, add it at the bottom:

```markdown
## Change Log

| Date | Description | Impact |
|------|-------------|--------|
| [ISO date] | [change description] | [N completed may need rework, M pending updated] |
```

4. Announce:

```
Changes applied: <track_id>

Updated:
- draft/tracks/<id>/spec.md
- draft/tracks/<id>/plan.md

[If completed tasks flagged:]
⚠️  Review N completed task(s) — they may not align with the updated spec.
    Re-run /draft:implement to address rework, or /draft:review to assess.

Next: /draft:implement to continue, or /draft:review to assess current state.
```

---

## Error Handling

### Track Not Found
```
Error: Track '<id>' not found.
Run /draft:status to see available tracks.
```

### No Active Track
```
Error: No active track found.
Use: /draft:change track <id> <description>
```

### No Spec or Plan
```
Error: Missing spec.md or plan.md for track <id>.
Cannot perform change analysis without both files.
```

---

## Examples

### Change description for active track
```bash
/draft:change the export format should support JSON in addition to CSV
```

### Targeting a specific track
```bash
/draft:change track add-export-feature also require a progress indicator for exports over 500 rows
```
