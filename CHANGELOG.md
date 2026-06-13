# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.7.0] - 2026-06-13

### Changed
- **Installation rewritten as an npm CLI (`@drafthq/draft`)** — `draft install <host>` replaces the previous `curl | bash scripts/install.sh` flow. Run `npx @drafthq/draft install <host>` (or install globally with `npm install -g @drafthq/draft`), where `<host>` is `claude-code`, `cursor`, `codex`, or `opencode`. `draft list` shows every host and its target; flags: `--global`/`--project`, `--dry-run`, `--force`, `--no-graph`. The CLI bundles all assets, so installs are self-contained (no runtime `git clone`).

### Added
- **Cross-host `AGENTS.md` integration** — `scripts/build-integrations.sh` now also generates `integrations/agents/AGENTS.md` (the full inlined methodology with native agent names preserved), consumed by the `codex` and `opencode` installers.

### Removed
- **`scripts/install.sh`** — the `curl | bash` universal installer is removed in favor of the npm CLI. GitHub Copilot and Gemini are no longer installable "hosts"; copy their committed instructions file directly (see README).

## [2.6.0] - 2026-06-11

### Changed
- **Graph engine replaced with [codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp)** — Draft's knowledge graph is now powered by codebase-memory-mcp (tree-sitter + LSP across 159 languages, 100% local, no API key). The previous in-house Node.js + tree-sitter-WASM engine is retired. The engine is fetched on install (`scripts/fetch-memory-engine.sh`, checksum-verified) into `~/.cache/draft/bin` rather than vendored, and resolved via `scripts/tools/_lib.sh:find_memory_bin` (`DRAFT_MEMORY_BIN` > PATH > managed > vendored). Set `DRAFT_MEMORY_DISABLE=1` to opt out.
- **Graph artifacts** — `draft/graph/` now holds a lightweight committed snapshot (`schema.yaml`, `architecture.json`, `hotspots.jsonl`, `*.mermaid`) instead of the per-language JSONL indexes. Live structural queries run on demand against the engine.

### Added
- **`/draft:graph` command** — Initialize or refresh the `draft/graph/` snapshot for a repo (optional `<path>` argument). Ensures the engine is present (fetching if needed), then builds and reports counts/hotspots/cycles.
- **New graph tools** — `graph-snapshot.sh` (committed snapshot), `graph-impact.sh` (file/symbol blast radius), `graph-callers.sh` (caller enumeration), plus `fetch-memory-engine.sh` (pinned, checksum-verified engine install).
- **Two-tier command architecture** — 4 primary workflow commands (`init`, `new-track`, `implement`, `review`) + 5 routers (`plan`, `ops`, `docs`, `discover`, `jira`) as the recommended public interface. 22 specialist commands are dispatched underneath the routers.
- **Unified `/draft:jira` router** — Single entry point replacing the previous flat `/draft:jira-preview` and `/draft:jira-create`. Supports `preview [track]`, `create [track] [--epic]`, and the advanced `review <JIRA-ID>` qualification subcommand.
- **Full Jira qualification pipeline** — 7-phase deep engine (context loading → collection → synthesis → code changes → deep-review + bughunt + coverage + test-gap analysis) now public. Produces `qualification-report.md` + `remediation-plan.md` with QUALIFIED / PARTIALLY QUALIFIED / NOT QUALIFIED verdict. Pipeline lives in `skills/jira/references/review.md` for correct inlining into integrations.
- **Guardrails subsystem** — New `core/guardrails/` (baseline + language standards) plus 9 shared quality modules (`red-flags.md`, `verification-gates.md`, `template-hygiene.md`, `context-verify.md`, `template-contract.md`, etc.).
- **13 new deterministic hygiene/verification tools** (`check-track-hygiene.sh`, `check-scope-conflicts.sh`, `check-template-noop.sh`, `verify-citations.sh`, `render-track.sh`, etc.).
- **New router skills** — `skills/plan/`, `skills/ops/`, `skills/docs/`, `skills/discover/`, `skills/jira/`.
- **`docs/MIGRATION.md`** — Actionable guidance for transitioning from the old flat command surface to the router model.

### Changed
- **Public website & book completely synchronized** — Exhaustive pass across `web/index.html`, `web/llms-full.txt`, `web/llms.txt`, all notebook sources, and rendered `web/book/chapters/*.html`. Removed every stale reference to removed flat Jira commands and outdated "28 commands" language. The live site now accurately presents the 5-router architecture.
- **Build & registration** — `SKILL_ORDER`, `CORE_FILES`, and `TOOLS` updated in `scripts/lib.sh`. Static "Available Commands" and "Intent Mapping" tables in `build-integrations.sh` now lead with the 5 routers.
- **`skills/GRAPH.md`** — Full rewrite of topology description, Mermaid diagrams, execution chains, and dependency matrix to reflect the routed two-tier model.
- All cross-references, skill bodies, core docs, and high-level documentation updated for the new surface.

### Removed
- `skills/jira-preview/` and `skills/jira-create/` directories and all associated flat command references.

### Fixed
- Critical packaging defect: advanced review pipeline was invisible to Copilot/Gemini users because `review.md` lived outside `references/`.
- Numerous stale command strings, count mismatches ("28 commands"), and public documentation drift across the book and website.

All 25+ test suites pass, `make build` + `make lint` clean, zero branding leaks or internal references in public tree. Public surfaces at https://getdraft.dev are now authoritative.

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