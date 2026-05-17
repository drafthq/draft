# Session Summary Template

Compact summary emitted by `/draft:implement` at the end of sessions where 3 or more tasks were completed. Saved to `draft/tracks/<id>/session-summary-<timestamp>.md`.

**Called by:** `/draft:implement` Step 6 (track completion or end-of-session with ≥3 completed tasks)

---

## Template

```markdown
---
track_id: "{TRACK_ID}"
generated_by: "draft:implement"
generated_at: "{ISO_TIMESTAMP}"
synced_to_commit: "{FULL_SHA}"
---

# Session Summary — {TRACK_TITLE}

**Date:** {ISO_DATE}
**Commit range:** {START_SHA}^..{END_SHA}

## Tasks Completed

| # | Task | Commit |
|---|------|--------|
| 1 | {task description} | `{sha}` |
| 2 | {task description} | `{sha}` |
| ... | | |

**Total:** N tasks completed this session

## Files Touched

- `{path/to/file}` — {brief description of change}
- `{path/to/file}` — {brief description of change}

## Tests Run

- **Suite:** {test command run}
- **Result:** {pass count} passed / {fail count} failed / {skip count} skipped
- **Coverage delta:** {+N%} (if available)

## Drift Detected

{One of:}
- None
- ⚠️ LLD interface conflict in task N: {description of conflict, resolution deferred}
- ⚠️ Architecture drift: {description}

## Blockers

{One of:}
- None
- {Blocker description and recovery action}

## Next Task

{First pending `[ ]` task from plan.md, or "Track complete" if all tasks done}
```

---

## Emission Rules

Emit when `/draft:implement` completes a session and **any** of these conditions are met:
- 3 or more tasks completed in the current session
- Track is fully complete (all tasks `[x]`)
- A drift or blocker was detected and resolved

**Do not emit** for sessions with fewer than 3 completed tasks and no track completion — use the standard Progress Report instead.

**File naming:** `session-summary-{YYYYMMDD}-{HHMM}.md` in `draft/tracks/<id>/`
