# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
- Ongoing refinements to agent behavior protocols.

## [2.4.0] - 2026-04-26

### Added

- **Knowledge graph engine** (`graph/`) — Pure Node.js + tree-sitter WASM. Indexes Go, Python, TypeScript/JS, C/C++, proto. ctags fallback for Java/Rust/Ruby/Swift/Kotlin/PHP/etc. CLI exposes 6 query modes:
  - `--mode callers` — file-level (include graph) and function-level (call index) callers.
  - `--mode impact` — transitive blast radius with depth grouping and **file-class dimension** (code/test/doc/config).
  - `--mode hotspots` — complexity × fan-in ranking.
  - `--mode modules` — inter-module dependency graph with hub detection.
  - `--mode cycles` — circular dependency detection (iterative DFS, cycle-stable).
  - `--mode mermaid` — module-deps and proto-map diagrams as fenced code blocks ready for embedding.
- **Confidence markers on call edges** — every `*-call` JSONL record carries `confidence: direct | inferred`. Direct = bare-identifier callee (`foo()`, `Foo::bar()`); inferred = member/attribute/field call where the receiver collapses (`obj.foo()`). Skills weight findings accordingly.
- **Atomic incremental graph builds** — per-module SHA-256 hashing in `hashes.json`. Output writes to a temp directory then renames into place; readers never see partial state.
- **14 deterministic shell helpers** under `scripts/tools/`:
  - `git-metadata.sh`, `parse-git-log.sh` — git introspection emitting JSON.
  - `classify-files.sh` — language + category classification with broad ignore set (`.terraform`, `_build`, `.svelte-kit`, `.dart_tool`, `Pods`, `cdk.out`, `.turbo`, `.parcel-cache`, `.nuxt`, `.vercel`, `.pnpm-store`, plus the standard set).
  - `hotspot-rank.sh`, `cycle-detect.sh`, `mermaid-from-graph.sh` — graph wrappers with graceful degradation.
  - `freshness-check.sh`, `manage-symlinks.sh`, `parse-reports.sh`, `adr-index.sh`, `validate-frontmatter.sh`, `scan-markers.sh`, `detect-test-framework.sh`, `run-coverage.sh`.
  - All emit JSON, follow uniform exit-code contract (0 = success, 1 = invocation error, 2 = upstream-data missing), degrade gracefully.
- **Track-level impact memory** — `metadata.json` schema gains an `impact` block (`files_touched`, `modules_touched`, `downstream_files`, `downstream_modules`, `max_depth`, `by_category`, `computed_at`). Written by `/draft:implement` on phase complete; read by `/draft:new-track` to surface overlap warnings when a new track touches modules recently changed by a completed track.
- **Shared procedures** — `core/shared/graph-query.md` (canonical graph CLI reference), `core/shared/parallel-analysis.md` (Map/Reduce IR-based parallel codebase analysis for large repos — ~60% wall-clock cut at XL tier).
- **16 new tool tests** under `tests/test-tools-*.sh` plus a registry test (`tests/test-tools-registered.sh`) and a conventions test (`tests/test-tools-conventions.sh`).
- **`make build` and `make lint` Makefile targets** — `make build` is an explicit alias for `make build-integrations`; `make lint` runs `scripts/lint.sh`.

### Changed

- **Methodology and skills refreshed** with deeper guidance and "Red Flags — STOP if you're..." preambles; `architecture.md` template expanded from 25 sections to 28 sections + 5 appendices.
- **Build script** (`scripts/build-integrations.sh`) refactored to source shared definitions from `scripts/lib.sh` (`SKILL_ORDER`, `CORE_FILES`, `TOOLS`).
- **Copilot syntax transform** hardened — kebab-case skill names only (no over-match for `<>`), email-shaped tokens (`foo@draft.com`) preserved, alternation delimiters fixed.
- **TS module-edge resolution** in graph writer now resolves multi-segment relative imports (`../../shared/foo`) against the source file's directory rather than stripping a single `../`.
- **JSON escape helper** in `scripts/tools/_lib.sh` now strips ASCII control characters so adversarial filenames can't produce invalid JSON.
- **Glob exclude patterns** in graph engine now anchor to full-string match (`*.pem` no longer matches `foo.pem.txt`).
- **`#draftXXX` TOC anchors** in `core/methodology.md` corrected (16 entries) to match actual `### /draft:X` heading slugs.

### Fixed

- **CI's `make build` invocation** — added the missing target so re-enabling auto-triggers won't fail with "No rule to make target 'build'".
- **Duplicate `workflow_dispatch:` keys** in `.github/workflows/pages.yml` — would have failed `check-yaml`.
- **`.h` C++ detection by substring** in graph engine — was triggering on any header containing `class ` (comments, identifiers, strings); now requires a real `class Name {`/`class Name :` pattern.
- **Mermaid loader CRLF handling** — graph mermaid generator now tolerates Windows-edited JSONL.
- **`.tsx` files with no TSX parser** — route straight to regex extractor instead of producing partial output through the TS parser.
- **`/draft:` callers dispatch** — bare symbols ending in extension-like tokens (e.g. `Foo.cc`) no longer mis-route to file-callers mode.
- **`parse-git-log.sh` scope match** — uses `BASH_REMATCH[0]` so unanchored patterns extract just the matched token, not the whole scope. `${var:N:-N}` substring syntax replaced for macOS Bash 3.2 compatibility.
- **`validate-frontmatter.sh` CRLF handling** — opening `---` line and closing-marker check now tolerate `\r`.
- **`detect-test-framework.sh` substring match** — vitest/jest/mocha detection now requires the `"name":` JSON dependency-key shape, no longer triggers on description text.
- **Stale doc counts** — README, CLAUDE.md, methodology.md aligned with actual codebase: 28 skills, 38 core reference files, 20 templates.

### Removed

- Three vendor-specific skills (`upload`, `regression`, `epic-status`) and their cross-references — Draft is GitHub-first; users wanting bisect should use `git bisect` directly.
- `core/guardrails.md` (legacy C++ systems-programming rules) and the C++ guardrails backfill paths in `learn`/`init` — six broken refs cleaned up.
- All legacy CLI / GitHub branches in `core/shared/vcs-commands.md` — rewritten as git + GitHub conventions only.

## [2.3.0] - 2026-04-05

### Added
- **3 new DX-focused commands** expanding Draft from 25 to 28 commands:
  - `/draft:tour` — Interactive architecture mentorship and codebase walk-through.
  - `/draft:impact` — ROI analytics tracking project friction, timeline metrics, and risk analysis.
  - `/draft:assist-review` — Summarizes intent and structural PR risks specifically for human reviewers.
- **Progressive Disclosure Reading Flow** — Major restructuring of the Draft book to prioritize developer workflows:
  - **Part II: Track Lifecycle** (Specs, Implementation, Review) now immediately follows Getting Started.
  - **Part III: How Draft Thinks** (deep architectural internals) moved to later chapters to maintain momentum.

### Changed
- **Global Synchronization:** All documentation, the main website, and all 24 book chapters updated to reflect the new **28-command** total.
- **Build Engine Refactor:** `scripts/build-book.sh` updated with dynamic TOC generation logic to handle renamed chapter files and shifted indices.
- **Appendix Audit:** Updated every chapter cross-reference in `Appendix A: Command Reference` to point to the correct sections in the new chapter sequence.
- **UI Consistency:** Chapter metadata in all 24 HTML fragments synchronized with the new Part numbering.

### Fixed
- Stale chapter indices in the command reference table.
- Hardcoded chapter ranges in the book landing page TOC logic.


### Added
- **8 new specialist commands** expanding Draft from 17 to 25 skills:
  - `/draft:debug` — Structured debugging: reproduce, isolate, diagnose, fix. Auto-invoked by `/draft:new-track` for bug tracks.
  - `/draft:deploy-checklist` — Pre-deployment verification checklists customized by tech-stack with rollback triggers.
  - `/draft:documentation` — Technical doc writing (readme, runbook, api, onboarding) using writer agent principles.
  - `/draft:incident-response` — Incident lifecycle: triage, communicate, mitigate, postmortem. Three modes (new/update/postmortem).
  - `/draft:quick-review` — Lightweight ad-hoc review for PRs, diffs, or files. Four dimensions, no track context required.
  - `/draft:standup` — Generate standup summaries from git history and track progress. Read-only.
  - `/draft:tech-debt` — Identify, categorize, and prioritize tech debt across six dimensions with remediation plans.
  - `/draft:testing-strategy` — Design test strategies with coverage targets. Complements `/draft:coverage`.
- **Two-tier architecture** — 4 primary workflow commands with auto-invocation + 21 specialist commands
- **Draft Book** — 22-chapter + 2-appendix comprehensive guide at `web/book/`:
  - Static path-based pages for SEO (migrated from hash SPA)
  - Full chapter navigation with prev/next links
  - Mobile-friendly responsive design
- **Website enhancements:**
  - Light theme with SVG illustrations
  - Comprehensive SEO (meta tags, Open Graph, sitemap with 24 book entries)
  - GA4 analytics on book pages
  - Bento grid layout with dense flow and full-width capstone
  - Guardrails.md card in architecture section
- **Enhanced agents:** debugger and RCA agents with expanded investigation protocols
- **Context loading improvements:** draft context loading shared procedure enhanced

### Changed
- Plugin manifest updated to register all 25 skills (was 17)
- `SKILL_ORDER` in build script expanded to 25 entries with headers and triggers for all new skills
- Skill dependency graph (`GRAPH.md`) rewritten for two-tier architecture with new subsystem groupings (Debugging, Operations, Authoring)
- `/draft:draft` overview command updated with complete 25-command reference table and subsystem descriptions
- Core methodology updated with references to new specialist commands
- Copilot integration regenerated (20,311 lines, up from ~15,000)
- Book build script (`build-book.sh`) improvements

### Fixed
- GRAPH.md specialist command count corrected (20 → 21)
- Skill enhancements and bug fixes (init, new-track, implement skills)

### Added
- **Codebase Signal Detection** in `/draft:init` Phase 1:
  - Classifies all source files into 11 signal categories: `backend_routes`, `frontend_routes`, `components`, `services`, `data_models`, `auth_files`, `state_management`, `background_jobs`, `persistence`, `test_infra`, `config_files`
  - Signal counts drive adaptive section depth — HIGH (>=3 files), brief (1-2), SKIP (0)
  - Integrates with existing Adaptive Sections table to override default skip rules
  - Persisted to `draft/.state/signals.json` for structural drift detection on refresh

- **Freshness State Tracking** in `/draft:init`:
  - SHA-256 hashes of all analyzed source files stored in `draft/.state/freshness.json`
  - Enables file-level staleness detection — more granular than `synced_to_commit` (which only detects that commits happened)
  - On refresh: changed/new/deleted files identified by hash diff, unchanged files skipped entirely
  - Short-circuits refresh when no source files changed: "Architecture context is current. Nothing to refresh."

- **Run Memory** for cross-session continuity:
  - Persists run state to `draft/.state/run-memory.json` with: run_id, phases completed/remaining, files analyzed, unresolved questions, resumable checkpoints
  - Detects interrupted previous runs and offers resume from last checkpoint
  - Surfaces unresolved questions in completion report (e.g., "Could not determine if src/legacy/ is actively used")
  - Preserves unresolved questions across refreshes for future session context

- **Enhanced Refresh Mode** (`/draft:init refresh`):
  - New Step 0: State-Aware Pre-Check before any refresh work
  - Loads freshness.json for file-level delta computation
  - Loads signals.json for structural drift detection (new signal categories, removed categories, significant growth)
  - Reports signal drift summary (e.g., "NEW: auth_files (0->5) — §16 Security Architecture needs generation")
  - Loads previous run's unresolved questions for continuity
  - Step k: Regenerates all three state files after successful refresh

- **Skill Dependency Graph** (`skills/GRAPH.md`):
  - Static reference artifact mapping all 17 Draft skill relationships
  - Mermaid topology diagram with hard dependencies (solid arrows) and optional/conditional relationships (dotted arrows)
  - Dependency matrix showing required-by, requires, and shared artifacts per skill
  - Execution chains: standard dev flow, monorepo flow, quality audit flow, Jira integration flow, learning flow
  - Shared subroutines table (Condensation Subroutine, Standard File Metadata, Three-Stage Review, Signal Classification)
  - ASCII artifact flow diagram showing data flow from init through all downstream skills

- **State Directory** (`draft/.state/`):
  - New directory created alongside `draft/tracks/` during initialization
  - Contains: `freshness.json`, `signals.json`, `run-memory.json`
  - Purpose: Enables incremental refresh, structural drift detection, and cross-session continuity

### Fixed
- **Cross-skill consistency audit** (29 issues fixed across 13 files):
  - `/draft:deep-review`: Added `draft/` pre-check, added missing metadata fields (project, remote, commit_message, dirty, synced_to_commit)
  - `/draft:change`: Added `draft/` pre-check, added git traceability to Change Log entries
  - `/draft:revert`: Added `draft/` pre-check, added "nothing to revert" handling for zero-commit tracks
  - `/draft:coverage`: Fixed `.ai-context.md` direct write → update `architecture.md` then Condensation Subroutine, added YAML frontmatter requirement
  - `/draft:decompose`: Rewrote Mutation Protocol to be `architecture.md`-first, fixed Step 5 template contradiction, aligned module threshold >5 → >3
  - `/draft:review`: Fixed anti-patterns table stage references, fixed bughunt invocation syntax
  - `/draft:bughunt`: Replaced non-existent `AskUserQuestion` tool reference
  - `/draft:adr`: Fixed filename format mismatch (`ADR-<N>` vs `<N>-<kebab>`) and sed regex
  - `/draft:new-track`: Standardized file operations (write+delete instead of rename)
  - `/draft:index`: Fixed bughunt mode `cd` pattern, standardized `--init-missing` flag format
  - `/draft:status`: Fixed orphan recovery suggestion (was incorrectly suggesting `/draft:revert`)
  - `CLAUDE.md`: Updated "Two-Stage Review" → "Three-Stage Review"

### Changed
- **BREAKING:** `/draft:validate` deprecated and removed. Functionality absorbed into `/draft:review` Stage 1 (Automated Validation).
- `/draft:review` upgraded from 2-stage to 3-stage process:
  - **Stage 1 (NEW):** Automated Validation — fast static checks for architecture conformance, dead code, circular dependencies, OWASP security scans (hardcoded secrets, SQL injection, XSS), and performance anti-patterns (N+1 queries, blocking I/O, unbounded queries)
  - **Stage 2:** Spec Compliance — requirements coverage, acceptance criteria verification (unchanged from previous Stage 1)
  - **Stage 3:** Code Quality — architecture, error handling, testing, maintainability (unchanged from previous Stage 2)
- `/draft:bughunt` refined to focus strictly on logic errors and regression test generation; removed Maintainability dimension (Dimension 12) to eliminate overlap with review/deep-review
- `core/agents/reviewer.md` updated to 3-stage process matching new review workflow
- `with-validate` modifier in `/draft:review` deprecated (now ignored; validation is natively built into Stage 1)
- `full` modifier in `/draft:review` now only enables `with-bughunt` (validation is always included)

### Added
- `/draft:deep-review` — Enterprise-grade module lifecycle and ACID compliance audit
  - Performs exhaustive end-to-end review of services, components, or modules
  - Evaluates ACID compliance (Atomicity, Consistency, Isolation, Durability)
  - Assesses architectural resilience and production-grade quality
  - Generates Implementation Spec for fixes without mutating code
  - Maintains history at `draft/deep-review-history.json`
  - Generates reports at `draft/deep-review-report.md`

### Removed
- `/draft:validate` command — **Migration:** Use `/draft:review` for automated quality checks (now built into Stage 1)
- Skills: `skills/validate/SKILL.md` deleted (functionality absorbed)
- Templates: Unused `core/templates/metadata.json` deleted (skills use hardcoded templates)

## [1.3.0] - 2026-02-08

### Added
- `/draft:index` — Monorepo federation and service aggregation:
  - **Service discovery:** Scans immediate child directories for service markers (package.json, go.mod, Cargo.toml, etc.) at depth=1 only
  - **Context aggregation:** Reads each service's draft/ context (product.md, architecture.md, tech-stack.md) and synthesizes root-level knowledge
  - **Dependency mapping:** Detects inter-service dependencies and generates topological ordering for implementation planning
  - **Auto-generated files:** Creates service-index.md (service registry), dependency-graph.md (mermaid topology), tech-matrix.md (technology distribution), root product.md/architecture.md/tech-stack.md (system-of-systems view)
  - **Monorepo templates:** 6 new templates (service-index, dependency-graph, tech-matrix, root-product, root-architecture, root-tech-stack) in core/templates/
  - **Uninitialized service handling:** `--init-missing` flag to bootstrap services without draft/ context
  - **Manifest tracking:** Creates draft/manifest.json per service with metadata (name, tech, dependencies, team, last indexed)
- `/draft:adr` — Architecture Decision Records for documenting significant technical decisions:
  - **ADR structure:** Context (forces driving decision) → Decision (active voice proposal) → Alternatives Considered (≥2 with pros/cons) → Consequences (positive/negative/risks)
  - **Lifecycle:** Proposed → Accepted → Deprecated/Superseded
  - **Storage:** `draft/adrs/NNNN-title.md` with track linkage in metadata
  - **Commands:** `draft adr list`, `draft adr supersede <number>`
  - **Integration:** Suggested during `/draft:new-track` when making architectural choices
- `/draft:review` — Standalone code review orchestrator supporting both track-level and project-level review:
  - **Track-level review:** Reviews specific track implementation against spec.md and plan.md using two-stage process (spec compliance → code quality)
  - **Project-level review:** Reviews arbitrary changes (uncommitted, specific files, commit ranges) with code quality checks only
  - **Fuzzy track matching:** Accepts both exact track ID and fuzzy name matching (e.g., `--track "user auth"` finds `add-user-authentication`)
  - **Smart diff chunking:** Handles small diffs (<300 lines) with full context, large diffs (≥300 lines) with file-by-file iteration to avoid context overflow
  - **Quality tool integration:** Optional integration with `/draft:validate` and `/draft:bughunt` via `--with-validate`, `--with-bughunt`, or `--full` flags
  - **Unified reporting:** Aggregates findings from reviewer agent, validate, and bughunt with deduplication and severity ranking (Critical/Important/Minor)
  - **Review history tracking:** Updates metadata.json with lastReviewed timestamp and reviewCount
  - Generates reports: `draft/tracks/<id>/review-report.md` (track) or `draft/review-report.md` (project)
- **Enterprise Readiness Enhancements:**
  - **Red Flags sections** added to all 15 skills — proactive warnings to prevent common mistakes (wrong directory, missing context, skipping verification)
  - **OWASP Top 10 security checks** integrated into `/draft:validate` — detects SQL injection, XSS, broken auth, insecure deserialization, insufficient logging
  - **Tech Debt Log** section added to `/draft:implement` — tracks shortcuts, TODOs, and deferred improvements per task
  - **Enterprise spec sections** — Security/Compliance, Performance Requirements, Operational Runbooks added to spec.md template
- **Methodology Improvements:**
  - **Table of Contents** added to core/methodology.md (1,070+ lines) — hierarchical navigation for 8 major sections and 14 commands
  - **Mermaid diagrams** — Workflow visualization (Context → Spec → Plan → Implement → Review) and context hierarchy (Product → Architecture → Tech Stack)
  - **Validation expanded examples** — Concrete categories (Architecture Conformance, Security Scan, Performance Analysis) with specific patterns to detect
  - **ISO timestamp flexibility** documented — both `Z` and `.000Z` suffixes valid (second vs millisecond precision)

### Changed
- `.gitignore` expanded to ignore generated reports (`draft/bughunt-report.md`, `draft/validation-report.md`, `draft/tracks/*/validation-report.md`)
- Integration files regenerated with all methodology updates (Cursor, Copilot, Gemini)

## [1.1.0] - 2026-02-07

### Added
- `/draft:bughunt` — Exhaustive bug hunting across 12 analysis dimensions (correctness, reliability, security, performance, UI responsiveness, concurrency, state management, API contracts, accessibility, configuration, tests, maintainability):
  - Project-level analysis: full codebase bug discovery
  - Track-level analysis (`--track <id>`): focused hunt using spec.md and plan.md to verify implementation matches requirements
  - Draft context integration: uses architecture.md for module boundary violations, tech-stack.md for framework-specific anti-patterns, product.md for product requirement bugs
  - Severity-ranked findings (Critical/High/Medium/Low) with file:line locations and fix recommendations
  - Generates reports: `draft/bughunt-report.md` (project), `draft/tracks/<id>/bughunt-report.md` (track)
  - Complements `/draft:validate` (compliance checking) with defect discovery
- `/draft:validate` — Systematic codebase quality validation using Draft context (architecture.md, product.md, tech-stack.md):
  - Project-level validation: architecture conformance, dead code detection, dependency cycles, security scan (OWASP basics), performance anti-patterns (N+1 queries, blocking I/O)
  - Track-level validation: spec compliance (acceptance criteria coverage), architectural impact (new dependencies, pattern violations), regression risk (blast radius analysis)
  - Auto-runs at track completion when enabled in workflow.md (non-blocking by default)
  - Generates reports: `draft/validation-report.md` (project), `draft/tracks/<id>/validation-report.md` (track)
  - Configurable scope and blocking behavior via workflow.md
  - Integrated with `/draft:implement` for automatic quality checks
- **Architecture Discovery for brownfield projects** — `/draft:init` now performs deep three-phase codebase analysis for existing projects:
  - Phase 1 (Orientation): Directory structure, entry points, critical paths, request/response flows, tech stack inventory with mermaid diagrams (`graph TD`, `sequenceDiagram`)
  - Phase 2 (Logic): Data lifecycle mapping, primary domain objects, design pattern recognition, anti-pattern/complexity hotspot flagging, convention extraction, external dependency mapping with mermaid diagrams (`flowchart LR`, `graph LR`)
  - Phase 3 (Module Discovery): Reverse-engineers existing modules from import graph and directory boundaries — responsibility, files, API surface, dependencies, complexity. Generates module dependency diagram (`graph LR`), dependency table, topological ordering. `/draft:decompose` extends (not replaces) these when planning new features.
  - Generates `draft/architecture.md` as persistent context — every future track references it instead of re-analyzing the codebase
- `/draft:init refresh` now includes architecture refresh — re-scans codebase, diffs against existing `architecture.md`, updates mermaid diagrams, detects new/merged modules, flags structural changes
- Mermaid component diagram section in `tech-stack.md` template
- Enhanced `architecture.md` template with Phase 1, Phase 2 & Phase 3 sections, 7 mermaid diagram types, module discovery with init vs decompose ownership model, and anti-pattern/hotspot tracking
- GitHub Copilot integration (`integrations/copilot/.github/copilot-instructions.md`) — generated from skills via build script
- Google Gemini integration (`integrations/gemini/GEMINI.md`) — generated from skills via build script, uses `@draft` syntax
- `/draft:init refresh` — Re-scan tech stack, update product vision, review workflow settings without touching tracks
- `/draft:decompose` — Module decomposition with dependency mapping, cycle detection, and implementation ordering
- `/draft:coverage` — Auto-detect coverage tooling, run reports, classify gaps (testable / defensive / infrastructure), target 95%+
- `/draft:jira-preview` — Generate `jira-export.md` from track plan with auto-calculated story points
- `/draft:jira-create` — Push epics, stories, and sub-tasks to Jira via MCP integration
- Architecture Mode — opt-in during `/draft:init` for granular pre-implementation design:
  - Algorithm stories (Input → Process → Output documentation)
  - Execution state design (intermediate variables defined before coding)
  - Function skeletons (stubs with full type signatures approved before TDD)
  - Chunk reviews (~200-line implementation limits with mandatory review)
- Architect agent (`core/agents/architect.md`) — module decomposition, story writing, skeleton generation
- Team Workflow documentation — commit → review → update → merge cycle on all markdown artifacts before code
- "Alignment Before Code" section across methodology, README, and landing page
- Landing page (`index.html`) — full visual landing page with:
  - Installation / Getting Started section
  - Command Reference (all 12 commands)
  - Chat-Driven Development Problems section (6 problem cards + comparison table)
  - Revert Workflow visualization (3 levels + Preview → Confirm → Execute)
  - Quality Disciplines section (debugging flow, review comparison, coverage cards)
  - Architecture Mode deep-dive with checkpoint explanations and decomposition process
  - Constraint Mechanisms table
  - Engineering rationale ("why it exists") for every workflow step

### Changed
- `/draft:implement` — Mandatory per-task commits with SHA tracking; revert skill updated to match
- `core/methodology.md` — Full overhaul: added Installation & Getting Started, expanded all 9 command workflows, added Agent summaries, added Team Workflow section, added Gemini integration section
- `README.md` — Full rewrite: detailed installation, all 12 commands with usage/examples/output, Architecture Mode section, Quality Disciplines, Troubleshooting FAQ, Contributing guide, Team Workflow section, Gemini integration section; direct raw GitHub URLs for Cursor and Copilot setup
- `index.html` — Expanded all workflow sections with Problem/Solution framing and engineering rationale; added Gemini and Copilot to Getting Started
- `scripts/build-integrations.sh` — Unified build script now generates Cursor, Copilot, and Gemini integrations
- Debugger agent and Reviewer agent documentation expanded in methodology
- `.cursorrules`, `copilot-instructions.md`, `GEMINI.md` regenerated from updated skill files

### Removed
- `install.sh` — Unused installation script removed
- Conductor attribution removed from landing page footer

## [1.0.0] - 2025-01-25

### Added
- `/draft:init` - Initialize project context with product, tech-stack, and workflow definitions
- `/draft:new-track` - Create feature/bug/refactor tracks with spec.md and plan.md
- `/draft:implement` - Execute tasks with optional TDD workflow (RED → GREEN → REFACTOR)
- `/draft:status` - Display comprehensive progress overview
- `/draft:revert` - Git-aware rollback of tasks, phases, or entire tracks
- Cursor IDE integration via `.cursorrules`
- Quality disciplines: verification before completion, systematic debugging, two-stage review
- Specialized agents: planner, debugger, reviewer
