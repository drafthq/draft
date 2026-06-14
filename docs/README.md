# Draft `docs/` Index

Map of everything under `docs/`. This is the source of truth for **what each document is and whether it still reflects reality**. Skim the status column before acting on any plan or design here — several describe work that has already shipped.

> `docs/` holds engineering reference, design proposals, research, point-in-time audits, and go-to-market strategy. It is **not** end-user documentation (that lives on the site under `web/`) and **not** the methodology source of truth (that is `core/methodology.md`).

## Status legend

| Tag | Meaning |
|-----|---------|
| **Current** | Living reference; kept accurate. |
| **Proposal** | Forward-looking design; **not built**. |
| **Implemented** | The described work has shipped; doc retained as a design record. |
| **Partial** | Some of the described work shipped; remainder pending. |
| **Superseded** | Replaced by newer work; kept for history only. Do not act on it. |
| **Historical** | Dated point-in-time audit/review. Findings were resolved in later work — a snapshot, not a live checklist. |
| **Strategy** | Internal go-to-market / product-direction material (not engineering). |
| **Cruft** | Ephemeral artifact with no lasting value. |

## Reference (top-level)

| Document | Status | Summary |
|----------|--------|---------|
| [PLUGIN_ARCHITECTURE.md](PLUGIN_ARCHITECTURE.md) | **Current** | Skill registration mechanics, auto-discovery, plugin.json model, verification checklist. |
| [MIGRATION.md](MIGRATION.md) | **Implemented** | Record of the command-model migration to the 5-router surface (`plan`/`ops`/`docs`/`discover`/`jira`). Migration is complete. |
| [CONTEXT_ENGINE.md](CONTEXT_ENGINE.md) | **Proposal** | Design for a long-lived Rust context-serving engine for very large repos (10M+ LOC). Not implemented. |
| [COMMAND_REDUCTION_PLAN.md](COMMAND_REDUCTION_PLAN.md) | **Superseded** | The original plan to shrink the public command surface. The two-tier router model it argued for has shipped — see MIGRATION.md and the current README. |

## Design (`design/`)

| Document | Status | Summary |
|----------|--------|---------|
| [design/init-graph-simplification.md](design/init-graph-simplification.md) | **Current** | Locked spec collapsing `/draft:index` into a scope-aware `/draft:init` with a root-first graph spine. Tracks the in-flight `graph-init.sh` work. |

## Research (`research/`)

| Document | Status | Summary |
|----------|--------|---------|
| [research/workflow-audit-graph-init-plan-implement-review.md](research/workflow-audit-graph-init-plan-implement-review.md) | **Current** | Audit of the init → plan → implement → review pipeline and graph-primary transition. |
| [research/draft-mature-brownfield-feedback.md](research/draft-mature-brownfield-feedback.md) | **Current** | Field report from running `/draft:init` on a large, well-documented brownfield system; the input that drove the brownfield work. |
| [research/draft-mature-brownfield-implementation-plan.md](research/draft-mature-brownfield-implementation-plan.md) | **Partial** | 6-phase plan operationalizing the brownfield feedback. Phases 1–2 shipped (extended frontmatter, graph health dashboard, sections 9–10); 3–6 pending. |
| [research/proposed-graph-backed-architecture-template.md](research/proposed-graph-backed-architecture-template.md) | **Implemented** | Design for the graph-backed `architecture.md` template — shipped in `core/templates/root-architecture.md` and `/draft:init`. |
| [research/okf-open-knowledge-format-and-draft.md](research/okf-open-knowledge-format-and-draft.md) | **Implemented** | Open Knowledge Format alignment analysis — shipped via `scripts/tools/okf-{emit,bundle,check}.sh` and `type:` frontmatter. |

## Plans (`plans/`)

| Document | Status | Summary |
|----------|--------|---------|
| [plans/graph-engine-replacement.md](plans/graph-engine-replacement.md) | **Implemented** | Replacement of the vendored Aether `graph` binary with `codebase-memory-mcp` (CLI mode). Phases 0–5 landed; doc carries its own remaining-work note. |

## Audits (`audit/`) — all **Historical**

Dated point-in-time reviews. Their findings were addressed in the work that followed (the router model, jira unification, OKF, and Foundations quality layer all shipped; the merge-marker, `jira/references/review.md`, GRAPH.md, and lib.sh-registration items have been resolved in the current tree). Treat these as a record of how the codebase reached its current state, **not** as open task lists.

| Document | Subject |
|----------|---------|
| [audit/documentation-currency-audit-20260614.md](audit/documentation-currency-audit-20260614.md) | Most recent. Doc-count and OKF-documentation currency sweep; establishes the "`audit/*` are not living docs" policy and flags hardcoded-count drift. |
| [audit/draft-parity-porting-manifest.md](audit/draft-parity-porting-manifest.md) | The 4-phase parity porting plan (file inventory + forbidden-string list) that the phase-0/1/2 reviews below grade against. |
| [audit/phase-0-1-2-exec-summary-20260519-2100.md](audit/phase-0-1-2-exec-summary-20260519-2100.md) | Executive summary of the Phase 0/1/2 parity review. |
| [audit/phase-0-1-2-final-review-20260519-2100.md](audit/phase-0-1-2-final-review-20260519-2100.md) | Full 4-criterion review of the Phase 0/1/2 deliverables. |
| [audit/phase-1-command-routing-review-20260519-1430.md](audit/phase-1-command-routing-review-20260519-1430.md) | Independent review of the 5-router routing model. |
| [audit/command-surface-review.md](audit/command-surface-review.md) | Review of the router surface and removal of flat jira commands. |
| [audit/deep-review-full-codebase.md](audit/deep-review-full-codebase.md) | Post-jira-unification review across skills/core/scripts/tests. |
| [audit/deep-review-build-graph-tests.md](audit/deep-review-build-graph-tests.md) | Build system, graph engine, and test-suite registration review. |
| [audit/deep-review-hygiene-consistency.md](audit/deep-review-hygiene-consistency.md) | Public-doc consistency (counts, router model) review. |
| [audit/deep-review-web-public.md](audit/deep-review-web-public.md) | Public website (getdraft.dev) router/jira freshness review. |
| [audit/web-public-review.md](audit/web-public-review.md) | Exhaustive `web/` content audit with fix checklist. |
| [audit/jira-port-final-review.md](audit/jira-port-final-review.md) | Audit of the unified `/draft:jira` router + review pipeline. |
| [audit/codebase-review-2026-06-08.md](audit/codebase-review-2026-06-08.md) | Multi-agent 54-issue codebase review (merge markers, atomic writes, dead stubs). |
| [audit/skills-audit.md](audit/skills-audit.md) | Skills inventory + refactoring opportunities (triggers, sizing, voice). |
| [audit/branding-baseline-audit-20260519.md](audit/branding-baseline-audit-20260519.md) | Pre-merge zero-leakage branding baseline. |
| `audit/scheduler-branding-audit.log` | **Cruft** — single-line PASS log from the branding sweep. Safe to delete. |

## Internal — strategy & go-to-market (`internal/`)

Business/product-direction material, kept separate from engineering docs. Not generated, not derived from code.

| Document | Type | Summary |
|----------|------|---------|
| [internal/distribution-plan.md](internal/distribution-plan.md) | **Strategy** | Positioning + 4-layer launch strategy; `/draft:review` as the lead wedge. |
| [internal/competitive-analysis-kiro.md](internal/competitive-analysis-kiro.md) | **Strategy** | Draft vs. Kiro feature matrix (40+ dimensions). |
| [internal/draft-companion-vision.md](internal/draft-companion-vision.md) | **Strategy** | Phase-2 "Draft Companion" desktop/web cockpit concept. |
| [internal/draft-ide-startup-strategy.md](internal/draft-ide-startup-strategy.md) | **Strategy** | Phase-3 "Draft Studio" native-IDE direction. |
| [internal/launch-show-hn.md](internal/launch-show-hn.md) | **Strategy** | Show HN launch kit (title, body, playbook, tweet thread). |
| [internal/famous-repos-runbook.md](internal/famous-repos-runbook.md) | **Strategy** | Operational runbook for the "run Draft on 5 famous repos" blog launch. |
| [internal/blog-draft-on-famous-repos/index.html](internal/blog-draft-on-famous-repos/index.html) | **Strategy** | Draft blog-post scaffold for the famous-repos launch (`noindex`, in progress). |
| `internal/mcp-tool-discovery-2026.pdf` | **Strategy** | MCP tool-discovery reference (PDF, 156 KB). |

---

*Maintenance: when work described by a **Proposal**/**Partial**/**Plan** here ships, flip its status to **Implemented**/**Superseded** and point it at what replaced it. When you add a doc to `docs/`, add a row here.*
