# Chapter 7: Managing Tracks

Part II: Track Lifecycle· Chapter 7

4 min read

Specs get written. Plans get approved. Implementation begins. And then the requirements change. Or a task gets blocked by an external dependency. Or you realize phase 2 introduced a regression and need to undo it without losing phase 1's work. Draft provides three operational commands for exactly these situations:/draft:statusfor visibility,/draft:changefor mid-track adjustments, and/draft:revertfor git-aware rollback.

## Status: Project Visibility

/draft:statusreads every active track's plan and metadata, then produces a comprehensive dashboard showing exactly where everything stands.

The status display adapts to track type. Multi-phase tracks show phase progress with nested task trees. Quick-mode tracks show a flat task list without phase grouping. Both use the same status markers:[ ]Pending,[~]In Progress,[x]Completed,[!]Blocked.

### Orphaned Track Detection

The status command also scans for orphaned tracks — directories indraft/tracks/that have ametadata.jsonbut no corresponding entry intracks.md. These can occur when a track creation was interrupted between directory creation and registry update. The status output flags them with recovery options: add the entry totracks.mdmanually, or remove the orphaned directory.

### Module Reporting

When.ai-context.mdorarchitecture.mdexists, the status output includes a module-level view — which modules are complete, which are in progress with task counts, and which are blocked. This gives architectural visibility alongside task-level progress.

## Change: Mid-Track Adjustments

Requirements change. A stakeholder wants JSON export added to a feature that was specced for CSV only. A security review reveals a new constraint. A dependency you planned to use is deprecated./draft:changehandles these mid-stream adjustments without losing completed work.

The command follows a structured process:

* Impact Analysis— The AI classifies every requirement and acceptance criterion inspec.mdas Added, Modified, Removed, or Unaffected by the change.
* Plan Mapping— Each task inplan.mdis evaluated against the spec change. Completed tasks that are now invalidated get flagged for potential rework. In-progress tasks get flagged for review. Pending tasks get proposed new text.
* Preview— The full impact is displayed before any file is modified: how many completed tasks may need rework, how many pending tasks need updating, the exact before/after diffs for each affected section.
* Confirmation— You approve, reject, or request edits to the proposed changes. The edit loop continues until you say "yes" or "no."
* Application— On approval, amendments are applied tospec.mdandplan.md, metadata timestamps are updated, and a Change Log entry is appended to the plan with the current git SHA and timestamp.
/draft:changenever silently invalidates completed tasks. When a requirement change affects work that's already done, the task is flagged explicitly and the developer decides whether rework is needed. The commit history is preserved — you can inspect exactly what was built and decide how much needs to change.

## Revert: Git-Aware Rollback

Sometimes you need to undo work. A phase introduced a subtle regression. An approach turned out to be a dead end. A task's implementation conflicts with a concurrent change on another branch./draft:revertprovides git-aware rollback that understands Draft's logical units of work.

The command supports three granularity levels:

* Task-level revert— Undo a single task's commits. The most surgical option.
* Phase-level revert— Undo all commits in an entire phase. Useful when the approach for a phase was wrong.
* Track-level revert— Undo everything in the track. The nuclear option.
Every revert follows the same safety protocol:

* Pre-flight check— Verifies the working tree is clean. Uncommitted changes must be stashed or committed first.
* Commit identification— Reads commit SHAs from the[x]task markers inplan.md. Falls back to searching git log by track ID pattern if SHAs are missing.
* Preview— Shows exactly which commits will be reverted, which files are affected, and howplan.mdwill change. Nothing happens without your confirmation.
* Execution— Reverts commits in reverse chronological order usinggit revert --no-commit, then creates a single revert commit:revert(add-oauth2): Revert Phase 2 provider integration.
* State update— Reverted tasks change from[x]to[ ]inplan.md. The commit SHA is removed.metadata.jsoncounters are decremented. Phase status markers are adjusted — if any task in a completed phase is reverted, the phase returns to In Progress.
After a revert, any existing review or bughunt reports for the track are stale — they analyzed code that no longer exists. Draft adds a warning header to these reports or deletes them if the revert is substantial, preventing anyone from relying on outdated analysis.

## Handling Blocked Tasks

When a task cannot proceed, it is marked[!]Blocked with a reason recorded inplan.md. The implementation command skips blocked tasks and notifies you, but it never attempts to implement them. Blocked tasks require manual intervention — resolving an external dependency, getting an API key provisioned, waiting for a team member's input.

/draft:statussurfaces all blocked items in a dedicated section, making them visible even if you're focused on a different part of the project. When the blocker is resolved, you manually change the marker from[!]to[ ]and resume implementation.

## Track Completion

When all tasks in all phases are marked[x], the implementation command runs a final review (if auto-review is enabled inworkflow.md), updatesplan.mdstatus to Completed, setsmetadata.jsonstatus to"completed", and moves the track from the Active section to the Completed section intracks.mdwith a completion date. The AI verifies all three files are consistent before announcing completion — if any file shows inconsistent state, it halts and reports exactly what needs manual correction.

The completed track remains in the project history. Its specification, plan, and review reports are preserved as a permanent record of what was built, why it was built, and how it was verified. This trail becomes valuable context for future tracks that touch the same areas of the codebase.
