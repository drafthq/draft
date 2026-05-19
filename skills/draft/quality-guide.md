# Draft Quality Gate & Review Decision Guide

This guide helps you choose the most effective quality control and review commands for your codebase. Draft provides an **audit spectrum** that scales from quick, change-scoped checks to deep, service-wide production readiness reviews.

## The Quality Audit Spectrum

| Command | Scope | Analysis Time | Primary Objective | Key Outputs |
|:---|:---|:---|:---|:---|
| `/draft:quick-review` | File / PR / Diff | ~2 min | "Are there any obvious issues or regressions in this change?" | 4-dimension findings (Style, Bugs, Security, Performance) with severity rankings. |
| `/draft:review` | Change-scoped (Track, Diff, Commits) | ~10 min | "Does this track implementation meet the spec, coverage targets, and quality gates?" | Three-stage review report with verification verdict, automatic coverage verification, and quality gate sign-off. |
| `/draft:bughunt` | Codebase-scoped (Repo, paths, or active track) | ~20 min | "What deep, hidden, or structural bugs exist in this code?" | Exhaustive 14-dimension bug report, verification protocol, and automated regression tests (when a framework exists). |
| `/draft:deep-review` | Module-scoped (Single service or component) | ~30 min | "Is this component resilient, secure, observable, and fully ready for production?" | Production-grade audit across ACID compliance, reliability, observability, and concrete implementation specifications. |

---

## Command Decision Guide

### 1. Fast Feedback / Pre-Commit Sanity Check
> [!TIP]
> Use **`/draft:quick-review`** when you want a fast, lightweight sanity check of your modified files before opening a PR or running full reviews.
- **When to run:** Before staging changes, during local development loops.
- **Why:** Zero setup, rapid turnaround, checks standard dimensions (security, performance, styling).

### 2. Track Completion & Pull Request Quality Gate
> [!IMPORTANT]
> Use **`/draft:review`** (the canonical review command) when you finish a development phase or an entire track.
- **When to run:** Before submitting work for final PR approval.
- **Why:** It validates the implementation directly against the active track's `spec.md` and `plan.md` to ensure all acceptance criteria and quality gates are met. It also auto-invokes coverage checks when TDD is active.

### 3. Debugging Hard-to-Find Defects or Refactoring
> [!WARNING]
> Use **`/draft:bughunt`** if you are encountering elusive bugs, regression errors, or before refactoring a legacy module.
- **When to run:** Prior to refactoring complex areas, or when users report intermittent production bugs.
- **Why:** Conducts a deep, 14-dimension sweep specifically designed to surface edge cases, race conditions, memory leaks, and logic flaws.

### 4. Shipping Core Infrastructure to Production
> [!CAUTION]
> Use **`/draft:deep-review`** before launching a critical service, API, database layer, or high-throughput component.
- **When to run:** Before major deployments or architectural sign-offs.
- **Why:** Audits the architecture for ACID compliance, concurrency safety, fault tolerance, rate limiting, and telemetry, providing a formal readiness score.

---

## Relationship to Built-in Bug Hunt Agents

Many AI tools and editors provide built-in bug-hunting agents (such as Claude Code's native `bughunt` or other automated scanners). Draft's quality commands are designed to be **complementary**:

* **Built-in Agents:** Typically focus on fast, generic static analysis, automated linting, and rapid parallel auto-fixes.
* **Draft Quality Commands:** Leverage project-specific context (including `draft/architecture.md`, `draft/product.md`, `draft/tech-stack.md`, and `draft/guardrails.md`). This eliminates false positives and ensures findings align with your specific domain constraints, team conventions, and technical stack choices.

For maximum quality assurance, run built-in scanners in parallel with Draft commands!
