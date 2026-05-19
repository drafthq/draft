---
name: impact
description: Generate a project-wide impact report on Draft track delivery — pace, phase duration, completion rate, friction hotspots, ADR/guardrail/decomposition adoption — by parsing track metadata, git revert history, and phase timestamps. Use when measuring CDD effectiveness ("show project impact", "where are bottlenecks", "measure track delivery").
---

# Draft Impact: Track Telemetry & Analytics

Generate a project-wide impact report measuring Context-Driven Development effectiveness across all tracks.

## Red Flags - STOP if you're:
- Profiling code coverage instead of measuring track-level impact.
- Rewriting tracker logic when local state objects are available for inspection.
- Generating reports without reading existing track metadata first.

---

## Execution Constraints

1. **Load Track State:**
   - Read all `draft/tracks.md` entries.
   - For each track, read `metadata.json` to extract: `created_at`, `updated`, `status`, phase counts, task counts, `scope_includes`, `scope_excludes`.
   - If no tracks exist, report "No tracks found. Run `/draft:new-track` to create your first track."
   - Run `scripts/tools/check-scope-conflicts.sh` to surface adjacent
     tracks sharing scope tags — duplicate effort signals in impact
     reporting. Schema:
     [core/shared/template-contract.md](../../core/shared/template-contract.md).

2. **Compute Metrics:**
   - **Delivery Pace:** Average elapsed time from track creation to completion (planning → implementation → review).
   - **Phase Duration:** Time spent in each phase (planning, implementation, review). Flag any phase exceeding 14 days without updates.
   - **Completion Rate:** Ratio of completed tracks to total tracks.
   - **Task Granularity:** Average tasks per track. Flag tracks with fewer than 3 tasks (under-decomposed) or more than 30 (over-decomposed).

3. **Friction Detection:**
   - Scan `git log` for revert commits associated with each track.
   - High revert count (>2 per track) signals unclear specification boundaries.
   - Flag tracks that moved backward (e.g., from implementation back to planning).

4. **Architectural Impact:**
   - Count ADRs created (`draft/adrs/`).
   - Count guardrail entries added via `/draft:learn`.
   - Count modules decomposed via `/draft:decompose`.

5. **Report Output:**
   Generate a Markdown report with sections shown below. The shape is fixed so reports diff cleanly across runs.

   ```markdown
   # Draft Impact Report — {YYYY-MM-DD}

   ## Summary
   - Total tracks: 12   (Completed: 7, In-progress: 3, Abandoned: 2)

   ## Delivery Pace
   - Average track duration: 8.4 days   |   Median: 6 days
   - Phases exceeding 14d without update: <list track IDs or "none">

   ## Friction Hotspots
   | Track | Reverts | Stall (days) | Notes |
   |---|---|---|---|
   | track-042 | 3 | 9 | Reverted after review; spec scope unclear |

   ## CDD Adoption
   - ADRs: 4   |   Guardrail entries: 11   |   Decomposed modules: 6

   ## Recommendations
   - <one actionable suggestion per detected pattern>
   ```

---

## Report Closing: Next Actions (REQUIRED)

Every impact/telemetry report must end with a `## Next Actions` section listing the smallest set of follow-ups in execution order. Use this exact shape:

```markdown
## Next Actions

| # | Action | Owner | Blocker? | Skill / Command |
|---|---|---|---|---|
| 1 | <imperative one-liner> | <team-lead|TBD> | no | `/draft:<skill> <args>` or `n/a` |
```

Rules:
- Impact reports are advisory — `Blocker? = no` is the default; mark `yes` only when a metric breach demands immediate process change.
- Suggest `/draft:tech-debt` for systemic friction, `/draft:adr` for methodology adjustments, `/draft:tour` for onboarding gaps.
- Cap at 7 actions.
