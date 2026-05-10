---
name: status
description: "Display current progress of Draft tracks and active tasks. Shows phases, completion percentages, and blocked items. Use when the user asks for 'track status', 'where am I', 'show progress', 'list active tracks', or says 'what is pending'."
---

# Draft Status

Display a comprehensive overview of project progress.

## Red Flags - STOP if you're:

- Reporting status without actually reading the files
- Making up progress percentages
- Skipping blocked items in the report
- Not checking each active track's actual state
- Summarizing without evidence from the files

**Always read before reporting.**

---

## Gather Data

1. Read `draft/tracks.md` for track list
2. For each active track, read:
   - `draft/tracks/<id>/metadata.json` for stats. If `metadata.json` is malformed or unreadable, display `(metadata unavailable)` for that track's statistics instead of failing.
   - `draft/tracks/<id>/plan.md` for task status
   - `draft/tracks/<id>/architecture.md` for module status (if exists)
3. Check for project-wide `draft/.ai-context.md` (or legacy `draft/architecture.md`) for module status
4. **Detect orphaned tracks:**
   - Scan `draft/tracks/` for all directories
   - For each directory, check if it has `metadata.json`
   - Cross-reference with `draft/tracks.md` entries
   - If directory has metadata.json but NOT in tracks.md → orphaned track
   - Collect list of orphaned track IDs for warning section

## Output Format

Check each track's `metadata.json` `type` field to determine display format.

### Standard (multi-phase) tracks

```
═══════════════════════════════════════════════════════════
                      DRAFT STATUS
═══════════════════════════════════════════════════════════

PROJECT: [from product.md title]

ACTIVE TRACKS
─────────────────────────────────────────────────────────
[track-id-1] Feature Name
  Status: [~] In Progress
  Phase:  2/3 (Phase 2: [Phase Name])
  Tasks:  5/12 complete
  ├─ [x] Task 1.1: Description
  ├─ [x] Task 1.2: Description
  ├─ [~] Task 2.1: Description  ← CURRENT
  ├─ [ ] Task 2.2: Description
  └─ [!] Task 2.3: Blocked - [reason]

[track-id-2] Another Feature
  Status: [ ] Not Started
  Phase:  0/2
  Tasks:  0/6 complete

```

### Quick-mode tracks (metadata.json `type` is `"quick"`)

Quick-mode tracks use flat task numbering (`Task 1:`, `Task 2:`) without phases. Display them with a flat task list instead of the phase-grouped tree:

```
[track-id-3] Quick Feature
  Status: [~] In Progress
  Type:   quick
  Tasks:  2/5 complete
  ├─ [x] Task 1: Description
  ├─ [x] Task 2: Description
  ├─ [~] Task 3: Description  ← CURRENT
  ├─ [ ] Task 4: Description
  └─ [ ] Task 5: Description
```

Do **not** show `Phase: X/Y` for quick-mode tracks — they have no phases.

### Remaining sections (shared by both formats)

```
MODULES (if architecture.md exists)
─────────────────────────────────────────────────────────
Module A         [x] Complete  (Coverage: 96.2%)
Module B         [~] In Progress - 3/5 tasks
Module C         [ ] Not Started

BLOCKED ITEMS
─────────────────────────────────────────────────────────
- [track-id-1] Task 2.3: [blocked reason]

ORPHANED TRACKS
─────────────────────────────────────────────────────────
⚠ The following tracks have metadata.json but are missing from tracks.md:
- draft/tracks/orphan-track-id/

Recovery options:
1. Add to tracks.md manually if track is valid
2. Remove orphaned track directory if no longer needed

RECENTLY COMPLETED
─────────────────────────────────────────────────────────
- [track-id-3] - Completed [date]

QUICK STATS
─────────────────────────────────────────────────────────
Active Tracks:    2
Total Tasks:      18
Completed:        5 (28%)
Blocked:          1
═══════════════════════════════════════════════════════════
```

## Module Reporting

When `.ai-context.md` or `architecture.md` exists for a track (track-level or project-level):

1. Read the `.ai-context.md` (or `architecture.md`) module definitions from `## Modules` section
2. For each module, determine status from its status marker:
   - `[ ]` Not Started
   - `[~]` In Progress — count completed vs total tasks mapped to this module
   - `[x]` Complete — include coverage percentage if recorded
   - `[!]` Blocked — include reason
3. Display in the MODULES section of the track report
4. If project-wide `draft/.ai-context.md` (or legacy `draft/architecture.md`) exists, show a project-level module summary after QUICK STATS

---

## If No Tracks

```
═══════════════════════════════════════════════════════════
                      DRAFT STATUS
═══════════════════════════════════════════════════════════

PROJECT: [from product.md title]

No active tracks.

Get started:
  /draft:new-track "Your feature description"

═══════════════════════════════════════════════════════════
```

## If Not Initialized

```
Draft not initialized in this project.

Run /draft:init to initialize.
```
