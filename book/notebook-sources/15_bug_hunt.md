# Chapter 15: Bug Hunt

Part IV: Quality· Chapter 13

6 min read

A developer runs the test suite. Everything passes. They open a pull request. The reviewer approves it. The code ships to production. Three days later, a user in Germany discovers that entering an umlaut in the search field crashes the application. The test suite tested ASCII inputs. The reviewer checked logic flow. Nobody traced untrusted input from the search box through the URL encoder, into the database query, and back to the response renderer. Nobody checked all fourteen places where bugs hide./draft:bughuntdoes.

## Why Fourteen Dimensions

Bugs do not confine themselves to a single category. A race condition in state management creates a security vulnerability when stale auth tokens are used for requests. A performance issue in an algorithm becomes a reliability issue under load. An accessibility gap becomes a legal liability in regulated industries.

Most code review catches bugs in one or two dimensions — usually correctness and style./draft:bughuntsystematically analyzes code across fourteen dimensions because bugs cluster at the intersections between concerns, in the places where no single reviewer has expertise.

The bug report is the primary deliverable. Every verified bug appears in the final report regardless of whether a regression test can be written. Tests are supplementary output. Bughunt does not fix code — it finds defects, verifies them with evidence, and reports them with severity rankings and actionable fix descriptions.

## The Fourteen Dimensions

Each dimension targets a distinct class of defect. Before analysis,/draft:bughuntdetermines which dimensions apply to the codebase — a CLI tool skips UI Responsiveness and Accessibility, a frontend-only repo skips API Contracts and Configuration. Skipped dimensions are documented with reasons, not silently omitted.

## Taint Tracking

Dimension 3 (Security) includes end-to-end taint tracking — following untrusted input from its entry point through the entire codebase to every dangerous sink. This is not a surface-level check forinnerHTMLusage. It is a systematic trace of data flow.

Bughunt identifies all entry points: HTTP parameters, form data, file uploads, environment variables, CLI arguments, message queue payloads, webhook bodies. For each entry point, it traces the data through every function call, transformation, and storage operation until it reaches a dangerous sink — SQL queries, shell execution,eval,innerHTML, file path construction, URL construction, deserialization, or template rendering.

For each sink, bughunt verifies whether sanitization or validation exists onevery pathfrom source to sink. A single unsanitized path is sufficient for exploitation, even if nine other paths are properly guarded.

## The Verification Protocol

The difference between bughunt and a static analysis tool is the verification protocol. Static analysis tools produce hundreds of findings, most of them false positives. Bughunt applies a multi-step verification process to every candidate finding before it enters the report.

### Six Verification Steps

* Code path verification— Read the actual code, trace the data flow, check for upstream guards and validators, verify the path is reachable in production
* Context cross-reference— Check.ai-context.md(is this behavior intentional?),tech-stack.md(does the framework handle it?),product.md(is this a requirement violation?), existing tests (is this expected behavior?)
* Framework verification— Read the official documentation for the specific method or pattern, quote the relevant section, check framework version for behavior differences
* Codebase pattern check— Search for the same pattern elsewhere. If it appears consistently and works, investigate what makes this instance different
* False positive elimination— Is this dead code? Test-only code? Intentionally disabled? Explained by a comment?
* Pattern prevalence check— If the pattern appears 5+ times, sample three instances. If they all work correctly, do not report. If all are buggy, report the total count
Every reported bug must include: the actual problematic code snippet, the trace showing how data reaches the bug, which verification checks were completed, and an explicit statement of why this is not a false positive. A finding without evidence is not a finding — it is speculation.

## Confidence Filtering

Bughunt uses a strict confidence threshold. OnlyHIGHandCONFIRMEDfindings are included in the report. This is a deliberate design choice — a report with 50 findings where half are false positives teaches the team to ignore the report. A report with 8 verified findings, all actionable, teaches the team to trust it.

## Context-Driven Analysis

What separates/draft:bughuntfrom generic static analysis is its use of Draft context. Whendraft/.ai-context.mdexists, bughunt leverages every documented architectural decision to find bugs that tools without context cannot detect:

* Critical invariants— The architecture documents that "user IDs are always UUIDs" or "all monetary values use integer cents." Bughunt checks for violations
* Concurrency model— The architecture specifies the threading model. Bughunt uses this to identify race conditions specific to that model
* Data state machines— If the architecture defines valid state transitions (e.g., Order: pending → confirmed → shipped), bughunt checks for code that allows invalid transitions
* Failure recovery matrix— If the architecture claims operations are idempotent, bughunt verifies those claims by tracing retry paths
* Consistency boundaries— Where eventual consistency is documented, bughunt looks for stale reads, lost events, and missing reconciliation at those seams

## Regression Test Generation

For each verified bug, bughunt generates a regression test in the project's native test framework. The test is designed tofail against the current buggy codeand pass after the fix — serving as both proof of the bug and protection against regression.

Before generating any test, bughunt discovers existing test coverage for the buggy code path. Each bug is classified as COVERED (existing test catches it), PARTIAL (test exists but misses this case), WRONG_ASSERTION (test asserts buggy behavior as correct), NO_COVERAGE (no test exists), or N/A (untestable code).

If no test framework is detected, bugs are still reported in full — the test section is marked N/A. The bug report is the primary deliverable; tests are supplementary.

## Bughunt vs. Review

These commands serve different purposes and are designed to work together:

Thewith-bughuntmodifier on/draft:reviewruns both in sequence — first the review checks spec compliance and conventions, then bughunt sweeps for defects across all fourteen dimensions. This combined run inherits the scope from the review command, so there is no redundant scope confirmation.

The most dangerous bugs live at the intersection of two dimensions. A performance issue (Dimension 4) in an algorithm becomes a denial-of-service vulnerability (Dimension 3) when the input is user-controlled. A state management bug (Dimension 7) becomes a data loss issue (Dimension 2) when the stale state is persisted. Fourteen dimensions is not about being exhaustive for its own sake — it is about covering the cross-cutting spaces where single-dimension reviews have blind spots.

## Dimension Deep Dives

Three of the fourteen dimensions deserve special attention because they catch bug classes that are commonly missed:

### Dimension 11: Tests

Bughunt analyzes tests themselves for defects. This includesassertion densityproblems — tests with zero or weak assertions likeexpect(result).toBeDefined()that pass without actually verifying behavior. It catchestest isolation violationswhere shared mutable state between test cases creates ordering dependencies. And it identifiestest double misusewhere mocks diverge from real implementation behavior, giving false confidence.

### Dimension 12: Dependencies

Beyond checking for known CVEs, bughunt examinestyposquatting risk(packages with names suspiciously similar to popular ones),transitive dependency depth(deeply nested chains that increase supply chain attack surface), andlicense conflicts(GPL dependencies in MIT projects, AGPL in proprietary code).

### Dimension 13: Algorithmic Complexity

This dimension goes beyond obvious O(n^2) loops. Bughunt identifiesregex catastrophic backtracking— nested quantifiers like(a+)+applied to user-controlled input that can lock a CPU for minutes. It findscache invalidation stormswhere a cache miss triggers recomputation that itself invalidates caches, creating a thundering herd. And it catcheshot path inefficiencywhere linear scans are used where hash maps would suffice, or the same collection is sorted repeatedly.
