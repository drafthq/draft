---
name: quick-review
description: "Lightweight ad-hoc code review for a PR, diff, or file. Four dimensions — security, performance, correctness, maintainability. No track context required. Use when the user asks for a 'quick review', 'review this diff', 'review this PR', or says 'eyes on this change', 'sanity-check this'."
---

# Quick Review

Perform a lightweight, ad-hoc code review. This is the fast alternative to `/draft:review` — no track context needed, focused on a specific PR, diff, or file set.

## Red Flags — STOP if you're:

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
git branch --show-current    # Current branch name
git rev-parse --short HEAD   # Current commit hash
```

Store this for the review report header. The review is scoped to this specific branch/commit.

### 1. Load Draft Context (if available)

```bash
ls draft/ 2>/dev/null
```

If `draft/` exists, read and follow `core/shared/draft-context-loading.md`. This enriches review with project patterns, guardrails, and accepted patterns from `tech-stack.md`.

If no draft context, proceed with generic review — still valuable.

## Step 1: Parse Arguments

Check for arguments:
- `/draft:quick-review` — Review staged changes (`git diff --cached`) or current branch diff
- `/draft:quick-review <file>` — Review specific file(s)
- `/draft:quick-review <PR-URL>` — Review a pull request (via GitHub MCP / `gh` CLI)
- `/draft:quick-review <commit-range>` — Review specific commits

Determine the diff to review:
1. If PR URL: fetch via GitHub MCP or `gh pr diff <num>`
2. If file path: read the file(s)
3. If commit range: `git diff <range>`
4. Default: `git diff HEAD~1..HEAD` (last commit)

## Step 2: Four-Dimension Review

Review the code across four dimensions. For each finding, cite the specific `file:line`.

### Dimension 1: Security

- Authentication/authorization gaps
- Input validation and sanitization
- SQL injection, XSS, CSRF vulnerabilities
- Secrets or credentials in code
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

## Step 3: Classify Findings

Classify each finding:

| Severity | Action | Description |
|----------|--------|-------------|
| Critical | Must fix before merge | Security vulnerabilities, data corruption risks, crashes |
| Important | Should fix | Performance issues, logic bugs, error handling gaps |
| Suggestion | Nice to have | Style improvements, refactoring opportunities, documentation |

## Step 4: Generate Review Report

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

If track-scoped, save to `draft/tracks/<id>/quick-review-<timestamp>.md`.

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
**If MCP unavailable for PR:** Fall back to local git diff. "GitHub MCP and `gh` CLI unavailable. Reviewing local diff instead."
**If no draft context:** Proceed with generic review patterns. Note: "Review enriched when draft context is available (run `/draft:init`)."
