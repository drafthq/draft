# Chapter 13: Incremental Refresh

Part III: How Draft Thinks· Chapter 13

4 min read

Your project has been running Draft for three months. The codebase has gained two new modules, migrated from REST to GraphQL on one service, and swapped Redis for Memcached. The architecture document is now lying to the AI. You could re-run/draft:initfrom scratch — a full 5-phase analysis that re-reads every source file. Or you could run/draft:init refreshand let Draft figure out what actually changed, re-analyze only those files, and patch the existing documents. That is incremental refresh.

## The Problem: Context Goes Stale

Every document Draft generates is a snapshot. It reflects the codebase at the moment of generation, down to a specific git commit SHA recorded in the YAML frontmatter. The moment code changes after that commit, the documents start drifting from reality. A new module appears that is not in the component map. An API endpoint changes its request shape but the interface catalog still shows the old one. A dependency is removed but the dependency graph still references it.

Stale context is worse than no context. An AI operating with no context will at least read the actual code. An AI operating with stale context trusts the documentation and makes decisions based on information that is no longer true. Draft's incremental refresh exists to keep the cost of freshness low enough that teams actually do it.

## Hash-Based Change Detection

The foundation of incremental refresh isdraft/.state/freshness.json— a file containing SHA-256 hashes of every source file analyzed during the last initialization or refresh. When you run/draft:init refresh, Draft recomputes hashes of current source files and diffs against the stored baseline.

The diff produces four categories:

* Changed files— hash differs from stored. These need re-analysis.
* New files— present in current tree but not in stored baseline. New modules or components to document.
* Deleted files— present in stored baseline but not in current tree. Sections to prune.
* Unchanged files— hash matches. Skip entirely.
If all hashes match and no files were added or deleted, Draft announces that context is current and stops. No wasted analysis, no unnecessary regeneration.

File hashes provide more granularity than git diffs alone. Thesynced_to_commitfield in each document's YAML frontmatter tracks which git commit the document was last synced to. Draft usesgit diff --name-only <synced_sha> HEADto find changed files since that commit. But git diff only tells you that files changed — not whether the changes are meaningful. A file could be reformatted (content change, no semantic change) or modified in a way that does not affect architecture. File hashes provide the precise delta, while git diff provides the broader scope.

## Cross-Session Continuity

The second state file isdraft/.state/run-memory.json. It tracks what happened during the last Draft run: which phases completed, which files were analyzed, which questions remained unresolved, and where to resume if the run was interrupted.

If a previous run hasstatus: "in_progress", the next invocation detects the incomplete state and offers to resume from the last checkpoint or start fresh. This prevents partial analysis from being silently treated as complete. Unresolved questions from previous runs are surfaced again — they persist until answered.

## How Incremental Refresh Works

When you run/draft:init refresh, Draft executes this sequence:

* State-aware pre-check— Loadrun-memory.jsonto detect interrupted runs. Loadfreshness.jsonto compute file-level deltas. Loadsignals.jsonto detect signal drift (new or removed architectural concerns).
* Tech stack refresh— Re-scanpackage.json,go.mod, and other manifest files. Compare withdraft/tech-stack.mdand propose updates.
* Architecture refresh— Read thesynced_to_commitSHA from the existingarchitecture.mdfrontmatter. Get changed files since that commit. Categorize changes (added, modified, deleted, renamed). Perform targeted analysis on only the changed files.
* Section mapping— Map changed files to affected architecture sections. New files affect Component Map, Implementation Catalog, and File Structure. Modified interfaces affect API Definitions and Interface Contracts. Changed dependencies affect the Dependency Graph. New tests affect Testing Infrastructure.
* Contradiction detection— Iffacts.jsonexists, re-extract facts from changed files and compare against stored facts. Confirmed facts get updated timestamps. Contradicted facts get marked as superseded. New facts are added.
* Present diff— Show the developer which files were analyzed, which sections will be updated, and a summary of changes per section. Wait for approval.
* Apply updates— On approval, update only the affected sections. Preserve unchanged sections exactly. Regenerate.ai-context.mdfrom the updated architecture. Regenerate.ai-profile.mdwith current dynamic context.
* Persist state— Recompute and writefreshness.json(new hash baseline),signals.json(updated classification),facts.json(updated registry), andrun-memory.json(completed status).
If more than 100 files changed since the last sync, Draft recommends a full 5-phase refresh instead of incremental analysis. Too many changes mean the incremental approach loses its token-efficiency advantage — you are essentially re-analyzing most of the codebase anyway. This threshold also catches scenarios where thesynced_to_commitis far behind HEAD, such as after a major merge or long period without refresh.

## The Delta-Only Approach

The key design decision in incremental refresh is that Draft patches existing documents rather than regenerating them. Unchanged sections are preserved exactly as written. Only sections affected by changed files are rewritten. This has three benefits:

* Speed— Re-analyzing 8 changed files is dramatically faster than re-analyzing 142 files.
* Stability— Sections you have manually refined (added notes, corrected descriptions) are not overwritten by regeneration.
* Precision— Modules added by/draft:decompose(planned but not yet implemented) are preserved. They would be lost in a full regeneration that only sees what currently exists in code.
Deleted files trigger section pruning — components are removed from the map, endpoints are removed from the API catalog, dependencies are removed from the graph. Renamed files trigger reference updates. The architecture document evolves with the codebase without losing accumulated context.

## When to Run Full vs. Incremental

Incremental refresh handles day-to-day evolution: new endpoints, modified services, added tests, updated dependencies. But some changes are too structural for incremental patching:

The heuristic is straightforward: if the change affects the fundamental architecture (new paradigm, new database, new auth system), run a full init. If the change extends or modifies existing architecture, refresh is sufficient.

"After significant codebase changes" is vague. Here are concrete triggers your team should adopt:

* After merging large PRs(10+ files changed) — new modules, refactored services, or dependency updates shift the architecture context.
* At the start of each sprint or iteration— ensures all engineers begin with current context, especially after parallel work merges.
* After major refactors or architecture changes— renamed modules, extracted services, or restructured directories invalidate existing context.
* When onboarding new team members— guarantees the context they read is accurate, not a snapshot from three months ago.
* Before starting a new track— stale context means the spec intake aligns to an outdated architecture. A 10-second refresh prevents a 30-minute rework.
Context that goes stale is worse than no context — it silently misguides every AI-assisted decision. Make refresh a habit, not an afterthought.

A 100,000-line codebase with 400 source files. Full/draft:initreads all 400 files, runs 5-phase analysis, generates a completearchitecture.mdand.ai-context.md. Time: roughly 2 minutes.

Two weeks later, 12 files have changed: 3 new API endpoints, 2 modified services, 4 new tests, 2 config updates, 1 deleted utility./draft:init refreshcomputes file hashes (instant), identifies the 12-file delta, re-analyzes only those files, maps them to 4 affected sections, and patches the existing documents. Time: roughly 10 seconds.

Same result quality. One-twelfth the cost. That difference is what makes teams actually keep their context current instead of letting it rot.

## Signal Drift Detection

Beyond file-level changes, incremental refresh also tracks structural drift through signal re-classification. If your project had zero authentication files last month and now has five, that is not just "new files" — it is a new architectural concern. Draft flags signal drift separately from file changes because it has different implications: new signal categories may require generating entirely new sections ofarchitecture.md, not just updating existing ones.

The combination of file-level freshness tracking, git commit anchoring, signal drift detection, and fact contradiction analysis gives Draft a multi-layered understanding of what changed, why it matters, and exactly which parts of the documentation need updating. No more stale context. No more full regeneration. Just precise, incremental evolution.
