---
name: review
description: "Orchestrates multi-file code reviews at track level (against spec.md acceptance criteria) or project level (uncommitted changes, file patterns, commit ranges). Runs three stages: automated validation, spec compliance, and code quality. Optionally integrates bughunt. Use when the user asks for a code review, PR review, wants to check code quality, or validate changes against requirements."
---

# Code Review

Conduct a code review using Draft's Context-Driven Development methodology.

## Red Flags - STOP if you're:

- Reviewing without reading the track's spec.md and plan.md first
- Reporting findings without reading the actual code
- Skipping spec compliance stage and jumping to code quality
- Making up file locations or line numbers
- Claiming "no issues" without systematic analysis evidence

**Read before you review. Evidence over opinion.**

---

## Overview

This command orchestrates code review workflows at two levels:
- **Track-level:** Review against spec.md and plan.md (three-stage: automated validation, spec compliance, code quality)
- **Project-level:** Review arbitrary changes (automated validation + code quality)

Optionally integrates `/draft:bughunt` for finding logic errors and writing regression tests.
Note: Automated static validation (OWASP secrets, dead code, dependency cycles, N+1 patterns) is natively built into Phase 1 of this review.

---

## Step 1: Parse Arguments

Extract and validate command arguments from user input.

### Supported Arguments

**Scope specifiers (mutually exclusive):**
- `track <id|name>` - Review specific track (exact ID or fuzzy name match)
- `project` - Review uncommitted changes (`git diff HEAD`)
- `files <pattern>` - Review specific file pattern (e.g., `src/**/*.ts`)
- `commits <range>` - Review commit range (e.g., `main...HEAD`, `abc123..def456`)

**Quality integration modifiers:**
- `with-bughunt` - Include `/draft:bughunt` results
- `full` - Include bughunt results

### Validation Rules

1. **Scope requirement:** At least one scope specifier OR no arguments (auto-detect track)
2. **Mutual exclusivity:** Only one of `track`, `project`, `files`, `commits`
3. **Modifier normalization:** If `full` is present, enable `with-bughunt`, discarding redundant individual modifiers. No error — silently normalize.

### Default Behavior

If no arguments provided:
- Auto-detect active `[~]` In Progress track from `draft/tracks.md`
- If no `[~]` track, find first `[ ]` Pending track
- Display: `Auto-detected track: <id> - <name> [<status>]` and proceed
- If no tracks available, error: "No tracks found. Run `/draft:new-track` to create one."

---

## Step 2: Determine Review Scope

Based on parsed arguments, determine review scope and load appropriate context.

### Track-Level Review

**Trigger:** `track <id|name>` argument OR auto-detected track

#### 2.1: Resolve Track

1. **Check if argument is exact directory match:**
   ```bash
   ls draft/tracks/<arg>/ 2>/dev/null
   ```
   If exists → use this track

2. **Parse tracks.md for fuzzy matching:**
   - Read `draft/tracks.md`
   - Split by `---` separators
   - For each section, extract:
     - Track ID (from path: `./tracks/<id>/`)
     - Track name (from heading: `### <id> - <name>`)
   - Match input against:
     - Exact ID (case-insensitive)
     - Partial ID (substring)
     - Partial name (substring, case-insensitive)

3. **Handle matches:**
   - **Exact match:** Use immediately
   - **Multiple matches:** Display numbered list with format:
     ```
     Multiple tracks match '<input>':
     1. <id> - <name> [<status>]
     2. <id> - <name> [<status>]
     Select track (1-N):
     ```
     Validate selection is within 1-N range. Re-prompt on invalid input.
   - **No matches:** Error with suggestions (closest 3 by edit distance)

#### 2.2: Load Track Context

Once track is resolved:

1. **Verify track directory exists:**
   ```bash
   ls draft/tracks/<id>/ 2>/dev/null
   ```

2. **Read spec.md:**
   - Load `draft/tracks/<id>/spec.md`
   - Extract: Summary, Requirements, Acceptance Criteria, Non-Goals
   - Store for Stage 1 compliance checks

3. **Read plan.md:**
   - Load `draft/tracks/<id>/plan.md`
   - Extract commit SHAs from completed `[x]` task lines only. Match pattern: 7+ character hex strings in parentheses, regex `\(([a-f0-9]{7,})\)`. Example: `- [x] **Task 1.1:** Description (7a7dc85)`. Collect SHAs in order of appearance; deduplicate keeping first occurrence.
   - Determine commit range:
     - First commit parent: run `git rev-parse <first_SHA>^ 2>/dev/null`
     - If the parent exists: use `<first_SHA>^..<last_SHA>` as the range
     - If the parent does NOT exist (first commit in the repo — `git rev-parse` fails): use the empty tree SHA `4b825dc642cb6eb9a060e54bf8d69288fbee4904` as the range start, i.e., `4b825dc642cb6eb9a060e54bf8d69288fbee4904..<last_SHA>`. Alternatively, for single-commit ranges, use `git diff-tree --root -p <first_SHA>` to obtain the diff.
     - Last commit: `<last_SHA>`

4. **Check for incomplete work:**
   - Parse plan.md task statuses
   - Count `[ ]`, `[~]`, `[x]`, `[!]` tasks
   - If `[ ]` or `[~]` tasks exist: Display warning and proceed:
     ```
     Warning: Track has N incomplete tasks (M in-progress, K pending). Reviewing completed work only.
     ```

5. **Handle missing files:**
   - Missing spec.md: Error "spec.md not found for track <id>"
   - Missing plan.md: Warn "plan.md not found, skipping commit extraction"
   - No commits found: Warn "No commits found in plan.md, review may be incomplete"

### Project-Level Review

**Trigger:** `project`, `files <pattern>`, or `commits <range>` argument

#### 2.3: Project Scope Detection

1. **`project` argument:**
   - Scope: Uncommitted changes
   - Command: `git diff HEAD`

2. **`files <pattern>` argument:**
   - Scope: Specific files matching glob pattern
   - Command: `git diff HEAD -- <pattern>`
   - Validate pattern matches files:
     ```bash
     git ls-files <pattern> | head -1
     ```
     If empty: Error "No files match pattern '<pattern>'"

3. **`commits <range>` argument:**
   - Scope: Commit range
   - Validate range exists:
     ```bash
     git rev-parse <range> 2>/dev/null
     ```
     If fails: Error "Invalid commit range '<range>'"
   - Command: `git diff <range>`

#### 2.4: Load Project Context

For project-level reviews (no track context):

1. **Load Draft context (if available):**
   Read and follow the base procedure in `core/shared/draft-context-loading.md`.

2. **Note limitations:**
   - No spec.md → Skip Stage 1 (spec compliance)
   - Run Stage 2 (code quality) only

---

## Step 3: Generate Git Diff (Smart Chunking)

Generate diff output using smart chunking to avoid context overflow.

### 3.1: Determine Diff Size

Run shortstat to check diff size:
```bash
git diff --shortstat <range>
```

Parse output robustly — handle both singular (`1 file changed`) and plural (`N files changed`) forms. Extract numeric values for files, insertions, and deletions. Use total lines changed (insertions + deletions) for the chunking threshold.

### 3.2: Smart Chunking Strategy

**Small/Medium changes (<300 lines changed):**
- Run full diff in one pass:
  ```bash
  git diff <range>
  ```
- Store complete diff for analysis

**Large changes (≥300 lines changed):**
- Announce: "Large changeset detected (N files). Using file-by-file review mode."
- Get file list:
  ```bash
  git diff --name-only <range>
  ```
- For each file:
  - Display progress: `[N/M] Reviewing <filename>`
  - Run: `git diff <range> -- <file>`
  - Analyze immediately (don't store all)
  - Track findings in temporary structure
- Aggregate findings after all files processed

### 3.3: Filter Files (Optional)

Skip non-source files to focus review:
- Ignore lock/minified: `*.lock`, `package-lock.json`, `yarn.lock`, `*.min.js`, `*.min.css`, `*.map`
- Ignore build artifacts: `dist/`, `build/`, `target/`, `out/`, `__pycache__/`, `*.pyc`
- Ignore vendored: `node_modules/`, `vendor/`, `.git/`
- Ignore binaries: images, fonts, compiled assets
- Ignore generated files: check first 10 lines for `@generated` marker (case-insensitive, any comment syntax: `/* @generated */`, `// @generated`, `# @generated`)

---

## Step 4: Run Reviewer Agent

Apply a three-stage review process (merging static validation and semantic review).

### Stage 1: Automated Validation

**Goal:** Detect structural, security, and performance issues using fast, objective searches across the diff.

For the files changed in the diff, perform static checks using `grep` or similar tools:
1. **Architecture Conformance:** Search for pattern violations documented in `draft/.ai-context.md`. (e.g. `import * from 'database'` in a React component).
2. **Dead Code:** Check for newly exported functions/classes in the diff that have 0 references across the codebase.
3. **Dependency Cycles:** Trace the import chains for new imports to ensure no circular dependencies (e.g., A → B → C → A) are introduced.
4. **Graph Boundary Check** (if `draft/graph/module-graph.jsonl` exists):
   - For each changed file, identify its module from the graph
   - Check if any new cross-module includes were added in the diff
   - Verify they follow the established dependency direction from `module-graph.jsonl` edges
   - Flag reverse-direction dependencies (module A now depends on module B, but only B→A existed before) as "Potential architecture violation — new dependency direction"
   - Check if changes introduce files in modules listed in graph cycles — flag as higher risk
4. **Security Scan (OWASP):** Scan the diff for:
   - Hardcoded secrets and API keys
   - SQL injection risks (string concatenation in queries)
   - XSS vulnerabilities (`innerHTML` or raw DOM insertion)
5. **Performance Anti-patterns:** Scan the diff for:
   - N+1 database queries (loops containing queries)
   - Blocking synchronous I/O within async functions
   - Unbounded queries lacking pagination

6. **Context-Specific Checks:** Identify the primary domain of changed files and apply domain-specific checks:

   - **Crypto/Security changes** (files matching `auth`, `crypto`, `security`, `token`, `password`, `hash`, `encrypt`):
     - [ ] Timing-safe comparisons used (no `==` for secret comparison)
     - [ ] Constant-time operations for sensitive data
     - [ ] Secure random generation (no `Math.random()` for security)
     - [ ] Key length meets minimum requirements
   - **Database/Migration changes** (files matching `migration`, `schema`, `model`, `entity`, `repository`):
     - [ ] Backward compatibility preserved (no destructive column drops without migration path)
     - [ ] Index coverage for new queries
     - [ ] Constraint preservation (foreign keys, unique constraints)
     - [ ] Zero-downtime migration safety (no table locks on large tables)
   - **API Endpoint changes** (files matching `controller`, `handler`, `route`, `endpoint`, `resolver`):
     - [ ] Backward compatibility of public signatures (no breaking param changes)
     - [ ] Input validation present for all new parameters
     - [ ] Rate limiting configured for new endpoints
     - [ ] Authentication/authorization checks in place
   - **Configuration changes** (files matching `config`, `env`, `settings`):
     - [ ] No secrets exposed in plaintext
     - [ ] Validation at startup for required config values
     - [ ] Fallback defaults provided where appropriate
   - **UI/Frontend changes** (files matching `component`, `view`, `page`, `template`):
     - [ ] No XSS vectors (`innerHTML`, `dangerouslySetInnerHTML`, `v-html`)
     - [ ] Accessibility present (ARIA attributes, keyboard navigation)
     - [ ] Performance impact considered (bundle size, render cycles)

7. **Breaking Change Detection:** Check for public API changes in the diff:
   - [ ] Exported function/method signatures unchanged (no added required params, no changed return types)
   - [ ] No removed or renamed exported symbols
   - [ ] Error types and error codes unchanged
   - [ ] Serialization format preserved (JSON field names, protobuf field numbers)
   - Flag as **CRITICAL** if breaking change found with no deprecation period or version bump

8. **Threat Model (STRIDE):** For new endpoints or data mutations, check:
   - **S**poofing: Can the caller's identity be faked? (authentication check)
   - **T**ampering: Can request data be modified in transit? (integrity check)
   - **R**epudiation: Are actions logged for audit? (logging check)
   - **I**nformation Disclosure: Does the response leak internal details? (error message check)
   - **D**enial of Service: Can the endpoint be abused? (rate limiting, resource limits)
   - **E**levation of Privilege: Are authorization checks in place? (RBAC/ABAC check)

**Verdict:**
- **PASS:** No critical issues found → Proceed to Stage 2
- **FAIL:** ANY Critical issue found (e.g., circular dependency, hardcoded secret, raw SQL injection) → List the static analysis failures, generate the review report, and **STOP**. Do not proceed to Stage 2. This prevents wasting effort on structurally broken code.

### SAST Tool Recommendations

After completing Stage 1, recommend appropriate static analysis tools based on the project's `tech-stack.md`. Check if these tools are already configured in CI; if not, recommend adding them.

| Language | Recommended Tools |
|----------|-------------------|
| JavaScript/TypeScript | ESLint with `eslint-plugin-security`, Semgrep |
| Python | Bandit, Semgrep, pylint |
| Java | Error Prone, SpotBugs, Semgrep |
| Go | gosec, staticcheck |
| Rust | `cargo clippy`, `cargo audit` |
| C/C++ | Clang Static Analyzer, cppcheck |
| Multi-language | Semgrep (https://semgrep.dev/), CodeQL (https://codeql.github.com/) |

References: Meta Infer for CI integration patterns, Google Error Prone for compile-time analysis.

Include tool recommendations in the review report under Stage 1 as a "Recommended Tooling" subsection. Only recommend tools relevant to the languages detected in the diff.

### Stage 2: Spec Compliance (Track-Level Only)

**Skip for project-level reviews (no spec exists)**

Load `spec.md` acceptance criteria and verify implementation:

#### 4.1: Requirements Coverage

For each functional requirement in `spec.md`:
- [ ] Requirement implemented (find evidence in diff)
- [ ] Files modified/created match requirement

#### 4.2: Acceptance Criteria

For each criterion in `spec.md`:
- [ ] Criterion met (check against diff)
- [ ] Test coverage exists (if TDD enabled)

#### 4.3: Scope Adherence

- [ ] No missing features from spec
- [ ] No extra unneeded work (scope creep)

**Verdict:**
- **PASS:** All requirements implemented AND all acceptance criteria met → Proceed to Stage 3
- **PASS WITH NOTES:** All requirements met but minor gaps in acceptance criteria verification → Proceed to Stage 3 with notes
- **FAIL:** ANY requirement missing OR ANY acceptance criterion not met → List gaps, report, and stop (no Stage 3)

### Stage 3: Code Quality

**Run for both track-level (if Stage 2 passes) and project-level reviews**

Analyze semantic code quality across four dimensions:

#### 4.4: Architecture
- [ ] Follows project patterns (from tech-stack.md or CLAUDE.md)
- [ ] Appropriate separation of concerns
- [ ] Critical invariants honored (if `.ai-context.md` exists — check ## Critical Invariants section)

#### 4.5: Error Handling
- [ ] Errors handled at appropriate level
- [ ] User-facing errors are helpful
- [ ] No silent failures

#### 4.6: Testing
- [ ] Tests test real logic (not implementation details)
- [ ] Edge cases have test coverage

#### 4.7: Maintainability
- [ ] Code is readable without excessive comments
- [ ] Consistent naming and style

#### 4.8: Diff Complexity Metrics
- [ ] No functions exceeding cognitive complexity threshold (>15)
- [ ] No files with high churn + high complexity (flag as refactoring candidates)
- [ ] No deeply nested control flow (>3 levels of nesting)

For each flagged function, report: file path, function name, estimated complexity, and recommended action (split, extract, simplify).

#### Adversarial Pass (When Zero Findings)

If Stage 3 produces zero findings across all four dimensions, do NOT accept "clean" without one more look. Ask these 7 questions explicitly:

1. **Error paths** — Is every error/exception handled? Are any failure modes silently swallowed?
2. **Edge cases** — Are there boundary conditions (empty input, max values, concurrent access) not covered by tests?
3. **Implicit assumptions** — Does code assume inputs are always valid, services always up, or state always consistent?
4. **Future brittleness** — Is anything hardcoded that will break on scale or config change?
5. **Missing coverage** — Is there behavior that should be tested but isn't?
6. **Guardrails** — Do any changes violate learned anti-patterns from `guardrails.md`?
7. **Invariants** — Do any changes violate critical invariants documented in `.ai-context.md`?

If still zero after this pass, document it explicitly in the review report:
> "Adversarial pass completed. Zero findings confirmed: [one sentence per question explaining why each is clean]"

This prevents lazy LGTM verdicts. It only adds work when a reviewer claims "nothing to find."

### Issue Classification

Classify all findings by severity:

| Severity | Definition | Action |
|----------|------------|--------|
| **Critical** | Blocks release, breaks functionality, security issue | Must fix before proceeding |
| **Important** | Degrades quality, technical debt | Should fix before phase complete |
| **Minor** | Style, optimization, nice-to-have | Note for later, don't block |

**Scope-specific behavior:**
- For **track-level** reviews: Run all three stages. Stage 2 uses `spec.md` acceptance criteria loaded in Step 2.
- For **project-level** reviews: Skip Stage 2 (no spec). Run Stage 1 and Stage 3 only.

**Issue format:**
```markdown
- [ ] [File:line] Description of issue
  - **Impact:** [what breaks/degrades]
  - **Suggested fix:** [how to address]
```

---

## Step 5: Run Quality Tools (Optional)

If `with-bughunt` or `full` modifier is set, integrate bug hunting.

### 5.1: Run Bughunt

**Track-level:**
```bash
/draft:bughunt --track <id>
```

**Project-level:**
```bash
/draft:bughunt
```

Parse output from `draft/tracks/<id>/bughunt-report-latest.md` or `draft/bughunt-report-latest.md`

### 5.2: Aggregate Findings

Merge findings from:
1. Reviewer agent (Stage 1, 2, 3)
2. Bughunt results (if run)

**Deduplication:**
- Two findings are duplicates if they reference the **same file and line number**
- Severity ordering: **Critical > Important > Minor**
- On duplicate: keep the finding with highest severity; merge tool attribution as "Found by: reviewer, bughunt"
- If same severity from different tools: merge into single finding, combine descriptions

---

## Step 6: Generate Review Report

Create unified review report in markdown format.

**MANDATORY: Include YAML frontmatter with git metadata.** Follow the procedure in `core/shared/git-report-metadata.md` to gather git info, generate frontmatter, and include the report header table. Use `generated_by: "draft:review"`.

### Track-Level Report

**Path:** `draft/tracks/<id>/review-report-<timestamp>.md` (where `<timestamp>` is generated via `date +%Y-%m-%dT%H%M`, e.g., `2026-03-15T1430`)

After writing the timestamped report, create a symlink pointing to it:
```bash
ln -sf review-report-<timestamp>.md draft/tracks/<id>/review-report-latest.md
```

```markdown
[YAML frontmatter — see core/shared/git-report-metadata.md, use track_id: "<id>"]

# Review Report: <Track Title>

[Report header table — see core/shared/git-report-metadata.md]

**Track ID:** <id>
**Reviewer:** [Current model name and context window from runtime]
**Commit Range:** <first_SHA>^..<last_SHA>
**Diff Stats:** N files changed, M insertions(+), K deletions(-)

---

## Stage 1: Automated Validation

**Status:** PASS / FAIL

- **Architecture Conformance:** PASS/FAIL
- **Dead Code:** N found
- **Dependency Cycles:** PASS/FAIL
- **Security Scan:** N issues found
- **Performance:** N anti-patterns detected

[If FAIL: List critical structural issues and stop here]

---

## Stage 2: Spec Compliance

**Status:** PASS / FAIL

### Requirements Coverage
- [x] Requirement 1 - Implemented in <file:line>
- [x] Requirement 2 - Implemented in <file:line>
- [ ] Requirement 3 - **MISSING**

### Acceptance Criteria
- [x] Criterion 1 - Verified in <file:line>
- [x] Criterion 2 - Verified in <file:line>
- [ ] Criterion 3 - **NOT MET**

[If FAIL: List gaps and stop here]

---

## Stage 3: Code Quality

**Status:** PASS / PASS WITH NOTES / FAIL

### Critical Issues
[None / List with file:line]

### Important Issues
[None / List with file:line]

### Minor Notes
[None / List items]

---

[If with-bughunt or full]
## Integrations

### Bug Hunt Results
- **Critical:** N found
- **Important:** N found
- **Minor:** N found
- Full report: `./bughunt-report-latest.md`

---

## Summary

**Total Semantic Issues:** N
- Critical: N
- Important: N
- Minor: N

**Verdict:** PASS / PASS WITH NOTES / FAIL

**Required Actions:**
1. [Action item if any]
2. [Action item if any]

---

## Recommendations

[If incomplete tasks found]
⚠️  **Warning:** This track has N incomplete tasks. Consider completing all tasks before marking track as done.

[If no critical issues]
✅ **No blocking issues found.** This track is ready to merge.

[If critical issues found]
❌ **Critical issues must be resolved before proceeding.**
```

### Project-Level Report

**Path:** `draft/review-report-<timestamp>.md` (where `<timestamp>` is generated via `date +%Y-%m-%dT%H%M`, e.g., `2026-03-15T1430`)

After writing the timestamped report, create a symlink pointing to it:
```bash
ln -sf review-report-<timestamp>.md draft/review-report-latest.md
```

Similar format but:
- No Stage 2 section (no spec compliance)
- Header shows scope instead of track ID:
  - `project`: "Scope: Uncommitted changes"
  - `files <pattern>`: "Scope: Files matching '<pattern>'"
  - `commits <range>`: "Scope: Commits <range>"
- Each run creates a new timestamped file; the `-latest.md` symlink always points to the most recent report
- Include "Previous review: <timestamp>" if a prior `-latest.md` symlink exists (read its target to determine the previous timestamp)

### Report History

Previous timestamped reports are preserved. The `-latest.md` symlink always points to the most recent report.

---

## Step 7: Update Metadata (Track-Level Only)

For track-level reviews, update metadata.json with review status.

**Condition:** Always update metadata after generating the review report, regardless of verdict. This ensures review history is tracked for all outcomes (PASS, PASS_WITH_NOTES, or FAIL).

### 7.1: Read Current Metadata

Load `draft/tracks/<id>/metadata.json`

### 7.2: Add Review Fields

```json
{
  "id": "<track_id>",
  ...
  "lastReviewed": "<ISO timestamp>",
  "reviewCount": N,
  "lastReviewVerdict": "PASS" | "PASS_WITH_NOTES" | "FAIL"
}
```

Increment `reviewCount` on each review.

### 7.3: Write Updated Metadata

Save updated metadata.json

---

## Step 8: Present Results

Display summary to user with actionable next steps.

### Success Output

```
✅ Review complete: <track_id>

Report: draft/tracks/<id>/review-report-<timestamp>.md (symlink: review-report-latest.md)

Summary:
- Stage 1 (Automated Validation): PASS
- Stage 2 (Spec Compliance): PASS
- Stage 3 (Code Quality): PASS WITH NOTES
- Total semantic issues: 12 (0 Critical, 3 Important, 9 Minor)

[If full]
Additional Checks:
- Bug Hunt: 5 medium-severity findings

Verdict: PASS WITH NOTES

Recommended actions:
1. Fix 3 Important issues (see report)
2. Review 9 Minor notes for future improvements

Next: Address findings and run /draft:review again, or mark track complete.
```

### Failure Output

```
❌ Review failed: <track_id>

Report: draft/tracks/<id>/review-report-<timestamp>.md (symlink: review-report-latest.md)

Stage 1 (Automated Validation): PASS
Stage 2 (Spec Compliance): FAIL
- 3 requirements not implemented
- 2 acceptance criteria not met

Stage 3: SKIPPED (Stage 2 must pass first)

Verdict: FAIL

Required actions:
1. Implement missing requirements (see report)
2. Meet all acceptance criteria
3. Run /draft:implement to resume work

Next: Fix gaps and run /draft:review again.
```

---

## Error Handling

| Condition | Message |
|-----------|---------|
| No `draft/` directory | "Draft not initialized. Run `/draft:init`." |
| No tracks in `draft/tracks.md` | "No tracks found. Run `/draft:new-track`." |
| Track not found | Show closest matches by edit distance, suggest `/draft:status` |
| Multiple track matches | Display numbered list, prompt selection |
| Invalid git range | Show git error, suggest verifying with `git log` |
| No commit SHAs in plan.md | Suggest manual range or `/draft:review project` |

---

## Anti-Patterns

| Don't | Instead |
|-------|---------|
| Skip Stage 1 (Automated Validation) | Always run automated checks first |
| Skip Stage 2 (Spec Compliance) | Always verify spec compliance before quality checks |
| Run Stage 3 when Stage 2 fails | Fix spec gaps before quality checks |
| Ignore incomplete tasks | Warn user, suggest completing work first |
| Auto-fix issues found | Report only, let developer decide |
| Batch multiple tracks | Review one track at a time |

---

## Pattern Learning

After generating the review report, execute the pattern learning phase from `core/shared/pattern-learning.md` to update `draft/guardrails.md` with patterns discovered during this review.

---

## Examples

### Review active track
```bash
/draft:review
```

### Review specific track by ID
```bash
/draft:review track add-user-auth
```

### Review specific track by name (fuzzy)
```bash
/draft:review track "user authentication"
```

### Comprehensive track review
```bash
/draft:review track add-user-auth full
```

### Review uncommitted changes
```bash
/draft:review project
```

### Review specific files
```bash
/draft:review files "src/**/*.ts"
```

### Review commit range
```bash
/draft:review commits main...feature-branch
```

### Review with bughunt
```bash
/draft:review track my-feature with-bughunt
```

---

## Cross-Skill Dispatch

### Auto-Invoke at Completion

- **Coverage check:** If TDD enabled in workflow.md, auto-run `/draft:coverage` and include results in review report

### Suggestions at Completion

After review completion, based on findings:

**If significant code quality findings:**
```
"Review complete. Consider:
  → /draft:tech-debt — Catalog and prioritize the technical debt found"
```

**If new public APIs lack documentation:**
```
  → /draft:documentation api — Document new API endpoints"
```

**If undocumented design decisions discovered:**
```
  → /draft:adr — Record architectural decisions found during review"
```

### Jira Sync

If Jira ticket linked, sync via `core/shared/jira-sync.md`:
- Attach `review-report-latest.md` to ticket
- Post comment: "[draft] review-complete: {PASS/FAIL}. {n} findings: {critical} critical, {suggestions} suggestions."
