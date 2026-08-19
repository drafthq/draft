# Chapter 16: Coverage

Part IV: Quality· Chapter 14

5 min read

The dashboard says 94% code coverage. The team celebrates. Then a production incident exposes a bug in the payment retry logic — code that is technically "covered" because a test executes the function, but never asserts that retries are idempotent. The line was hit. The behavior was never verified. This is the coverage trap: measuring execution instead of verification./draft:coveragegoes beyond line counts to analyze what coverage actually means for each module.

## Coverage Is Measurement, Not Process

Draft separates the process from the measurement. TDD is the process — write a failing test, implement the minimum code to pass, refactor. That lives in/draft:implement. Coverage is the measurement — how much code do those tests actually exercise?/draft:coverageruns the project's existing coverage tools, parses the output, and produces a structured report with gap analysis.

The command auto-detects the project's language and test framework fromdraft/tech-stack.mdand config files. It supports Jest, Vitest, pytest, Go's built-in coverage, Cargo tarpaulin, JaCoCo, SimpleCov, and others. If the tool cannot be detected, it asks rather than guessing.

## Per-Module Coverage Targets

A single global coverage target is a blunt instrument. Authentication code and utility functions do not carry the same risk./draft:coveragesupports differentiated targets by module risk level, configured indraft/workflow.md:

The defaults above are starting points, not mandates. Teams should customize coverage targets inworkflow.mdunder thecoverage_targetskey, including per-module overrides that map specific directories to risk levels. A payments service handling real money needs different thresholds than an internal admin dashboard. Teams operating under regulatory requirements (SOC2, HIPAA, PCI-DSS) may need higher minimums. Engineering leads should calibrate these targets after/draft:initand revisit them when the risk profile of the codebase changes.

When no explicit configuration exists, these defaults are applied and the inferred classification is flagged in the report so the developer can correct it. The report shows per-module targets alongside actual coverage:

The insight behind per-module targets: not all code has the same blast radius when it fails. A bug in the payment processor can cost real money. A bug in a log formatter produces ugly output. Allocating the same testing effort to both is a misuse of engineering time. Risk-based targets focus effort where failures are most consequential.

## Types of Coverage

Line coverage is the most common metric and the least meaningful./draft:coverageanalyzes multiple types of coverage depending on the module's complexity.

### Line Coverage (Basic)

Was this line executed during testing? This catches completely untested code but misses untested branches within tested lines. A function with anif/elsecan show 100% line coverage if both branches happen to execute the same lines for different reasons.

### Branch/Condition Coverage (Meaningful)

Was every branch of every decision point exercised? For modules with complex conditional logic — nested conditionals, switch statements, compound boolean expressions — line coverage alone is insufficient. Branch coverage ensures that both thetrueandfalsepath of every condition have been tested.

### MC/DC — Modified Condition/Decision Coverage

For safety-critical modules (auth, payments, crypto),/draft:coveragerecommends MC/DC analysis. MC/DC requires that each individual condition in a compound decision independently affects the outcome. This is the standard in DO-178C (avionics software) and is referenced in ISTQB Advanced Test Analyst syllabi.

Any boolean expression with three or more conditions is flagged as an MC/DC candidate. For example,if (isAdmin && hasPermission && !isLocked)requires tests proving that changing each condition alone can flip the result — not just that the overall expression was true once and false once.

## Gap Analysis

For every file below its target,/draft:coverageidentifies uncovered lines and classifies each gap:

## Characterization Testing for Legacy Code

When/draft:coverageencounters modules with zero or very low coverage, it does not recommend writing unit tests directly. Untested legacy code is, by definition, code whose behavior is not fully understood. Writing tests for it means guessing what it should do — and guessing wrong locks in incorrect behavior.

Instead, Draft recommends the Golden Master approach (from Michael Feathers'Working Effectively with Legacy Code):

* Create Golden Master baselines— Generate fixed-seed inputs that exercise the module's public interface. Capture all outputs (return values, side effects, logs) as the approved baseline
* Lock behavior with approval tests— Any change that alters the captured output triggers a failure, making current behavior explicit and protected
* Refactor under the safety net— With approval tests guarding against regressions, refactor the module incrementally
* Write proper unit tests during refactoring— As logic is extracted and clarified, write focused tests using TDD
* Retire approval tests— Once proper coverage meets the target, remove the Golden Master tests
Writing unit tests for legacy code without understanding it creates a false safety net. You write a test asserting the function returns 42. It passes. But 42 is thebuggyanswer. Now the bug is locked in by a passing test. Characterization testing avoids this by first documenting what the codeactually does, then deciding what itshould doduring a deliberate refactoring phase.

## Mutation Testing

High line coverage can coexist with weak tests. A test that calls a function and checks only that it does not throw has technically "covered" every line the function executes — but it has not verified any behavior. Mutation testing exposes this gap.

The concept: introduce small code changes (mutants) into the source. If a mutant changesx > 0tox >= 0and all tests still pass, those tests are not actually verifying the boundary condition. The mutant "survived," indicating weak assertions even at high coverage.

Mutation score= killed mutants / total non-equivalent mutants. Target: 80% or higher for critical modules.

/draft:coveragerecommends mutation testing for modules at 90%+ line coverage that are high-risk, or where past bugs have occurred. It does not block coverage completion on mutation analysis — the recommendation is advisory, surfaced when the conditions warrant it.

100% line coverage does not mean 100% correct. Coverage measures execution, not verification. A test that calls every function but makes no assertions achieves full coverage while testing nothing. The antidote is layered analysis: line coverage for the basics, branch coverage for decision logic, MC/DC for safety-critical paths, and mutation testing to verify that the tests actually test something. Each layer catches what the previous one misses.

## Bughunt Cross-Reference

When a bughunt report exists for the same track or module,/draft:coveragecross-references it against the coverage data. The intersection of "known bugs" and "uncovered code" is the most dangerous zone in any codebase — confirmed defects in code that no test exercises.

These cross-referenced findings are prioritized above all other suggested tests. The reasoning is straightforward: a known bug in untested code is a bug that can regress silently. The first step in fixing it is writing a test that proves it exists.

## The Coverage Report

After analysis,/draft:coveragepresents the full report and stops for developer approval. The developer can accept current coverage, request additional tests for testable gaps, justify and document acceptable uncovered lines, or adjust the coverage target. Nothing is recorded until the developer explicitly approves.

Approved results are recorded in three places: the track'splan.md(coverage note on the relevant phase),metadata.json(machine-readable coverage data with timestamp), and a timestamped report file indraft/tracks/<id>/with a-latest.mdsymlink for quick access. Re-running coverage on the same module shows the delta: "Coverage improved from 87.3% to 96.2% (+8.9%)."
