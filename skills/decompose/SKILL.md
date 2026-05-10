---
name: decompose
description: "Decompose project or track into modules with dependency mapping. Updates architecture.md (source of truth) and derives .ai-context.md (token-optimized) with module definitions, dependency diagram, and implementation order. Use when the user asks to 'decompose this project', 'break into modules', 'design module boundaries', or says 'split this up', 'plan module structure'."
---

# Decompose

Decompose a project or track into modules with clear responsibilities, dependencies, and implementation order.

## Red Flags - STOP if you're:

- Defining modules without understanding the codebase
- Creating modules with circular dependencies
- Making modules too large (>3 files, excluding test files) or too small (single function)
- Skipping dependency analysis
- Not waiting for developer approval at checkpoints

---

## Standard File Metadata

**ALL generated files MUST include the standard YAML frontmatter.** This enables refresh tracking, sync verification, and traceability.

### Gathering Git Information

Before generating any file, run these commands to gather metadata:

```bash
# Project name (from manifest or directory)
basename "$(pwd)"

# Git branch
git branch --show-current

# Git remote tracking branch
git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null || echo "none"

# Git commit SHA (full)
git rev-parse HEAD

# Git commit SHA (short)
git rev-parse --short HEAD

# Git commit date
git log -1 --format="%ci"

# Git commit message (first line)
git log -1 --format="%s"

# Check for uncommitted changes
git status --porcelain | head -1
```

For track-scoped decomposition, also derive the human-readable track title used in the `track-architecture.md` H1:

- `{TRACK_TITLE}` — first-level heading text from the active track's `spec.md` (the `# ...` line). If `spec.md` has no H1, fall back to the `{TRACK_ID}`.

### Metadata Template

Insert this YAML frontmatter block at the **top of every generated file**:

```yaml
---
project: "{PROJECT_NAME}"
module: "{MODULE_NAME or 'root'}"
track_id: "{TRACK_ID or null}"
generated_by: "draft:decompose"
generated_at: "{ISO_TIMESTAMP}"
git:
  branch: "{LOCAL_BRANCH}"
  remote: "{REMOTE/BRANCH or 'none'}"
  commit: "{FULL_SHA}"
  commit_short: "{SHORT_SHA}"
  commit_date: "{COMMIT_DATE}"
  commit_message: "{FIRST_LINE_OF_COMMIT_MESSAGE}"
  dirty: {true|false}
synced_to_commit: "{FULL_SHA}"
---
```

> **Note**: `generated_by` uses `draft:command` format (not `/draft:command`) for cross-platform compatibility.

---

## Step 1: Determine Scope

Parse `$ARGUMENTS` for flags first, then strip them before interpreting the remaining text as scope:

- `--lld` → **LLD mode** — generate Section 6 (Low-Level Design) in addition to HLD. Strip from arguments before scope detection.

Scope detection (on stripped arguments):
- `project` or no argument with no active track → **Project-wide** decomposition → `draft/.ai-context.md`
- Track ID or active track exists → **Track-scoped** decomposition → `draft/tracks/<id>/architecture.md`

**LLD auto-trigger:** Even without `--lld`, LLD is generated automatically when any module in Step 3 is marked `Complexity: High`. Tell the developer when this triggers: "One or more modules are High complexity — generating LLD automatically."

## Step 2: Load Context

1. Read `draft/product.md` for product understanding
2. Read `draft/tech-stack.md` for technical patterns
3. If track-scoped:
   - Read track's `spec.md` for requirements
   - Read track's `plan.md` for existing task breakdown

For brownfield projects, scan the existing codebase using these concrete steps:

### Codebase Scanning Patterns

**Directory structure** — Map top-level organization:
```bash
ls -d src/*/ lib/*/ app/*/ packages/*/ 2>/dev/null
```

**Entry points** — Find main files and exports:
- Look for: `index.ts`, `main.ts`, `app.ts`, `mod.rs`, `__init__.py`, `main.go`
- Check `package.json` `main`/`exports` fields, `pyproject.toml` entry points, `go.mod` module path

**Existing module boundaries** — Identify by:
- Directory-per-feature patterns (e.g., `src/auth/`, `src/users/`)
- Package files (`package.json` in subdirs, `__init__.py`, `go` package declarations)
- Barrel exports (`index.ts` re-exporting from a directory)

**Dependency patterns** — Trace imports:
- Search for `import` / `require` / `from` statements across source files
- Identify which directories import from which other directories
- Flag cross-cutting imports (e.g., `utils/` imported everywhere)

**File type filters by language:**
| Language | Source Extensions | Config Files |
|----------|-------------------|--------------|
| TypeScript/JS | `*.ts`, `*.tsx`, `*.js`, `*.jsx` | `tsconfig.json`, `package.json` |
| Python | `*.py` | `pyproject.toml`, `setup.py`, `requirements.txt` |
| Go | `*.go` | `go.mod`, `go.sum` |
| Rust | `*.rs` | `Cargo.toml` |

**What to ignore:** `node_modules/`, `__pycache__/`, `target/`, `dist/`, `build/`, `.git/`, vendored dependencies. Always respect `.gitignore` and `.claudeignore`.

### Graph-Accelerated Discovery (if `draft/graph/` exists)

When graph data is available, use it as the primary source for module discovery instead of manual scanning:

- **Module boundaries**: Load `draft/graph/module-graph.jsonl` — exact module list with file counts per language (`.cc`, `.h`, `.go`, `.proto`, `.py`)
- **Dependency edges**: Weighted inter-module dependencies with exact include counts — replaces manual import tracing
- **Cycle detection**: Circular dependency paths already computed — use for identifying tight coupling and decomposition candidates
- **Hotspots**: Load `draft/graph/hotspots.jsonl` — high-complexity files that may need further decomposition
- **Per-module detail**: Load `draft/graph/modules/<name>.jsonl` for file-level graphs within modules of interest

This data is deterministic and exhaustive. Prefer it over heuristic scanning when available. See `core/shared/graph-query.md`.

## Step 3: Module Identification

Propose a module breakdown through dialogue:

For each module, define:
- **Name** - Short, descriptive identifier
- **Responsibility** - One sentence: what this module owns
- **Files** - Expected source files (existing or to be created)
- **API Surface** - Public functions, classes, or interfaces
- **Dependencies** - Which other modules it imports from
- **Complexity** - Low / Medium / High

### Module Guidelines (see `core/agents/architect.md`)

1. Each module should have a single responsibility
2. Target 1-3 files per module
3. Every module needs a clear API boundary
4. **Minimal Coupling** — communicate through interfaces, not internals
- Modules should be testable in isolation
- Each module typically contains: API, control flow, execution state, functions

### CHECKPOINT (MANDATORY)

**STOP.** Present the module breakdown to the developer.

```
═══════════════════════════════════════════════════════════
                   MODULE BREAKDOWN
═══════════════════════════════════════════════════════════

Scope: [Project / Track: <track-id>]

MODULE 1: [name]
  Responsibility: [one sentence]
  Files: [file list]
  API: [public interface summary]
  Dependencies: [none / module names]
  Complexity: [Low/Medium/High]

MODULE 2: [name]
  ...

═══════════════════════════════════════════════════════════
```

**Wait for developer approval.** Developer may add, remove, rename, or reorganize modules.

## Step 4: Dependency Mapping

After modules are approved:

1. **Map dependencies** - For each module, list what it imports from other modules
2. **Detect cycles** - If circular dependencies exist, propose how to break them (extract shared interface into new module)
3. **Generate ASCII diagram** - Visual representation of dependency graph
4. **Generate dependency table** - Tabular format for reference
5. **Determine implementation order** - Topological sort (implement leaves first, then dependents)

### CHECKPOINT (MANDATORY)

**STOP.** Present the dependency diagram and implementation order.

```
═══════════════════════════════════════════════════════════
                 DEPENDENCY ANALYSIS
═══════════════════════════════════════════════════════════

DIAGRAM
─────────────────────────────────────────────────────────
[auth] ──> [database]
   │            │
   └──> [config] <──┘
            │
      [logging] (no deps)

TABLE
─────────────────────────────────────────────────────────
Module     | Depends On        | Depended By
---------- | ----------------- | -----------------
logging    | -                 | auth, database, config
config     | logging           | auth, database
database   | config, logging   | auth
auth       | database, config  | -

IMPLEMENTATION ORDER
─────────────────────────────────────────────────────────
1. logging (leaf - no dependencies)
2. config (depends on: logging)
3. database (depends on: config, logging)
4. auth (depends on: database, config)

Parallel opportunities: config and database can start after logging.
═══════════════════════════════════════════════════════════
```

**Wait for developer approval.**

## Step 5: Generate Architecture Context

Template selection depends on scope:

- **Project-wide** → `core/templates/architecture.md` (full 25-section reference)
- **Track-scoped** → `core/templates/track-architecture.md` (HLD-focused, with optional LLD block)

**Location:**
- Project-wide: Update `draft/architecture.md` with the module changes, then run the Condensation Subroutine (defined in `core/shared/condensation.md`) to regenerate `draft/.ai-context.md`
- Track-scoped: `draft/tracks/<id>/architecture.md`

### Step 5a: HLD Generation (Track-Scoped, Always)

For track-scoped decomposition, populate these HLD sections in the track-architecture template — do not leave placeholders:

1. **§1 Overview** — pull from `spec.md` (Problem Statement, Technical Approach, Non-Functional Requirements). Name integration points from `draft/.ai-context.md`.
2. **§2 Module Breakdown** — one block per module from Step 3, including status (`New` / `Modified` / `Existing`), responsibility, files, API surface, deps, complexity.
3. **§3.1 Component Diagram** — Mermaid `flowchart TD` with three subgraphs: modules in scope, existing system modules this track touches, external collaborators (DB, queue, third-party API). Label edges with transport type when non-obvious.
4. **§3.2 Data Flow** — Mermaid `flowchart LR` tracing the primary data transformation: input → validation → logic → persistence → output. Add a separate read-path diagram if the track has both.
5. **§3.3 Sequence Diagrams** — one `sequenceDiagram` per acceptance criterion that crosses more than one module. Include at minimum: (a) the happy-path flow, (b) one error/failure path. Annotate gates and invariants with `Note over`.
6. **§3.4 State Machine** — Mermaid `stateDiagram-v2` only if the track introduces or mutates stateful entities. Omit the section when not applicable — do not emit empty diagrams.
7. **§4 Dependency Analysis** — from Step 4. ASCII graph + table with a `Cycle?` column.
8. **§5 Implementation Order** — from Step 4 (topological sort + parallel opportunities).

### Contents (common to both templates)

- Module definitions with all fields from Step 3
- Dependency diagram from Step 4
- Dependency table from Step 4
- Implementation order from Step 4
- Story placeholder per module (see `core/agents/architect.md` Story Lifecycle for how this gets populated during `/draft:implement`)
- Status marker per module (`[ ] Not Started`)
- Notes section for architecture decisions

### Step 5b: LLD Generation (Gated)

**Trigger:** `--lld` flag was passed in Step 1 **OR** any module in §2 has `Complexity: High`.

**Skip condition:** None of the above. Leave §6 with the stub: _"LLD not generated. Run `/draft:decompose --lld` to expand."_

When triggered, populate §6 of the track-architecture template. Refer to `core/agents/architect.md` for contract-design conventions.

- **§6.1 Per-Module API Contracts** — for every module marked `New` or `Modified`, list every public function/method with: language-appropriate signature, param constraints, return shape, error types. Document preconditions, postconditions, and invariants (thread safety, idempotency, ordering).
- **§6.2 Data Models & Schemas** — concrete type definitions for every new/modified entity. Fill the field table (type, nullability, default, validation). Include storage location, indexes/keys, and schema-migration path if this is a breaking change.
- **§6.3 Error Handling & Retry Semantics** — one row per operation with non-trivial error handling. Classify each error (transient / permanent / timeout), specify retry policy, backoff, max attempts, fallback. Call out circuit-breaker thresholds and idempotency keys.
- **§6.4 Algorithm Pseudocode** — include only for genuinely non-trivial logic. Skip for straightforward CRUD. Declare inputs, outputs, time/space complexity. Enumerate edge cases.

### CHECKPOINT (MANDATORY)

**STOP.** Present the generated `track-architecture.md` to the developer. Call out:
- Which sections were populated vs. omitted (and why — e.g., "no state machine — track is stateless")
- Whether LLD was generated, and the trigger (`--lld` flag or auto-triggered by High-complexity module X)

**Wait for developer approval before proceeding to Step 6.**

## Step 6: Update Plan (Track-Scoped Only)

If this is a track-scoped decomposition and a `plan.md` exists:

1. Review existing phases against the module implementation order
2. Propose restructuring phases to align with module boundaries
3. Each module becomes a phase or maps to existing phases

### Plan Merge Rules

When restructuring plan.md around modules, follow these rules for existing tasks:

**Completed tasks `[x]`:** Preserve exactly as-is. Map them to the appropriate module phase. Do not rename, reorder, or modify. Add a note: `(preserved from original plan)`.

**In-progress tasks `[~]`:** Map to the appropriate module phase. Flag for developer review if the task spans multiple modules:
```markdown
- [~] **Task 2.1:** Original task description
  - ⚠ REVIEW: This task may need splitting across modules [auth] and [database]
```

**Pending tasks `[ ]`:** Remap freely to module phases. Split tasks that span module boundaries into per-module tasks. Preserve the original task description in the new task.

**Blocked tasks `[!]`:** Preserve the blocked status and reason. Map to appropriate module. If the blocker is in a different module, add a cross-module dependency note.

**Conflict handling:** If a task doesn't map cleanly to any module:
1. List it under a `### Unmapped Tasks` section at the end
2. Flag it for developer decision
3. Never silently drop tasks

### CHECKPOINT (MANDATORY)

**STOP.** Present the updated plan structure.

```
PROPOSED PLAN RESTRUCTURE
─────────────────────────────────────────────────────────
Phase 1: [Module A] (Foundation)
  - Task 1.1: [existing or new task]
  - Task 1.2: ...

Phase 2: [Module B] (depends on Module A)
  - Task 2.1: ...
  ...
```

**Wait for developer approval before writing changes to plan.md.**

### Step 6b: Sync Metadata After Restructuring

After applying the approved plan changes:

1. **Update `metadata.json`:** Set `phases.total` to match the new number of phases in the restructured plan.
2. **Update `draft/tracks.md`:** Update the phase count for this track's entry to reflect the new total (e.g., `Phase: 0/4` → `Phase: 0/5` if a phase was added).

## Completion

Announce:
```
Architecture decomposition complete.

Created: [path to architecture.md]
Modules: [count]
Implementation order: [module names in order]

Next steps:
- Review architecture.md and edit as needed
- Run /draft:implement to start building (stories, execution state,
  and skeleton checkpoints will activate automatically)
- After implementation is complete, run `/draft:coverage` to verify test quality
```

## Mutation Protocol for architecture.md and .ai-context.md (Project-Wide)

> `draft/architecture.md` is the source of truth. `draft/.ai-context.md` is derived from it via the Condensation Subroutine (defined in `core/shared/condensation.md`). Always update `architecture.md` first, then regenerate `.ai-context.md`.

When adding new modules to the project-wide architecture:

1. Update `draft/architecture.md`: append module definitions, update dependency diagram and table
2. Do NOT remove/modify `[x] Existing` modules
3. Update YAML frontmatter `git.commit` and `git.message` to current HEAD
4. Run the Condensation Subroutine (defined in `core/shared/condensation.md`) to regenerate `draft/.ai-context.md`

**Safe write pattern for architecture.md:**
1. Backup `architecture.md` → `architecture.md.backup`
2. Write changes to `architecture.md.new`
3. Present diff for review
4. On approval: replace `architecture.md` with `architecture.md.new`, run Condensation Subroutine, then delete `architecture.md.backup`
5. On rejection: delete `architecture.md.new` and rename `architecture.md.backup` back to `architecture.md`

## Updating architecture context

When revisiting decomposition (running `/draft:decompose` on an existing `.ai-context.md` or `architecture.md`):
1. Read the existing context file
2. Ask developer what changed (new modules, removed modules, restructured boundaries)
3. Follow the same checkpoint process for changes
4. Update the document, preserving completed module statuses and stories

---

## Cross-Skill Dispatch

### After Module Decomposition

After defining module boundaries and interfaces:

```
"Decomposition complete. Consider:

Testing:
  → /draft:testing-strategy — Define per-module test boundaries and integration test strategy

Documentation:
  → /draft:documentation api <module> — Document public module interfaces

Architecture:
  → /draft:adr "Module boundary decisions for {project}" — Record decomposition rationale"
```

### Dependency Cycle Detection

If dependency analysis (Step 4) detects cycles or high coupling:
```
"Detected dependency cycles / high coupling. Consider:
  → /draft:tech-debt — Catalog architecture debt and prioritize remediation"
```

### ADR Auto-Invocation

When decomposition involves breaking a monolith, choosing module boundaries, or extracting services:
- Auto-invoke: "This decomposition is a significant architectural decision. Creating ADR to document rationale."
- Invoke `/draft:adr "Module boundary decisions for {project}"`
