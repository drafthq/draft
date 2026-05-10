---
name: tech-debt
description: "Identify, categorize, and prioritize technical debt across six dimensions. Generates remediation plans with effort estimates. Offered by /draft:new-track for refactor tracks. Use when the user asks to 'analyze tech debt', 'catalog debt', 'plan debt remediation', or says 'what should we refactor', 'where is our tech debt'."
---

# Tech Debt

Conduct a technical debt analysis to catalog, prioritize, and plan remediation of debt across the codebase.

## Red Flags — STOP if you're:

- Flagging intentional design choices as debt (check tech-stack.md accepted patterns first)
- Cataloging debt without understanding the business context
- Setting priorities without considering team capacity
- Recommending "rewrite from scratch" without exhausting incremental options
- Ignoring the existing guardrails.md conventions

**Not all shortcuts are debt. Check accepted patterns before flagging.**

---

## Pre-Check

### 0. Capture Git Context

Before starting, capture the current git state:

```bash
git branch --show-current    # Current branch name
git rev-parse --short HEAD   # Current commit hash
```

Store this for the report header. All findings are relative to this specific branch/commit.

### 1. Verify Draft Context

```bash
ls draft/ 2>/dev/null
```

If `draft/` doesn't exist, this skill can still run standalone with reduced context.

### 2. Load Draft Context (if available)

Read and follow the base procedure in `core/shared/draft-context-loading.md`.

## Step 1: Parse Arguments

- `/draft:tech-debt` — Project-wide scan (default)
- `/draft:tech-debt module <name>` — Module-scoped scan
- `/draft:tech-debt category <type>` — Filter by category (code, architecture, test, dependency, documentation, infrastructure)
- `/draft:tech-debt <path>` — Scan specific directory/file pattern

## Step 2: Load Context

1. Read `draft/tech-stack.md` — **Critical:** "Accepted Patterns" section. Do NOT flag these as debt.
2. Read `draft/guardrails.md` — Learned conventions (skip) and anti-patterns (always flag)
3. Read `draft/.ai-context.md` — Module boundaries, invariants, known constraints
4. Read `draft/product.md` — Business priorities for impact assessment
5. Read `draft/workflow.md` — Team conventions and toolchain for feasibility assessment

## Step 3: Scan for Debt

Scan the codebase systematically across all six categories. For each finding, record: location (file:line), description, evidence, and category.

### Category 1: Code Debt

- Complex functions (cyclomatic complexity >10, deep nesting >4 levels)
- Duplicated code blocks (>20 lines similar across multiple locations)
- TODO/FIXME/HACK/XXX comments (especially old ones — check git blame age)
- Dead code (unreachable branches, unused exports, commented-out blocks)
- Inconsistent naming patterns within the same module
- Long functions (>100 lines without clear separation of concerns)
- God classes (>500 lines, >10 public methods, mixed responsibilities)
- Magic numbers and hardcoded strings that should be constants
- Deeply nested callbacks or promise chains (callback hell)

### Category 2: Architecture Debt

- Dependency cycles between modules (A depends on B depends on A)
- Tight coupling (modules with >5 direct cross-references)
- Layer violations (UI calling DB directly, business logic in controllers)
- Missing abstractions (repeated patterns without shared interface)
- Monolith tendencies (single module >50% of codebase)
- Inconsistent data flow patterns (some modules use events, others direct calls)
- Missing or bypassed API boundaries (internal implementation details exposed)
- Configuration scattered across multiple locations

### Category 3: Test Debt

- Modules with zero test coverage
- Missing integration tests for service boundaries
- Brittle tests (frequently failing, time-dependent, order-dependent)
- Test-code coupling (tests that break on internal refactor, not behavior change)
- Missing E2E tests for critical user flows (from product.md)
- Tests with no assertions (tests that only check "doesn't throw")
- Disabled/skipped tests without justification
- Missing test fixtures or shared test utilities (repeated setup code)

### Category 4: Dependency Debt

- Outdated dependencies (>2 major versions behind)
- Known security vulnerabilities (check advisories: `npm audit`, `pip audit`, etc.)
- Deprecated APIs in use (check dependency changelogs)
- Version conflicts or pinning issues
- Abandoned dependencies (no updates >2 years, archived repos)
- Overly broad dependency versions (no pinning in production)
- Unnecessary dependencies (functionality available in stdlib or already-included packages)

### Category 5: Documentation Debt

- Undocumented public APIs (exported functions/classes without docstrings)
- Stale README (doesn't match current setup steps or architecture)
- Missing architecture decision records for non-obvious choices
- Outdated onboarding documentation
- Missing runbooks for production services
- API docs out of sync with implementation
- Missing inline comments for complex algorithms or business rules

### Category 6: Infrastructure Debt

- Manual deployment steps (should be automated)
- Missing or insufficient monitoring (services without health checks or alerts)
- Hardcoded configuration (should be environment variables)
- Missing CI checks (linting, security scanning, type checking)
- No automated backup/restore verification
- Missing or outdated Dockerfiles / container configs
- Inconsistent environment parity (dev/staging/prod divergence)
- Missing rate limiting or resource guards on public endpoints

## Step 4: Prioritize

For each finding, score on three dimensions:

- **Impact** (1-5): How much does this hurt development velocity or production reliability?
  - 1: Minor annoyance, cosmetic
  - 2: Slows development occasionally
  - 3: Regular friction, workarounds needed
  - 4: Significant velocity drag or reliability risk
  - 5: Blocking progress or causing incidents

- **Risk** (1-5): How likely is this to cause a production incident?
  - 1: Extremely unlikely
  - 2: Unlikely but possible
  - 3: Moderate likelihood
  - 4: Likely under certain conditions
  - 5: Near-certain or already causing issues

- **Effort** (1-5): How much work to remediate?
  - 1: Hours (quick fix)
  - 2: A day or two
  - 3: A sprint (1-2 weeks)
  - 4: Multiple sprints
  - 5: Large project (months)

**Priority = (Impact + Risk) / (6 - Effort)**

Higher score = higher priority. This formula naturally favors high-impact, low-effort items ("quick wins") and deprioritizes low-impact, high-effort items.

## Step 5: Generate Remediation Plan

Organize findings into three actionable tiers:

### Tier 1: Quick Wins (Priority > 3, Effort <= 2)

Items that can be fixed in a single sprint or less. Do these first — they deliver the best return on investment.

For each item:
- Specific fix description
- Estimated time (hours)
- Suggested assignee pattern (e.g., "whoever touches this module next")

### Tier 2: Strategic Improvements (Priority > 2, Effort > 2)

Items requiring dedicated effort. Create via `/draft:new-track` or feed into `/draft:jira-preview`.

For each item:
- Scope and approach
- Estimated effort (sprints)
- Dependencies and sequencing
- Risk of deferral (what happens if we wait?)

### Tier 3: Nice-to-Haves (Priority <= 2)

Track but don't prioritize. Revisit quarterly. These items are real debt but the cost of remediation exceeds the current pain.

## Step 6: Save Output

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

Save to: `draft/tech-debt-report-<timestamp>.md`
Create symlink: `draft/tech-debt-report-latest.md`

```bash
TIMESTAMP=$(date +%Y-%m-%dT%H%M)
# Example: draft/tech-debt-report-2026-03-15T1430.md
ln -sf tech-debt-report-${TIMESTAMP}.md draft/tech-debt-report-latest.md
```

Report structure:
1. **Executive Summary** — Total findings by category and priority tier, headline stats
2. **Priority Matrix** — Table of all findings sorted by priority score
3. **Category Details** — Per-category findings with file locations and evidence
4. **Remediation Plan** — Three tiers with effort estimates
5. **Recommendations** — Strategic advice on debt management practices

## Cross-Skill Dispatch

- **Offered by:** `/draft:new-track` (refactor tracks — scope the debt before planning)
- **Suggested by:** `/draft:implement` (when TODO/FIXME detected at completion)
- **Suggested by:** `/draft:deep-review` (architecture debt findings)
- **Feeds into:** `/draft:jira-preview` (create remediation tickets from Tier 2 items)
- **Feeds into:** `/draft:testing-strategy` (Test Debt findings inform test planning)
- **Jira sync:** If ticket linked, attach report and post summary via `core/shared/jira-sync.md`

## Error Handling

**If no draft context:** Run with reduced analysis, note: "Run `/draft:init` for better debt detection with accepted-pattern filtering"
**If tech-stack.md has accepted patterns:** Explicitly skip those patterns, note: "Skipped N accepted patterns from tech-stack.md"
**If >100 findings:** Group by category, show top 20 by priority in the summary, full list in Category Details section
**If module scope requested but module not found:** List available modules, ask user to confirm
