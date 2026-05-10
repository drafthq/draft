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
