---
name: review
description: "Canonical review parent command. Runs the default three-stage review for tracks or project changes, and routes to quick-review, bughunt, deep-review, or assist-review when the user asks for explicit review depth or when the review context justifies escalation."
---

# Code Review

You are conducting a code review using Draft's Context-Driven Development methodology.

## MANDATORY GRAPH LOOKUP (read before any review stage)

When `draft/graph/schema.yaml` exists, this skill **must** follow the graph-first lookup contract in [core/shared/graph-query.md](../../core/shared/graph-query.md) §Mandatory Lookup Contract. Stage 1 (Automated Validation) **starts from the graph**:

1. Run blast-radius assessment via `scripts/tools/hotspot-rank.sh --repo .` and `scripts/tools/graph-impact.sh` (see Stage 1).
2. For each changed file with non-trivial diff size, run `scripts/tools/graph-impact.sh --repo . --file <path>` to obtain the affected module set deterministically.
3. For each public symbol modified, run `scripts/tools/graph-callers.sh --repo . --symbol <name>` to enumerate downstream callers before judging breaking-change severity.

Filesystem `grep` is reserved for source-text scans (string literals, log messages, regex matches in code) — not for discovering modules, files, or callers when the graph can answer.

## Red Flags - STOP if you're:

See [shared red flags](../../core/shared/red-flags.md) — applies to all code-touching skills.

Skill-specific:
- Reviewing without reading the track's spec.md and plan.md first
- Reporting findings without reading the actual code
- Skipping spec compliance stage and jumping to code quality
- Making up file locations or line numbers
- Claiming "no issues" without systematic analysis evidence

**Read before you review. Evidence over opinion.**

---

## Overview

This command is the **canonical review parent**.

It orchestrates review workflows at two levels:
- **Track-level:** Review against spec.md and plan.md (three-stage: automated validation, spec compliance, code quality)
- **Project-level:** Review arbitrary changes (automated validation + code quality)

Specialist review workflows remain available:

- `/draft:quick-review`
- `/draft:bughunt`
- `/draft:deep-review`
- `/draft:assist-review`

`/draft:review` should remove the burden of choosing among them when the right depth is obvious from user intent or track state.

Important semantic note:

- `/draft:impact` is **not** a review-depth mode in the current product. It measures project/track delivery telemetry, not code-change review depth. Do not route `/draft:review` to `/draft:impact`.

Automated static validation (OWASP secrets, dead code, dependency cycles, N+1 patterns) is natively built into Stage 1 of this review.

---

## Step 1: Parse Arguments

Extract and validate command arguments from user input.

### Supported Arguments

**Explicit review modes:**
- `quick` - Route to `/draft:quick-review`
- `bughunt` - Route to `/draft:bughunt`
- `deep` - Route to `/draft:deep-review`
- `assist` - Route to `/draft:assist-review`

**Scope specifiers (mutually exclusive for baseline review):**
- `track <id|name>` - Review specific track (exact ID or fuzzy name match)
- `project` - Review uncommitted changes (`git diff HEAD`)
- `files <pattern>` - Review specific file pattern (e.g., `src/**/*.ts`)
- `commits <range>` - Review commit range (e.g., `main...HEAD`, `abc123..def456`)

**Quality integration modifiers:**
- `with-bughunt` - Include `/draft:bughunt` results
- `with-assist` - Include `/draft:assist-review` summary
- `full` - Enable all sensible add-ons for the selected scope (`with-bughunt`, `with-assist`, and any justified deep-review escalation)

### Validation Rules

1. **Mode exclusivity:** At most one explicit mode among `quick`, `bughunt`, `deep`, `assist`
2. **Scope requirement:** At least one scope specifier OR no arguments (auto-detect track/project)
3. **Scope exclusivity:** Only one of `track`, `project`, `files`, `commits`
4. **Modifier normalization:** If `full` is present, enable `with-bughunt` and `with-assist`. Do not silently force `deep`; deep-review is module-scoped and must still satisfy escalation rules.

### Default Behavior

If no arguments provided:
- Auto-detect active `[~]` In Progress track from `draft/tracks.md`
- If no `[~]` track, find first `[ ]` Pending track
- If track found: display `Auto-detected track: <id> - <name> [<status>]` and proceed
- If no track is found but the repo has local changes: default to project-level review of current changes
- If no track and no changes: error "No review scope found. Specify a track, files, commit range, or create changes to review."

---

## Step 1.5: Route Explicit Modes Before Baseline Review

If the user explicitly invoked a specialist mode, route directly.

### Explicit Mode Routing

- `/draft:review quick ...` → follow `/draft:quick-review`
- `/draft:review bughunt ...` → follow `/draft:bughunt`
- `/draft:review deep ...` → follow `/draft:deep-review`
- `/draft:review assist ...` → follow `/draft:assist-review`

When routing, preserve any scope that can be mapped sensibly.

Examples:

- `/draft:review quick files "src/**/*.ts"` → quick review of those files
- `/draft:review bughunt track payments-refactor` → bughunt scoped to that track
- `/draft:review deep auth` → deep-review of the `auth` module
- `/draft:review assist track add-user-auth` → reviewer-assist summary for that track

Explicit mode always wins over automatic escalation.

If no explicit mode is present, continue with the baseline `/draft:review` workflow below.

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

2.5. **Read hld.md and lld.md (when present):**
   - `draft/tracks/<id>/hld.md` — extract §High-Level Design / Architecture, §Detailed Design (per-component subsections), §Dependencies, §Checklist (Performance/Scale/Security/Resiliency/Multi-tenancy/Upgrade/Cost), §Approvals
   - `draft/tracks/<id>/lld.md` — extract §Classes and Interfaces (signatures, invariants), §Data Model (schemas, migrations), §Error Handling, §Observability metrics
   - Store for HLD/LLD compliance pass (Stage 1.5 below)

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

**Trigger:** `project`, `files <pattern>`, `commits <range>` argument, or no active track with local changes

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

## Step 2.5: Choose Baseline Review Depth

After scope is resolved, decide whether baseline `/draft:review` should proceed as the full three-stage review or should delegate to a specialist by default.

### Routing Heuristics for Bare `/draft:review`

1. **Tiny ad-hoc scope with no track context**  
   If scope is project/files/commits and the diff is small, prefer `/draft:quick-review`.

   Good signals:
   - single file or very small file set
   - no spec/plan context available
   - user asks for a sanity check rather than a formal gate

2. **Track-complete or handoff review**  
   If the review is track-scoped and the output is likely for another reviewer or approver, attach `/draft:assist-review` unless the user explicitly opted out.

   Good signals:
   - all tasks completed
   - upload / PR / handoff language
   - `full` or `with-assist` modifier present

3. **High defect-risk changes**  
   If the diff touches high-risk surfaces, attach `/draft:bughunt`.

   Good signals:
   - auth, payments, persistence, concurrency, migrations, public API boundaries
   - hotspot / high-fanIn files
   - weak or missing tests
   - `full` or `with-bughunt` modifier present

4. **Single-module structural risk**  
   If the review scope maps cleanly to one high-risk module, attach `/draft:deep-review`.

   Good signals:
   - single module or service dominates the diff
   - structural or resilience-sensitive changes
   - high blast radius plus concurrency / durability / resiliency concerns

   If the diff spans many modules, do **not** auto-run multiple deep reviews. Instead, finish baseline review and recommend targeted deep-review follow-ups for the highest-risk modules.

### Mandatory Baseline Behavior

Even when no specialist command is attached:

- always compute and report blast radius / hotspot impact from graph data when available
- always explain which specialist workflows were auto-invoked and why

Example:

```text
Running /draft:review
- baseline three-stage review
- bughunt attached because auth and persistence paths changed
- assist-review attached because this is a completed track handoff
```

If the heuristic selects `/draft:quick-review` instead of baseline review, route there directly and stop this workflow.

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

Load plugin guardrails before scanning: `core/guardrails/review-checks.md` (RC-###), `core/guardrails/security.md` (SEC-##), and the relevant `core/guardrails/language-standards.md` section for the detected stack. `draft/guardrails.md` project rules take precedence on any conflict.

**Hard red line violations (SEC-01…SEC-10) are always Critical and block review approval.** If the violation has a `// SECURITY-OVERRIDE: <ticket> <justification>` annotation, downgrade to Important and record the ticket in the report.

**Read-before-report gate (Ground-Truth Discipline G1):** Static checks (grep, scanner output) identify *candidate* findings. Every candidate that survives to the final review report must be backed by an actual Read of the cited file in this session. A grep hit on `dangerouslySetInnerHTML` is a candidate; only after opening the file and checking surrounding context (sanitiser? test/mock file? feature flag?) does it become a reported finding. Filing findings directly from grep output is the dominant false-positive source in review skills — do not do it.

For the files changed in the diff, perform static checks using `grep` or similar tools:

- **Blast Radius Assessment** (if the `draft/graph/` snapshot exists):
   - List all changed files from the diff
   - For each changed file, check if it appears in `scripts/tools/hotspot-rank.sh --repo .` output — if yes, record its `fanIn` value
   - Classify: files with fanIn in the top 20% of the hotspot output = **HIGH IMPACT**; top 21–50% = **MEDIUM**; below 50% or not in output = **STANDARD**
   - For any file in a HIGH or MEDIUM module, query `scripts/tools/graph-arch.sh --repo . | jq '.packages[].fan_in'` (how many modules depend on this module)
   - Include a `Blast Radius` line in the Stage 1 report summary: `Blast Radius: HIGH | MEDIUM | STANDARD — <N> changed files affect high-fanIn modules: [file list]`
   - If any changed file is HIGH IMPACT: escalate Stage 3 thoroughness (check all callers of changed functions) and note this in the report header
- **Architecture Conformance:** Search for pattern violations documented in `draft/.ai-context.md`. (e.g. `import * from 'database'` in a React component).
- **Dead Code:** Check for newly exported functions/classes in the diff that have 0 references across the codebase.
- **Dependency Cycles:** Trace the import chains for new imports to ensure no circular dependencies (e.g., A → B → C → A) are introduced.
- **Graph Boundary Check** (if `draft/graph/schema.yaml` exists) `[RC-013]`:
   - For each changed file, identify its module from the graph
   - Check if any new cross-module includes were added in the diff
   - Verify they follow the established dependency direction from `scripts/tools/graph-arch.sh --repo .` package fan-in/out
   - Flag reverse-direction dependencies (module A now depends on module B, but only B→A existed before) as "Potential architecture violation — new dependency direction"
   - Check if changes introduce files in modules listed in graph cycles — flag as higher risk
- **Security Scan** `[RC-001, RC-002, RC-003, RC-011]`:
   - Hardcoded secrets and API keys `[RC-001]`
   - SQL injection risks (string concatenation in queries) `[RC-002]`
   - XSS vulnerabilities (`innerHTML` or raw DOM insertion) `[RC-011]`
   - Missing input validation at new entry points `[RC-003]`
- **Dependency Manifest Check** `[RC-014]`: If diff modifies `package.json`, `requirements.txt`, `go.mod`, `Cargo.toml`, `pom.xml`, or `build.gradle`, run the project's configured dependency vulnerability scanner (from `draft/tech-stack.md`) or recommend `npm audit` / `pip-audit` / `cargo audit` as appropriate. Include results in Stage 1 findings.
- **Performance Anti-patterns:** Scan the diff for:
   - N+1 database queries (loops containing queries)
   - Blocking synchronous I/O within async functions
   - Unbounded queries lacking pagination

- **Context-Specific Checks:** Identify the primary domain of changed files and apply domain-specific checks:

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
   - **API Endpoint changes** (files matching `controller`, `handler`, `route`, `endpoint`, `resolver`) `[RC-005, RC-012]`:
     - [ ] Backward compatibility of public signatures (no breaking param changes) `[RC-012]`
     - [ ] Input validation present for all new parameters `[RC-003]`
     - [ ] Rate limiting configured for new endpoints
     - [ ] Authentication/authorization checks in place `[RC-005]`
   - **Configuration changes** (files matching `config`, `env`, `settings`):
     - [ ] No secrets exposed in plaintext
     - [ ] Validation at startup for required config values
     - [ ] Fallback defaults provided where appropriate
   - **UI/Frontend changes** (files matching `component`, `view`, `page`, `template`):
     - [ ] No XSS vectors (`innerHTML`, `dangerouslySetInnerHTML`, `v-html`)
     - [ ] Accessibility present (ARIA attributes, keyboard navigation)
     - [ ] Performance impact considered (bundle size, render cycles)

- **Breaking Change Detection** `[RC-012]`: Check for public API changes in the diff:
    - [ ] Exported function/method signatures unchanged (no added required params, no changed return types)
    - [ ] No removed or renamed exported symbols
    - [ ] Error types and error codes unchanged
    - [ ] Serialization format preserved (JSON field names, protobuf field numbers)
    - Flag as **CRITICAL** if breaking change found with no deprecation period or version bump

- **Threat Model (STRIDE):** For new endpoints or data mutations, check:
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
| Multi-language | Semgrep (https://semgrep.dev/), CodeQL (semantic code analysis) |

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

### Stage 2.5: HLD/LLD Compliance (Track-Level Only, when hld.md exists)

**Skip if no `hld.md`** — fall through to Stage 3.

#### 2.5.1: HLD §Approvals signed

- [ ] All required approver rows have a Date populated (per `/draft:upload` Step 3.1 logic)
- [ ] If HLD was modified after the latest signed Date → flag as Critical "HLD modified after sign-off — re-circulate"

#### 2.5.2: HLD §Detailed Design coverage

For every component subsection in HLD §Detailed Design:
- [ ] Files listed in the component diff actually exist at the cited `path:line`
- [ ] Each component's `Whitebox requirements addressed` list is non-empty

#### 2.5.3: HLD §Checklist populated

For `criticality ∈ {high, mission-critical}` (frontmatter):
- [ ] §Performance, §Scale, §Security, §Resiliency, §Multi-tenancy, §Upgrade, §Cost are populated (not still "<Describe...>" placeholders)

#### 2.5.4: Code-vs-HLD drift

- [ ] Diff introduces no new modules absent from HLD §Detailed Design
- [ ] Diff introduces no new cross-module dependencies absent from HLD §Dependencies
- [ ] Diff respects HLD §Key Design Decisions (e.g., decision says "single-writer" → no new shared-write paths in code)

#### 2.5.5: LLD compliance (when lld.md exists)

- [ ] Public API additions in diff are reflected in LLD §Classes and Interfaces
- [ ] Schema/data-model changes in diff are reflected in LLD §Data Model with migration path
- [ ] Diff respects LLD invariants (thread safety, idempotency, ordering)

**Verdict:**
- PASS → Stage 3
- FAIL → list HLD/LLD gaps with severity Critical (drift) or Important (incomplete sections), then Stage 3

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

#### Adversarial Pass (mandatory when Stage 3 yields zero findings)

If Stage 3 produces zero findings across all four dimensions, do NOT accept "clean" without this gate. This pass is **mandatory**, not optional — a "zero findings" verdict that did not complete it is incomplete and must be flagged in the report.

Answer each of the 7 questions explicitly with `file:line` evidence (not "looks fine"):

1. **Error paths** — Is every error/exception handled? Are any failure modes silently swallowed? Quote the handler or note its absence.
2. **Edge cases** — Are there boundary conditions (empty input, max values, concurrent access) not covered by tests? Cite tests or note coverage gap.
3. **Implicit assumptions** — Does code assume inputs are always valid, services always up, or state always consistent? Quote the assumption site.
4. **Future brittleness** — Is anything hardcoded that will break on scale or config change? Cite the constant or flag.
5. **Missing coverage** — Is there behavior that should be tested but isn't? Name the behavior and the missing test.
6. **Guardrails** — Do any changes violate learned anti-patterns from `guardrails.md`? Cite the rule.
7. **Invariants** — Do any changes violate critical invariants documented in `.ai-context.md`? Cite the invariant.

Document the pass in the review report:
> "Adversarial pass: 7/7 answered with evidence. [one line per question with `file:line` or 'N/A — <reason>']."

A review verdict of "clean / LGTM" without this filled-in block is non-conforming and must not be emitted. Skipping the pass is a [Ground-Truth Red Flag](../../core/shared/red-flags.md) G4 violation (claim about absence-of-issues from incomplete examination).

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
- [ ] [File:line] Description of issue `[RC-### or CQ-### or SEC-## if applicable]`
  - **Impact:** [what breaks/degrades]
  - **Suggested fix:** [how to address]
```

Cite the most specific guardrail rule ID that applies. If no numbered rule covers the finding, omit the citation — the finding is still valid.

---

## Step 5: Run Specialist Integrations (Optional / Heuristic)

Run the specialist workflows selected explicitly or by the Step 2.5 heuristics.

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

### 5.2: Run Assist Review

If `with-assist`, `full`, or handoff heuristics selected assist-review:

- run `/draft:assist-review` for the same track context
- extract:
  - intent summary
  - structural edits
  - HLD/LLD drift flags
  - suggested review order

Append this as a dedicated section in the final review report rather than merging it into bug findings.

### 5.3: Run Deep Review

If deep-review escalation is justified and the scope maps to one dominant module:

- run `/draft:deep-review <module>`
- extract critical and important findings relevant to the current diff
- include a short `Deep Review Escalation` section in the report

If deep-review is recommended but not auto-run:

- add a `Next Actions` row pointing to `/draft:review deep <module>` or `/draft:deep-review <module>`

### 5.4: Aggregate Findings

Merge findings from:
1. Reviewer agent (Stage 1, 2, 3)
2. Bughunt results (if run)
3. Deep-review findings relevant to the current diff (if run)

**Deduplication:**
- Two findings are duplicates if they reference the **same file and line number**
- Severity ordering: **Critical > Important > Minor**
- On duplicate: keep the finding with highest severity; merge tool attribution as "Found by: reviewer, bughunt, deep-review" as applicable
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

- **Blast Radius:** HIGH | MEDIUM | STANDARD — [list hotspot files if HIGH/MEDIUM]
- **Architecture Conformance:** PASS/FAIL
- **Dead Code:** N found
- **Dependency Cycles:** PASS/FAIL
- **Security Scan:** N issues found
- **Dependency Vulnerabilities:** N Critical / N High (or "Clean" if scanner found none)
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
⚠️ **Warning:** This track has N incomplete tasks. Consider completing all tasks before marking track as done.

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

### Missing Draft Directory

```
Error: Draft not initialized.
Run /draft:init to set up Context-Driven Development.
```

### No Tracks Found

```
Error: No tracks found in draft/tracks.md
Run /draft:new-track to create your first track.
```

### Track Not Found

```
Error: Track 'xyz' not found.

Did you mean:
1. add-review-command
2. enterprise-readiness

Use exact track ID or run /draft:status to see all tracks.
```

### Ambiguous Match

```
Multiple tracks match 'review':
1. add-review-command - Add /draft:review Command [~]
2. review-architecture-md - Review architecture.md [x]

Select track (1-2):
```

### Invalid Git Range

```
Error: Invalid commit range 'main...feature'
Git error: fatal: ambiguous argument 'feature': unknown revision

Verify the range exists:
  git log main...feature
```

### Missing Commits in Plan

```
⚠️ Warning: No commit SHAs found in plan.md

Cannot determine commit range for review.

Options:
1. Manually specify range: /draft:review track <id> commits <range>
2. Review uncommitted changes: /draft:review project
```

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

### Explicit quick review via parent
```bash
/draft:review quick files "src/**/*.ts"
```

### Explicit deep review via parent
```bash
/draft:review deep auth
```

### Explicit assist review via parent
```bash
/draft:review assist track my-feature
```

---

## Report Closing: Next Actions (REQUIRED)

Every review report must end with a `## Next Actions` section listing the smallest set of follow-ups in execution order. Use this exact shape:

```markdown
## Next Actions

| # | Action | Owner | Blocker? | Skill / Command |
|---|---|---|---|---|
| 1 | <imperative one-liner> | <author\|reviewer\|TBD> | yes/no | `/draft:<skill> <args>` or `n/a` |
```

Rules:
- Critical findings produce blocker rows (`Blocker? = yes`); proceeding to merge is forbidden until cleared.
- Each action is imperative ("Add CSRF token to /api/transfer"), not a restatement of the finding.
- Suggest the Draft follow-up when one applies (`/draft:debug`, `/draft:regression`, `/draft:tech-debt`, `/draft:bughunt`, `/draft:adr`). Otherwise put `n/a`.
- Cap at 7 actions; if more remain, add a final row pointing at the full report.

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

## Mandatory Self-Check (before final verdict)

Before printing the final verdict, internally verify and report:

1. **Graph data queried** — which live-engine tools were invoked (e.g. `get_architecture`, `hotspot-rank.sh`, `graph-impact.sh`, `graph-callers.sh`, `cycle-detect.sh`).
2. **Layer 1 files deliberately skipped** — list any context sections skipped as irrelevant to the diff under review.
3. **Filesystem grep fallback justification** — for every `grep`/`find` run, state the concept it searched for. Source-text scans (string literals, regex matches in code) are exempt — they are not symbol/file discovery.

If `draft/graph/schema.yaml` does not exist, set `Graph files queried: NONE` and use justification `graph data unavailable`.

## Graph Usage Report (append to review report)

Emit the canonical footer from [core/shared/graph-usage-report.md](../../core/shared/graph-usage-report.md). The lint hook `scripts/tools/check-graph-usage-report.sh` validates the section on save.

## Skill Telemetry

As the last step after saving the review report, emit a metrics record. Best-effort — never block.

**Payload fields:**
```json
{
  "skill": "review",
  "track_id": "<track_id or null>",
  "stage_reached": "stage1|stage2|stage3",
  "verdict": "PASS|PASS_WITH_NOTES|NEEDS_CHANGES|FAIL",
  "critical_count": <N>,
  "important_count": <N>,
  "blast_radius": "HIGH|MEDIUM|STANDARD",
  "graph_queries": <N>,
  "fallback_grep_count": <N>
}
```

**Emit call:**
```bash
DRAFT_TOOLS="${DRAFT_PLUGIN_ROOT:-$HOME/.claude/plugins/draft}/scripts/tools"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$HOME/.cursor/plugins/local/draft/scripts/tools"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$PWD/scripts/tools"
[ -x "$DRAFT_TOOLS/emit-skill-metrics.sh" ] && bash "$DRAFT_TOOLS/emit-skill-metrics.sh" \
  '{"skill":"review","track_id":"<id_or_null>","stage_reached":"<stage>","verdict":"<v>","critical_count":<N>,"important_count":<N>,"blast_radius":"<br>","graph_queries":<N>,"fallback_grep_count":<N>}'
```
