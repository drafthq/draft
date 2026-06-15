---
name: tech-debt
description: Identify, categorize, and prioritize technical debt across seven dimensions. Generates remediation plans with effort estimates. Offered by /draft:new-track for refactor tracks.
---

# Tech Debt

You are conducting a technical debt analysis to catalog, prioritize, and plan remediation of debt across the codebase.

## MANDATORY GRAPH LOOKUP (read before debt scan)

When `draft/graph/schema.yaml` exists, this skill **must** follow the graph-first lookup contract in [core/shared/graph-query.md](../../core/shared/graph-query.md) §Mandatory Lookup Contract. Tech-debt prioritization is fundamentally driven by graph data:

1. Run `scripts/tools/hotspot-rank.sh --repo .` — **rank candidates by `fanIn × complexity`** to surface high-leverage debt first.
2. Query `scripts/tools/graph-arch.sh --repo .` and run `scripts/tools/cycle-detect.sh --repo .` — flag debt in modules involved in cycles as higher priority.
3. Run `scripts/tools/cycle-detect.sh --repo .` to enumerate dependency cycles — every cycle is a candidate architecture-debt entry.
4. For each catalogued finding, run `scripts/tools/graph-impact.sh --repo . --file <path>` so the remediation plan includes blast-radius.

Filesystem `grep` (e.g. `scan-markers.sh`) is still primary for TODO/FIXME marker discovery — markers are source-text, not graph-derived. The graph governs **prioritization**, the marker scan governs **discovery**.

## Red Flags — STOP if you're:

See [shared red flags](../../core/shared/red-flags.md) — applies to all code-touching skills.

Skill-specific:
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
git branch --show-current # Current branch name
git rev-parse --short HEAD # Current commit hash
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

Scan the codebase systematically across all seven categories. For each finding, record: location (file:line OR track id for Process Debt), description, evidence, and category.

### Category 1: Code Debt

For TODO/FIXME/HACK/XXX/DEPRECATED markers, prefer the deterministic `scan-markers.sh` wrapper — it emits JSON `[{path,line,marker,text,sha,author,introduced,age_days}]` with blame ages already computed. Resolve via the canonical tool resolver (see [core/shared/tool-resolver.md](../../core/shared/tool-resolver.md)):

```bash
DRAFT_TOOLS="${DRAFT_PLUGIN_ROOT:-$HOME/.claude/plugins/draft}/scripts/tools"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$HOME/.cursor/plugins/local/draft/scripts/tools"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$PWD/scripts/tools"
[ -x "$DRAFT_TOOLS/scan-markers.sh" ] && bash "$DRAFT_TOOLS/scan-markers.sh" --root .
# Fallback when script unavailable: grep -rn 'TODO\|FIXME\|HACK\|XXX\|DEPRECATED' .
```

Use the JSON output to prioritise: markers with `age_days > 180` are stale and should be promoted to tracked tech debt.

**Marker context gate (Ground-Truth Discipline G1):** `scan-markers.sh` produces *candidates*, not findings. Before promoting a TODO/FIXME/HACK/XXX/DEPRECATED marker to your debt catalog, **Read** the surrounding 10–20 lines at that `file:line`. Many markers are justified (intentional deferrals with ownership) or already addressed (the marker rotted, the work shipped). A debt entry whose Evidence is "marker exists" without a Read is a Ground-Truth Red Flag — produce false positives and reviewer churn.

- Complex functions (cyclomatic complexity >10, deep nesting >4 levels)
- Duplicated code blocks (>20 lines similar across multiple locations)
- TODO/FIXME/HACK/XXX comments (especially old ones — check git blame age via `scan-markers.sh` above)
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

### Category 7: Process Debt ( HLD/LLD compliance)

Scan `draft/tracks/*/` for design-process gaps. For each track:

- Read `spec.md` frontmatter `classification.criticality`. Default to `standard` if absent.
- Check for `hld.md`:
  - Missing for `criticality ∈ {standard, high, mission-critical}` → flag as Process Debt
  - Severity: `critical` for mission-critical, `high` for high, `medium` for standard
  - Remediation: "Run `/draft:decompose <track>` to generate hld.md"
- Check `hld.md` Approvals table:
  - Required rows unsigned (per `/draft:upload` Step 3.1 logic) and the track has merged commits → flag
  - Severity: `high` if criticality ∈ {high, mission-critical}, `medium` otherwise
  - Remediation: "Re-circulate hld.md to listed approvers; update Date column on sign-off"
- Check for `lld.md`:
  - Any module in HLD §Detailed Design has `Complexity: High` AND `lld.md` is missing → flag
  - Severity: `medium`
  - Remediation: "Run `/draft:decompose <track> --lld`"
- Check HLD §Checklist completeness:
  - For criticality ≥ standard: any §Checklist sub-section still showing the placeholder text "<Describe..." or empty bullets → flag as Process Debt
  - Severity: `high` for high/mission-critical, `medium` for standard
  - Remediation: "Author must populate hld.md §Checklist before /draft:deploy-checklist will pass"
- Check HLD/LLD freshness:
  - If `synced_to_commit` is older than the latest merged commit touching files in HLD §Detailed Design → flag as drift
  - Severity: `medium`
  - Remediation: "Run `/draft:decompose <track>` to refresh graph slots; review structural sections; re-circulate if signed"

Process Debt findings carry the same Impact/Effort/Risk scoring as other categories. They surface in the remediation plan alongside code/architecture debt.

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

Items requiring dedicated effort. Create via `/draft:new-track` or route via `/draft:jira` (or `/draft:plan "tech debt remediation"`).

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

## Report Closing: Next Actions (REQUIRED)

Every tech-debt report must end with a `## Next Actions` section listing the smallest set of follow-ups in execution order. Use this exact shape:

```markdown
## Next Actions

| # | Action | Owner | Blocker? | Skill / Command |
|---|---|---|---|---|
| 1 | <imperative one-liner> | <team\|TBD> | yes/no | `/draft:<skill> <args>` or `n/a` |
```

Rules:
- Tech-debt rarely "blocks" merge; mark `Blocker? = yes` only for items that will cause an outage on next deploy.
- Suggest `/draft:new-track` for items >1 day of work, `/draft:adr` for design re-decisions, `/draft:implement` for surgical cleanups.
- Cap at 10 actions; full backlog stays in the report body.

## Mandatory Self-Check (before debt report)

Before printing the final debt report, internally verify and report:

1. **Graph files queried** — JSONL files loaded plus any live graph query-tool invocations (especially `cycles` and `impact`).
2. **Layer 1 files deliberately skipped** — list any context sections skipped as irrelevant to the categories scanned.
3. **Filesystem grep fallback justification** — for every `grep`/`find` run beyond `scan-markers.sh`, name the concept it searched for.

If `draft/graph/schema.yaml` does not exist, set `Graph files queried: NONE` and use justification `graph data unavailable`.

## Graph Usage Report (append to debt report)

Emit the canonical footer from [core/shared/graph-usage-report.md](../../core/shared/graph-usage-report.md) §Canonical footer. The lint hook `scripts/tools/check-graph-usage-report.sh` validates the section on save.
## Cross-Skill Dispatch

- **Offered by:** `/draft:new-track` (refactor tracks — scope the debt before planning)
- **Suggested by:** `/draft:implement` (when TODO/FIXME detected at completion)
- **Suggested by:** `/draft:deep-review` (architecture debt findings)
- **Feeds into:** `/draft:jira` (or `/draft:plan` for remediation tracks) (create remediation tickets from Tier 2 items)
- **Feeds into:** `/draft:testing-strategy` (Test Debt findings inform test planning)
- **Jira sync:** If ticket linked, attach report and post summary via `core/shared/jira-sync.md`

## Error Handling

**If no draft context:** Run with reduced analysis, note: "Run `/draft:init` for better debt detection with accepted-pattern filtering"
**If tech-stack.md has accepted patterns:** Explicitly skip those patterns, note: "Skipped N accepted patterns from tech-stack.md"
**If >100 findings:** Group by category, show top 20 by priority in the summary, full list in Category Details section
**If module scope requested but module not found:** List available modules, ask user to confirm
