---
name: learn
description: Scan codebase to discover coding patterns and update draft/guardrails.md. Learns conventions (skip in future) and anti-patterns (always flag). Supports migration from workflow.md and pattern promotion.
---

# Learn — Pattern Discovery & Guardrails Update

Scan the codebase to discover recurring coding patterns and update `draft/guardrails.md` with learned conventions and anti-patterns. This improves future quality command accuracy by reducing false positives and catching known-bad patterns.

## MANDATORY GRAPH LOOKUP (read before pattern scanning)

When `draft/graph/schema.yaml` exists, this skill **must** follow the graph-first lookup contract in [core/shared/graph-query.md](../../core/shared/graph-query.md) §Mandatory Lookup Contract. Use the graph to:

1. Enumerate a module's symbols/files via `scripts/tools/graph-callers.sh`/`graph-impact.sh` and `scripts/tools/graph-arch.sh --repo .` (preferred over `find`).
2. Prioritize hotspots via `scripts/tools/hotspot-rank.sh --repo .` — patterns in high-fanIn files are more impactful when learned.
3. For TS/Python/Go/C/C++, use `*-index.jsonl` to identify class/function definitions rather than re-discovering them via regex.

Filesystem `find` for source discovery (Step 2.1) is permitted **as a complement** to the graph for languages not covered by indexes (e.g. Ruby, Java without ctags). Record the rationale in the Graph Usage Report.

## Red Flags - STOP if you're:

See [shared red flags](../../core/shared/red-flags.md) — applies to all code-touching skills.

Skill-specific:
- Writing to guardrails.md without reading the codebase first
- Learning a pattern from fewer than 3 occurrences
- Auto-promoting patterns to Hard Guardrails (requires human approval)
- Overwriting human-curated Hard Guardrails with learned patterns
- Learning patterns that contradict `tech-stack.md ## Accepted Patterns`
- Removing existing learned entries (only update or add)

**Evidence over assumptions. Quantity over anecdote.**

---

## Arguments

- No arguments — full codebase pattern scan
- `promote` — review high-confidence learned patterns and offer promotion to Hard Guardrails or Accepted Patterns
- `migrate` — migrate `## Guardrails` from `workflow.md` to `guardrails.md` (for existing projects)
- `<path>` — scan specific directory or file pattern

---

## Step 0: Verify Draft Context

```bash
ls draft/ 2>/dev/null
```

If `draft/` does not exist: **STOP** — "No Draft context found. Run `/draft:init` first."

---

## Step 1: Load Existing Guardrails

### 1.1: Check for guardrails.md

```bash
ls draft/guardrails.md 2>/dev/null
```

If it exists, read it and internalize:
- Current Hard Guardrails (checked items)
- Current Learned Conventions (existing entries)
- Current Learned Anti-Patterns (existing entries)

**Then verify core guardrails integrity (backfill if missing):**

Check if `draft/guardrails.md` contains the C++/Systems Hard Guardrails from `core/guardrails.md`. Detection: look for the marker heading `### C++/Systems — Object Lifecycle & Memory Safety`.

- **If missing AND project contains C++ code:** The file predates `core/guardrails.md`. Backfill by inserting the full C++/Systems Hard Guardrails sections from `core/templates/guardrails.md` (G1.x–G7.x, all pre-checked `[x]`) into the `## Hard Guardrails` section, after any existing general guardrails. Preserve all existing entries. Announce: "Backfilled C++/Systems Hard Guardrails (G1.x–G7.x) from core/guardrails.md into draft/guardrails.md."
- **If missing AND project has no C++ code:** Skip — these guardrails only apply to C++ projects.
- **If present:** No action — core guardrails already integrated.

### 1.2: Check for Legacy Guardrails (migration path)

If `draft/guardrails.md` does NOT exist:

1. Check `draft/workflow.md` for `## Guardrails` section
2. If found, announce: "Found guardrails in workflow.md. Creating guardrails.md and migrating."
3. Create `draft/guardrails.md` using template from `core/templates/guardrails.md`
4. Copy checked guardrail items from `workflow.md ## Guardrails` into the Hard Guardrails section
5. Add a comment in `workflow.md` where `## Guardrails` was:
   ```markdown
   ## Guardrails

   > **Migrated** — Guardrails have moved to `draft/guardrails.md`. See that file for hard guardrails, learned conventions, and learned anti-patterns.
   ```

If `migrate` argument was given, stop here after migration. Otherwise, continue to pattern scanning.

### 1.3: Load Supporting Context

Read and follow `core/shared/draft-context-loading.md` for full Draft context. Key files:
- `draft/.ai-context.md` — Module boundaries, invariants, concurrency model
- `draft/tech-stack.md` — Frameworks, accepted patterns (do not learn patterns that duplicate these)
- `draft/product.md` — Product requirements

---

## Step 2: Codebase Pattern Scan

### 2.1: Discover Source Files

```bash
# Find all source files (exclude vendored, generated, build artifacts)
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
  -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.java" \
  -o -name "*.cpp" -o -name "*.cc" -o -name "*.h" -o -name "*.hpp" \
  -o -name "*.rb" -o -name "*.php" -o -name "*.swift" -o -name "*.kt" \) \
  -not -path "*/node_modules/*" -not -path "*/vendor/*" -not -path "*/.git/*" \
  -not -path "*/dist/*" -not -path "*/build/*" -not -path "*/__pycache__/*" \
  -not -path "*/draft/*" \
  | head -500
```

If scope argument provided, filter to that path.

### 2.2: Analyze Pattern Dimensions

Scan the codebase across these dimensions, looking for **recurring patterns** (3+ occurrences):

#### Error Handling Conventions
- How errors are caught, logged, and propagated
- Custom error classes or error codes
- Try/catch patterns, error boundaries
- Retry and fallback strategies

#### Naming Conventions
- Variable, function, class naming styles beyond language defaults
- File naming patterns (kebab-case, PascalCase, etc.)
- Module/directory organization conventions

#### Architecture Patterns
- Import/dependency patterns (barrel exports, lazy loading)
- State management approaches
- API call patterns (centralized client, interceptors)
- Component composition patterns

#### Concurrency Patterns
- Async/await usage conventions
- Locking and synchronization approaches
- Queue and worker patterns
- Cancellation and timeout handling

#### Data Flow Patterns
- Validation placement (boundary vs deep)
- Serialization/deserialization conventions
- Caching strategies
- Data transformation pipelines

#### Testing Conventions
- Test file placement and naming
- Test structure (arrange/act/assert, given/when/then)
- Mock/stub conventions
- Fixture and factory patterns

#### Configuration Patterns
- Environment variable access patterns
- Feature flag patterns
- Config file conventions

### 2.3: Temporal Pattern Analysis

Detect patterns that are being phased out by the team:

1. **Identify declining patterns** — For each candidate pattern, use `git blame` to check the age of files containing it:
   - **Old files** (last modified >1 year ago): high occurrence of the pattern
   - **New files** (last modified <6 months ago): low or zero occurrence of the pattern
   - If occurrence ratio old:new is >3:1, flag as a declining pattern
2. **Mark declining patterns** — When writing to guardrails.md, add `declining: true` to the entry metadata:
   ```markdown
   - **Declining:** yes — found in 8 old files (avg age 18mo), 1 new file (avg age 2mo). Being replaced by [newer pattern].
   ```
3. **Do NOT propagate declining patterns** — Quality commands should not flag absence of a declining pattern as inconsistency
4. **Example:** Old error handling style `try/catch with manual logging` found in files last modified >1 year ago, newer files use structured error middleware — the old style is declining, not a convention to enforce

**Reference:** Google large-scale changes (Rosie) — systematic detection of patterns being migrated away from.

### 2.4: Cross-Service Pattern Comparison (Monorepo)

When in a monorepo (detected by `draft/service-index.md` existing OR multiple `draft/` directories OR presence of `packages/`, `services/`, `apps/` directories):

1. **Scan across services** — Run pattern analysis in each service/package independently
2. **Compare patterns for the same concern** — For each pattern dimension (error handling, naming, etc.):
   - Does Service A use a different approach than Service B for the same concern?
   - Example: Service A uses `Result<T, E>` for error handling, Service B uses exceptions
3. **Flag inconsistencies** — Report cross-service divergences:
   ```
   Cross-service inconsistency: Error Handling
     services/auth/ → uses custom Result type (5 files)
     services/billing/ → uses thrown exceptions (8 files)
     Suggestion: standardize on one approach
   ```
4. **Respect intentional differences** — Do NOT flag inconsistencies when:
   - Services use different languages or frameworks
   - The pattern difference is documented in `tech-stack.md` or `.ai-context.md`
   - The services have fundamentally different runtime requirements

**Reference:** Google monorepo practices — consistent patterns across services reduce cognitive overhead and enable large-scale tooling.

### 2.5: Cross-Reference Existing Knowledge

For each candidate pattern:

1. **Check `tech-stack.md ## Accepted Patterns`** — if already documented there, skip (no duplication)
2. **Check existing `guardrails.md` entries** — if already learned, update evidence count and date
3. **Check `.ai-context.md`** — if described as architecture, skip (it's documented)
4. **Verify consistency** — sample 3+ instances and confirm they follow the same approach

---

### 2.6: Git History Signal Mining

Mine git commit history for pattern signals that code scanning misses. Run only if the project is a git repository.

```bash
git log --oneline --no-merges -500
```

Scan the output for recurring message patterns (3+ occurrences of the same type):

| Commit pattern | Signal |
|---------------|--------|
| `fix: don't X` / `fix: never X` | Team keeps violating X → anti-pattern candidate |
| `refactor: replace X with Y` | X is declining, Y is the replacement → mark X as `declining: true` |
| `chore: enforce X` / `chore: add X check` | X is being formalized → convention candidate |
| `revert: ` followed by same topic 3+ times | That topic is consistently problematic → anti-pattern candidate |

**Rules:**
- Do NOT add git-only signals as standalone entries. Use them only to adjust confidence of patterns already found in Step 2.2.
- If a pattern appears in both commit history AND code (3+ occurrences): increase confidence by one level.
- If a pattern appears only in commit history but not in current code: note as `historically_recurring: true` — do not add as active anti-pattern.

**Recency weighting** — for each candidate pattern from Step 2.2, check when the files containing it were last modified:

```bash
git log --follow --oneline -1 -- {file_containing_pattern}
```

- Modified within 90 days AND pattern persists → add `recently_active: true` to the entry
- Not modified in 12+ months → add `stale: true` — lower enforcement priority

---

### 2.7: Graph-Aware Severity Enrichment

If `draft/graph/schema.yaml` exists (engine live), derive objective severity for all anti-pattern candidates based on the fanIn of files where the pattern was found via `scripts/tools/hotspot-rank.sh --repo .`.

For each anti-pattern candidate from Step 2.2:
1. Check if any evidence files appear in the hotspot output from `scripts/tools/hotspot-rank.sh --repo .`
2. Take the highest fanIn value across all evidence files:
   - fanIn ≥ 10 → `graph_severity: critical` (breakage propagates to many callers)
   - fanIn 5–9 → `graph_severity: high`
   - fanIn 1–4 → `graph_severity: medium`
   - fanIn 0 or file not in hotspot output → `graph_severity: low`
3. If no graph data exists → `graph_severity: unresolved`

Collect all evidence files with fanIn ≥ 5 for the `high_fanin_files` field.

When `graph_severity` differs from the subjectively assigned `severity`, use `graph_severity` as the enforcement priority in quality commands — it is objective and reproducible.

---

## Step 3: Apply Confidence Threshold

Follow the threshold from `core/shared/pattern-learning.md`:

| Evidence | Confidence | Action |
|----------|------------|--------|
| Found 1-2x | — | Skip (insufficient data) |
| Found 3-5x, all consistent | `medium` | Learn as convention or anti-pattern |
| Found >5x, all consistent, cross-verified | `high` | Learn + flag as promotion candidate |
| Found >5x but inconsistent | — | Do NOT learn (investigate inconsistency) |

**Consistency-claim ground-truth gate (Ground-Truth Discipline G1, G4):** "Consistent" and "cross-verified" require you to have **Read** at least 3 of the instances in this session (5 if claiming `high`). A grep match count is not consistency proof — variant call sites can use the same identifier with different semantics. List the file:line of each Read instance in the learned-pattern record under §Evidence. A `medium` or `high` entry whose Evidence list shows only grep counts is a Red Flag and must be downgraded or discarded.

### Distinguishing Conventions from Anti-Patterns

- **Convention:** Pattern is consistently applied AND does not cause bugs, security issues, or violations of documented invariants
- **Anti-Pattern:** Pattern is consistently applied BUT causes or risks bugs, security issues, performance problems, or invariant violations

---

## Step 3.5: Pattern Conflict Detection

Before saving any new pattern, check for conflicts with existing entries:

1. **Check against existing conventions** — Does the new pattern contradict a learned convention?
2. **Check against existing anti-patterns** — Does the new pattern contradict a learned anti-pattern?
3. **Check against Hard Guardrails** — Does the new pattern violate a hard guardrail?

**If conflict found:**
- Do NOT silently save the new pattern
- Alert the user with both patterns side by side:
  ```
  CONFLICT DETECTED:

  Existing convention: "Use async/await for all async operations"
    Evidence: 12 files, high confidence, learned 2025-01-15

  New candidate: "Avoid async in database module — use callback style"
    Evidence: 4 files in src/db/, medium confidence

  These may both be valid (module-scoped exception) or one may be outdated.
  Options:
    [1] Keep both (new pattern is a scoped exception)
    [2] Replace existing with new (pattern has evolved)
    [3] Discard new (existing is correct)
  ```
- Wait for user input before proceeding

**Reference:** Google Code Health — conflicting patterns create confusion and should be resolved explicitly.

---

## Step 3.7: External Benchmark Comparison

After discovering patterns, optionally compare project conventions against community standards for the detected language:

| Language | Benchmarks |
|----------|-----------|
| **Go** | Effective Go, Go Code Review Comments |
| **Python** | PEP 8, PEP 20, Google Python Style Guide |
| **Java** | Effective Java, Google Java Style Guide |
| **TypeScript** | typescript-eslint recommended rules |
| **Rust** | Rust API Guidelines, Clippy lints |
| **C/C++** | Google C++ Style Guide, C++ Core Guidelines |

For each project convention that **deviates** from its language's community standard:
1. Note the deviation in the summary report (not as an anti-pattern — deviations may be intentional)
2. If the deviation is undocumented, suggest adding it to `tech-stack.md ## Accepted Patterns` with a rationale
3. Example: project uses `snake_case` for TypeScript functions (deviates from `camelCase` convention) — flag for documentation, not correction

**Reference:** Google Abseil Tips of the Week, language-specific style guides — deviations from community standards increase onboarding friction and should be documented even when intentional.

---

## Step 4: Update guardrails.md

Follow the write procedure in `core/shared/pattern-learning.md`:

1. Read current `draft/guardrails.md`
2. For each new pattern: check for duplicates, then append
3. For existing patterns: update evidence count, confidence, `last_verified`
4. Update `draft/metadata.json` with current git state (use `git-metadata.sh --project-metadata --generated-by "draft:learn"` or update `git.commit`, `git.commit_message`, and `synced_to_commit` manually) — `guardrails.md` frontmatter carries only stable fields per WS-8

**Cap enforcement:** Maintain a maximum of 50 learned entries per section. If at capacity, replace the oldest `medium` confidence entry that has not been re-verified in 90+ days (per `core/shared/pattern-learning.md`).

### Entry Format — Convention

```markdown
### [Pattern Name]
- **Category:** error-handling | naming | architecture | concurrency | state-management | data-flow | testing | configuration
- **Confidence:** high | medium
- **Evidence:** Found in N files — `path/file1.ext:line`, `path/file2.ext:line`, `path/file3.ext:line`
- **Discovered at:** YYYY-MM-DD (when Draft first observed this pattern)
- **Established at:** YYYY-MM-DD (when the pattern entered the codebase, via git blame)
- **Last verified:** YYYY-MM-DD
- **Last active:** YYYY-MM-DD (when source files containing this pattern were last modified)
- **Discovered by:** draft:learn on YYYY-MM-DD
- **Description:** [What the pattern is and why it's intentional]
```

### Entry Format — Anti-Pattern

```markdown
### [Anti-Pattern Name]
- **Category:** security | reliability | performance | correctness | concurrency
- **Severity:** critical | high | medium
- **graph_severity:** critical | high | medium | low | unresolved (fanIn-derived from Step 2.7; "unresolved" if no graph data)
- **high_fanin_files:** `path/file.go` (fanIn:12), `path/other.go` (fanIn:7) (omit line if none meet fanIn ≥ 5)
- **Evidence:** Found in N files — `path/file1.ext:line`, `path/file2.ext:line`
- **Discovered at:** YYYY-MM-DD (when Draft first observed this pattern)
- **Established at:** YYYY-MM-DD (when the pattern entered the codebase, via git blame)
- **Last verified:** YYYY-MM-DD
- **Last active:** YYYY-MM-DD (when source files containing this pattern were last modified)
- **recently_active:** true | false (true if any evidence file modified within 90 days)
- **stale:** true | false (true if all evidence files unmodified for 12+ months)
- **Discovered by:** draft:learn on YYYY-MM-DD
- **Description:** [What the pattern is and why it's problematic]
- **Suggested fix:** [Brief description of the correct approach]
```

---

## Step 5: Promotion Workflow (when `promote` argument given)

Review all learned patterns with `confidence: high` and present promotion candidates:

```
Pattern promotion candidates:

1. [Convention] "Centralized API client pattern" (high confidence, 12 files)
   → Promote to: tech-stack.md ## Accepted Patterns? [y/n]

2. [Convention] "Error boundary at route level" (high confidence, 8 files)
   → Promote to: Hard Guardrail (enforce always)? [y/n]

3. [Anti-Pattern] "Unguarded .env access" (high confidence, 6 files)
   → Promote to: Hard Guardrail (enforce always)? [y/n]
```

For each promoted pattern:
- **Convention → Accepted Pattern**: Append to `draft/tech-stack.md ## Accepted Patterns` and remove from guardrails.md Learned Conventions
- **Convention → Hard Guardrail**: Move from Learned Conventions to Hard Guardrails section (as checked `[x]` item)
- **Anti-Pattern → Hard Guardrail**: Move from Learned Anti-Patterns to Hard Guardrails section (as checked `[x]` item)

---

## Step 6: Generate Summary Report

Display results to the user:

```
/draft:learn complete

Scanned: N source files across M directories
Duration: ~Xs

Results:
  New conventions learned: N [list names]
  New anti-patterns learned: N [list names]
  Existing patterns updated: N [list names]
  Skipped (insufficient data): N
  Skipped (already documented): N

Promotion candidates (high confidence):
  N patterns ready for promotion — run /draft:learn promote to review

Updated: draft/guardrails.md
```

---

## How Quality Commands Use guardrails.md

After `/draft:learn` populates guardrails.md, all quality commands automatically:

| Section | Quality Command Behavior |
|---------|------------------------|
| **Hard Guardrails** (checked) | Flag violations as issues |
| **Learned Conventions** | Skip these patterns during analysis (not bugs) |
| **Learned Anti-Patterns** | Always flag these patterns as bugs |
| **Unchecked Hard Guardrails** | Ignore (not enforced) |

This creates a **continuous improvement loop**:
1. Quality command runs → discovers patterns → updates guardrails.md
2. Next quality command run → reads updated guardrails.md → fewer false positives, catches known-bad patterns
3. `/draft:learn promote` → graduates stable patterns to permanent status

---

## Anti-Patterns

| Don't | Instead |
|-------|---------|
| Learn from <3 occurrences | Require minimum 3 consistent instances |
| Auto-promote to Hard Guardrails | Always require human approval for promotion |
| Overwrite human-curated entries | Learned patterns complement, never replace |
| Learn framework defaults as conventions | Only learn project-specific patterns |
| Remove entries on re-scan | Update evidence/dates, never delete |
| Learn from test/mock code | Focus on production source code |

## Mandatory Self-Check (before completion summary)

Before printing the completion summary, internally verify and report:

1. **Graph files queried** — JSONL files loaded plus any live graph query-tool invocations.
2. **Layer 1 files deliberately skipped** — list any context sections skipped.
3. **Filesystem find/grep fallback justification** — for every `find`/`grep` run for source discovery, state which languages or extensions were not covered by the graph indexes (e.g. Ruby without ctags).

If `draft/graph/schema.yaml` does not exist, set `Graph files queried: NONE` and use justification `graph data unavailable`.

## Graph Usage Report (append to completion summary)

Emit the canonical footer from [core/shared/graph-usage-report.md](../../core/shared/graph-usage-report.md) §Canonical footer. The lint hook `scripts/tools/check-graph-usage-report.sh` validates the section on save.
