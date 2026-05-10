---
name: impact
description: "Telemetry and analytics suite generating project-wide insights by parsing execution timestamps, revert history, and phase tracking. Use when the user asks to 'show track telemetry', 'measure impact', 'project insights', 'how effective is Draft', or says 'show me Draft analytics'."
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
   - For each track, read `metadata.json` to extract: `created_at`, `updated`, `status`, phase counts, task counts.
   - If no tracks exist, report "No tracks found. Run `/draft:new-track` to create your first track."

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
   Generate a Markdown report with sections:
   - **Summary:** Total tracks, completed, in-progress, abandoned.
   - **Delivery Pace:** Average and median track duration.
   - **Friction Hotspots:** Tracks with highest revert counts, longest stalls, or phase regressions.
   - **CDD Adoption:** ADR count, guardrail growth, decomposition usage.
   - **Recommendations:** Actionable suggestions based on detected friction patterns.

---
