---
name: coverage
description: Compute code coverage for active track or module. Targets 95%+ coverage with report and justification for uncovered lines. Complements TDD workflow.
---

# Coverage Report

Compute and report code coverage for the active track or a specific module. This complements the TDD workflow — TDD is the process (write test, implement, refactor), coverage is the measurement (how much code do those tests exercise).

## Red Flags - STOP if you're:

- Reporting coverage without actually running the coverage tool
- Making up coverage percentages
- Skipping uncovered line analysis
- Not presenting the report for developer approval
- Treating this as a replacement for TDD (it's not — TDD stays in `/draft:implement`)

---

## Step 1: Load Context

1. Read `draft/tech-stack.md` for test framework and language info
2. Find active track from `draft/tracks.md`
3. If track has `architecture.md` (track-level) or project has `.ai-context.md`, identify current module for scoping
4. Look for `coverage_target` in `draft/workflow.md`. Check for per-module targets first (see Per-Module Coverage Enforcement below); if absent, default to 95%.
5. Check if `draft/tracks/<id>/bughunt-report-latest.md` (track scope) or `draft/bughunt-report-latest.md` (project scope) exists for cross-referencing (see Coverage-Bughunt Cross-Reference below)

If no active track and no argument provided:
- Tell user: "No active track. Provide a path or track ID, or run `/draft:new-track` first."

## Step 2: Detect Coverage Tool

Auto-detect from tech stack:

| Language | Coverage Tools |
|----------|---------------|
| JavaScript/TypeScript | `jest --coverage`, `vitest --coverage`, `c8`, `nyc` |
| Python | `pytest --cov`, `coverage run`, `coverage.py` |
| Go | `go test -coverprofile=coverage.out` |
| Rust | `cargo tarpaulin`, `cargo llvm-cov` |
| C/C++ | `gcov`, `lcov` |
| Java/Kotlin | `jacoco`, `gradle jacocoTestReport` |
| Ruby | `simplecov` |

**Detection order:**
1. Check `tech-stack.md` for explicit testing section
2. Check config files (`jest.config.*`, `vitest.config.*`, `pytest.ini`, `setup.cfg`, `pyproject.toml`, `.nycrc`)
3. Check `package.json` scripts for coverage commands
4. If not detectable, ask the developer which tool and command to use

## Step 3: Determine Scope

**Priority order:**
1. If argument provided (path or module name): use as scope filter
2. If track has `architecture.md` (or project has `.ai-context.md`) with an in-progress module: scope to that module's files
3. If active track exists: scope to files changed in the track (use `git diff` against base branch)
4. Fallback: run coverage for entire project

Build the coverage command with the appropriate scope/filter flags.

## Step 4: Run Coverage

1. Execute the coverage command. Request machine-readable output when possible: `--json` for Jest, `--cov-report=json` for pytest, `-coverprofile` for Go, `--coverage-output-format json` for dotnet.
2. Capture full output
3. If command fails:
   - Check if dependencies are installed (test framework, coverage plugin)
   - Suggest installation command
   - Ask developer to fix and retry

## Step 5: Parse and Present Report

Parse coverage output and present in a standardized format:

```
═══════════════════════════════════════════════════════════
                     COVERAGE REPORT
═══════════════════════════════════════════════════════════
Track: [track-id]
Module: [module name, if applicable]
Target: [from workflow.md, default 95%]

SUMMARY
─────────────────────────────────────────────────────────
Overall: 87.3% (target: 95%)  ← BELOW TARGET

PER-FILE BREAKDOWN
─────────────────────────────────────────────────────────
src/auth/middleware.ts    96.2%  PASS
src/auth/jwt.ts           72.1%  FAIL
src/auth/types.ts        100.0%  PASS

UNCOVERED LINES
─────────────────────────────────────────────────────────
src/auth/jwt.ts:45-52    Error handler for malformed token
src/auth/jwt.ts:78       Defensive null check (unreachable via public API)

═══════════════════════════════════════════════════════════
```

## Step 6: Branch/Condition Coverage (Optional)

If the project's test framework supports branch/condition coverage (e.g., Istanbul, coverage.py branch mode), execute this step. Otherwise skip to Step 7.

Beyond line coverage, evaluate branch coverage for modules with complex conditional logic:

1. **When to apply:** If the module contains nested conditionals, switch statements, or complex boolean expressions, line coverage alone is insufficient. 100% line coverage can miss untested branches in complex if/else/switch logic.
2. **Branch coverage** measures whether every branch of every decision point has been exercised. Enable it with the appropriate flag:
   - Jest/Vitest: `--coverage --coverageReporters=json-summary` (branch data included by default)
   - pytest: `--cov --cov-branch`
   - Go: `go test -covermode=count` (counts execution per branch)
   - JaCoCo: branch coverage reported by default
   - lcov/gcov: `--rc lcov_branch_coverage=1`
3. **MC/DC (Modified Condition/Decision Coverage)** — For safety-critical modules (auth, payments, crypto), recommend MC/DC analysis. MC/DC requires that each condition in a decision independently affects the outcome. This is the standard in DO-178C (avionics) and referenced in ISTQB Advanced Test Analyst syllabi.
   - Present MC/DC gaps separately from standard branch coverage gaps
   - Flag any boolean expression with 3+ conditions as an MC/DC candidate

Include branch coverage percentage in the report alongside line coverage when branch analysis is performed.

## Step 7: Analyze Gaps

For files below target (using per-module targets when configured — see Per-Module Coverage Enforcement):

1. **Identify uncovered lines** - List specific line ranges and what they contain
2. **Classify each gap:**
   - **Testable** - Can and should be covered. Suggest specific test to write.
   - **Defensive** - Assertions, error handlers for impossible states. Acceptable to leave uncovered.
   - **Infrastructure** - Framework boilerplate, main entry points. Usually acceptable.
   - **Legacy/Brownfield** - Modules with 0% or very low coverage that need refactoring. Apply Characterization Testing (see below).
3. **Suggest tests** for testable gaps:
   ```
   SUGGESTED TESTS
   ─────────────────────────────────────────────────────────
   1. Test malformed JWT token handling (jwt.ts:45-52)
      - Input: token with invalid signature
      - Expected: throws AuthError with code INVALID_TOKEN

   2. Test expired token rejection (jwt.ts:60-65)
      - Input: token with exp in the past
      - Expected: throws AuthError with code TOKEN_EXPIRED
   ```

## Step 7b: Characterization Testing (Brownfield/Legacy Code)

When encountering modules with 0% or very low coverage that need refactoring, do not attempt to write unit tests for untested legacy code directly. Instead, apply the Golden Master / Approval Testing approach (ref: Michael Feathers, "Working Effectively with Legacy Code"):

1. **Create Golden Master baselines** — Generate fixed-seed inputs that exercise the module's public interface. Capture all outputs (return values, side effects, logs) as the approved baseline.
2. **Lock behavior with approval tests** — Any change that alters the captured output triggers a test failure, making the current behavior explicit and protected.
3. **Refactor under Golden Master safety net** — With approval tests guarding against regressions, refactor the module incrementally.
4. **Write proper unit tests via TDD during refactoring** — As you extract and clarify logic, write focused unit tests using RED → GREEN → REFACTOR.
5. **Remove approval tests** — Once proper unit test coverage meets the target, retire the Golden Master tests.

**Tool references:**
- ApprovalTests (https://approvaltests.com/) — available for Java, C#, Python, JS, and more
- Verify (.NET) — snapshot testing library

Present characterization testing recommendations in the gap analysis when applicable.

## Step 7c: Mutation Testing Awareness

After measuring line coverage (and branch coverage if applicable), prompt the engineer to consider mutation testing for critical modules. Mutation testing introduces small code changes (mutants) into the source; if existing tests still pass, the mutant "survived," indicating weak test assertions even at high line coverage.

**When to recommend:** Modules at 90%+ line coverage that are high-risk (auth, payments, crypto, data persistence) or where past bugs have occurred. Mutation testing is most valuable when line coverage is already high but test quality is uncertain.

**Mutation score** = killed mutants / total non-equivalent mutants. Target: 80%+ for critical modules.

**Tool recommendations by language:**

| Language | Tool | Reference |
|----------|------|-----------|
| Java | PIT | https://pitest.org/ |
| JavaScript/TypeScript | Stryker | https://stryker-mutator.io/ |
| Python | mutmut | https://github.com/boxed/mutmut |
| Rust | cargo-mutants | https://github.com/sourcefrog/cargo-mutants |
| C# | Stryker.NET | https://stryker-mutator.io/ |
| Go | go-mutesting | https://github.com/zimmski/go-mutesting |

**Reference:** Google's mutation testing program is used by 6,000+ engineers and processes approximately 30% of all code diffs, validating that mutation testing scales to large codebases.

Include mutation testing recommendations in the report when applicable, but do not block coverage completion on mutation analysis — it is advisory.

## Step 7d: Coverage-Bughunt Cross-Reference

If a bughunt report exists (`draft/tracks/<id>/bughunt-report-latest.md` or `draft/bughunt-report-latest.md`):

1. **Parse bughunt findings** — Extract file paths and line ranges of confirmed or suspected bugs.
2. **Cross-reference with uncovered code paths** — Identify bughunt findings that fall in uncovered lines.
3. **Flag as highest-priority test gaps** — Confirmed bugs in uncovered code are the most dangerous gaps. Present them prominently:
   ```
   BUGHUNT CROSS-REFERENCE
   ─────────────────────────────────────────────────────────
   ⚠ CRITICAL: Bug "Race condition in session refresh" (bughunt #3)
     at src/auth/session.ts:112-118 — IN UNCOVERED CODE
     → Write a test that exposes this bug FIRST before fixing

   ⚠ HIGH: Bug "Missing null check on user lookup" (bughunt #7)
     at src/users/repository.ts:45 — IN UNCOVERED CODE
     → Write a regression test targeting this path
   ```
4. **Prioritize suggested tests** — Tests that cover bughunt-flagged code should appear first in the SUGGESTED TESTS section.

## Per-Module Coverage Enforcement

Instead of applying a single global coverage target, support differentiated targets by module risk level. Check `draft/workflow.md` for a `coverage_targets` section:

```yaml
# Example workflow.md configuration
coverage_targets:
  high_risk: 95    # auth, payments, crypto, data persistence
  business_logic: 85
  infrastructure: 70
  generated: exclude
  modules:
    src/auth/: high_risk
    src/payments/: high_risk
    src/crypto/: high_risk
    src/db/: high_risk
    src/api/handlers/: business_logic
    src/utils/: infrastructure
    src/generated/: generated
```

**If no per-module configuration exists**, apply these defaults and inform the developer:

| Risk Level | Target | Applies To |
|------------|--------|------------|
| High-risk | 95%+ | Auth, payments, crypto, data persistence modules |
| Business logic | 85%+ | Core domain logic, API handlers |
| Infrastructure | 70%+ | Utilities, glue code, configuration |
| Generated | Exclude | Auto-generated code, proto stubs, ORM models |

**Classification heuristic:** Infer module risk from directory names and file content when explicit configuration is absent. Flag the inferred classification in the report so the developer can correct it.

In the coverage report, show per-module targets alongside actual coverage:
```
PER-FILE BREAKDOWN (module-level targets)
─────────────────────────────────────────────────────────
src/auth/middleware.ts    96.2%  [high_risk: 95%]    PASS
src/auth/jwt.ts           72.1%  [high_risk: 95%]    FAIL
src/utils/logger.ts       75.0%  [infrastructure: 70%]  PASS
src/generated/api.ts       —     [generated: excluded]
```

## Step 8: Developer Review

### CHECKPOINT (MANDATORY)

**STOP.** Present the full coverage report and gap analysis.

Ask developer:
- Accept current coverage? (if at or above target)
- Write additional tests for testable gaps?
- Justify and document acceptable uncovered lines?
- Adjust coverage target for this track?

**Wait for developer approval before recording results.**

## Step 9: Record Results

After developer approves:

1. **Update plan.md** - Add coverage note to the relevant phase:
   ```markdown
   **Coverage:** 96.2% (target: 95%) - PASS
   - Uncovered: defensive null checks in jwt.ts (justified)
   ```

2. **Update architecture context** — update the project-level `draft/architecture.md` with coverage data (not a track-level architecture file), then run the Condensation Subroutine (defined in `core/shared/condensation.md`) to regenerate `draft/.ai-context.md`. The Condensation Subroutine only applies to the project-level `draft/architecture.md` → `draft/.ai-context.md` pipeline:
   ```markdown
   - **Status:** [x] Complete (Coverage: 96.2%)
   ```

3. **Update metadata.json** - Add coverage field if not present:
   ```json
   {
     "coverage": {
       "overall": 96.2,
       "target": 95,
       "timestamp": "2025-01-15T10:30:00Z"
     }
   }
   ```

4. **Write detailed coverage report** to `draft/tracks/<id>/coverage-report-<timestamp>.md` (where `<timestamp>` is generated via `date +%Y-%m-%dT%H%M`, e.g., `2026-03-15T1430`) with YAML frontmatter (include `project`, `track_id`, `generated_by: "draft:coverage"`, `generated_at`, `git` metadata matching other skills) and timestamped entries for historical tracking.

   After writing the timestamped report, create a symlink pointing to it:
   ```bash
   ln -sf coverage-report-<timestamp>.md draft/tracks/<id>/coverage-report-latest.md
   ```

   Previous timestamped reports are preserved. The `-latest.md` symlink always points to the most recent report.

## Completion

Announce:
```
Coverage report complete.

Overall: [percentage]% (target: [target]%)
Status: [PASS / BELOW TARGET]
Files analyzed: [count]
Gaps documented: [count testable] testable, [count justified] justified

Report: draft/tracks/<id>/coverage-report-<timestamp>.md (symlink: coverage-report-latest.md)

Results recorded in:
- plan.md (phase notes)
- architecture.md → .ai-context.md (module status, via Condensation Subroutine) [if applicable]
- metadata.json (coverage data)
```

## Re-running Coverage

When coverage is run again on the same track/module:
1. Compare with previous results from metadata.json. If no previous coverage data found in metadata.json, skip delta comparison and report current values only.
2. Show delta: "Coverage improved from 87.3% to 96.2% (+8.9%)"
3. Highlight newly covered lines
4. Update all records with latest results
