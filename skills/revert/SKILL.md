---
name: revert
description: "Git-aware revert that understands Draft tracks, phases, and tasks. Safely undo work at task, phase, or track level. Use when the user asks to 'revert this track', 'undo a phase', 'revert task X', or says 'roll back the last task', 'undo this work'."
---

# Draft Revert

Perform intelligent git revert that understands Draft's logical units of work.

## Red Flags - STOP if you're:

- Reverting without showing preview first
- Skipping user confirmation
- Not checking for uncommitted changes first
- Reverting more than requested
- Not updating Draft state after git revert
- Assuming you know which commits to revert without checking

**Preview and confirm before any destructive action.**

---

## Step 0: Pre-flight Check

1. **Verify Draft context exists:**
   ```bash
   ls draft/tracks.md 2>/dev/null
   ```
   If `draft/` does not exist: **STOP** — "No Draft context found. Run `/draft:init` first."

2. **Check working tree:**
   Run `git status --porcelain`. If output is non-empty, warn the user about uncommitted changes and suggest stashing or committing first. Do NOT proceed until working tree is clean.

---

## Step 1: Analyze What to Revert

Ask user what level to revert:

1. **Task** - Revert a single task's commits
2. **Phase** - Revert all commits in a phase
3. **Track** - Revert entire track's commits

If user specifies by name/description, find the matching commits.

## Step 2: Find Related Commits

**Primary method:** Read `plan.md` — every completed task has its commit SHA recorded inline. Use these SHAs directly.

**If no commits found** (all tasks are `[ ]` Pending with no SHAs): announce "No commits found for this scope — nothing to revert." and **STOP**.

**Fallback method (if SHAs missing but completed tasks exist):** Search git log by track ID pattern:

For Draft-managed work, commits follow pattern:
- `feat(<track_id>): <description>`
- `fix(<track_id>): <description>`
- `test(<track_id>): <description>`
- `refactor(<track_id>): <description>`

```bash
# Find commits for a track
git log --oneline --grep="<track_id>"

# Find commits in date range (for phase)
git log --oneline --since="<phase_start>" --until="<phase_end>" --grep="<track_id>"
```

**Cross-reference:** Verify SHAs from `plan.md` match the git log results. Git log is always authoritative for commit identification. plan.md is authoritative for task-to-commit mapping. On SHA mismatch, prefer git log and warn the user.

## Step 3: Preview Revert

Show user what will be reverted:

```
═══════════════════════════════════════════════════════════
                    REVERT PREVIEW
═══════════════════════════════════════════════════════════

Reverting: [Task/Phase/Track] "[name]"

Commits to revert (newest first):
  abc1234 feat(add-auth): Add JWT validation
  def5678 feat(add-auth): Create auth middleware
  ghi9012 test(add-auth): Add auth middleware tests

Files affected:
  src/auth/middleware.ts
  src/auth/jwt.ts
  tests/auth/middleware.test.ts

Plan.md changes:
  Task 2.1: [x] (abc1234) → [ ]
  Task 2.2: [x] (def5678) → [ ]

═══════════════════════════════════════════════════════════
Proceed with revert? (yes/no)
```

## Step 4: Execute Revert

If confirmed:

Maintain a list of successfully reverted commits during execution.

Read `draft/workflow.md` → `## Toolchain` section for VCS CLI. See `core/shared/vcs-commands.md` for the full command mapping.

**git mode:**
```bash
# Revert each commit in reverse order (newest first)
git revert --no-commit <commit1>
git revert --no-commit <commit2>
# ... continue for all commits

# Create single revert commit
git commit -m "revert(<track_id>): Revert [task/phase description]"
```

On conflict, report: "Successfully reverted: [list]. Conflict on: [sha]. Run `git revert --abort` to undo partial state."

## Step 5: Update Draft State

1. Update `plan.md`:
   - Change reverted tasks from `[x]` to `[ ]`
   - Remove the commit SHA from the reverted task line
   - Add revert note

2. Update `metadata.json`:
   - Decrement tasks.completed
   - Decrement phases.completed if applicable
   - Update timestamp
   - **Note:** `metadata.json` only stores `phases.total` (int) and `phases.completed` (int). Decrement `phases.completed` if all tasks in a previously completed phase are reverted. Phase status markers (`[~]`, `[x]`, `[ ]`) are tracked in `plan.md` text, not in `metadata.json`. Update `plan.md` phase headings accordingly: if any task in a completed phase is reverted, mark that phase `[~]` In Progress in `plan.md`; if ALL tasks are reverted, mark it `[ ]` Pending in `plan.md`.

3. Update `draft/tracks.md` if track status changed

4. **Stale reports:** After revert, existing `review-report-latest.md` and `bughunt-report-latest.md` for the track are stale. Resolve symlink targets first: `readlink -f review-report-latest.md` and `readlink -f bughunt-report-latest.md`. Add a warning header to the symlink targets (the actual timestamped files): `> **WARNING: This report predates a revert operation and may be stale. Re-run the review/bughunt.**` Or delete them if the revert is substantial.

## Step 6: Confirm

```
Revert complete

Reverted:
  - [list of tasks/commits]

Updated:
  - draft/tracks/<track_id>/plan.md
  - draft/tracks/<track_id>/metadata.json

Git status:
  - Created revert commit: [sha]

The reverted tasks are now available to re-implement.
Run /draft:implement to continue.
```

## Recovery

If the process is interrupted between git revert and Draft state update, the recovery procedure is: check `git log` for the revert commit, then manually update plan.md task statuses to match the reverted state.

---

## Abort Handling

If user says no to preview:
```
Revert cancelled. No changes made.
```

If git revert has conflicts:
```
Revert conflict detected in: [files]

Options:
1. Resolve conflicts manually, then run: git revert --continue
2. Abort revert: git revert --abort

Draft state NOT updated (pending revert completion).
```
