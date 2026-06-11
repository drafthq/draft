---
name: quick-review
description: Ad-hoc PR/diff/file review. No track context needed. Four dimensions — security, performance, correctness, maintainability. Use for one-off reviews when you don't have or don't need a Draft track.
---

# Quick Review

You are performing a lightweight, ad-hoc code review. This is the fast alternative to `/draft:review` — no track context needed, focused on a specific PR, diff, or file set.

## MANDATORY GRAPH LOOKUP (read before dimension review)

When `draft/graph/schema.yaml` exists, this skill **must** follow the graph-first lookup contract in [core/shared/graph-query.md](../../core/shared/graph-query.md) §Mandatory Lookup Contract. Quick-review keeps the graph load light:

1. Always check `draft/graph/hotspots.jsonl` for every changed file (Step 2 blast-radius pre-check below).
2. If a finding spans more than one file, run `scripts/tools/graph-callers.sh --repo . --symbol <name>` to enumerate the call sites before claiming "no other usages".

Filesystem `grep` is reserved for source-text scans (literal strings, regex patterns). Symbol and caller discovery go through the graph.

## Red Flags — STOP if you're:

See [shared red flags](../../core/shared/red-flags.md) — applies to all code-touching skills.

Skill-specific:
- Reviewing without reading the code first
- Providing generic feedback not grounded in the actual code
- Missing security implications in authentication/authorization code
- Ignoring error handling paths
- Reviewing a whole module when asked for a specific file

**Read the code. Ground every finding in a specific line.**

---

## Pre-Check

### 0. Capture Git Context

Before starting, capture the current git state:

```bash
git branch --show-current # Current branch name
git rev-parse --short HEAD # Current commit hash
```

Store this for the review report header. The review is scoped to this specific branch/commit.

### 1. Load Draft Context (if available)

```bash
ls draft/ 2>/dev/null
```

If `draft/` exists, read and follow `core/shared/draft-context-loading.md`. This enriches review with project patterns, guardrails, and accepted patterns from `tech-stack.md`. Layer 0.5 of that procedure includes loading the relevant `core/guardrails/language-standards.md` section for the project stack — apply those standards in Dimension 4 (Maintainability) and Dimension 3 (Correctness) for language-specific patterns.

If no draft context, proceed with generic review — still valuable.

## Step 1: Parse Arguments

Check for arguments:
- `/draft:quick-review` — Review staged changes (`git diff --cached`) or current branch diff
- `/draft:quick-review <file>` — Review specific file(s)
- `/draft:quick-review <PR-URL>` — Review a pull request (via GitHub/GitHub MCP)
- `/draft:quick-review <commit-range>` — Review specific commits

Determine the diff to review:
1. If PR URL: fetch via GitHub MCP (`get_change_detail`, `get_change_diff`) or GitHub
2. If file path: read the file(s)
3. If commit range: `git diff <range>`
4. Default: `git diff HEAD~1..HEAD` (last commit)

## Step 2: Blast Radius Pre-check (if `draft/graph/hotspots.jsonl` exists)

Before the four-dimension review, check if any files in scope appear in `draft/graph/hotspots.jsonl`. If any file has a `fanIn` in the top 20% of the list, add this warning at the top of the review report:

```
⚠ HIGH IMPACT: {file} is a high-fanIn hotspot (fanIn={N}). Changes here propagate to many callers — review with extra care.
```

If no hotspot data exists or no file matches, skip silently.

## Step 3: Four-Dimension Review

Review the code across four dimensions. For each finding, cite the specific `file:line`.

### Dimension 1: Security

Load `core/guardrails/security.md` before this dimension. Apply the **5-step security reasoning chain** (identify goal → check hard red lines SEC-01…SEC-10 → assess blast radius → trace generative paths → classify). Any hard red line violation is automatically **Critical**.

If a violation has a `// SECURITY-OVERRIDE: <ticket> <justification>` annotation, downgrade to **Important** and include the ticket in the finding.

- Authentication/authorization gaps `[RC-005, SEC-10]`
- Input validation and sanitization `[RC-003]`
- SQL injection, XSS, CSRF vulnerabilities `[RC-002, RC-011, SEC-03]`
- Secrets or credentials in code `[RC-001, SEC-01]`
- Disabled TLS or certificate verification `[SEC-04]`
- Shell injection or unsafe subprocess calls `[SEC-06]`
- PII or credentials in log output `[RC-006, SEC-05]`
- OWASP Top 10 patterns
- Insecure deserialization

### Dimension 2: Performance

- N+1 query patterns
- Missing indexes for frequent queries
- Unnecessary allocations in hot paths
- Missing caching opportunities
- Unbounded loops or recursion
- Large payload serialization

### Dimension 3: Correctness

- Logic errors, off-by-one, null handling
- Race conditions in concurrent code
- Error handling gaps (uncaught exceptions, missing error paths)
- Edge cases not covered
- State management issues
- Contract violations (API, type, invariant)

### Dimension 4: Maintainability

- Code clarity and naming
- DRY violations (repeated logic)
- Dead code or unreachable paths
- Missing or misleading comments
- Test coverage for new logic
- Consistency with project patterns (from tech-stack.md if available)

## Step 4: Classify Findings

Classify each finding:

| Severity | Action | Description |
|----------|--------|-------------|
| Critical | Must fix before merge | Security vulnerabilities, data corruption risks, crashes |
| Important | Should fix | Performance issues, logic bugs, error handling gaps |
| Suggestion | Nice to have | Style improvements, refactoring opportunities, documentation |

## Step 5: Generate Review Report

Present findings organized by severity:

```markdown
## Quick Review: {scope description}

**Reviewer:** Draft Quick Review
**Scope:** {files/PR/commits reviewed}
**Date:** {ISO_TIMESTAMP}

### Summary
- Critical: {count}
- Important: {count}
- Suggestion: {count}

### Verdict: {PASS | PASS WITH NOTES | NEEDS CHANGES}

### Findings

#### Critical
1. **[finding title]** — `file:line`
   [description and recommendation]

#### Important
...

#### Suggestion
...

### What Went Well
[2-3 positive observations about the code — good patterns, clean logic, thorough error handling]
```

**If track-scoped, save to `draft/tracks/<id>/quick-review-<timestamp>.md`.**

Also check `core/guardrails/dependency-triage.md` if the diff modifies a dependency manifest file.

**MANDATORY: Include YAML frontmatter with git metadata when saving.** Follow `core/shared/git-report-metadata.md`.

Include the report header table immediately after frontmatter:

```markdown
| Field | Value |
|-------|-------|
| **Branch** | `{LOCAL_BRANCH}` → `{REMOTE/BRANCH}` |
| **Commit** | `{SHORT_SHA}` — {COMMIT_MESSAGE} |
| **Generated** | {ISO_TIMESTAMP} |
| **Synced To** | `{FULL_SHA}` |
```

## Mandatory Self-Check (before review report)

Before printing the review report, internally verify and report:

1. **Graph files queried** — JSONL files loaded plus any live graph query-tool invocations.
2. **Layer 1 files deliberately skipped** — list any context sections skipped.
3. **Filesystem grep fallback justification** — for every `grep`/`find` run, state the concept it searched for.

If `draft/graph/schema.yaml` does not exist, set `Graph files queried: NONE` and use justification `graph data unavailable`.

## Graph Usage Report (append to review report)

Emit the canonical footer from [core/shared/graph-usage-report.md](../../core/shared/graph-usage-report.md) §Canonical footer. The lint hook `scripts/tools/check-graph-usage-report.sh` validates the section on save.
## Cross-Skill Dispatch

- **Offered by:** `/draft:implement` at phase boundaries as lightweight alternative to full review
- **Escalates to:** `/draft:review` if critical findings require deeper analysis
- **Feeds into:** `/draft:learn` (findings update guardrails via pattern learning)
- **Suggests at completion:**
  - If many findings: "Consider running `/draft:review` for full three-stage analysis"
  - If security findings: "Consider running `/draft:deep-review` for security audit"
- **Jira sync:** If ticket linked, attach review and post summary via `core/shared/jira-sync.md`

## Error Handling

**If no diff/file found:** "No changes to review. Specify a file, PR URL, or commit range."
**If MCP unavailable for PR:** Fall back to local git diff. "GitHub/GitHub MCP unavailable. Reviewing local diff instead."
**If no draft context:** Proceed with generic review patterns. Note: "Review enriched when draft context is available (run `/draft:init`)."
