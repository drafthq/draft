# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Draft is a Claude Code plugin that implements Context-Driven Development methodology. It provides a two-tier command surface: 4 primary workflow commands (`/draft:init`, `/draft:new-track`, `/draft:implement`, `/draft:review`) plus 5 routers (`/draft:plan`, `/draft:ops`, `/draft:docs`, `/draft:discover`, `/draft:jira`) as the recommended public interface. 24 specialist commands are dispatched underneath the routers. The unified `/draft:jira` router supports `preview`, `create`, and the advanced `review <JIRA-ID>` qualification pipeline (deep-review + bughunt + coverage + test-gap analysis). Run `/draft` for the full intent map. Total surface: 33 skills.

Draft also ships a **knowledge graph engine** — `codebase-memory-mcp`, fetched on install to `~/.cache/draft/bin/` (not vendored; see `bin/README.md`) — driven by `scripts/tools/` (41 deterministic shell helpers). Skills are markdown (source of truth, processed by a bash build script into platform-specific integration files for Copilot and Gemini); the graph engine and shell helpers handle mechanical work that markdown can't.

## Build & Test Commands

```bash
make build              # Generate integration files from skills
make build-integrations # Same as above (explicit target)
make test               # Run all 44 test suites (skills, build, tools)
make lint               # Run shellcheck + markdownlint
make clean              # Remove generated integrations

# Run a single test
./tests/test-skill-frontmatter.sh
./tests/test-build-integrations.sh
./tests/test-tools-classify-files.sh
# etc. — any test in tests/ is independently executable

# Graph engine (codebase-memory-mcp — fetched on install, not vendored)
scripts/fetch-memory-engine.sh                          # install engine to ~/.cache/draft/bin/
scripts/tools/graph-snapshot.sh --repo .                # index repo + write draft/graph/schema.yaml gate
scripts/tools/hotspot-rank.sh --repo .                  # fan-in-ranked hotspots (live query)
scripts/tools/graph-impact.sh --repo . --symbol <name>  # blast radius for a symbol (live query)

# Prerequisites: Bash 4.0+, jq (graph tools), Node 18+ (draft CLI), shellcheck, markdownlint-cli (lint only)
```

Tests use a custom bash framework (`tests/test-helpers.sh`) with `assert()`, `pass()`, `fail()` helpers. No external test runner.

## Architecture

### Build Pipeline (the critical path)

```
skills/<name>/SKILL.md  ──┐
core/methodology.md       ├──→  scripts/build-integrations.sh  ──→  integrations/copilot/.github/copilot-instructions.md
core/shared/*.md          │                                          (~23,600 lines, auto-generated)
core/templates/*.md       ├──→  (Gemini uses bootstrap .gemini.md — no longer generated)
core/agents/*.md          ──┘
```

The build script (`scripts/build-integrations.sh`) reads `SKILL_ORDER`, `CORE_FILES`, and `TOOLS` from `scripts/lib.sh` (sourced) and:
1. Iterates `SKILL_ORDER` (33 skills in current two-tier model, order matters)
2. Validates YAML frontmatter (`name:` and `description:` required)
3. Validates body format: blank, `# Title`, blank, then content
4. Extracts body via `extract_body()`, skipping frontmatter
5. Applies syntax transforms (`/draft:command` → `draft command`; `@architect`, `@debugger`, etc. → `@workspace` for Copilot)
6. Inlines 62 core reference files (methodology, shared procedures, templates, agents, guardrails)
7. Writes atomically to a temp file then renames into place
8. Runs `verify_output()` — line count, completeness, syntax

### Source of Truth Hierarchy

1. **`core/methodology.md`** — Master methodology (update first)
2. **`skills/<name>/SKILL.md`** — Skill implementations (derive from methodology)
3. **`integrations/copilot/.github/copilot-instructions.md`** — GENERATED, never edit directly

### Key Directories

- **`core/shared/`** — Shared procedures loaded by skills (context loading, git metadata, pattern learning, cross-skill dispatch, Jira sync, **graph queries**, **parallel analysis**, VCS commands)
- **`core/agents/`** — Behavioral protocols for specialized agents (architect, debugger, planner, rca, reviewer, ops, writer)
- **`core/templates/`** — 26 templates for files that `/draft:init` generates in user projects
- **`bin/`** — Holds only `README.md`. The graph engine (`codebase-memory-mcp`) is **not vendored** — it is fetched on install (`scripts/fetch-memory-engine.sh`) to `~/.cache/draft/bin/` and resolved by `scripts/tools/_lib.sh:find_memory_bin()` (`DRAFT_MEMORY_BIN` → `$PATH` → cache). Output gate marker under `draft/graph/schema.yaml`; all structural data is queried live. CLI and schema documented in `bin/README.md`.
- **`scripts/tools/`** — 41 deterministic shell helpers (git-metadata, classify-files, hotspot-rank, cycle-detect, graph-* capability wrappers, etc.). Skills call these for mechanical work. All knowledge-graph Cypher lives in the sourced `_graph_queries.sh` module (single source of query truth); the `graph-*.sh` wrappers are thin arg-parse → builder → fail-loud JSON.
- **`scripts/lib.sh`** — Shared definitions sourced by build script: `SKILL_ORDER`, `CORE_FILES`, `TOOLS`.
- **`web/`** — Static website deployed to GitHub Pages (`getdraft.dev`), deployed via `.github/workflows/pages.yml`. Includes the Draft Book (22 chapters + 2 appendices) under `web/book/`.
- **`draft/`** — Dogfooding: Draft's own context files, generated by running `/draft:init` on this repo

### Skill File Format (strict)

```yaml
---
name: skill-name
description: Brief description
---

# Skill Title

Execution instructions below...
```

After the closing `---`, the body **must** be: (1) blank line, (2) `# Title` heading, (3) blank line, (4) content. The build script skips the first 3 body lines (`tail -n +4`) when inlining into integrations. Violating this format produces silent corruption in the generated output.

### Progressive Disclosure: `skills/<skill>/references/*.md`

A skill may ship supplementary content under `skills/<skill>/references/*.md` (top-level `.md` files only). The build script inlines these into the Copilot integration immediately after the SKILL body, sorted alphabetically, with the same syntax transforms applied. Use this for detail that bloats SKILL.md beyond the 1,500–2,000-word target (advanced patterns, schemas, exhaustive examples).

Coverage in tests: `tests/test-skill-references.sh`.

### Syntax Transformation Rules

The build script transforms skill content for platform compatibility:
- `/draft:command` → `draft command` (Copilot uses bare syntax, no slash prefix)
- `@architect`, `@debugger`, etc. → `@workspace` (Copilot agent references)

## Maintaining the Plugin

### Updating Methodology

1. Update `core/methodology.md` first
2. Apply changes to relevant `skills/` SKILL.md files
3. Run `./scripts/build-integrations.sh` to regenerate integrations
4. Update this CLAUDE.md only if core concepts change

### Adding a New Skill

1. Create `skills/<skill-name>/SKILL.md` with frontmatter (kebab-case name, no path traversal chars)
2. Add skill name to `SKILL_ORDER` in `scripts/lib.sh`
3. Add a case entry in `get_skill_header()` AND `get_copilot_trigger()` in `scripts/build-integrations.sh` (both case statements are coverage-checked by `tests/test-trigger-functions.sh`)
4. Run `make build && make test` (plugin.json auto-discovers skills via directory convention)
5. Document in README.md and CHANGELOG.md

### Adding a New Tool

1. Create `scripts/tools/<tool-name>.sh` (kebab-case, lowercase)
2. Add to `TOOLS` array in `scripts/lib.sh` (`tests/test-tools-registered.sh` reads this array dynamically and validates the new entry — no separate allowlist to update)
3. Create a test at `tests/test-tools-<tool-name>.sh` and add it to `TEST_SCRIPTS` in `Makefile`
4. Run `make test`

### Plugin Manifest

`.claude-plugin/plugin.json` — registers skills with Claude Code. The `skills` field uses a directory path (`"./skills/"`) for auto-discovery; `SKILL_ORDER` in the build script controls integration generation order (these are independent).

### Releasing / Bumping the Version

**`package.json` is the single source of truth for the version.** Never hand-edit the version anywhere else. Bump with:

```bash
npm version <patch|minor|major|x.y.z>   # writes package.json, runs the `version` hook
git push --follow-tags origin main
npm publish
```

The npm `version` lifecycle hook runs `scripts/sync-version.sh`, which propagates the new version into `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, and the `web/index.html` release labels, then `git add`s them — so all four land in the bump commit atomically. Release *copy* (headlines, dates, changelog prose) stays hand-written. `tests/test-version-sync.sh` (in `make test`) fails CI if any consumer drifts from `package.json`; run `bash scripts/sync-version.sh` to fix.

## End-User Context

When users run `/draft:init`, it creates a `draft/` directory in their project with:
- **`index.md`** — Plain docs index listing the prose context files (architecture.md, product.md, tech-stack.md, workflow.md, guardrails.md, .ai-context.md, .ai-profile.md) and tracks.md; notes that the graph is engine-only.
- **`architecture.md`** — Source of truth: 10-section graph-primary engineering reference with Mermaid diagrams
- **`.ai-context.md`** — Token-optimized 200-400 line AI context (derived from architecture.md)
- **`.ai-profile.md`** — Ultra-compact 20-50 line always-injected profile (derived from .ai-context.md)
- **`product.md`**, **`tech-stack.md`**, **`workflow.md`**, **`guardrails.md`** — Project config files
- **`tracks/`** — Individual feature/fix tracks with `spec.md`, `plan.md`, `metadata.json` (now includes `impact` block: files_touched, modules_touched, downstream_files, by_category)
- **`.state/`** — Freshness hashes, signal classification, run memory for incremental refresh
- **`graph/`** — Holds only `schema.yaml` (gate marker: engine + project metadata, point-of-index counts; `access: engine-live`). All structural graph data is queried live from the `codebase-memory-mcp` engine via the `scripts/tools/graph-*.sh` wrappers.

Status markers in tracks: `[ ]` Pending, `[~]` In Progress, `[x]` Completed, `[!]` Blocked

## Quality Disciplines

- **Verification Before Completion:** No completion claims without fresh verification evidence
- **Systematic Debugging:** Investigate → Analyze → Hypothesize → Implement (see `core/agents/debugger.md`)
- **Root Cause Analysis:** Reproduce → Trace → Hypothesize → Fix with blast radius scoping (see `core/agents/rca.md`)
- **Three-Stage Review:** (1) Automated Validation, (2) Spec Compliance, (3) Code Quality (see `core/agents/reviewer.md`)

## Communication Style

Lead with conclusions. Be concise. Direct, professional tone. Code over explanation.
