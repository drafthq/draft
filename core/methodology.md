# Draft Methodology

**Measure twice, code once.**

Draft is a methodology for Context-Driven Development that ensures consistent, high-quality delivery through: **Context → Spec & Plan → Implement**.

## Philosophy

### The Core Problem

AI coding assistants are powerful but undirected. Without structure, they:
- Make assumptions about requirements
- Choose arbitrary technical approaches
- Produce code that doesn't fit the existing codebase
- Lack accountability checkpoints

Draft solves this through **Context-Driven Development**: structured documents that constrain and guide AI behavior. By treating context as a managed artifact alongside code, your repository becomes a single source of truth that drives every agent interaction with deep, persistent project awareness.

---

## Table of Contents

- [Philosophy](#philosophy)
- [Installation & Getting Started](#installation--getting-started)
- [Core Workflow](#core-workflow)
- [Tracks](#tracks)
- [Project Context Files](#project-context-files)
- [Status Markers](#status-markers)
- [Plan Structure](#plan-structure)
- [Command Workflows](#command-workflows)
  - [/draft:init](#draftinit--initialize-project)
  - [/draft:plan](#draftplan--planning-orchestrator)
  - [/draft:index](#draftindex--monorepo-service-index)
  - [/draft:new-track](#draftnew-track--create-feature-track)
  - [/draft:implement](#draftimplement--execute-tasks)
  - [/draft:status](#draftstatus--show-progress)
  - [/draft:revert](#draftrevert--git-aware-rollback)
  - [/draft:decompose](#draftdecompose--module-decomposition)
  - [/draft:coverage](#draftcoverage--code-coverage-report)
  - [/draft:jira](#draftjira--unified-jira-integration)
  - [/draft:adr](#draftadr--architecture-decision-records)
  - [/draft:deep-review](#draftdeep-review--module-lifecycle-audit)
  - [/draft:bughunt](#draftbughunt--exhaustive-bug-discovery)
  - [/draft:review](#draftreview--code-review-orchestrator)
  - [/draft:learn](#draftlearn--pattern-discovery--guardrails-update)
  - [/draft:change](#draftchange--course-correction)
- [Architecture Mode](#architecture-mode)
- [Code Coverage](#code-coverage)
- [Concurrency](#concurrency)
- [Jira Integration (Optional)](#jira-integration-optional)
- [TDD Workflow (Optional)](#tdd-workflow-optional)
- [Intent Mapping](#intent-mapping)
- [Quality Disciplines](#quality-disciplines)
- [Agents](#agents)
- [Communication Style](#communication-style)
- [Principles](#principles)

---

### Why Each Document Exists

| Document | Purpose | Prevents |
|----------|---------|----------|
| `product.md` | Defines users, goals, success criteria, guidelines | AI building features nobody asked for |
| `tech-stack.md` | Languages, frameworks, patterns, accepted patterns | AI introducing random dependencies |
| `architecture.md` | **Source of truth.** Comprehensive human-readable engineering reference with 28 sections + 5 appendices, Mermaid diagrams, and code snippets. Generated from Graph build + 5-phase codebase analysis. | Engineers needing onboarding documentation |
| `.ai-profile.md` | **Derived from .ai-context.md.** 20-50 lines, ultra-compact always-injected project profile. Contains: language, framework, database, auth, API style, critical invariants, safety rules, active tracks, recent changes. Auto-refreshed on mutations. | AI needing full context for simple tasks |
| `.ai-context.md` | **Derived from architecture.md.** 200-400 lines, token-optimized, self-contained AI context. 15+ mandatory sections: architecture, invariants, interface contracts, data flows, concurrency rules, error handling, implementation catalogs, extension cookbooks, testing strategy, glossary. Auto-refreshed on mutations. | AI re-analyzing codebase every session |
| `workflow.md` | TDD preference, commit style, review process | AI skipping tests or making giant commits |
| `guardrails.md` | Hard guardrails, learned conventions, learned anti-patterns. Entries include dual-layer timestamps (`discovered_at`, `established_at`, `last_verified_at`, `last_active_at`) for temporal reasoning. | AI repeating false positives or missing known-bad patterns |
| `spec.md` | Acceptance criteria for a specific track | Scope creep, gold-plating |
| `plan.md` | Ordered phases with verification steps | AI attempting everything at once |

### The Constraint Hierarchy

```
product.md → "Build a task manager for developers"
  ↓
tech-stack.md → "Use React, TypeScript, Tailwind"
  ↓
architecture.md → "Express API → Service layer → Prisma ORM → PostgreSQL"
  ↓ (.ai-context.md condensed for AI consumption)
  ↓ (.ai-profile.md ultra-compact 20-50 line always-on profile)
  ↓ (.state/facts.json atomic fact registry with knowledge graph)
spec.md → "Add drag-and-drop reordering"
  ↓
plan.md → "Phase 1: sortable list, Phase 2: persistence"
```

Each layer narrows the solution space. By the time AI writes code, most decisions are already made.

### Context Tiering

Draft uses a layered context system inspired by memory tiering — see `core/shared/draft-context-loading.md` for the authoritative specification.

```
Layer 0: .ai-profile.md (20-50 lines) — Always loaded. Minimum project context.
Layer 1: .ai-context.md (200-400 lines) — Base context: boundaries, invariants, flows.
Layer 1.5: draft/graph/*.jsonl — Structural graph (when available).
Layer 2: draft/.state/facts.json — Fact-level precision (queried by relevance).
```

`architecture.md` is the source-of-truth document these layers are condensed from, not a layer itself. Simple tasks only need Layer 0. Implementation tasks load Layer 0+1 plus relevant graph/facts. Deep reviews access all layers. Relevance-scored loading keeps tokens bounded.

### Draft Command Workflow

```mermaid
graph TD
    A["/draft:init"] -->|"Creates draft/"| B["/draft:plan"]
    B -->|"Routes to new-track/change/adr"| C["/draft:new-track"]
    C -->|"Creates spec.md + plan.md"| D{Complex?}
    D -->|Yes| E["/draft:decompose"]
    D -->|No| F["/draft:implement"]
    E -->|"Creates architecture.md"| F
    F -->|"TDD cycle per task"| G{Phase done?}
    G -->|No| F
    G -->|Yes| H["Three-Stage Review"]
    H -->|Pass| I{All phases?}
    H -->|Fail| F
    I -->|No| F
    I -->|Yes| J["Track Complete"]
    J -->|"Upload for review"| U["/draft:upload"]

    K["/draft:status"] -.->|"Check anytime"| F
    L["/draft:revert"] -.->|"Undo if needed"| F
    M["/draft:coverage"] -.->|"After implementation"| F
    N["/draft:bughunt"] -.->|"Quality check"| F
    O["/draft:review"] -.->|"At track end"| H
    P["/draft:adr"] -.->|"Document decisions"| B
<<<<<<< HEAD
    Q["/draft:jira"] -.->|"Jira integration"| B
    R["/draft:deep-review"] -.->|"Audit module"| E
=======
    Q["/draft:jira-preview"] -.->|"Export to Jira"| C
    R["/draft:deep-review"] -.->|"Audit module"| F
>>>>>>> a79c14023e16774c77463870ac3510b728e8a91c
```

### Context Hierarchy

```mermaid
graph LR
    P["product.md<br/><i>What & Why</i>"] --> T["tech-stack.md<br/><i>How (tools)</i>"]
    T --> A[".ai-context.md<br/><i>How (structure)</i>"]
    A --> S["spec.md<br/><i>What (specific)</i>"]
    S --> PL["plan.md<br/><i>When & Order</i>"]
    PL --> Code["Implementation"]
```

### Keeping AI Constrained

Without constraints, AI will:
1. **Over-engineer** — add abstractions, utilities, "improvements" you didn't ask for
2. **Assume context** — guess at requirements instead of asking
3. **Lose focus** — drift across the codebase making tangential changes
4. **Skip verification** — claim completion without proving it works

| Mechanism | Effect |
|-----------|--------|
| Explicit spec | AI can only implement what's documented |
| Phased plans | AI works on one phase at a time |
| Verification steps | Each phase requires proof of completion |
| Status markers | Progress is tracked, not assumed |

The AI becomes an executor of pre-approved work, not an autonomous decision-maker.

### Human Review Before AI Codes

**This is Draft's most important feature.**

The workflow:
1. Developer runs `/draft:plan` — AI routes to the right planning workflow, usually `/draft:new-track`
2. Developer reviews and edits these documents
3. Developer commits them for peer review
4. Team approves the approach
5. *Only then* does `/draft:implement` begin

| Traditional AI Coding | Draft Approach |
|-----------------------|----------------|
| AI writes code immediately | AI writes spec first |
| Review happens on code PR | Review happens on spec PR |
| Disagreements require rewriting code | Disagreements resolved before coding |
| AI decisions are implicit | AI decisions are documented |

**Benefits:**
- **Faster reviews** — Reviewers approve approach, not implementation details
- **Fewer rewrites** — Catch design issues before code exists
- **Knowledge transfer** — Specs document *why*, not just *what*
- **Accountability** — Clear record of what was requested vs. delivered
- **Onboarding** — New team members read specs to understand features

### Team Workflow: Alignment Before Code

Draft's artifacts are designed for team collaboration through standard git workflows. Before any code is written, every markdown file goes through **commit → review → update → merge** until the team is aligned.

**The PR cycle on documents:**

1. **Project context** — Tech lead runs `/draft:init`. Team reviews `product.md`, `tech-stack.md`, and `workflow.md` via PR. Product managers review vision without reading code. Engineers review technical choices without context-switching into implementation.
<<<<<<< HEAD
2. **Spec & plan** — Lead runs `/draft:new-track`. Team reviews `spec.md` (requirements, acceptance criteria) and `plan.md` (phased task breakdown, dependencies) via PR. Disagreements surface as markdown comments — resolved by editing a paragraph, not rewriting a module.
3. **Architecture** — Lead runs `/draft:decompose`. Team reviews `architecture.md` (derived human-readable guide with module boundaries, API surfaces, dependency graph, implementation order) via PR. Senior engineers validate architecture without touching the codebase. The machine-optimized `.ai-context.md` is the source of truth.
4. **Work distribution** — Lead runs `/draft:jira` (preview/create). Work is pushed to Jira. Individual team members pick up stories and implement — with or without `/draft:implement`.
=======
2. **Spec & plan** — Lead runs `/draft:plan` for new work. In the common case, Draft routes to `/draft:new-track`. Team reviews `spec.md` (requirements, acceptance criteria) and `plan.md` (phased task breakdown, dependencies) via PR. Disagreements surface as markdown comments — resolved by editing a paragraph, not rewriting a module.
3. **Architecture** — When planning reveals structural complexity, `/draft:plan` escalates to `/draft:decompose`. Team reviews `architecture.md` (derived human-readable guide with module boundaries, API surfaces, dependency graph, implementation order) via PR. Senior engineers validate architecture without touching the codebase. The machine-optimized `.ai-context.md` is the source of truth.
4. **Work distribution** — Lead runs `/draft:jira-preview` and `/draft:jira-create`. Epics, stories, and sub-tasks are created from the approved plan. Individual team members pick up Jira stories and implement — with or without `/draft:implement`.
>>>>>>> a79c14023e16774c77463870ac3510b728e8a91c
5. **Implementation** — Only after all documents are merged does coding start. Every developer has full context: what to build (`spec.md`), in what order (`plan.md`), with what boundaries (`.ai-context.md` / `architecture.md`).

**Why this works:** The CLI is single-user, but the artifacts it produces are the collaboration layer. Draft handles planning and decomposition. Git handles review. Jira handles distribution. Changing a sentence in `spec.md` takes seconds. Changing an architectural decision after 2,000 lines of code takes days.

### When to Use Draft

**Good fit:**
- Features requiring design decisions
- Work that will be reviewed by others
- Complex multi-step implementations
- Anything where "just do it" has failed before

**Overkill:**
- One-line bug fixes
- Typo corrections
- Exploratory prototypes you'll throw away

Draft adds structure. Use it when structure has value.

### Problems with Chat-Driven Development

Traditional AI chat interfaces have fundamental limitations:

| Problem | Impact |
|---------|--------|
| **Context window fills up** | Long chats exhaust token limits; AI loses early context |
| **Hallucination increases with context size** | More tokens → more confusion → worse decisions |
| **No persistent memory** | Close the chat, lose the context |
| **Unsearchable history** | "Where did I work on feature X?" — good luck finding it |
| **No team visibility** | Your chat history is invisible to colleagues |
| **Repeated context loading** | Every session starts from zero |

### How Draft Solves This

| Draft Approach | Benefit |
|----------------|---------|
| **File-based context** | Persistent memory on the filesystem |
| **Git-tracked specs** | Version history, diffs, blame |
| **Scoped context loading** | Only load what's needed for the current track |
| **Fewer tokens used** | Smaller context → better AI decisions |
| **Searchable artifacts** | `grep` your specs, not chat logs |
| **Team-visible planning** | Specs and plans are PR-reviewable |

### The Economics

Writing specs feels slower. It isn't.

| Scenario | Without Spec | With Spec |
|----------|--------------|-----------|
| Simple feature | 1 hour | 1.2 hours |
| Feature with ambiguity | 3 hours + rework | 2 hours |
| Feature requiring team input | 5 hours + meetings + rework | 2.5 hours |
| Wrong feature entirely | Days wasted | Caught in review |

The overhead is constant (~20% for simple tasks). The savings scale with:
- **Complexity** — More moving parts = more value from upfront planning
- **Team size** — More reviewers = more value from documented decisions
- **Criticality** — Higher stakes = more value from discipline

For critical product development, Draft isn't overhead — it's risk mitigation.

## Installation & Getting Started

### Prerequisites

- **Claude Code CLI** — Install from [claude.ai/code](https://claude.ai/code) or via `npm install -g @anthropic-ai/claude-code`
- **Git** — Version control is required for track history, revert, and commit workflows
- **Node.js 18+** — Required for Claude Code CLI

### Install Draft Plugin

```bash
# From Claude Code CLI
claude plugin install draft

# Or clone and install locally
git clone <your-draft-repo-url> ~/.claude/plugins/draft
```

### Verify Installation

```bash
# Run the overview command
/draft
```

You should see the list of available Draft commands. If not, check that the plugin directory is correctly placed under `~/.claude/plugins/`.

### Quick Start

```bash
# 1. Initialize project context (once per project)
/draft:init

# 2. Plan a feature track with spec and plan
/draft:plan "Add user authentication"

# 3. Review the generated spec.md and plan.md, then implement
/draft:implement

# 4. Check progress at any time
/draft:status
```

### Supported Platforms

Draft works with **Claude Code** (native `.claude-plugin/` support) and **Cursor** (supports `.claude/` plugin structure natively). No build pipeline required.

---

## Core Workflow

```
Context → Spec & Plan → Implement
```

1. **Setup** - Initialize project context (once per project)
2. **New Track** - Create specification and plan
3. **Implement** - Execute tasks with optional TDD workflow
4. **Verify** - Confirm acceptance criteria met

## Tracks

A **track** is a high-level unit of work (feature, bug fix, refactor). Each track contains `spec.md`, `plan.md`, `metadata.json`, and optionally `jira-export.md`.

Two layouts are supported; both are valid:

```
# Single-track project (default) # Multi-track project
draft/ draft/tracks/<track-id>/
├── spec.md ├── spec.md
├── plan.md ├── plan.md
├── metadata.json ├── metadata.json
└── jira-export.md (optional) └── jira-export.md (optional)
```

`/draft:new-track` selects the multi-track layout when a second track is created (existing `draft/spec.md` and `draft/plan.md` are migrated into `draft/tracks/<original-track-id>/`). Commands referring to "the active track" resolve to whichever layout is in use.

### Track Lifecycle

1. **Planning** - Spec and plan are being drafted
2. **In Progress** - Tasks are being implemented
3. **Completed** - All acceptance criteria met
4. **Archived** - Track is archived for reference

## Project Context Files

Located in `draft/` of the target project:

| File | Purpose |
|------|---------|
| `product.md` | Product vision, users, goals, guidelines (optional section) |
| `tech-stack.md` | Languages, frameworks, patterns, accepted patterns |
| `architecture.md` | **Source of truth.** Comprehensive human-readable engineering reference with 28 sections + 5 appendices. Generated from Graph build + 5-phase codebase analysis. |
| `.ai-context.md` | **Derived from architecture.md.** 200-400 lines, token-optimized, self-contained AI context with 15+ mandatory sections. Consumed by all Draft commands and external AI tools. Auto-refreshed on mutations. |
| `workflow.md` | TDD preferences, commit strategy, validation config |
| `guardrails.md` | Hard guardrails, learned conventions, learned anti-patterns |
| `jira.md` | Jira project configuration (optional) |
| `tracks.md` | Master list of all tracks |
| `.state/facts.json` | Atomic fact registry with temporal metadata and knowledge graph edges. Enables fact-level contradiction detection on refresh. |
| `.state/freshness.json` | SHA-256 hashes of all analyzed source files. Enables file-level staleness detection for incremental refresh. |
| `.state/signals.json` | Codebase signal classification (11 categories). Detects structural drift on refresh. |
| `.state/run-memory.json` | Run metadata, resumable checkpoints, unresolved questions. Enables cross-session continuity. |

### Key Sections

- **`product.md` `## Guidelines`** — UX standards, writing style, branding (optional)
- **`tech-stack.md` `## Accepted Patterns`** — Intentional design decisions honored by bughunt/deep-review/review
- **`guardrails.md`** — Hard guardrails (human-defined constraints), learned conventions (auto-discovered, skip in analysis), learned anti-patterns (auto-discovered, always flag)

## Status Markers

Used throughout spec.md and plan.md:

| Marker | Meaning |
|--------|---------|
| `[ ]` | Pending/New |
| `[~]` | In Progress |
| `[x]` | Completed |
| `[!]` | Blocked |

## Plan Structure

Plans are organized into phases:

1. **Foundation** - Core data structures, interfaces
2. **Implementation** - Main functionality
3. **Integration** - Connecting components
4. **Polish** - Error handling, edge cases, docs

### Task Granularity

Good tasks are:
- Completable in a focused session
- Have clear success criteria
- Produce testable output
- Fit in a single commit

## Command Workflows

### `/draft:init` — Initialize Project

Initializes a Draft project by creating the `draft/` directory and context files. Run once per project.

#### Project Discovery

Draft auto-classifies the project:

- **Brownfield (existing codebase):** Detected by the presence of `package.json`, `requirements.txt`, `go.mod`, `Cargo.toml`, `src/`, or git history with commits. Draft scans the existing stack and pre-fills `tech-stack.md`.
- **Greenfield (new project):** Empty or near-empty directory. Developer provides all context through dialogue.
- **Mature high-context brownfield:** Projects with strong existing agent-optimized docs (CLAUDE.md, INVARIANTS.md, ADRs, etc.) now receive an early Context Quality Audit, graph fidelity declaration, and explicit Relationship/Gaps sections so the generated architecture.md acts as graph-primary overlay rather than duplicative prose.
- **Monorepo:** Detected by `lerna.json`, `pnpm-workspace.yaml`, `nx.json`, `turbo.json`, or multiple package manifests in child directories. Suggests `/draft:index` instead.

#### Initialization Sequence

1. **Project discovery** — Classify as brownfield, greenfield, or monorepo
2. **Architecture discovery (brownfield only)** — Five-phase analysis:

   **Phase 1: Discovery** — Directory structure, build/dependency files, API definitions, interface/type files. Includes **signal classification** — categorizes all source files into 11 signal categories (`backend_routes`, `frontend_routes`, `components`, `services`, `data_models`, `auth_files`, `state_management`, `background_jobs`, `persistence`, `test_infra`, `config_files`). Signal counts drive adaptive section depth.

   **Phase 2: Wiring** — Entry points, orchestrator/controller initialization, registry/registration code, dependency wiring (DI, module system, import graph).

   **Phase 3: Depth** — Data flows end-to-end, core module implementations, concurrency model, safety checks (invariants, validation, auth).

   **Phase 4: Periphery** — External dependencies, test infrastructure, configuration mechanisms, existing documentation.

   **Phase 5: Synthesis** — Cross-reference, completeness validation, pattern identification, diagram generation.

   This produces `draft/architecture.md` (comprehensive human-readable reference), `draft/.ai-context.md` (200-400 line token-optimized context), and `draft/.ai-profile.md` (20-50 line ultra-compact always-on profile). All three become persistent context — every future track references them instead of re-analyzing the codebase.

3. **Fact extraction** — Extracts atomic architectural facts into `draft/.state/facts.json` with dual-layer timestamps (`discovered_at`, `established_at`, `last_verified_at`, `last_active_at`), relationship edges (`updates`, `extends`, `derives`), and per-fact confidence scoring. Enables granular change tracking and contradiction detection on refresh.

4. **State persistence** — Writes `draft/.state/` directory with four files:
   - `facts.json` — Atomic fact registry with temporal metadata and knowledge graph edges (enables fact-level contradiction detection on refresh)
   - `freshness.json` — SHA-256 hashes of all analyzed source files (enables file-level staleness detection on refresh)
   - `signals.json` — Signal classification with section relevance mapping (enables structural drift detection)
   - `run-memory.json` — Run metadata, unresolved questions, resumable checkpoints (enables cross-session continuity)
5. **Product definition** — Dialogue to define product vision, users, goals, constraints, guidelines (optional) → `draft/product.md`
6. **Tech stack** — Auto-detected for brownfield (cross-referenced with architecture discovery); manual for greenfield. Includes accepted patterns section → `draft/tech-stack.md`
7. **Workflow configuration** — TDD preference (strict/flexible/none), commit style, review process → `draft/workflow.md`
8. **Guardrails configuration** — Hard guardrails, learned conventions, learned anti-patterns → `draft/guardrails.md`
9. **Tracks registry** — Empty tracks list → `draft/tracks.md`
10. **Directory structure** — Creates `draft/tracks/` and `draft/.state/` directories

> **Note:** Architecture features (module decomposition, stories, execution state, skeletons, chunk reviews) are automatically enabled when you run `/draft:decompose` on a track. File-based activation — no opt-in needed.

If `draft/` already exists with context files, init reports "already initialized" and suggests using `/draft:init refresh` or `/draft:plan`.

#### Refresh Mode (`/draft:init refresh`)

Re-scans and updates existing context without starting from scratch. Uses stored state for incremental, targeted refresh.

0. **State-Aware Pre-Check** — Loads `draft/.state/freshness.json` and computes current file hashes. If all hashes match (no changed/new/deleted files), short-circuits: "Architecture context is current. Nothing to refresh." Also loads `draft/.state/signals.json` to detect structural drift (new signal categories appearing, e.g., auth files added for the first time). Checks `draft/.state/run-memory.json` for interrupted previous runs and offers resume.
1. **Tech Stack Refresh** — Re-scans `package.json`, `go.mod`, etc. Compares with existing `draft/tech-stack.md`. Proposes updates.
2. **Architecture Refresh** — Uses file-level hash deltas (from freshness state) to scope re-analysis to only changed/new files. Detects new directories, removed components, changed integrations, new domain objects, new or merged modules. Updates mermaid diagrams. Preserves modules added by `/draft:decompose`. Presents changes for review before writing. After updating `architecture.md`, derives `draft/.ai-context.md` and `draft/.ai-profile.md` using the Condensation Subroutine.
3. **Contradiction Detection** — If `facts.json` exists, performs fact-level diff against changed files. Detects superseded facts (contradictions), extended facts (refinements), and new facts. Generates a Fact Evolution Report showing confirmed/updated/extended/new/stale facts. Updates relationship edges in the knowledge graph.
4. **Product Refinement** — Asks if product vision/goals in `draft/product.md` need updates.
5. **Workflow Review** — Asks if `draft/workflow.md` settings (TDD, commits) need changing.
6. **State Refresh** — Regenerates all state files (`facts.json`, `freshness.json`, `signals.json`, `run-memory.json`) with current baseline. Updates profile.
7. **Preserve** — Does NOT modify `draft/tracks.md` unless explicitly requested.

---

### `/draft:plan` — Planning Orchestrator

Canonical parent command for planning and design work.

#### Purpose

`/draft:plan` routes to the right specialist planning workflow:

- `/draft:new-track` for fresh feature, bugfix, or refactor planning
- `/draft:decompose` for architecture and module boundary work
- `/draft:change` for mid-track requirement changes
- `/draft:adr` for durable technical decisions

#### Routing Rules

1. **Explicit mode wins** — `/draft:plan new-track|decompose|change|adr`
2. **Requirement drift beats deeper design** — existing-scope changes route to `/draft:change` first
3. **Complexity escalates to decomposition** — multi-module or structurally risky tracks route to `/draft:decompose`
4. **Decision capture is explicit or tradeoff-driven** — `/draft:adr` records lasting rationale
5. **Otherwise default to new-track** — fresh planning requests usually become `/draft:new-track`

#### Bare `/draft:plan`

When run without a clear mode, Draft inspects:

- `draft/tracks.md`
- active track `spec.md` and `plan.md`
- `hld.md` / `lld.md` when present

Then it announces the selected planning mode and reason before continuing.

Example:

```text
Planning mode selected: decompose
Reason: the active track spans multiple modules and has no HLD yet.
```

The parent command should move planning forward rather than listing options.

---

### `/draft:index` — Monorepo Service Index

Aggregates Draft context from multiple services in a monorepo into unified root-level documents. Designed for organizations with multiple services, each with their own `draft/` context.

#### What It Does

1. **Scans** immediate child directories for services (detects `package.json`, `go.mod`, `Cargo.toml`, etc.)
2. **Reads** each service's `draft/product.md`, `draft/.ai-context.md` (or legacy `draft/architecture.md`), `draft/tech-stack.md`
3. **Synthesizes** root-level documents:
   - `draft/service-index.md` — Service registry with status, tech, and links
   - `draft/dependency-graph.md` — Inter-service dependency topology
   - `draft/tech-matrix.md` — Technology distribution across services
   - `draft/product.md` — Synthesized product vision (if not exists)
   - `draft/.ai-context.md` — System-of-systems architecture view
   - `draft/tech-stack.md` — Org-wide technology standards

#### Arguments

- `init-missing` — Run `/draft:init` on services that lack a `draft/` directory
- `bughunt [dir1 dir2 ...]` — Run `/draft:bughunt` across subdirectories with `draft/` folders. If no directories specified, auto-discovers all subdirectories with `draft/`. Generates summary report at `draft-index-bughunt-summary.md`.

#### When to Use

- After running `/draft:init` on individual services
- After adding or removing services from the monorepo
- Periodically to refresh cross-service context

---

### `/draft:new-track` — Create Feature Track

Creates a new track (feature, bug fix, or refactor) with a specification and phased plan.

#### Context Loading

Every new track loads the full project context before spec creation:
- `draft/product.md` — product vision, users, goals, guidelines
- `draft/tech-stack.md` — languages, frameworks, patterns, accepted patterns
- `draft/.ai-context.md` — system map, modules, data flows, invariants, security architecture (if exists). Falls back to `draft/architecture.md` for legacy projects.
- `draft/workflow.md` — TDD preference, commit conventions
- `draft/guardrails.md` — Hard guardrails, learned conventions, learned anti-patterns
- `draft/tracks.md` — existing tracks (check for overlap/dependencies)

Every spec includes a **Context References** section that explicitly links back to these documents with a one-line description of how each is relevant to this track. This ensures every track is grounded in the big picture.

#### Track Types

New track auto-detects the track type from the description and dialogue:

| Type | Indicators | Spec Template | Plan Structure |
|------|-----------|---------------|----------------|
| **Feature / Refactor** | "add", "implement", "refactor", "improve" | Standard spec | Flexible phases |
| **Bug / RCA** | "fix", "bug", "investigate", Jira bug ticket, "root cause", production incident | Bug spec with Code Locality, Blast Radius | Fixed 3-phase: Investigate → RCA → Fix |

#### Specification Creation (Feature)

Engages in dialogue to understand scope before generating `spec.md`:
- **What** — Exact scope and boundaries
- **Why** — Business/user value
- **Acceptance criteria** — How we know it's done
- **Non-goals** — What's explicitly out of scope
- **Technical approach** — High-level approach based on tech-stack.md and .ai-context.md

#### Specification Creation (Bug / RCA)

For bugs, incidents, and Jira-sourced issues. Focused investigation, not broad exploration:
- **Symptoms** — Exact error, affected users/flows, frequency
- **Reproduction** — Steps to trigger, environment conditions
- **Blast Radius** — What's broken AND what's not (scopes the investigation)
- **Code Locality** — Direct `file:line` references to suspect area, entry point, related code
- **Investigation Constraints** — Stay in the blast radius, respect module boundaries

The spec is presented for approval and iterated until the developer is satisfied.

#### Plan Creation

Based on the approved spec, generates a phased task breakdown in `plan.md`:
- **Feature tracks:** Tasks organized into phases (Foundation → Implementation → Integration → Polish)
- **Bug tracks:** Fixed 3-phase structure: Investigate & Reproduce → Root Cause Analysis → Fix & Verify. Includes an RCA Log table for tracking hypotheses.
- Each task specifies target files and test files
- Dependencies between tasks are documented
- Verification criteria defined per phase

Also creates `metadata.json` (status tracking) and registers the track in `draft/tracks.md`.

#### Track ID

Auto-generated kebab-case from the description:
- Full description converted to lowercase
- Spaces replaced with hyphens
- Special characters removed
- Examples:
  - "Add user authentication" → `add-user-auth`
  - "Fix: login bug" → `fix-login-bug`
  - "Update project docs" → `update-project-docs`

---

### `/draft:implement` — Execute Tasks

Canonical implementation parent command.

#### Parent Behavior

`/draft:implement` owns the implementation family:

- baseline task-by-task execution
- `/draft:status` for progress inspection
- `/draft:coverage` for test-coverage measurement
- `/draft:revert` for safe rollback

Explicit parent modes route directly:

- `/draft:implement status`
- `/draft:implement coverage`
- `/draft:implement revert`

Implements tasks from the active track's plan, following the TDD workflow when enabled.

#### Task Selection

Scans `plan.md` for the first uncompleted task:
- `[ ]` Pending — picks this one
- `[~]` In Progress — resumes this one
- `[x]` Completed — skips
- `[!]` Blocked — skips, notifies user

#### Production Robustness Patterns (always active)

During code generation, the implement skill applies trigger→pattern rules across 6 dimensions: **atomicity** (all-or-nothing mutations, atomic file writes, DB-first state updates), **isolation** (lock-guarded shared state, deep-copy returns, no DB I/O under locks), **durability** (crash-recoverable state, no fire-and-forget writes), **defensive boundaries** (numeric validation, API response validation, parameterized SQL), **idempotency** (dedup keys, legal state transitions, alert dedup), and **fail-closed** (deny on error/missing data). Patterns activate based on code triggers — no manual opt-in needed.

When `draft/.ai-context.md` exists, project-specific invariants (lock ordering, concurrency model, consistency boundaries) are loaded as active constraints and take precedence over general patterns.

#### TDD Cycle (when enabled in `workflow.md`)

1. **RED** — Write a failing test that captures the requirement. Run the test, verify it fails with an assertion failure (not a syntax error).
2. **GREEN** — Write the minimum code to make the test pass. Run the test, verify it passes.
3. **REFACTOR** — Clean up the code while keeping tests green. Run all related tests after each change.

Red flags that stop the cycle: writing code before a test exists, test passes immediately, running tests mentally instead of executing.

#### Architecture Mode Checkpoints (when .ai-context.md exists)

**Activation:** Automatically enabled when track has `draft/tracks/<id>/.ai-context.md` (created by `/draft:decompose`). Falls back to `draft/tracks/<id>/architecture.md` for legacy projects.

Before the TDD cycle, three additional mandatory checkpoints:

1. **Story** — Natural-language algorithm description (Input → Process → Output) written as a comment at the top of the code file. Developer approves before proceeding.
2. **Execution State** — Define intermediate state variables needed for processing. Developer approves.
3. **Function Skeletons** — Generate function stubs with complete signatures and docstrings, no implementation bodies. Developer approves.

Additionally, implementation chunks are limited to ~200 lines with a review checkpoint after each chunk.

#### Progress Updates

After each task: update `plan.md` status markers, increment `metadata.json` counters, commit per workflow conventions.

#### Parent-Owned Escalations

The baseline implementation loop should absorb adjacent execution helpers when they are the obvious next step:

- **Status-style checkpoint** when blocked or ambiguous task state needs to be surfaced before continuing
- **Coverage checkpoint** after a phase or high-risk module completes
- **Revert guidance** when progress should not continue without undoing invalid work

This keeps `/draft:implement` as the common entry point while preserving explicit child modes for power users.

#### Phase Boundary Review

When all tasks in a phase are `[x]`, a three-stage review is triggered:
1. **Stage 1: Automated Validation** — Fast static checks (architecture conformance, dead code, circular dependencies, OWASP security, performance anti-patterns)
2. **Stage 2: Spec Compliance** — Verify all requirements for the phase are implemented
3. **Stage 3: Code Quality** — Verify patterns, error handling, test quality; classify issues as Critical/Important/Minor

Only proceeds to the next phase if no Critical issues remain.

#### Track Completion

When all phases complete: update `plan.md`, `metadata.json`, and `draft/tracks.md`. Move the track from Active to Completed.

#### Examples

```bash
/draft:implement # continue the next task
/draft:implement status # inspect current execution state
/draft:implement coverage # measure coverage for the active implementation scope
/draft:implement revert # start rollback flow
```

---

### `/draft:status` — Show Progress

Displays a comprehensive overview of project progress:
- All active tracks with phase and task counts
- Current task indicator
- Module status (if `.ai-context.md` exists) with coverage percentages
- Blocked items with reasons
- Recently completed tracks
- Quick stats summary

---

### `/draft:revert` — Git-Aware Rollback

Safely undo work at three levels. The command prompts interactively for the revert level and target.

| Level | What It Reverts |
|-------|----------------|
| **Task** | Single task's commits |
| **Phase** | All commits in a phase |
| **Track** | Entire track's commits |

#### Revert Process

1. **Select level** — Prompts user to choose: Task, Phase, or Track
2. **Identify commits** — Reads commit SHAs from `plan.md` or searches git log by track pattern (`feat(<track_id>): ...`)
3. **Preview** — Shows commits, affected files, and plan.md status changes before executing
4. **Confirm** — Requires explicit user confirmation
5. **Execute** — Runs `git revert --no-commit` for each commit (newest first), then creates a single revert commit
6. **Update Draft state** — Reverts task markers from `[x]` to `[ ]`, decrements metadata counters

If a revert produces merge conflicts, Draft reports the conflicted files and halts. The user resolves conflicts manually, then runs `git revert --continue`.

---

### `/draft:decompose` — Module Decomposition

Breaks a project or track into modules with clear responsibilities, dependencies, and implementation order.

#### Scope

- **Project-wide** (`/draft:decompose project`) → `draft/architecture.md` (derives `draft/.ai-context.md`)
- **Track-scoped** (`/draft:decompose` with active track) → `draft/tracks/<id>/architecture.md` (derives `draft/tracks/<id>/.ai-context.md`)

#### Process

1. **Load context** — Read product.md, tech-stack.md, spec.md; scan codebase for brownfield projects (directory structure, entry points, existing module boundaries, import patterns)
2. **Module identification** — Propose modules with: name, responsibility, files, API surface, dependencies, complexity. Each module targets 1-3 files with a single responsibility.
3. **CHECKPOINT** — Developer reviews and modifies module breakdown
4. **Dependency mapping** — Map inter-module imports, detect cycles, generate ASCII dependency diagram, determine implementation order via topological sort
5. **CHECKPOINT** — Developer reviews dependency diagram and implementation order
6. **Generate `architecture.md`** — Module definitions, dependency diagram/table, implementation order, story placeholders. Derive `.ai-context.md` for AI consumption.
7. **Update plan.md (track-scoped only)** — Restructure phases to align with module boundaries, preserving completed/in-progress task states

#### Cycle Breaking

When circular dependencies are detected, Draft proposes one of: extract shared interface module, invert dependency direction, or merge the coupled modules.

---

### `/draft:coverage` — Code Coverage Report

Measures test coverage quality after implementation. Complements TDD — TDD is the process, coverage is the measurement.

#### Process

1. **Detect coverage tool** — Auto-detect from tech-stack.md or project config files (jest, vitest, pytest-cov, go test -coverprofile, cargo tarpaulin, etc.)
2. **Determine scope** — Argument-provided path, architecture module files, track-changed files, or full project
3. **Run coverage** — Execute the coverage command and capture output
4. **Report** — Per-file breakdown with line/branch percentages and uncovered line ranges
5. **Gap analysis** — Classify uncovered lines:
   - **Testable** — Should be covered; suggests specific tests to write
   - **Defensive** — Error handlers for impossible states; acceptable to leave uncovered
   - **Infrastructure** — Framework boilerplate; acceptable
6. **CHECKPOINT** — Developer reviews and approves
7. **Record results** — Update plan.md with coverage section, `.ai-context.md` module status, and metadata.json

Target: 95%+ line coverage (configurable in `workflow.md`).

---

### `/draft:jira` — Unified Jira Integration

Single entry point for Jira workflows via subcommands:

- `preview` (default): Generate editable export from track plan (supports `--epic` for richer hierarchy).
- `create`: Push issues to Jira via MCP (supports `--epic`).
- `review <JIRA-ID>`: Full qualification review of any existing Jira ticket using Draft's analysis tools (delegates to the review pipeline in `skills/jira/references/review.md`).

All work items live inside the root issue description by default. Use the unified router in normal usage.

---

### `/draft:adr` — Architecture Decision Records

Documents significant technical decisions with context, alternatives, and consequences. ADRs capture **why** a decision was made, not just what was decided.

#### When to Use

Create an ADR during or after `/draft:plan` when making architectural decisions:
- Adopting a new technology or framework
- Changing system architecture or module boundaries
- Selecting between multiple viable approaches with trade-offs
- Establishing patterns or conventions that constrain future work

Skip ADRs for trivial decisions (variable naming, formatting) or reversible choices.

#### ADR Structure

Each ADR contains:
- **Context** — The issue or forces driving the decision (technical, business, organizational)
- **Decision** — What we're proposing/doing, stated in active voice ("We will...")
- **Alternatives Considered** — At least 2 alternatives with pros/cons and rejection rationale
- **Consequences** — Positive outcomes, negative trade-offs, and risks with mitigations

#### Storage & Linking

ADRs are stored at `draft/adrs/NNNN-title.md` (e.g., `001-use-postgresql.md`). When created within a track context, the ADR file references the track ID in its metadata for traceability. Use `/draft:adr list` to see all decisions, `/draft:adr supersede <number>` to mark an ADR as replaced.

#### Status Lifecycle

`Proposed` (awaiting review) → `Accepted` (approved and in effect) → `Deprecated` (context changed) or `Superseded by ADR-XXX` (replaced by newer decision).

---

### `/draft:deep-review` — Module Lifecycle Audit

Perform an exhaustive end-to-end lifecycle review of a service, component, or module. Evaluates ACID compliance, architectural resilience, and production-grade enterprise quality.

#### Scope

- **Module-level only:** `/draft:deep-review src/auth`

Unlike standard review, this tool performs structural analysis and flags deep architectural flaws. It maintains a history file at `draft/deep-review-history.json` and generates an actionable specification for fixes at `draft/deep-review-report.md`. It does NOT auto-fix code.

---

### `/draft:bughunt` — Exhaustive Bug Discovery

Systematic bug hunt across 11 dimensions: correctness, reliability, security, performance, UI responsiveness, concurrency, state management, API contracts, accessibility, configuration, and tests.

#### Process

1. Load Draft context (architecture, tech-stack, product)
2. For tracks: verify implementation matches spec requirements
3. Analyze code across all 11 dimensions
4. Verify each finding (trace code paths, check for mitigations, eliminate false positives)
5. Generate severity-ranked report with fix recommendations
6. Detect language and test framework (GTest, pytest, go test, Jest/Vitest, cargo test, JUnit)
7. Discover test infrastructure (build system, test directories, naming conventions, dependencies)
8. Write regression tests in the project's native framework (new files for NO_COVERAGE, modifications for PARTIAL/WRONG_ASSERTION)
9. Validate tests compile/parse via language-appropriate command (up to 2 retries; never run tests — they are expected to fail against buggy code)

Generates report at `draft/bughunt-report-<timestamp>.md` (symlinked as `bughunt-report-latest.md`) or `draft/tracks/<id>/bughunt-report-<timestamp>.md`.
Test files are written directly to the project using native test conventions.

---

### `/draft:review` — Code Review Orchestrator

Canonical review parent command.

#### Parent Behavior

`/draft:review` owns the review family:

- baseline three-stage review
- `/draft:quick-review` for small ad-hoc change review
- `/draft:bughunt` for defect-focused escalation
- `/draft:deep-review` for module-level production-readiness escalation
- `/draft:assist-review` for human-review handoff summaries

Explicit parent modes route directly:

- `/draft:review quick`
- `/draft:review bughunt`
- `/draft:review deep`
- `/draft:review assist`

Important scope note:

- `/draft:impact` is not part of this family in the current implementation; it measures project delivery telemetry, not code-review depth.

#### Baseline Review

The default `/draft:review` path is the baseline three-stage review:

- Stage 1 automated validation
- Stage 2 spec compliance (track review only)
- Stage 3 code quality

When graph data exists, baseline review always includes blast-radius / hotspot impact analysis.

#### Track-Level Review

Reviews a track's implementation against its spec.md and plan.md:
- **Stage 1 (Automated Validation):** Fast, static checks for structural flaws (dead code, circular dependencies, OWASP secrets, N+1 patterns).
- **Stage 2 (Spec Compliance):** Verifies all functional requirements and acceptance criteria are met.
- **Stage 3 (Code Quality):** Evaluates architecture, error handling, testing, and maintainability.

Extracts commit SHAs from plan.md to determine diff range. Supports fuzzy track matching.

#### Project-Level Review

Reviews arbitrary changes (static validation + code quality only, no spec compliance):
- `project` — uncommitted changes
- `files <pattern>` — specific file patterns
- `commits <range>` — commit range

#### Quality Integration

- `with-bughunt` — include `/draft:bughunt` findings
- `with-assist` — include `/draft:assist-review` structural handoff summary
- `full` — enable bughunt + assist, and allow justified deep-review escalation

Generates unified report at `draft/tracks/<id>/review-report.md` or `draft/review-report.md`.

#### Examples

```bash
/draft:review # auto-detect active track
/draft:review track add-user-auth # review specific track
/draft:review project # review uncommitted changes
/draft:review files "src/**/*.ts" # review specific files
/draft:review commits main...HEAD # review commit range
/draft:review track my-feature full # comprehensive review with bughunt
/draft:review quick files "src/**/*.ts" # explicit quick review via parent
/draft:review deep auth # explicit deep review via parent
/draft:review assist track my-feature # reviewer handoff summary via parent
```

---

### `/draft:learn` — Pattern Discovery & Guardrails Update

Scans the codebase to discover recurring coding patterns and updates `draft/guardrails.md` with learned conventions (skip in future analysis) and anti-patterns (always flag). Creates a continuous improvement loop where quality commands become more accurate over time.

#### How It Works

1. Loads existing guardrails and Draft context
2. Scans source files across pattern dimensions: error handling, naming, architecture, concurrency, data flow, testing, configuration
3. Identifies patterns with 3+ consistent occurrences
4. Cross-references against `tech-stack.md ## Accepted Patterns` and `.ai-context.md` to avoid duplicates
5. Updates `draft/guardrails.md` with new entries (conventions or anti-patterns)

#### Subcommands

- No arguments — full codebase scan
- `promote` — review high-confidence learned patterns for promotion to Hard Guardrails or Accepted Patterns
- `migrate` — migrate `## Guardrails` from legacy `workflow.md` to `guardrails.md`
- `<path>` — scan specific directory or file pattern

#### Continuous Learning Loop

Quality commands (`/draft:bughunt`, `/draft:deep-review`, `/draft:review`) also update guardrails incrementally after each run via the shared pattern learning procedure. `/draft:learn` performs a comprehensive standalone scan.

#### Examples

```bash
/draft:learn # full codebase pattern scan
/draft:learn src/api/ # scan specific directory
/draft:learn promote # review promotion candidates
/draft:learn migrate # migrate from workflow.md
```

---

### `/draft:change` — Course Correction

Handles mid-track requirement changes without losing work. Analyzes the impact of the change on completed and pending tasks, proposes amendments to `spec.md` and `plan.md`, then applies them only after explicit confirmation.

#### When to Use

Use when requirements shift after a track is already in progress:
- A stakeholder changes scope mid-sprint
- A dependency constraint forces a pivot
- New information invalidates part of the original spec

#### Process

1. **Detect active track** — Auto-detects the `[~]` In Progress track; use `track <id>` to target a specific track
2. **Parse change description** — Extracts the change from `$ARGUMENTS`
3. **Impact analysis** — Classifies every existing task and AC against the change:
   - Tasks still valid, need modification, now invalid, or newly required
   - Completed `[x]` tasks that the change retroactively invalidates are flagged explicitly
4. **Propose amendments** — Presents exact diffs for `spec.md` and `plan.md` (what will be added, removed, or reworded)
5. **CHECKPOINT** — `[yes / no / edit]`. No file is touched until the user confirms. The loop continues until the user selects `yes` or `no`.
6. **Apply & log** — Writes changes to `spec.md` and `plan.md`, appends a timestamped entry to `## Change Log` in `plan.md`, updates `metadata.json`

#### Examples

```bash
/draft:change the export format should support JSON in addition to CSV
/draft:change track add-export-feature also require a progress indicator for exports over 500 rows
```

---

## Architecture Mode

Draft supports granular pre-implementation design for complex projects. **Architecture mode is automatically enabled when `draft/tracks/<id>/.ai-context.md` exists** (created by `/draft:decompose`). Falls back to `draft/tracks/<id>/architecture.md` for legacy projects.

**How it works:**
1. Run `/draft:decompose` on a track → Creates `draft/tracks/<id>/architecture.md` (and derived `.ai-context.md`)
2. Run `/draft:implement` → Automatically detects `architecture.md` and enables architecture features
3. Features: Story writing, Execution State design, Function Skeletons, ~200-line chunk reviews

See `core/agents/architect.md` for detailed decomposition rules, story writing, and skeleton generation.

### Module Decomposition

Use `/draft:decompose` to break a project or track into modules:

- **Project-wide:** `draft/architecture.md` — overall codebase module structure (derives `draft/.ai-context.md`)
- **Per-track:** `draft/tracks/<id>/architecture.md` — module breakdown for a specific feature (derives `draft/tracks/<id>/.ai-context.md`)

Each module defines: responsibility, files, API surface, dependencies, complexity. Modules are ordered by dependency graph (topological sort) to determine implementation sequence.

### Pre-Implementation Design

When `architecture.md` exists for a track, `/draft:implement` automatically enables three additional checkpoints before the TDD cycle:

1. **Story** — Natural-language algorithm description (Input → Process → Output) written as a comment at the top of the code file. Captures the "how" before coding. Mandatory checkpoint for developer approval.

2. **Execution State** — Define intermediate state variables (input state, intermediate state, output state, error state) needed for processing. Bridges the gap between algorithm and code structure. Mandatory checkpoint.

3. **Function Skeletons** — Generate function/method stubs with complete signatures, types, and docstrings. No implementation bodies. Developer approves names, signatures, and structure before TDD begins. Mandatory checkpoint.

Additionally, implementation chunks are limited to ~200 lines with a review checkpoint after each chunk.

### Code Coverage

Use `/draft:coverage` after implementation to measure test quality:

- Auto-detects coverage tool from `tech-stack.md`
- Targets 95%+ line coverage (configurable in `workflow.md`)
- Reports per-file breakdown and identifies uncovered lines
- Classifies gaps: testable (should add tests), defensive (acceptable), infrastructure (acceptable)
- Results recorded in `plan.md` and `.ai-context.md` using the following format:

#### Coverage Results Format (plan.md)

Add a `## Coverage` section at the end of the relevant phase:

```markdown
## Coverage
- **Overall:** 96.2% line coverage (target: 95%)
- **Tool:** jest --coverage
- **Date:** 2026-02-01

| File | Lines | Covered | % | Uncovered Lines |
|------|-------|---------|---|-----------------|
| src/auth.ts | 120 | 116 | 96.7% | 45, 88, 112, 119 |
| src/config.ts | 80 | 80 | 100% | - |

### Gaps
- **Testable:** `auth.ts:45` — error branch for expired token (add test)
- **Defensive:** `auth.ts:88` — unreachable fallback (acceptable)
- **Infrastructure:** `auth.ts:112,119` — logging statements (acceptable)
```

#### Coverage Results Format (.ai-context.md)

Update each module's status line to include coverage:

```markdown
- **Status:** [x] Complete — 96.7% coverage
```

And add a coverage summary in the Notes section:

```markdown
## Notes
- Overall coverage: 96.2% (target: 95%)
- Uncovered gaps classified and documented in plan.md
```

Coverage complements TDD — TDD is the process (write test, implement, refactor), coverage is the measurement.

### When to Use Architecture Mode

**Good fit:**
- Multi-module features with component dependencies
- New projects where architecture decisions haven't been made
- Complex algorithms or data transformations
- Teams wanting maximum review granularity

**Overkill:**
- Simple features touching 1-2 files
- Bug fixes with clear scope
- Configuration changes

### Workflow with Architecture Mode

```
/draft:init
     │ (creates draft/architecture.md + draft/.ai-context.md for brownfield)
     │
/draft:plan "feature"
     │ (creates draft/tracks/feature/spec.md + plan.md)
     │
/draft:decompose
     │ (creates draft/tracks/feature/architecture.md + .ai-context.md)
     │ → Architecture mode AUTO-ENABLED
     │
/draft:implement
     │ ├── Story → CHECKPOINT
     │ ├── Execution State → CHECKPOINT
     │ ├── Skeletons → CHECKPOINT
     │ ├── TDD (red/green/refactor)
     │ └── ~200-line chunk review → CHECKPOINT
     │
/draft:coverage → coverage report → CHECKPOINT
```

**Key insight:** Running `/draft:decompose` automatically enables architecture features for that track. No manual configuration needed.

---

## Jira Integration (Optional)

Sync tracks to Jira via the unified router:

`/draft:jira preview` → review/edit export → `/draft:jira create`

Story points are auto-calculated from task count:
- 1-2 tasks = 1 point
- 3-4 tasks = 2 points
- 5-6 tasks = 3 points
- 7+ tasks = 5 points

Requires `jira.md` configuration with project key, board ID, and epic link field.

## TDD Workflow (Optional)

When enabled in workflow.md:

1. **Red** - Write failing test first
2. **Green** - Implement minimum code to pass
3. **Refactor** - Clean up with tests green
4. **Commit** - Following project conventions

## Intent Mapping

Natural language patterns that map to Draft commands:

| User Says | Action |
|-----------|--------|
| "set up the project" | Initialize Draft |
| "plan this", "scope this work", "continue planning" | Planning orchestrator |
| "index services", "aggregate context" | Monorepo service index |
| "new feature", "add X" | Planning orchestrator (usually routes to new track) |
| "start implementing" | Execute tasks from plan |
| "what's the status" | Show progress overview |
| "undo", "revert" | Rollback changes |
| "break into modules" | Module decomposition |
| "check coverage" | Code coverage report |
| "deep review", "audit module", "production audit" | Module lifecycle audit |
| "hunt bugs", "find bugs" | Systematic bug discovery |
| "review code", "review track", "check quality" | Code review orchestrator (track/project) |
| "learn patterns", "update guardrails", "discover conventions" | Pattern discovery & guardrails update |
| "requirements changed", "scope changed", "update the spec" | Planning orchestrator (routes to course correction) |
| "preview jira", "export to jira" | Preview Jira issues |
| "create jira issues" | Create Jira issues via MCP |
| "upload for review", "open a PR", "submit code" | Upload for review |
| "find regression", "when did this break", "bisect" | Regression detection |
| "qualify epic", "epic qualification" | Epic status and qualification |
| "the plan" | Read active track's plan.md |
| "the spec" | Read active track's spec.md |

## Quality Disciplines

### Verification Before Completion

**Iron Law:** Evidence before claims, always.

Every completion claim requires running the verification command in the current message, reading full output, showing evidence alongside the claim, and only then updating `[x]` status markers. No fresh run in this message → no check.

### Systematic Debugging

**Iron Law:** No fixes without root cause investigation first. See `core/agents/debugger.md` for the four-phase process (Investigate → Analyze → Hypothesize → Implement).

### Root Cause Analysis (Bug Tracks)

**Iron Law:** No fix without a confirmed root cause. No investigation without scope boundaries. See `core/agents/rca.md` for the four-phase RCA process, classification taxonomy, and distributed-systems considerations.

### Three-Stage Review

At phase boundaries: Stage 1 automated validation → Stage 2 spec compliance → Stage 3 code quality. See `core/agents/reviewer.md` for the output template, stopping rules, and full process.

---

## Agents

Canonical agent behavior lives in `core/agents/*.md` — those files are inlined at runtime. This table is a pointer index only; when in doubt, defer to the agent file.

| Agent | File | Role |
|-------|------|------|
| Debugger | `core/agents/debugger.md` | Activated on `[!]` blocked tasks. Four-phase root cause investigation. |
| RCA | `core/agents/rca.md` | Activated for bug/RCA tracks. Structured SRE-style postmortem methodology. |
| Reviewer | `core/agents/reviewer.md` | Activated at phase boundaries. Three-stage automated + spec + quality review. |
| Architect | `core/agents/architect.md` | Activated in `/draft:decompose` and architecture-mode `/draft:implement`. Module decomposition, story writing, function skeletons. |
| Planner | `core/agents/planner.md` | Activated during `/draft:plan`, `/draft:new-track`, and `/draft:decompose`. Phased plan generation. |
| Writer | `core/agents/writer.md` | Activated during `/draft:documentation`. Doc generation and condensation. |
| Ops | `core/agents/ops.md` | Activated for `/draft:incident-response`, `/draft:deploy-checklist`, `/draft:standup`. Hands off to RCA for deep investigation. |

---

## Concurrency

Draft skills are designed for single-agent, single-track execution. Do not run multiple Draft commands concurrently on the same track.

## Communication Style

Lead with conclusions. Be concise. Prioritize clarity over comprehensiveness.

- Direct, professional tone
- Code over explanation when implementing
- Complete, runnable code blocks
- Show only changed lines with context for updates
- Ask clarifying questions only when requirements are genuinely ambiguous

## Principles

1. **Plan before you build** - Create specs and plans that guide development
2. **Maintain context** - Ensure agents follow style guides and product goals
3. **Iterate safely** - Review plans before code is written
4. **Work as a team** - Share project context across team members
5. **Verify before claiming** - Evidence before assertions, always
