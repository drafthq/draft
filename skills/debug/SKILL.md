---
name: debug
description: "Runs a structured debugging session: reproduces the bug, isolates the failing code path, forms and tests hypotheses one at a time, fixes with developer approval, and generates a debug report. Use when the user reports an error, crash, broken feature, exception, stack trace, or says 'not working', 'debug this', or 'investigate bug'. Invoked by /draft:new-track for bug tracks or directly for ad-hoc debugging."
---

# Debug

Conduct a structured debugging session following systematic investigation methodology.

## Red Flags — STOP if you're:

- Making code changes before reproducing the bug
- Guessing at the cause instead of tracing data/control flow
- Trying multiple fixes simultaneously ("shotgun debugging")
- Skipping reproduction steps because "I think I know the issue"
- Writing tests without asking the developer first (bug/RCA contexts)

**No fixes without root cause investigation first.**

---

## Pre-Check

### 0. Capture Git Context

Before starting, capture the current git state:

```bash
git branch --show-current    # Current branch name
git rev-parse --short HEAD   # Current commit hash
```

Store this for the debug report header. The session is scoped to this specific branch/commit.

### 1. Verify Draft Context (Optional)

```bash
ls draft/ 2>/dev/null
```

Debug can run standalone (without draft context) or within a draft track. If `draft/` exists, load context for richer investigation.

### 2. Load Draft Context (if available)

Read and follow the base procedure in `core/shared/draft-context-loading.md`.

Key context for debugging:
- `.ai-context.md` — Module boundaries, data flows, invariants (crucial for tracing)
- `tech-stack.md` — Language-specific debugging tools and techniques
- `guardrails.md` — Known anti-patterns that may be causing the issue
- `draft/graph/` (if available) — Load `module-graph.jsonl` for dependency context, `hotspots.jsonl` for complexity awareness. Use graph callers query to find all files that include a suspect file, and impact query to understand blast radius of potential fixes. See `core/shared/graph-query.md`.

## Step 1: Parse Arguments

Check for arguments:
- `/draft:debug` — Interactive: ask what's broken
- `/draft:debug <description>` — Start with the described problem
- `/draft:debug track <id>` — Debug within a specific track context (load spec.md, plan.md)
- `/draft:debug <JIRA-KEY>` — Pull context from Jira ticket via MCP

If a Jira ticket is provided:
1. Pull ticket via Jira MCP: `get_issue()`, `get_issue_description()`, `get_issue_comments()`
2. Extract: URLs, log paths, stack traces, reproduction steps, affected services
3. Use `curl`/`wget` to fetch any URLs mentioned (dashboards, error pages, API responses)
4. Use `ssh` to access log locations on remote nodes (if paths like `/home/log/`, node IPs mentioned)
5. Collect all gathered data into a triage context bundle

## Step 2: Reproduce

**Goal:** Confirm the bug exists and establish reproduction steps.

1. **Identify the symptom** — Exact error message, unexpected behavior, or performance degradation
2. **Establish reproduction steps** — Minimum steps to trigger the issue consistently
3. **Capture evidence** — Error messages, stack traces, log output (verbatim, not summarized)
4. **Classify reproducibility:**
   - Always reproducible — proceed to Step 3
   - Intermittent — document frequency, conditions, patterns (time, load, data-dependent)
   - Cannot reproduce — gather more context, check environment differences

Reference `core/agents/debugger.md` Phase 1 for detailed investigation techniques.

## Step 3: Isolate

**Goal:** Narrow the failure to a specific code path.

1. **Trace data flow** — Follow data from input to failure point, documenting each hop with `file:line` references
2. **Trace control flow** — Map the execution path, identify where it diverges from expected behavior
3. **Differential analysis** — Compare working vs failing cases:
   | Aspect | Working Case | Failing Case | Difference |
   |--------|-------------|-------------|------------|
4. **Check boundaries** — Reference `.ai-context.md` module boundaries to scope the investigation

Reference `core/agents/debugger.md` Phase 2 for language-specific debugging techniques.

## Step 4: Diagnose

**Goal:** Confirm root cause with evidence.

1. **Form hypothesis** — "The bug is caused by [X] at `file:line` because [evidence]"
2. **Predict outcome** — "If this hypothesis is correct, then [Y] should be observable"
3. **Test minimally** — Smallest possible test to prove or disprove
4. **Record result** — Document in hypothesis log:

| # | Hypothesis | Test | Prediction | Actual | Result |
|---|-----------|------|-----------|--------|--------|
| 1 | [description] | [test] | [expected] | [actual] | Confirmed/Rejected |

**If hypothesis fails:** Return to Step 3 with updated understanding. After 3 failed cycles, escalate (see Error Handling).

Reference `core/agents/debugger.md` Phase 3 and `core/agents/rca.md` for 5 Whys analysis.

## Step 5: Fix (with Developer Approval)

**Goal:** Fix the root cause with minimal change.

### Test Writing Guardrail

**STOP.** Before writing any test:
```
ASK: "Root cause confirmed: [summary]. Want me to write a regression test for this fix? [Y/n]"
```
- If accepted: write regression test first (fails before fix, passes after)
- If declined: note "Tests: developer-handled" and proceed to fix

### Fix Implementation

1. **Minimal fix** — Address root cause only, no "while we're here" improvements
2. **Stay in blast radius** — No changes to adjacent modules without explicit approval
3. **Run existing tests** — Verify no regressions
4. **Document root cause** — Add findings to Debug Report

## Step 6: Generate Debug Report

**MANDATORY: Include YAML frontmatter with git metadata.** Follow `core/shared/git-report-metadata.md`.

Include the report header table immediately after frontmatter:

```markdown
| Field | Value |
|-------|-------|
| **Branch** | `{LOCAL_BRANCH}` → `{REMOTE/BRANCH}` |
| **Commit** | `{SHORT_SHA}` — {COMMIT_MESSAGE} |
| **Generated** | {ISO_TIMESTAMP} |
| **Synced To** | `{FULL_SHA}` |
```

Save to:
- Track-scoped: `draft/tracks/<id>/debug-report.md`
- Standalone: `draft/debug-report-<timestamp>.md` with symlink `debug-report-latest.md`

```bash
TIMESTAMP=$(date +%Y-%m-%dT%H%M)
# Example: draft/debug-report-2026-03-15T1430.md
ln -sf debug-report-${TIMESTAMP}.md draft/debug-report-latest.md
```

## Cross-Skill Dispatch

- **Auto-invoked by:** `/draft:new-track` (bug tracks — Offer tier), `/draft:implement` (blocked tasks — Offer tier)
- **Invokes:** RCA agent (`core/agents/rca.md`) for 5 Whys and blast radius analysis
- **Feeds into:** `/draft:new-track` spec.md (reproduction and root cause sections via Detect+Auto-Feed)
- **Suggests at completion:**
  - "Run `git bisect` to find the exact commit that introduced this bug"
  - "Run `/draft:new-track` to create a bug fix track from these findings"
- **Jira sync:** If ticket linked, attach debug report and post summary via `core/shared/jira-sync.md`

## Error Handling

**If cannot reproduce:** Gather more context — check environment differences, ask for additional logs, check if the issue is environment-specific.
**If no draft context:** Run standalone with generic debugging methodology. Recommend `/draft:init` for richer context.
**After 3 failed hypothesis cycles:** Document all findings, list what's been eliminated, escalate — consider architectural review or external input.
**If MCP unavailable for Jira:** Skip Jira context gathering, proceed with available information.
