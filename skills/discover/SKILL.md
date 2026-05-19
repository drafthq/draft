---
name: discover
description: "Primary router for discovery, debugging, investigation, quality, and exploration workflows. Analyzes user intent and dispatches to debug, bughunt, quick-review, deep-review, coverage, testing-strategy, learn, index, tour, impact, assist-review. The recommended entry point for any 'find out', 'check', 'review', or 'investigate' request."
---

# Discover - Investigation & Quality Router

`/draft:discover` is the single front door for all investigation, auditing, pattern learning, and quality exploration activities.

## When to Use

- Any debugging or root-cause work
- Code quality reviews (lightweight to exhaustive to architectural)
- Coverage analysis and test strategy design
- Discovering and codifying project conventions
- Monorepo indexing and context aggregation
- Project tours, impact analysis, or reviewer assistance

## Routing Logic

Strong keyword and phrase matching with fallback to a menu when intent is broad or compound. Several quality commands auto-chain (e.g. review may call bughunt).

| User Intent Keywords                              | Dispatches To            | Purpose |
|---------------------------------------------------|--------------------------|---------|
| debug, investigate bug, reproduce, isolate, diagnose | `/draft:debug` | Structured 4-phase debugging |
| hunt bugs, find bugs, exhaustive sweep, regression hunt | `/draft:bughunt` | 14-dimension bug hunt + regression tests |
| quick review, fast review, sanity check, lightweight review | `/draft:quick-review` | 4-dimension review (~2 min) |
| deep review, production audit, module audit, ACID compliance | `/draft:deep-review` | Full module lifecycle + architecture audit |
| coverage, code coverage, test coverage report | `/draft:coverage` | Coverage measurement and gap report |
| test strategy, testing plan, coverage targets, pyramid | `/draft:testing-strategy` | Test approach design |
| learn patterns, discover conventions, update guardrails, anti-patterns | `/draft:learn` | Pattern mining + guardrail evolution |
| index services, aggregate context, monorepo index | `/draft:index` | Monorepo service context aggregation |
| tour, walkthrough, onboard me, getting started tour | `/draft:tour` | Guided interactive project tour |
| impact, blast radius, change impact, analytics | `/draft:impact` | Telemetry-driven change impact reports |
| assist review, help reviewer, PR architectural audit | `/draft:assist-review` | Risk audit to support human reviewers |

## Dispatch Examples

User: "debug the flaky test in CI"

→ dispatches to `/draft:debug "flaky test in CI"`

User: "quick review the PR diff"

→ dispatches to `/draft:quick-review [pr context]`

User: "run a deep production audit on the auth service"

→ dispatches to `/draft:deep-review auth`

User: "learn the coding patterns in this repo and tighten guardrails"

→ dispatches to `/draft:learn`

User: "index the monorepo so agents see all services"

→ dispatches to `/draft:index --init-missing`

## Auto-Chains & Recommendations

- `/draft:implement` and `/draft:review` (primary) frequently call into discover skills at phase boundaries.
- `/draft:discover "full quality"` may suggest or chain review + bughunt + coverage.
- After major changes, `/draft:discover learn` is recommended to keep guardrails current.

Direct specialist commands are preserved as shims for existing workflows and scripts.
