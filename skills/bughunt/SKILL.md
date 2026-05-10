---
name: bughunt
description: "Performs an exhaustive 14-dimension bug hunt across the codebase using Draft context (architecture, tech-stack, product) for false-positive elimination. Generates a severity-ranked report with code evidence, data flow traces, and suggested fixes. Optionally writes regression tests. Use when the user asks to find bugs, audit code for defects, scan for vulnerabilities, or says 'hunt bugs', 'find bugs', or 'code audit'."
---

# Bug Hunt

Conduct an exhaustive bug hunt on this Git repository, enhanced by Draft context when available.

## Primary Deliverable

**The bug report is the primary deliverable.** Every verified bug MUST appear in the final report regardless of whether a regression test can be written. Regression tests are a supplementary output — helpful when possible, but never a filter for bug inclusion.

## Relationship to Built-in Bug Hunt Agents

Some AI tools (e.g., Claude Code) provide a built-in `bughunt` agent that auto-discovers project structure and runs parallel sweeps. `/draft:bughunt` is **complementary, not competing**:

| | `/draft:bughunt` | Built-in bughunt agent |
|---|---|---|
| **Approach** | Context-driven methodology with 14 analysis dimensions and verification protocol | Auto-discovery with parallel sweep subagents |
| **Draft context** | Uses architecture, tech-stack, product, guardrails for false-positive elimination | No Draft context awareness |
| **Output** | Severity-ranked report with evidence | Inline fixes + regression tests |
| **Modifies code** | No (report + regression tests only) | Yes (finds AND fixes) |

**When to use which:** Use `/draft:bughunt` when you need context-aware analysis with structured evidence and false-positive elimination. Use the built-in agent when you want fast parallel sweeps with auto-fix capability. For maximum coverage, run both — `/draft:bughunt` catches context-specific bugs the built-in misses, and vice versa.

## Red Flags - STOP if you're:

- Hunting for bugs without reading Draft context first (architecture.md, tech-stack.md, product.md)
- Reporting a finding without reproducing or tracing the code path
- Fixing production code instead of reporting bugs (bughunt reports bugs and writes regression tests — it doesn't fix source code)
- Assuming a pattern is buggy without checking if it's used successfully elsewhere
- Skipping the verification protocol (every bug needs evidence)
- Making up file locations or line numbers without reading the actual code
- Reporting framework-handled concerns as bugs without checking the docs
- **Skipping bugs because you can't write a test for them** — mark as N/A and still report

**Verify before you report. Evidence over assumptions.**

---

## Pre-Check

### 0. Capture Git Context

Before starting analysis, capture the current git state:

```bash
git branch --show-current    # Current branch name
git rev-parse --short HEAD   # Current commit hash
```

Store this for the report header. All bugs found are relative to this specific branch/commit.

### 1. Load Draft Context (if available)

Read and follow the base procedure in `core/shared/draft-context-loading.md`.

**Bug-hunt-specific context application:**
- Flag violations of intended architecture as bugs (coupling, boundary violations)
- Apply framework-specific checks from tech-stack (React anti-patterns, Node gotchas, etc.)
- Catch bugs that violate product requirements or user flows
- Prioritize areas relevant to active tracks
- **Leverage Critical Invariants** — Check for invariant violations across data safety, security, concurrency, ordering, idempotency categories
- **Leverage Concurrency Model** — Use thread/async model info for race condition and deadlock analysis
- **Leverage Error Handling** — Use failure modes and retry policies for reliability bug detection
- **Leverage Data State Machines** — Check for invalid state transitions, missing guard clauses, states with no exit path
- **Leverage Storage Topology** — Identify data loss risks at each tier (cache eviction without writeback, event log gaps, missing archive)
- **Leverage Consistency Boundaries** — Find bugs at eventual consistency seams (stale reads, lost events, missing reconciliation)
- **Leverage Failure Recovery Matrix** — Verify idempotency claims, check for partial failure states without recovery paths
- **Leverage Graph Data** (if `draft/graph/` exists) — Load `module-graph.jsonl` for dependency awareness. Flag imports from unexpected modules (not in established dependency edges). Flag code in modules involved in dependency cycles as higher risk. Use `hotspots.jsonl` to prioritize analysis of high-complexity, high-fanIn files. See `core/shared/graph-query.md`.
- **Leverage Learned Anti-Patterns** — If `draft/guardrails.md` exists, read the `## Learned Anti-Patterns` section. During the bug sweep, when a bug matches a learned anti-pattern, prefix the report entry with `[KNOWN-ANTI-PATTERN: {pattern name}]`. This distinguishes recurring documented patterns from newly discovered bugs, and signals that a systemic fix may be needed rather than a one-off patch.

### 2. Confirm Scope

When invoked programmatically by `/draft:review` with `with-bughunt`, skip scope confirmation and inherit the scope from the calling command.

Otherwise, ask user to confirm scope:
- **Entire repo** - Full codebase analysis
- **Specific paths** - Target directories or files
- **Track-level** (specify `<track-id>`) - Focus on files relevant to a specific track

### 3. Load Track Context (if track-level)

If running for a specific track, also load:
- [ ] `draft/tracks/<id>/spec.md` - Requirements, acceptance criteria, edge cases
- [ ] `draft/tracks/<id>/plan.md` - Implementation tasks, phases, dependencies

Use track context to:
- Verify implemented features match spec requirements
- Check edge cases listed in spec are handled
- Identify bugs in areas touched by the track's plan
- Focus analysis on files modified/created by the track

If no Draft context exists, proceed with code-only analysis.

## Dimension Applicability Check

Before analyzing all 14 dimensions, determine which apply to this codebase:

- **Skip explicitly** rather than forcing analysis of N/A dimensions
- **Mark skipped dimensions** with reason in report summary

**Examples of skipping:**
- "N/A - no backend code" (skip dimensions 2, 8, 10 for frontend-only repo)
- "N/A - no UI components" (skip dimensions 5, 9, 14 for CLI tool)
- "N/A - no database" (skip dimension 2 for in-memory app)
- "N/A - no external integrations" (skip dimension 8)
- "N/A - no external dependencies" (skip dimension 12 for zero-dependency project)
- "N/A - no user-facing strings" (skip dimension 14 for libraries/APIs)

## Analysis Dimensions

Analyze systematically across all applicable dimensions. Skip N/A dimensions explicitly (see Dimension Applicability Check above).

### 1. Correctness
- Logical errors, invalid assumptions, edge cases
- Incorrect state transitions, stale or inconsistent UI state
- Error handling gaps, silent failures
- Off-by-one errors, boundary conditions

### 2. Reliability & Resilience
- Crash paths, unhandled exceptions
- Reload/refresh behavior, retry logic
- UI behavior on partial backend failure
- Broken recovery after errors, navigation

### 3. Security
- XSS, injection vectors, unsafe rendering
- Client-side trust assumptions
- Secrets, tokens, auth data exposure
- CSRF, insecure deserialization
- Path traversal, command injection
- **Taint tracking (end-to-end data flow analysis):**
  - Identify all entry points: HTTP params, form data, file uploads, env vars, CLI args, message queue payloads, webhook bodies
  - Trace user input to dangerous sinks: SQL queries, shell exec, eval, innerHTML, file path construction, URL construction, deserialization, template rendering
  - For each sink, verify sanitization/validation exists on every path from source to sink
  - Flag paths where unsanitized input reaches a sink without passing through a validator, encoder, or sanitizer
  - Reference: OWASP Top 10, Meta Infer taint analysis methodology

### 4. Performance (Backend + UI)
- Inefficient algorithms and data fetching
- Blocking work on main/UI thread
- Excessive re-renders, unnecessary state updates
- Unbounded memory growth (listeners, caches, stores)

### 5. UI Responsiveness & Perceived Performance
- Long tasks blocking input
- Jank during scrolling, typing, resizing
- Layout thrashing, forced reflows
- Expensive animations or transitions
- Poor loading states, flicker, content shifts

### 6. Concurrency & Ordering
- Race conditions between async calls
- Stale responses overwriting newer state
- Incorrect cancellation or debouncing
- Event ordering assumptions
- Deadlocks, livelocks

### 7. State Management
- Source-of-truth violations
- Derived state bugs (computed from stale data)
- Global state misuse
- Memory leaks from subscriptions or observers
- Inconsistent state across components

### 8. API & Contracts
- UI assumptions not guaranteed by backend
- Schema drift, weak typing, missing validation
- Backward compatibility risks
- Undocumented API behavior dependencies

### 9. Accessibility & UX Correctness
- Keyboard navigation gaps
- Focus management bugs
- ARIA misuse or absence
- Broken tab order or unreadable states
- UI behavior that contradicts user intent
- Color contrast, screen reader compatibility

### 10. Configuration & Build
- Fragile environment assumptions
- Build-time vs runtime config leaks
- Dev-only code shipping to prod
- Missing environment variable validation
- CI gaps affecting builds or tests

### 11. Tests
- Missing coverage for critical flows
- Snapshot misuse (testing implementation, not behavior)
- Tests that assert implementation instead of behavior
- Mismatch between test and real user interaction
- Flaky tests, timing dependencies
- **Property-based testing gaps:** pure/mathematical functions without invariant-based tests (e.g., `encode(decode(x)) == x`, sorting idempotency, associativity)
- **Test isolation violations:** shared mutable state between test cases (global variables, singletons, class-level state modified in tests without reset)
- **Test double misuse:** mocks that leak state across tests, over-mocking (>3 mocks per test suggests testing wiring not behavior), stubs that diverge from real implementation behavior
- **Assertion density:** tests with zero or weak assertions (`assertTrue(true)`, `expect(result).toBeDefined()` only, empty catch blocks in test code, `assert result is not None` as sole check)
- **Flaky test patterns:** time-dependent assertions (sleep, Date.now, timestamps), port/file system assumptions, test ordering dependencies, non-deterministic data (random seeds, UUIDs without control)

### 12. Dependency & Supply Chain Security
- **Known CVEs:** Check dependencies against known vulnerability databases (reference tools: Snyk, Trivy, OWASP Dependency-Check, `npm audit`, `pip-audit`, `cargo audit`, `go vuln`)
- **Unpinned dependency versions:** Lockfile freshness, use of version ranges (`^`, `~`, `*`, `>=`) without lockfile enforcement, missing lockfile entirely
- **Deprecated packages:** Dependencies with known deprecation notices, archived repositories, or no maintenance activity
- **License conflicts:** GPL dependencies in MIT/Apache projects, AGPL in proprietary code, incompatible license combinations in the dependency tree
- **Typosquatting risk:** Packages with names similar to popular ones (e.g., `lodahs` vs `lodash`, `reqeusts` vs `requests`), recently published packages with few downloads
- **Transitive dependency depth:** Deeply nested dependency chains (>5 levels) increase supply chain attack surface; flag packages that pull in disproportionate transitive trees
- Reference: Google OSS-Fuzz, Microsoft SDL, OpenSSF Scorecard

### 13. Algorithmic Complexity
- **Quadratic or worse loops:** O(n^2) or worse nested loops over collections (nested `.filter()` inside `.map()`, repeated linear scans, cartesian joins in application code)
- **Regex catastrophic backtracking:** Nested quantifiers (`(a+)+`, `(a|a)*`), unbounded repetition with overlapping alternatives — flag any regex applied to user-controlled input
- **Unbounded recursion:** Recursive functions without depth limits, missing base cases, or base cases that depend on external/mutable state
- **Cache invalidation storms:** Cache miss triggering expensive recomputation that itself invalidates caches, thundering herd on cache expiry without jitter/locking
- **Hot path inefficiency:** Sorting/searching in hot paths without appropriate data structures (linear scan where hash map suffices, repeated sorting of same collection, string concatenation in loops)

### 14. Internationalization & Localization
- **Hardcoded user-facing strings:** Strings displayed to users embedded directly in source code rather than externalized to resource files/i18n frameworks
- **Locale-sensitive operations without locale parameter:** String comparison (`<`, `>`, `localeCompare` without locale), date formatting (`toLocaleDateString` without explicit locale), number formatting, sorting (alphabetical sort that assumes ASCII ordering)
- **RTL layout issues:** Hardcoded LTR assumptions in UI code (absolute `left`/`right` positioning, directional margin/padding, text alignment assumptions)
- **Unicode handling bugs:** String length vs byte length confusion, missing normalization (NFC/NFD), emoji handling (multi-codepoint sequences split incorrectly, `string.length` vs grapheme count), surrogate pair handling in substring operations

## Bug Verification Protocol

**CRITICAL: No bug is valid without verification.** Before declaring any finding as a bug, complete ALL applicable verification steps:

### Verification Checklist (for each potential bug)

1. **Code Path Verification**
   - [ ] Read the actual code at the suspected location
   - [ ] Trace the data flow from input to the bug location
   - [ ] Check if there are guards, validators, or error handlers upstream
   - [ ] Verify the code path is actually reachable in production

2. **Context Cross-Reference**
   - [ ] Check `.ai-context.md` (or `architecture.md`) — Is this behavior intentional by design?
   - [ ] Check `tech-stack.md` — Does the framework handle this case?
   - [ ] Check `tech-stack.md` `## Accepted Patterns` — Is this pattern explicitly documented as intentional?
   - [ ] Check `product.md` — Is this actually a requirement violation?
   - [ ] Check existing tests — Is this behavior already tested and expected?

3. **Framework/Library Verification**
   - [ ] Read official docs for the specific method/pattern in question
   - [ ] Quote relevant doc section proving this is/isn't handled
   - [ ] Check framework version in tech-stack.md (behavior may vary by version)
   - [ ] Look for middleware, interceptors, or global handlers that may address the issue

**Example Framework Documentation Quote:**
"React automatically escapes JSX content to prevent XSS (React Docs: Main Concepts > JSX). However, `dangerouslySetInnerHTML` bypasses this protection. Framework version: React 18.2.0 (from tech-stack.md)."

4. **Codebase Pattern Check**
   - [ ] Search for similar patterns elsewhere in codebase
   - [ ] If pattern is used consistently, verify it's actually buggy (not just unfamiliar)
   - [ ] Check if there's a project-specific utility/wrapper that handles the concern

5. **False Positive Elimination**
   - [ ] Is this dead code that's never executed?
   - [ ] Is this test/mock/stub code not in production?
   - [ ] Is this intentionally disabled (feature flag, config)?
   - [ ] Is there a comment explaining why this appears unsafe but is actually safe?

6. **Pattern Prevalence Check (before reporting)**
   - [ ] Run Grep to find all occurrences of the pattern
   - [ ] If found >5x:
     - Randomly sample 3 instances
     - Verify they exhibit the same suspected bug
     - If they work correctly, investigate: what's different about THIS instance?
   - [ ] If no difference found and other instances work: DO NOT REPORT
   - [ ] If all instances have the bug: Report with pattern count in "Impact"

**Example Pattern Prevalence Check:**
```
1. Grep: `rg 'dangerouslySetInnerHTML' src/` → found 12 occurrences
2. Sampled 3: src/Blog.tsx:45, src/About.tsx:12, src/FAQ.tsx:30
3. All 3 sanitize input via `DOMPurify.sanitize()` before rendering
4. THIS instance (src/Comment.tsx:88) passes raw user input without sanitization
5. Decision: REPORT — this instance lacks the sanitization all others have
```

### Confidence Levels

Only report bugs with HIGH or CONFIRMED confidence:

| Level | Criteria | Action |
|-------|----------|--------|
| **CONFIRMED** | Verified through code trace, no mitigating factors found | Report as bug |
| **HIGH** | Strong evidence, checked context, no obvious mitigation | Report as bug |
| **MEDIUM** | Suspicious but couldn't verify all factors | Ask user to confirm before reporting |
| **LOW** | Possible issue but likely handled elsewhere | Do NOT report |

**Example confirmation prompt for MEDIUM Confidence:**
"I found a potential race condition in `src/handler.ts:45` where async state updates may overwrite each other. However, I couldn't verify if there's a locking mechanism elsewhere. Should I report this as a bug?"

### Evidence Requirements

Each reported bug MUST include:
- **Code Evidence:** The actual problematic code snippet
- **Trace:** How data reaches this point (caller chain or data flow)
- **Verification Done:** Which checks from the checklist were completed
- **Why Not a False Positive:** Explicit statement of why this isn't handled elsewhere

## Analysis Rules

- **Do not execute code** - Reason from source only
- **Do not assume frameworks "handle it"** - Verify explicitly by checking docs/code
- **Do not assume code is buggy** - Verify it's actually reachable and unguarded
- **Trace data flow completely** - From input source to bug location
- **Cross-reference ALL Draft context** - Check architecture, tech-stack, product, tests
- **Check for existing mitigations** - Middleware, wrappers, utilities, global handlers
- **Search for patterns** - If used elsewhere without issues, investigate why

## Optional: Runtime Verification (if test suite exists)

For suspected bugs that can be tested, write a minimal failing test to confirm:

1. **Write minimal test** — Target the specific bug, not the entire feature
2. **Run test** — Execute and observe failure
3. **Confirm bug** — If test fails as predicted, confidence level increases to CONFIRMED
4. **Only report if**: Test fails OR CONFIRMED confidence from code trace

**Example:**
```javascript
// Suspected bug: off-by-one in pagination
test('should handle last page boundary', () => {
  const items = Array(100).fill('item');
  const result = paginate(items, { page: 10, perPage: 10 });
  expect(result.items.length).toBe(10); // Currently returns 9
});
```

If test fails, upgrade confidence to CONFIRMED and include test in bug report.

## Regression Test Generation

For each verified bug, generate a regression test in the **project's native test framework** that would expose the bug as a failing test. **Before writing any new test**, first discover the project's language/framework and whether existing tests already cover (or partially cover) the bug scenario.

### Step 1: Detect Language & Test Framework

Identify the project's language(s) and test framework by examining the codebase:

| Signal | Language | Test Framework | Build/Run Command |
|--------|----------|---------------|-------------------|
| `BUILD`/`WORKSPACE`/`MODULE.bazel` + `.cpp`/`.cc`/`.h` | C/C++ | GTest | `bazel build` / `bazel test` |
| `CMakeLists.txt` + `.cpp`/`.cc` | C/C++ | GTest | `cmake --build` / `ctest` |
| `go.mod` or `go.sum` | Go | `testing` (stdlib) | `go test` |
| `pytest.ini`/`pyproject.toml`/`setup.py`/`conftest.py` | Python | pytest | `pytest` |
| `requirements.txt` + `unittest` imports | Python | unittest | `python -m pytest` |
| `package.json` + Jest config | JavaScript/TypeScript | Jest | `npx jest` / `npm test` |
| `package.json` + Vitest config | JavaScript/TypeScript | Vitest | `npx vitest` |
| `package.json` + Mocha config | JavaScript/TypeScript | Mocha | `npx mocha` |
| `Cargo.toml` | Rust | built-in `#[test]` | `cargo test` |
| `pom.xml` | Java | JUnit | `mvn test` |
| `build.gradle`/`build.gradle.kts` | Java/Kotlin | JUnit | `gradle test` |

**Resolution order:**
1. Check `draft/tech-stack.md` first — it may explicitly state the test framework
2. Look for existing test files and match their import/framework patterns
3. Fall back to build system signals above

If the project is **polyglot** (multiple languages), detect per-component and generate tests in the matching language for each bug.

**If no test framework is detected:** Mark all bugs with `Regression Test Status: N/A — no test framework detected` and proceed with bug reporting. **Do not skip bugs because tests cannot be written.** The regression test section is supplementary — the primary deliverable is the bug report.

Record the detected configuration:
```
Language: [detected | none]
Test Framework: [detected | none]
Build System: [detected | none]
Test Command: [detected | N/A]
```

### Step 2: Existing Test Discovery (REQUIRED per bug, skip if no test framework)

For each verified bug, search the codebase for existing tests before generating new ones:

1. **Locate test files for the buggy module** using language-appropriate patterns:

   | Language | Search Patterns |
   |----------|----------------|
   | C/C++ | `*_test.cpp`, `*_test.cc`, `test_*.cpp`; patterns: `TEST(`, `TEST_F(`, `TEST_P(` |
   | Go | `*_test.go` in same package; patterns: `func Test`, `func Benchmark` |
   | Python | `test_*.py`, `*_test.py` in `tests/`; patterns: `def test_`, `class Test` |
   | JS/TS | `*.test.ts`, `*.spec.ts`, `__tests__/*.ts`; patterns: `describe(`, `it(`, `test(` |
   | Rust | `#[cfg(test)]` in same file, or `tests/*.rs`; patterns: `#[test]`, `fn test_` |
   | Java | `*Test.java`, `*Tests.java` in `src/test/`; patterns: `@Test`, `@ParameterizedTest` |

2. **Analyze existing test coverage**
   - Read each related test file found
   - Check if any test exercises the **exact code path** that triggers the bug
   - Check if any test covers the **same function/method** but misses the specific edge case
   - Check if a test exists but has a **wrong assertion** (asserts buggy behavior as correct)

3. **Classify the coverage status** — one of:

   | Status | Meaning | Action |
   |--------|---------|--------|
   | **COVERED** | Existing test already catches this bug (test fails on buggy code) | Report the existing test — no new test needed |
   | **PARTIAL** | Test exists for the function but misses this specific scenario | Add the missing case to the existing test file |
   | **WRONG_ASSERTION** | Test exists but asserts the buggy behavior as correct | Fix the assertion in the existing test |
   | **NO_COVERAGE** | No test exists for this code path | Generate a new test |
   | **N/A** | Bug is in non-testable code (config, markdown, LLM workflow) | Write `N/A — [reason]` |

4. **Document discovery results** in the bug report's Regression Test field

**Example Existing Test Discovery:**
```
1. Bug location: src/parser.cpp:145 — off-by-one in tokenize()
2. Grep: `rg 'tokenize' tests/` → found tests/parser_test.cpp
3. Read tests/parser_test.cpp:
   - TEST(Parser, TokenizeSimpleInput) — tests basic input ✓
   - TEST(Parser, TokenizeEmptyString) — tests empty string ✓
   - No test for boundary input length (the bug trigger)
4. Status: PARTIAL — parser_test.cpp covers tokenize() but misses boundary case
5. Action: Add new TEST case to existing tests/parser_test.cpp
```

### Step 3: Generate or Modify Test Cases

Based on discovery results, generate tests in the project's native framework:

#### When status is COVERED
```
**Regression Test:**
**Status:** COVERED — existing test already catches this bug
**Existing Test:** `tests/parser_test.cpp:45` — `TEST(Parser, TokenizeBoundary)`
No new test needed.
```

#### When status is PARTIAL — add to existing test file
#### When status is WRONG_ASSERTION — fix assertion in existing test
#### When status is NO_COVERAGE — generate new test

### Test Case Requirements (all languages)

Each new test MUST:

1. **Target exactly one bug** — One test per finding, named after the bug
2. **Use descriptive test names** — Language-idiomatic naming (see templates below)
3. **Include the bug setup** — Reproduce the preconditions that trigger the bug
4. **Assert the expected (correct) behavior** — The test should FAIL against the current buggy code
5. **Comment the expected vs actual** — Explain what the test expects and what currently happens
6. **Be self-contained** — Include necessary imports, minimal fixtures, no external dependencies beyond the test framework and project modules
7. **Specify target file** — State whether this goes in an existing test file or a new one

### Language-Specific Test Templates

#### C/C++ (GTest)

```cpp
#include <gtest/gtest.h>
// #include "relevant/project/header.h"

// Bug: [SEVERITY] Category: Brief Title
// Location: path/to/file.cpp:line
// This test FAILS against current code, PASSES after fix

TEST(BugCategory, BriefBugTitle) {
    // Setup
    // Act
    // Assert
    EXPECT_EQ(actual, expected) << "Description of what should happen";
}
```

#### Python (pytest)

```python
# Bug: [SEVERITY] Category: Brief Title
# Location: path/to/file.py:line
# This test FAILS against current code, PASSES after fix

import pytest
from module.under.test import function_under_test


def test_brief_bug_title():
    """[Category] Brief description of the bug scenario."""
    # Setup
    # Act
    result = function_under_test(input)
    # Assert
    assert result == expected, "Description of what should happen"
```

#### Go (testing)

```go
package package_name

import (
    "testing"
    // project imports
)

// Bug: [SEVERITY] Category: Brief Title
// Location: path/to/file.go:line
// This test FAILS against current code, PASSES after fix

func TestBriefBugTitle(t *testing.T) {
    // Setup
    // Act
    got := FunctionUnderTest(input)
    // Assert
    if got != expected {
        t.Errorf("FunctionUnderTest() = %v, want %v", got, expected)
    }
}
```

#### JavaScript/TypeScript (Jest/Vitest)

```typescript
// Bug: [SEVERITY] Category: Brief Title
// Location: path/to/file.ts:line
// This test FAILS against current code, PASSES after fix

import { functionUnderTest } from './module-under-test';

describe('BugCategory', () => {
  it('should brief bug title', () => {
    // Setup
    // Act
    const result = functionUnderTest(input);
    // Assert
    expect(result).toBe(expected);
  });
});
```

#### Rust (#[test])

```rust
// Bug: [SEVERITY] Category: Brief Title
// Location: path/to/file.rs:line
// This test FAILS against current code, PASSES after fix

#[cfg(test)]
mod bug_regression_tests {
    use super::*;

    #[test]
    fn test_brief_bug_title() {
        // Setup
        // Act
        let result = function_under_test(input);
        // Assert
        assert_eq!(result, expected, "Description of what should happen");
    }
}
```

#### Java (JUnit 5)

```java
// Bug: [SEVERITY] Category: Brief Title
// Location: path/to/File.java:line
// This test FAILS against current code, PASSES after fix

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class BugCategoryTest {
    @Test
    void briefBugTitle() {
        // Setup
        // Act
        var result = classUnderTest.methodUnderTest(input);
        // Assert
        assertEquals(expected, result, "Description of what should happen");
    }
}
```

### Consolidated Test File

After all bugs are documented, collect all test cases into a single consolidated section in the report (see Report Generation). Group by discovery status so the reader knows which tests are new vs modifications to existing tests.

### Step 4: Test Infrastructure Discovery

Before writing any test files, discover the project's test infrastructure and conventions:

1. **Detect Build System & Test Runner**

   | Language | Build System Signals | Test Runner |
   |----------|---------------------|-------------|
   | C/C++ | `WORKSPACE`/`MODULE.bazel` → Bazel; `CMakeLists.txt` → CMake | `bazel test` / `ctest` |
   | Go | `go.mod` (always present) | `go test ./...` |
   | Python | `pyproject.toml` / `setup.cfg` / `tox.ini` / bare | `pytest` (prefer) / `python -m unittest` |
   | JS/TS | `package.json` → check `scripts.test` and devDeps | `npx jest` / `npx vitest` / `npm test` |
   | Rust | `Cargo.toml` (always present) | `cargo test` |
   | Java | `pom.xml` → Maven; `build.gradle` → Gradle | `mvn test` / `gradle test` |

   If no recognized build system is found, inform user and keep report-only test output:
   `"No recognized build/test system detected. Regression tests are included in the report only."`

2. **Map Source Files to Test Locations**
   For each buggy source file, determine where its tests live (or should live):

   | Language | Common Conventions |
   |----------|--------------------|
   | C/C++ (Bazel) | Co-located `foo_test.cpp` or separate `tests/` tree; check `cc_test` in BUILD |
   | Go | Same directory: `foo.go` → `foo_test.go` (always co-located) |
   | Python | `src/auth/handler.py` → `tests/auth/test_handler.py` or `tests/test_auth_handler.py` |
   | JS/TS | `src/auth/handler.ts` → `src/auth/handler.test.ts` or `__tests__/handler.test.ts` |
   | Rust | In-file `#[cfg(test)]` module, or `tests/` directory for integration tests |
   | Java | `src/main/java/com/...` → `src/test/java/com/...` (Maven convention) |

   - If tests exist: record the directory, naming convention, and any build config
   - If no tests exist: adopt the project's dominant convention
   - If no convention exists: default to a `tests/` directory mirroring the source tree

3. **Identify Test Dependencies** (language-specific)

   | Language | What to Find |
   |----------|-------------|
   | C/C++ (Bazel) | GTest dep label: `@com_google_googletest//:gtest_main`; source `cc_library` targets |
   | Go | No extra deps needed (`testing` is stdlib) |
   | Python | Check if `pytest` is in `requirements*.txt` / `pyproject.toml`; add if missing |
   | JS/TS | Check if test framework is in `devDependencies`; identify import style |
   | Rust | No extra deps for unit tests; `dev-dependencies` for integration test crates |
   | Java | JUnit version in `pom.xml` / `build.gradle` dependencies |

### Step 5: Write Test Files (only for testable bugs)

**Skip this step entirely if no test framework was detected in Step 1.**

For bugs with status NO_COVERAGE, PARTIAL, or WRONG_ASSERTION, write the actual test files. Bugs with COVERED or N/A status do not need action here — they are still included in the final report:

#### NO_COVERAGE — Create new test file

1. **Create directory** if it doesn't exist:
   ```bash
   mkdir -p <test_directory>/
   ```

2. **Write the test file** using the language-appropriate template:

   | Language | Example Target File |
   |----------|-------------------|
   | C/C++ | `tests/auth/login_handler_test.cpp` |
   | Go | `auth/login_handler_test.go` (same package) |
   | Python | `tests/auth/test_login_handler.py` |
   | JS/TS | `src/auth/login_handler.test.ts` or `__tests__/auth/login_handler.test.ts` |
   | Rust | `tests/login_handler_test.rs` or `#[cfg(test)]` in source |
   | Java | `src/test/java/com/example/auth/LoginHandlerTest.java` |

3. **Create or update build config** (if required by the build system):

   **C/C++ (Bazel)** — add `cc_test` to BUILD:
   ```python
   cc_test(
       name = "<source_filename>_test",
       srcs = ["<source_filename>_test.cpp"],
       deps = [
           "//src/<component>:<library_target>",
           "@com_google_googletest//:gtest_main",
       ],
   )
   ```

   **Java (Maven)** — no build config change needed (convention-based discovery)
   **Java (Gradle)** — no build config change needed
   **Go** — no build config change needed (`go test` discovers `_test.go` automatically)
   **Python** — no build config change needed (`pytest` discovers `test_*.py` automatically)
   **JS/TS** — no build config change needed (Jest/Vitest discover `*.test.*` automatically)
   **Rust** — no build config change needed (`cargo test` discovers `#[test]` automatically)

4. If multiple bugs affect different files in the same component, create one test file per source file (not one per bug). Group related bug tests into the same file.

#### PARTIAL — Add test case to existing file

1. Read the existing test file
2. Append the new test at the idiomatic location:
   - **C/C++:** Before closing namespace brace
   - **Go:** End of file (same package)
   - **Python:** End of file or within existing test class
   - **JS/TS:** Inside the relevant `describe()` block, or at end of file
   - **Rust:** Inside existing `#[cfg(test)]` module
   - **Java:** Inside existing test class, before closing brace
3. No build config changes needed

#### WRONG_ASSERTION — Fix assertion in existing file

1. Read the existing test file
2. Locate the wrong assertion
3. Replace with the corrected assertion
4. No build config changes needed

**Constraints:**
- **Never modify production source code** — only test files and their build configs
- Each test file must be valid for the project's test runner
- Use the project's actual import paths, module names, and namespace conventions
- Match existing test style (fixtures, helpers, naming conventions)

### Step 6: Build & Syntax Validation

After writing all test files, validate them using the project's native toolchain.

1. **Validate each new/modified test** using the language-appropriate command:

   | Language | Validation Command | What It Checks |
   |----------|-------------------|----------------|
   | C/C++ (Bazel) | `bazel build //tests/<component>:<target>_test` | Compilation + linking |
   | C/C++ (CMake) | `cmake --build <build_dir> --target <target>_test` | Compilation + linking |
   | Go | `go vet ./path/to/package/...` | Syntax + type checking (no execution) |
   | Python | `python -m py_compile tests/path/test_file.py` | Syntax validation |
   | JS/TS | `npx tsc --noEmit tests/path/file.test.ts` (TS) or `node --check tests/path/file.test.js` (JS) | Type check / syntax |
   | Rust | `cargo check --tests` | Type check + borrow check (no execution) |
   | Java (Maven) | `mvn test-compile` | Compilation only |
   | Java (Gradle) | `gradle testClasses` | Compilation only |

2. **Handle validation results:**

   | Result | Action |
   |--------|--------|
   | **Succeeds** | Mark as `BUILD_OK` in report |
   | **Fails — import/include error** | Fix the import path, retry (up to 2 retries) |
   | **Fails — missing dep** | Add the dependency, retry (up to 2 retries) |
   | **Fails — type/API mismatch** | Fix the test to match actual API signatures, retry (up to 2 retries) |
   | **Persistent failure (3 attempts)** | Mark as `BUILD_FAILED` with the error message in report. Delete the broken test file and note in the report: "Test file removed due to persistent build failure." |

3. **Do NOT run the tests.** The tests are designed to **FAIL** against the current buggy code — that's the point. Validation checks only syntax, types, and linking. Running them would produce expected failures that aren't useful here.

   **Exception for Go:** `go vet` is preferred over `go build` for test files because Go compiles tests as part of `go test` only. `go vet` catches type errors and common issues without executing.

4. **Validation summary** — Record results for the report:
   ```
   BUILD_OK:     3 targets
   BUILD_FAILED: 1 target (tests/config/test_loader.py — ImportError: no module named 'config.loader')
   SKIPPED:      1 target (N/A — race condition not reliably testable)
   ```

## Fix Suggestion Generation

For each bug with CONFIRMED or HIGH confidence, generate a minimal suggested fix alongside the bug report. Fix suggestions are advisory — they are never auto-applied.

### Fix Generation Rules

1. **Minimal change principle:** The fix must be the smallest code change that addresses the root cause. Do not refactor surrounding code, add features, or improve style.
2. **Before/after format:** Include the exact current code (BEFORE) and the suggested fix (AFTER) as code snippets with file path and line numbers.
3. **Root cause targeting:** The fix must address the root cause identified in the bug's data flow trace, not a symptom. If the root cause is in a different location than the symptom, fix at the root.
4. **Mark as SUGGESTED:** Every fix must be clearly marked as `SUGGESTED (REVIEW REQUIRED)` — never imply auto-application.
5. **One fix per bug:** Each bug gets exactly one suggested fix. If multiple fix strategies exist, choose the most conservative one and note alternatives.
6. **Preserve behavior:** The fix must not change behavior beyond correcting the identified bug. No side-effect improvements.
7. **Skip when inappropriate:** Mark fix as `N/A` for bugs where the fix requires architectural changes, significant refactoring, or domain knowledge beyond what the code provides.

Reference: Meta SapFix — automated fix suggestion with human-in-the-loop validation.

## Output Format

For each verified bug:

```markdown
### [SEVERITY] Category: Brief Title

**Location:** `path/to/file.ts:123`
**Confidence:** [CONFIRMED | HIGH | MEDIUM]

**Code Evidence:**
```[language]
// The actual problematic code
```

**Data Flow Trace:**
[How data reaches this point: caller → caller → this function]

**Issue:** [Precise technical description of what is wrong]

**Impact:** [User-visible effect or system failure mode]

**Verification Done:**
- [x] Traced code path from [entry point]
- [x] Checked architecture.md — not intentional
- [x] Verified framework doesn't handle this
- [x] No upstream guards found in [files checked]

**Why Not a False Positive:**
[Explicit statement: "No sanitization exists because X", "Framework Y doesn't escape Z in this context", etc.]

**Fix:** [Minimal code change or mitigation]

**Suggested Fix (REVIEW REQUIRED):**
```[language]
// BEFORE (current buggy code):
[exact code snippet from the codebase]

// AFTER (suggested fix):
[minimal change that addresses root cause]
```
_This fix is SUGGESTED only — human review required before applying. Reference: Meta SapFix methodology._

**Regression Test:**
**Status:** [COVERED | PARTIAL | WRONG_ASSERTION | NO_COVERAGE | N/A]
**Existing Test:** [`path/to/test_file:line` — test name | None found]
[Action: existing test reference, proposed modification, or new test case]
```[language]
// New or modified test case (omit if COVERED or N/A)
```
```

**Example — COVERED (no new test needed):**
```markdown
**Regression Test:**
**Status:** COVERED — existing test already catches this bug
**Existing Test:** `tests/validator_test.cpp:89` — `TEST(Validator, RejectsScriptTags)`
No new test needed. Existing test fails when XSS sanitization is removed.
```

**Example — PARTIAL (C++ / GTest):**
```markdown
**Regression Test:**
**Status:** PARTIAL — tests exist for processInput() but miss unsanitized HTML path
**Existing Test File:** `tests/input_test.cpp`
**Modification:** Add to existing file:
```cpp
TEST(InputSanitization, RejectsMaliciousScript) {
  std::string malicious = "<script>alert('xss')</script>";
  std::string result = processInput(malicious);
  EXPECT_EQ(result.find("<script>"), std::string::npos)
      << "Input should be sanitized to remove script tags";
}
```
```

**Example — NO_COVERAGE (Python / pytest):**
```markdown
**Regression Test:**
**Status:** NO_COVERAGE — no tests found for process_input()
**Target File:** `tests/test_input_processor.py` (new file)
```python
import pytest
from input.processor import process_input

def test_rejects_malicious_script():
    """Input should be sanitized to remove script tags."""
    malicious = "<script>alert('xss')</script>"
    result = process_input(malicious)
    assert "<script>" not in result, "XSS script tag should be stripped"
# Expected: FAILS against current code (passes XSS through), PASSES after fix
```
```

**Example — NO_COVERAGE (Go / testing):**
```markdown
**Regression Test:**
**Status:** NO_COVERAGE — no tests found for ProcessInput()
**Target File:** `input/processor_test.go` (new file)
```go
package input

import (
    "strings"
    "testing"
)

func TestProcessInputRejectsMaliciousScript(t *testing.T) {
    malicious := "<script>alert('xss')</script>"
    result := ProcessInput(malicious)
    if strings.Contains(result, "<script>") {
        t.Error("XSS script tag should be stripped from input")
    }
}
// Expected: FAILS against current code (passes XSS through), PASSES after fix
```
```

**Example — N/A (not testable, but still report the bug):**
```markdown
**Regression Test:**
**Status:** N/A — environment config, no executable code path
**Reason:** Bug is in `config/production.yaml` which sets incorrect timeout value. Config files are not unit-testable; fix requires changing the YAML value directly.
```

Severity levels:
- **Critical** — Blocks release, breaks functionality, security issue
- **Important** — Degrades quality, creates tech debt
- **Minor** — Style, optimization, edge cases

## Report Generation

Generate report at:
- **Project-level:** `draft/bughunt-report-<timestamp>.md` (where `<timestamp>` is generated via `date +%Y-%m-%dT%H%M`, e.g., `2026-03-15T1430`)
- **Track-level:** `draft/tracks/<track-id>/bughunt-report-<timestamp>.md` (if analyzing specific track)

After writing the timestamped report, create a symlink pointing to it:
```bash
# Project-level
ln -sf bughunt-report-<timestamp>.md draft/bughunt-report-latest.md

# Track-level
ln -sf bughunt-report-<timestamp>.md draft/tracks/<track-id>/bughunt-report-latest.md
```

Previous timestamped reports are preserved. The `-latest.md` symlink always points to the most recent report.

**MANDATORY: Include YAML frontmatter with git metadata.** Follow the procedure in `core/shared/git-report-metadata.md` to gather git info and generate the frontmatter. Use `generated_by: "draft:bughunt"`.

Report structure:

```markdown
[YAML frontmatter — see core/shared/git-report-metadata.md]

# Bug Hunt Report

[Report header table — see core/shared/git-report-metadata.md]

**Scope:** [Entire repo | Specific paths | Track: <track-id>]
**Draft Context:** [Loaded | Not available]

## Summary

| Severity | Count | Confirmed | High Confidence |
|----------|-------|-----------|-----------------|
| Critical | N | X | Y |
| Important | N | X | Y |
| Minor | N | X | Y |

## Critical Issues

[Issues...]

## Important Issues

[Issues...]

## Minor Issues

[Issues...]

## Dimensions With No Findings

| Dimension | Status |
|-----------|--------|
| Correctness | No bugs found |
| Reliability | N/A — no runtime application |
| Performance | N/A — static site, no dynamic content |
| Concurrency | N/A — no async operations |

## Regression Test Suite

**Language:** [detected language]
**Test Framework:** [detected framework]
**Validation Command:** [command used]

### Test Discovery Summary

| # | Bug Title | Severity | Status | Existing Test | Action |
|---|-----------|----------|--------|---------------|--------|
| 1 | [Brief title] | [SEV] | COVERED | `path:line` | None needed |
| 2 | [Brief title] | [SEV] | PARTIAL | `path:line` | Added case to existing file |
| 3 | [Brief title] | [SEV] | WRONG_ASSERTION | `path:line` | Fixed assertion |
| 4 | [Brief title] | [SEV] | NO_COVERAGE | — | Created new test |
| 5 | [Brief title] | [SEV] | N/A | — | Not testable |

### Validation Status

| # | Bug Title | Test File / Target | Validation Status |
|---|-----------|-------------------|-------------------|
| 2 | [Brief title] | `tests/test_foo.py` | BUILD_OK (modified) |
| 3 | [Brief title] | `tests/test_bar.py:67` | BUILD_OK (modified) |
| 4 | [Brief title] | `tests/test_baz.py` | BUILD_OK (new) |
| 5 | [Brief title] | — | SKIPPED (N/A) |

```
Validation Summary: 3 BUILD_OK, 0 BUILD_FAILED, 1 SKIPPED
Validation Command: python -m py_compile <file>
```

### New Tests Written (NO_COVERAGE)

New test files created for bugs with no existing test coverage.

| Bug # | File Created | Build Target / Runner |
|-------|-------------|----------------------|
| 4 | `tests/test_baz.py` | `pytest tests/test_baz.py` |

```[language]
// Contents of new test file
```

### Modifications Applied (PARTIAL / WRONG_ASSERTION)

Changes applied to existing test files.

| File | Bug # | Change Applied |
|------|-------|----------------|
| `tests/test_foo.py` | 2 | Added `test_missing_case()` |
| `tests/test_bar.py:67` | 3 | Changed `assert result == 0` → `assert result == 1` |

### Already Covered (COVERED)

Bugs already caught by existing tests — no action needed.

| Bug # | Bug Title | Existing Test |
|-------|-----------|---------------|
| 1 | [Brief title] | `tests/test_foo.py:45` — `test_sanitize_input()` |

### Not Testable (N/A)

Bugs that cannot have automated regression tests (config issues, documentation, LLM workflows, etc.).

| Bug # | Bug Title | Reason |
|-------|-----------|--------|
| 6 | [Brief title] | Config file — no executable code |
```

## Final Instructions

**CRITICAL: All verified bugs appear in the main report body.** The Regression Test Suite section organizes test artifacts, but every bug — regardless of whether a test can be written — MUST be documented in the severity sections (Critical/Important/Minor Issues) above. Bugs with `N/A` regression test status are still valid bugs that need reporting.

**CRITICAL: Regression tests are supplementary, not a filter.** If no test framework is detected, or if a bug cannot have a test written (config, docs, LLM workflows), mark it as `N/A` and **still include the bug in the report**. Never skip a verified bug because you cannot write a test for it.

- **No unverified bugs** — Every finding must pass the verification protocol
- **Evidence required** — Include code snippets and trace for every bug
- **Explicit false positive elimination** — State why each bug isn't handled elsewhere
- Analyze all applicable dimensions — skip N/A dimensions explicitly with reason (see Dimension Applicability Check)
- Assume the reader is a senior engineer who will verify your findings
- If Draft context is available, explicitly note which architectural violations or product requirement bugs were found
- Be precise about file locations and line numbers
- Include git branch and commit in report header
- **Write regression tests when possible** — If a test framework is detected, write test files using the project's native framework (Steps 4-6). If no framework exists, skip Steps 2-6 and mark all bugs as `N/A` for regression tests
- **Never modify production code** — Only create/modify test files and their build configs
- **Validate before reporting** — If tests were written, validate syntax/compilation before finalizing; include validation status in the report
- **Respect project conventions** — Match existing test directory structure, naming patterns, import conventions, and framework idioms
- **Use native frameworks** — pytest for Python, `go test` for Go, GTest for C++, Jest/Vitest for JS/TS, `cargo test` for Rust, JUnit for Java — never force a foreign test framework
- **Learn from findings** — After report generation, execute the pattern learning phase from `core/shared/pattern-learning.md` to update `draft/guardrails.md` with newly discovered conventions and anti-patterns

---

## Cross-Skill Dispatch

### Suggestions at Completion

After bughunt report generation:

**If critical bugs found:**
```
"Critical bugs found. Consider:
  → /draft:debug — Run structured debug session on critical finding #{n}
  → git bisect — Find the exact commit that introduced the bug"
```

### Test Writing Guardrail

When offering to write regression tests for found bugs:
```
ASK: "Want me to write regression tests for the {n} bugs found? [Y/n]"
```
Never auto-write tests — always ask first.

### Jira Sync

If Jira ticket linked, sync via `core/shared/jira-sync.md`:
- Attach `bughunt-report-latest.md` to ticket
- Post comment: "[draft] bughunt-complete: Found {n} issues — {critical} critical, {major} major."
