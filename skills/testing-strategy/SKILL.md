---
name: testing-strategy
description: Design test strategies and test plans with coverage targets. Complements /draft:coverage which measures what this skill plans. Auto-loaded by /draft:implement before TDD.
---

# Testing Strategy

Design a testing strategy and test plan for this project or track.

## Red Flags — STOP if you're:

- Writing a strategy without understanding the codebase
- Setting unrealistic coverage targets (100% is rarely appropriate)
- Focusing only on unit tests and ignoring integration/E2E
- Ignoring existing test infrastructure and conventions
- Not considering the testing pyramid for this project's architecture

**A good testing strategy matches the architecture. Not every project needs the same pyramid.**

---

## Pre-Check

### 0. Capture Git Context

Before starting, capture the current git state:

```bash
git branch --show-current    # Current branch name
git rev-parse --short HEAD   # Current commit hash
```

Store this for the report header. The strategy is scoped to this specific branch/commit.

### 1. Verify Draft Context

```bash
ls draft/ 2>/dev/null
```

If `draft/` doesn't exist, this skill can still run standalone with reduced context.

### 2. Load Draft Context (if available)

Read and follow the base procedure in `core/shared/draft-context-loading.md`.

## Step 1: Parse Arguments

- `/draft:testing-strategy` — Project-wide strategy (default if no active track)
- `/draft:testing-strategy track <id>` — Track-scoped strategy
- `/draft:testing-strategy module <name>` — Module-scoped strategy

## Step 2: Analyze Codebase

1. **Identify component types:**
   - APIs (REST, GraphQL, gRPC)
   - Data pipelines (ETL, streaming)
   - Frontend (React, Vue, etc.)
   - Infrastructure (Terraform, K8s configs)
   - Libraries/SDKs
   - CLI tools

2. **Discover existing tests:**
   ```bash
   find . -name "*test*" -o -name "*spec*" | head -50
   ```
   Identify: test frameworks, test directories, existing coverage config, test runners.

3. **Assess current coverage:**
   Check for existing coverage reports or configuration:
   ```bash
   ls coverage/ .nyc_output/ htmlcov/ .coverage 2>/dev/null
   ```

4. **Read project context:**
   - `draft/tech-stack.md` — Test frameworks, testing conventions
   - `draft/workflow.md` — TDD preferences (strict/flexible/none)
   - `draft/.ai-context.md` — INVARIANTS section (critical paths), module boundaries, concurrency model
   - `draft/guardrails.md` — Anti-patterns that need test coverage
   - `draft/product.md` — Critical user flows that demand E2E tests

## Step 3: Design Strategy

### Testing Pyramid

Tailor to the project architecture:

```
        ┌─────────┐
        │  E2E    │  Few, critical paths only
        ├─────────┤
        │ Integr. │  Service boundaries, DB, APIs
        ├─────────┤
        │  Unit   │  Business logic, utilities
        └─────────┘
```

Adjust the pyramid shape per architecture. A microservices backend may need a wider integration band. A UI-heavy app may need more E2E. A library may be almost entirely unit tests.

### Per-Component Strategy

| Component Type | Unit | Integration | E2E | Focus |
|---------------|------|-------------|-----|-------|
| API endpoints | Input validation, handlers | DB queries, auth | Critical flows | Contract testing |
| Data pipelines | Transform logic | Source/sink connections | Full pipeline | Data integrity |
| Frontend | Component rendering, hooks | API integration | User journeys | Visual regression |
| Infrastructure | Config validation | Resource provisioning | Deployment | Drift detection |
| Libraries | Public API surface | Cross-module | Consumer scenarios | Backward compat |
| CLI tools | Argument parsing, logic | File I/O, system calls | Full workflows | Exit codes, output |

### Coverage Targets

Set realistic targets based on component criticality:
- **Critical paths** (from .ai-context.md INVARIANTS): 95%+
- **Business logic**: 85-90%
- **Utilities/helpers**: 80%
- **Infrastructure/config**: 70%
- **Generated code**: Exclude from targets
- **Vendor/third-party wrappers**: 60%

### Test Quality Guidelines

Coverage alone is insufficient. Include guidance on:
- **Assertion density:** At least one meaningful assertion per test (not just "doesn't throw")
- **Boundary testing:** Edge cases, empty inputs, max values, off-by-one
- **Error paths:** Test failure modes, not just happy paths
- **Isolation:** Unit tests must not depend on external services, filesystem, or network
- **Determinism:** No time-dependent, order-dependent, or flaky tests
- **Naming:** Test names describe the scenario and expected outcome

## Step 4: Gap Analysis

Compare current state to targets:
1. Run test discovery to count existing tests per module
2. Identify modules with zero test coverage
3. Identify critical paths (from INVARIANTS) without integration tests
4. Identify user flows (from product.md) without E2E coverage
5. Identify anti-patterns (from guardrails.md) without regression tests
6. Prioritize gaps by risk: high-risk untested > low-risk untested

Present as a gap matrix:

| Module | Current Tests | Target | Gap | Risk | Priority |
|--------|--------------|--------|-----|------|----------|
| ... | ... | ... | ... | ... | ... |

## Step 5: Generate Test Plan

Priority test cases to write, ordered by impact:

1. Tests for critical invariants (from .ai-context.md)
2. Tests for anti-patterns (from guardrails.md) — regression prevention
3. Integration tests for service boundaries
4. E2E tests for critical user flows (from product.md)
5. Regression tests for known bugs
6. Property-based tests for complex business logic (if framework supports it)
7. Performance tests for latency-sensitive paths

For each priority test, specify:
- **What:** Description of the test scenario
- **Why:** Which invariant, anti-pattern, or flow it protects
- **How:** Test type (unit/integration/E2E), framework, key assertions
- **Where:** File path where the test should live

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

Save to:
- Project-wide: `draft/testing-strategy.md`
- Track-scoped: `draft/tracks/<id>/testing-strategy.md`

## Cross-Skill Dispatch

- **Auto-loaded by:** `/draft:implement` (before TDD cycle)
- **Suggested by:** `/draft:decompose` (after module definition), `/draft:init` (after setup)
- **Feeds into:** `/draft:coverage` (measurement against targets set here)
- **References:** `/draft:bughunt` findings as regression test candidates

## Error Handling

**If no test infrastructure found:** Recommend test framework based on tech-stack.md, include setup steps needed before tests can be written
**If no draft context:** Generate generic strategy, suggest running `/draft:init` for better results
**If conflicting test patterns found:** Document both patterns, recommend consolidation as a tech-debt item
