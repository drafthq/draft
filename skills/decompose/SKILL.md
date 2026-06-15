---
name: decompose
description: Decompose project or track into modules with dependency mapping. Project scope updates architecture.md and derives .ai-context.md. Track scope generates hld.md (always) and lld.md (when --lld or High-complexity module triggers it) — design-mandated artifacts that drive implement, deploy-checklist, and upload sign-off.
---

# Decompose

You are decomposing a project or track into modules with clear responsibilities, dependencies, and implementation order.

## MANDATORY GRAPH LOOKUP (read before any analysis)

When `draft/graph/schema.yaml` exists, this skill **must** follow the graph-first lookup contract in [core/shared/graph-query.md](../../core/shared/graph-query.md) §Mandatory Lookup Contract. Module identification (Step 3) and dependency mapping (Step 4) **start from the graph**:

1. Query `scripts/tools/graph-arch.sh --repo .` for the authoritative module list and fan-in/out.
2. Run `scripts/tools/hotspot-rank.sh --repo .` to identify candidate modules to split.
3. Use `scripts/tools/graph-callers.sh`/`graph-impact.sh` on demand for symbols/callers inside a candidate module.
4. Run `scripts/tools/cycle-detect.sh --repo .` to enumerate existing cycles before proposing new boundaries.

Filesystem `grep`/`find` for module discovery is only permitted **after** a documented graph miss, using the fallback sentence `Graph returned no match for <X>; falling back to grep.` and recorded in the Graph Usage Report.

## Red Flags - STOP if you're:

See [shared red flags](../../core/shared/red-flags.md) — applies to all code-touching skills. In particular, the **Ground-Truth Red Flags** are load-bearing for decompose: HLD/LLD are design-mandated artifacts and TBD citations on Modified modules fail review.

**Template contract:** HLD/LLD/Plan emissions conform to
[core/shared/template-contract.md](../../core/shared/template-contract.md) and
[core/shared/template-hygiene.md](../../core/shared/template-hygiene.md). The
`_TBD_<field>_` sentinel convention replaces `Author1` / `xxx@example.com` /
`[name]` placeholders. After decompose runs, the verification gate chain in
[core/shared/verification-gates.md](../../core/shared/verification-gates.md)
must pass clean on the regenerated set. Plan.md must back-link to
`./discovery.md` Phase 0 (Hotspots row IDs) per
[core/shared/discovery-schema.md](../../core/shared/discovery-schema.md).

Skill-specific:
- Defining modules without understanding the codebase
- Creating modules with circular dependencies
- Making modules too large (>3 files, excluding test files) or too small (single function)
- Skipping dependency analysis
- Not waiting for developer approval at checkpoints
- Emitting `Citation: TBD` for a module marked `Status: Modified` or `Status: Existing` (see §Step 5 Mandatory Citation Gate below)
- Leaving HLD §Checklist sections (Performance / Scale / Security / Resiliency / Multi-tenancy / Upgrade / Cost) as raw `-` placeholders instead of structured TBD bullets (see §Step 5a Checklist Scaffolding)

---

## Standard File Metadata

**ALL generated files MUST include the standard YAML frontmatter.** This enables refresh tracking, sync verification, and traceability.

### Gathering Git Information

Use the deterministic `git-metadata.sh` script (preferred) or the manual commands — both documented in [core/shared/git-report-metadata.md](../../core/shared/git-report-metadata.md), which contains the canonical resolver pattern for locating the script in any install layout. Both produce the same field set used in the YAML template below.

For track-scoped decomposition, also derive the human-readable track title used in the `hld.md` / `lld.md` H1:

- `{TRACK_TITLE}` — first-level heading text from the active track's `spec.md` (the `# ...` line). If `spec.md` has no H1, fall back to the `{TRACK_ID}`.

Also extract from `spec.md` frontmatter:
- `classification.criticality`, `classification.data_classification`, `classification.deployment_surface` — copy verbatim into hld.md frontmatter.
- `approvers.*` — pre-fill the HLD Approvals table (tech_leads, arb_leads, cloudops_leads, qa_leads, pm_leads) and LLD Approvals table (team_leads, tech_leads, qa). If a field is empty in spec.md, leave the table cell empty — do not invent names.

### Metadata Template

Insert this **stable** YAML frontmatter at the top of every generated file. Git state lives in `tracks/<track_id>/metadata.json` — never in per-file frontmatter (WS-8).

```yaml
---
project: "{PROJECT_NAME}"
module: "{MODULE_NAME or 'root'}"
track_id: "{TRACK_ID or null}"
generated_by: "draft:decompose"
generated_at: "{ISO_TIMESTAMP}"
# Stable frontmatter only (WS-8). Ephemeral fields live in metadata.json
# and render via <!-- META:<key> --> directives.
links:
  spec: "./spec.md"
---
```

> **Note**: `generated_by` uses `draft:command` format (not `/draft:command`) for cross-platform compatibility.
> After writing HLD/LLD, update `tracks/<track_id>/metadata.json` with current git state and `synced_to_commit`.

---

## Step 1: Determine Scope

Parse `$ARGUMENTS` for flags first, then strip them before interpreting the remaining text as scope:

- `--lld` → **LLD mode** — generate Section 6 (Low-Level Design) in addition to HLD. Strip from arguments before scope detection.

Scope detection (on stripped arguments):
- `project` or no argument with no active track → **Project-wide** decomposition → `draft/architecture.md` + `draft/.ai-context.md`
- Track ID or active track exists → **Track-scoped** decomposition → `draft/tracks/<id>/hld.md` (always) + `draft/tracks/<id>/lld.md` (when triggered)

**LLD auto-trigger:** Even without `--lld`, LLD is generated automatically when any module in Step 3 is marked `Complexity: High`. Tell the developer when this triggers: "One or more modules are High complexity — generating LLD automatically."

**No legacy `track-architecture.md`:** That artifact has been retired. New tracks always use `hld.md` (and `lld.md` when triggered). Existing tracks that have a `track-architecture.md` are not migrated automatically — leave them alone; new tracks get the new format.

### Pre-Generation Sanity Checks (Track-Scoped Only)

Before Step 2, run these checks and prompt the developer when triggered. Do **not** silently proceed.

1. **Spec readiness** — read `draft/tracks/<id>/spec.md` frontmatter and first 20 lines:
   - If `spec.md` is missing → ERROR: "No spec.md for track `<id>`. Run `/draft:new-track` first." Halt.
   - If `spec.md` contains `Status: [ ] Drafting` or `spec-draft.md` still exists → WARN: "Spec for `<id>` is still in draft. HLD generated against a draft spec will need rework. Continue anyway? [y/N]" — default No.
   - If `classification.criticality` is unset or still placeholder (`{...}`) → WARN: "Classification not set in spec.md frontmatter — HLD Approvals gate (`/draft:upload`) will not engage correctly for high-criticality tracks. Continue? [y/N]".

2. **Existing artifacts** — check what already exists:
   - If `hld.md` exists → ASK: "`hld.md` already exists for `<id>`. (1) Overwrite, (2) Skip HLD and only generate LLD, (3) Cancel." Default (3).
   - If `lld.md` exists and LLD will be regenerated → ASK same 3-way choice.

Only proceed to Step 2 after the developer resolves each prompt.

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

### Graph-Accelerated Discovery (MANDATORY when `draft/graph/` exists)

When graph data is available, the graph is the **primary** (not optional) source for module discovery — manual scanning above is reserved for the graph-miss fallback path:

- **Module boundaries**: Query `scripts/tools/graph-arch.sh --repo .` — module list with node counts and per-language file counts
- **Dependency edges**: Weighted inter-module dependencies with exact include counts — replaces manual import tracing
- **Cycle detection**: Circular dependency paths already computed — use for identifying tight coupling and decomposition candidates
- **Hotspots**: Run `scripts/tools/hotspot-rank.sh --repo .` — high-complexity files that may need further decomposition
- **Per-module detail**: query `scripts/tools/graph-callers.sh`/`graph-impact.sh` for symbol/call detail within modules of interest

This data is deterministic and exhaustive. The manual scanning recipes above only run **after** the graph misses on the concept the user named — and the miss must be reported in the Graph Usage Report footer. See [core/shared/graph-query.md](../../core/shared/graph-query.md) §Concept-to-Files Recipe.

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
---
                   MODULE BREAKDOWN
---
Scope: [Project / Track: <track-id>]

MODULE 1: [name]
  Responsibility: [one sentence]
  Files: [file list]
  API: [public interface summary]
  Dependencies: [none / module names]
  Complexity: [Low/Medium/High]

MODULE 2: [name]
  ...

---
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
---
                 DEPENDENCY ANALYSIS
---
DIAGRAM
---
[auth] ──> [database]
   │ │
   └──> [config] <──┘
            │
      [logging] (no deps)

TABLE
---
Module | Depends On | Depended By
---------- | ----------------- | -----------------
logging | - | auth, database, config
config | logging | auth, database
database | config, logging | auth
auth | database, config | -

IMPLEMENTATION ORDER
---
1. logging (leaf - no dependencies)
2. config (depends on: logging)
3. database (depends on: config, logging)
4. auth (depends on: database, config)

Parallel opportunities: config and database can start after logging.
---
```

**Wait for developer approval.**

## Step 5: Generate Design Documents

Template selection depends on scope:

- **Project-wide** → `core/templates/architecture.md` (full 28-section engineering reference)
- **Track-scoped** → `core/templates/hld.md` (always) and `core/templates/lld.md` (when triggered)

**Output location:**
- Project-wide: Update `draft/architecture.md` with the module changes, then run the Condensation Subroutine (defined in `core/shared/condensation.md`) to regenerate `draft/.ai-context.md`.
- Track-scoped: write to `draft/tracks/<id>/hld.md` and (when triggered) `draft/tracks/<id>/lld.md`.

> **Context:** HLD and LLD are design-mandated review artifacts. HLD is approved by Technical Leads / Architecture Review Board / Cloud Operations / QA / PM Leads before significant implementation; LLD is approved by Team Leads / Technical Leads / QA before code review begins. `/draft:upload` gates `git upload` for high-criticality tracks on the HLD Approvals table being populated.

### Step 5a: HLD Generation (Track-Scoped, Always)

Generate `draft/tracks/<id>/hld.md` from `core/templates/hld.md`. Populate every section that has a directive — do not ship placeholders.

**Frontmatter:**
- Copy git metadata from current repo state.
- Copy `classification.*` from `spec.md` frontmatter (criticality, data_classification, deployment_surface). The HLD's `links.*` block is statically correct in `core/templates/hld.md` — do not copy it from spec.md.

**Approvals table:** Pre-fill from `spec.md` `approvers.*` frontmatter. Empty values stay empty — do not invent names.

**§Background:** ½–1 page. Pull from `spec.md` §Problem Statement and §Background & Why Now. Tighten for HLD audience (focus on the "why now" and the system context).

**§Requirements:** Do not duplicate `spec.md`. Verify the link references resolve to actual sections in spec.md; if a section is missing, flag it.

**§High Level Design / Architecture:**
- **`<!-- GRAPH:track-component-diagram -->` slot:** Render Mermaid `flowchart TD` with three subgraphs — `Track` (modules in scope from Step 3), `Existing` (existing modules this track touches per integration edges), `External` (DB, queue, 3P APIs). Label edges with transport (HTTP / RPC / queue / direct call) when non-obvious.
- **Architecture narrative** (≤300 words). Explain how blackbox requirements map to the architecture. Name the architectural style. Justify from observable evidence.

**§High Level Design / UI Architecture Changes:** Populate only if the track touches UI; otherwise write `N/A — backend-only track.`

**§High Level Design / Key Design Decisions:** 2–5 bullet decisions, each with a one-sentence "Why:" referencing an observable constraint (latency budget, multi-tenant isolation requirement, regulatory compliance), not aesthetics.

**§High Level Design / Alternatives Considered:** Table format. Promote any non-trivial rejected alternative to a standalone ADR via `/draft:adr` and link both ways.

**§Detailed Design:**
- **`<!-- GRAPH:track-component-table -->` slot:** Render one row per module from Step 3. Columns: Module, Status (`New`/`Modified`/`Existing`), Files (count + comma list), Public API count, Fan-In, Fan-Out, Complexity (`Low`/`Medium`/`High`), Primary Deps, Citation (`path:line` of entry symbol).
- **Mandatory Citation Gate:** For every row whose Status is `Modified` or `Existing`, the Citation cell **MUST** resolve to a real `path:line` from a file you Read in this run. `TBD` is only legal for `Status: New` rows, and only when the planned file path is filled (e.g. `Citation: newscribe/server/ops/shuffle_memory_eligibility.h (planned)`). If a Modified-row Citation is unresolved, **halt** — Read the file, locate the entry symbol, and fill the cell before emitting the table. See [graph-query.md](../../core/shared/graph-query.md) §Ground-Truth Discipline rules G1 and G3.
- **Per-component subsection:** One `#### {Component Name}` block per module. Fill Responsibility, Status, Entry point (resolved `path:line` for Modified/Existing modules), Public API link to LLD, Whitebox requirements addressed (AC IDs from spec.md), Design notes (≤200 words).

**§Dependencies:**
- **`<!-- GRAPH:track-dependencies -->` slot:** Render rows per cross-module integration edge of kind `call`/`import`/`event`/`shared-schema`. Columns: Dependent Component, Edge Kind, Impact Assessment (Small/Medium/Large — graph fan-in heuristic: 1–2 = Small, 3–5 = Medium, 6+ = Large), Description, Citation. The Citation column is bound by the same Mandatory Citation Gate as the component table.

**§Intellectual Property, §Checklist, §Deployment, §Observability:** These are author-driven sections that the design author completes before the HLD is presented for approval. Decompose's job is to **scaffold structured TBD bullets**, not to invent claims and not to leave bare `-` placeholders.

#### Checklist Scaffolding (mandatory)

For `criticality: standard | high | mission-critical` tracks, replace bare `-` placeholders in HLD §Checklist with structured TBD bullets. This turns blank review-gate sections into a concrete punch-list. Bullets vary by section:

```markdown
### Performance
- [ ] **Latency budget (p50/p95/p99):** TBD — fill before HLD review
- [ ] **Throughput target:** TBD
- [ ] **Resource budget (CPU / RAM / IO per node):** TBD
- [ ] **Baseline measurement methodology:** TBD — name benchmark or production dashboard

### Scale
- [ ] **Per-tenant / per-node limits:** TBD
- [ ] **Growth assumptions (1y / 3y):** TBD
- [ ] **Scaling axis (vertical / horizontal / partitioning):** TBD

### Security
- [ ] **Threat model reference:** TBD — link STRIDE doc or write inline
- [ ] **Auth / authz changes:** TBD (none / list)
- [ ] **Data classification touched:** TBD
- [ ] **Secrets / credentials surface:** TBD (none / list)

### Resiliency
- [ ] **Failure modes considered:** TBD
- [ ] **Crash / restart semantics:** TBD
- [ ] **Backpressure / circuit-breaker:** TBD
- [ ] **Rollback path:** TBD

### Multi-tenancy
- [ ] **Tenant isolation invariants preserved:** TBD (or N/A — single-tenant)
- [ ] **Noisy-neighbor risks:** TBD

### Upgrade
- [ ] **Forward compatibility (old reading new):** TBD
- [ ] **Backward compatibility (new reading old):** TBD
- [ ] **Mixed-version cluster behavior:** TBD
- [ ] **Migration / backfill required:** TBD

### Flags and Controlled Rollout of Features
- [ ] **Master flag name (default value):** TBD
- [ ] **Cluster feature gate (if any):** TBD
- [ ] **Rollout phases:** TBD
- [ ] **Kill switch:** TBD

### Cost Implications
- [ ] **Incremental CPU / RAM / IO / storage:** TBD
- [ ] **Cloud cost delta (if SaaS):** TBD or N/A
```

For `criticality: low` quick tracks, the bare `-` placeholder is acceptable — these sections are not gated by `/draft:upload` for low criticality.

The TBD bullets are **not** claims. They are reviewable gaps. A reviewer can ask "is the latency budget defined yet?" and the author can fill it. Bare `-` placeholders give the reviewer nothing to ask about.

> **TPT/IDF automation deferred** — when MCP integration to Jira ships, decompose will pre-fill the §IP TPT table from existing TPT JIRA issues. Today: section stays empty for the author.

### Step 5b: LLD Generation (Gated)

**Trigger:** `--lld` flag was passed in Step 1 **OR** any module in Step 3 has `Complexity: High`.

**Skip condition:** No `--lld` flag and no High-complexity module. Do not create `lld.md`. Note in completion announcement: _"LLD not generated. Run `/draft:decompose --lld` to expand."_

When triggered, generate `draft/tracks/<id>/lld.md` from `core/templates/lld.md`. Refer to `core/agents/architect.md` for contract-design conventions.

**Frontmatter:** Copy git metadata + `links.*` (point `hld` link at `./hld.md`).

**Approvals table:** Pre-fill from `spec.md` `approvers.{team_leads, tech_leads, qa}` (flat keys, no `lld_` prefix).

**§Background:** Single sentence linking to HLD §Background. Add component-internal context only if HLD doesn't cover it.

**§Requirements:** Link-only to `spec.md`; list AC IDs covered by this LLD.

**§Low Level Design / Classes and Interfaces:**
- **`<!-- GRAPH:track-class-table -->` slot:** Render per-module table from graph public-API index. One row per public symbol. Columns: Symbol, Kind (class/iface/func/method), Signature, Visibility, Citation (`path:line`), Concurrency Notes.
- **Mandatory Citation Gate (LLD):** Same rule as HLD §Detailed Design. For every symbol whose owning module has Status `Modified` or `Existing`, Citation must resolve to a real `path:line` from a file Read in this run. For `Status: New` symbols, Citation may be `<planned path>:<planned line or TBD>` provided the file path is concrete. A bare `TBD` cell is a halt — fix before emitting.
- **Per-component subsection:** Public API table with full signatures, params, returns, errors, citation. Document Preconditions, Postconditions, Invariants (thread safety, idempotency, ordering).

**§Low Level Design / Data Model:**
- **`<!-- GRAPH:track-data-models -->` slot:** Render one block per new/modified entity. Pull proto/struct/class declarations and field metadata from the graph data-model index.
- **Per-model subsection:** Field table (type, nullable, default, validation), Storage, Indexes/Keys, Migration path.

**§Low Level Design / Key Algorithms and Workflows:** Sequence diagram per AC that crosses more than one module — happy path + at least one error path. Annotate gates with `Note over`. For genuinely non-trivial logic: pseudocode with declared inputs, outputs, time/space complexity, edge cases. Skip for straightforward CRUD.

**§Low Level Design / Error Handling & Retry Semantics:** One row per operation with non-trivial error handling. Classify each error, specify retry policy, backoff, max attempts, fallback. Document circuit-breaker thresholds and idempotency keys.

**§Low Level Design / Refactoring of Existing Code:** Populate when the track refactors existing code; otherwise leave empty.

**§Low Level Design / Programming Language Choice and Unit Testing:** Author-driven. Reference `/draft:testing-strategy` for project-level test strategy; LLD section covers only what is component-specific.

**§Low Level Design / PaaS Choices:** Author-driven. Decompose does not infer Data Store / Workflow Engine / Checkpointing choices.

**§Observability / Metrics + Alerting Thresholds:** Author-driven. `/draft:deploy-checklist` validates this table is populated before deploy.

### Step 5c: Normalise Whitespace

After writing all generated files, strip trailing whitespace and blank lines at EOF. GitHub rejects commits containing either.

Resolve the script via the canonical tool resolver (see [core/shared/tool-resolver.md](../../core/shared/tool-resolver.md)):

```bash
DRAFT_TOOLS="${DRAFT_PLUGIN_ROOT:-$HOME/.claude/plugins/draft}/scripts/tools"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$HOME/.cursor/plugins/local/draft/scripts/tools"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$PWD/scripts/tools"
# Fix all generated markdown for this track:
[ -x "$DRAFT_TOOLS/fix-whitespace.sh" ] && bash "$DRAFT_TOOLS/fix-whitespace.sh" --track <id>
# Also fix project-level files if architecture.md was touched:
[ -x "$DRAFT_TOOLS/fix-whitespace.sh" ] && bash "$DRAFT_TOOLS/fix-whitespace.sh" draft/architecture.md draft/.ai-context.md 2>/dev/null || true
```

Run unconditionally — idempotent if files are already clean.

### CHECKPOINT (MANDATORY)

**STOP.** Present the generated `hld.md` (and `lld.md` if generated) to the developer. Call out:
- Which graph slots were populated vs. unpopulated (and why — e.g., "no proto definitions found, GRAPH:track-data-models slot empty").
- Whether LLD was generated, and the trigger (`--lld` flag or auto-triggered by High-complexity module X).
- Author-driven sections that still need manual content: §IP, §Checklist (HLD), §PaaS/§UT (LLD), §Observability metrics/thresholds.
- Reminder: HLD must be circulated to the approvers in the Approvals table before significant implementation begins; `/draft:upload` will block `git upload` for high-criticality tracks until the table is signed.

**Wait for developer approval before proceeding to Step 6.**

## Step 6: Update Plan (Track-Scoped Only)

If this is a track-scoped decomposition and a `plan.md` exists:

1. Review existing phases against the module implementation order
2. Propose restructuring phases to align with module boundaries
3. Each module becomes a phase or maps to existing phases

### Bracketed-region rewriting (WS-6)

`core/templates/plan.md` (and tracks generated from it at template_version
≥ 2.0.0) wraps phase tables in:

```
<!-- DECOMPOSE:REGENERATE START -->
... phase tables ...
<!-- DECOMPOSE:REGENERATE END -->
```

Decompose **only** rewrites content between these markers. Manual notes the
author added above or below the markers (overview prose, design notes,
references, sunset criteria) survive every regenerate. After rewriting:

1. Update plan.md `generated_by:` to `draft:decompose`.
2. Update plan.md `generated_at:` to the current ISO-8601 timestamp.
3. Ensure plan.md `generated_at` ≥ sibling hld.md / lld.md `generated_at`
   (the hygiene validator fails on stale plan).
4. Run `scripts/tools/check-track-hygiene.sh <track_dir>` and resolve any
   findings before promoting status past `draft`.

If the plan does not yet have the bracket markers (pre-2.0 track), insert
them around the phase region during this first decompose run, then rewrite.

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
---
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

1. **Update `tracks/<track_id>/metadata.json`:** Set `phases.total` to match the new number of phases. Also update `git.commit`, `git.commit_message`, `git.dirty`, and `synced_to_commit` to current HEAD — this is the single source of truth for the track's git state.
2. **Update `draft/tracks.md`:** Update the phase count for this track's entry to reflect the new total (e.g., `Phase: 0/4` → `Phase: 0/5` if a phase was added).

## Completion

**Track-scoped announcement:**
```
Track decomposition complete.

Created: draft/tracks/<id>/hld.md
        [if LLD generated:] draft/tracks/<id>/lld.md
        [else:] (LLD not generated — run /draft:decompose --lld to expand)

Modules: [count]
Implementation order: [module names in order]

Author-driven sections still empty (fill before HLD review):
- HLD §Intellectual Property (Inventions, IDFs, TPT)
- HLD §Checklist (Performance, Scale, Security, Resiliency, Multi-tenancy, Upgrade, Cost)
- HLD §Deployment, §Observability
[if LLD generated:]
- LLD §Programming Language Choice, §PaaS Choices, §Observability metrics/thresholds

Next steps:
- Fill the author-driven sections in hld.md (and lld.md if present)
- Circulate hld.md to approvers listed in §Approvals
- Run /draft:implement to start building once HLD is approved
- /draft:upload will block git upload on HLD Approvals being signed
  for criticality ∈ {high, mission-critical}
```

**Project-wide announcement** (when scope = project):
```
Project architecture refresh complete.

Updated: draft/architecture.md
Derived: draft/.ai-context.md

Next steps:
- Review architecture.md and edit as needed
- For new feature work: /draft:new-track then /draft:decompose
```

## Mutation Protocol for architecture.md and .ai-context.md (Project-Wide)

> `draft/architecture.md` is the source of truth. `draft/.ai-context.md` is derived from it via the Condensation Subroutine (defined in `core/shared/condensation.md`). Always update `architecture.md` first, then regenerate `.ai-context.md`.

When adding new modules to the project-wide architecture:

1. Update `draft/architecture.md`: append module definitions, update dependency diagram and table
2. Do NOT remove/modify `[x] Existing` modules
3. Update `draft/metadata.json` with current HEAD (use `git-metadata.sh --project-metadata --generated-by "draft:decompose"` or update `git.commit`, `git.commit_message`, and `synced_to_commit` manually)
4. Run the Condensation Subroutine (defined in `core/shared/condensation.md`) to regenerate `draft/.ai-context.md`

**Safe write pattern for architecture.md:**
1. Backup `architecture.md` → `architecture.md.backup`
2. Write changes to `architecture.md.new`
3. Present diff for review
4. On approval: replace `architecture.md` with `architecture.md.new`, run Condensation Subroutine, then delete `architecture.md.backup`
5. On rejection: delete `architecture.md.new` and rename `architecture.md.backup` back to `architecture.md`

## Updating design context

**Project-wide rerun** (running `/draft:decompose` on existing `.ai-context.md` / `architecture.md`):
1. Read the existing context file
2. Ask developer what changed (new modules, removed modules, restructured boundaries)
3. Follow the same checkpoint process for changes
4. Update `draft/architecture.md`, preserving completed module statuses and stories, then regenerate `.ai-context.md`

**Track-scoped rerun** (running `/draft:decompose <track>` on existing `hld.md` / `lld.md`):
1. Read the existing HLD (and LLD if present)
2. If the track's `spec.md` has materially changed, prefer `/draft:change` first to amend spec/plan and flag HLD/LLD impact
3. Otherwise, regenerate the graph-fenced slots only (component diagram, component table, dependencies table, class table, data models). Author-driven sections (§IP, §Checklist, §PaaS, §UT, §Observability) and the §Approvals table are preserved verbatim
4. If the Approvals table had signatures and the HLD's structural sections changed, surface a warning: "HLD modified after sign-off — re-circulate to approvers."

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

## Mandatory Self-Check (before completion announcement)

Before printing the completion announcement, internally verify and report:

1. **Graph data queried** — which live-engine tools were invoked (e.g. `get_architecture`, `hotspot-rank.sh`, `cycle-detect.sh`).
2. **Layer 1 files deliberately skipped** — list any `.ai-context.md` sections, `tech-stack.md`, `product.md`, `workflow.md` you skipped as irrelevant to this decomposition. Be explicit; do not silently skip.
3. **Filesystem grep fallback justification** — for every `grep`/`find` run, state the concept it searched for and quote the graph-miss sentence.
4. **Citation Gate audit** — scan every Citation column in the generated component table, dependencies table, and LLD class table. Report:
   - Modified/Existing rows with resolved citations: count
   - Modified/Existing rows with `TBD` citations: must be **0** (halt and fix if non-zero)
   - New rows with `(planned)` paths: count
5. **Files actually Read** — list each source file opened during this run. Cross-reference: every Modified/Existing row in the component table must trace to at least one file in this list.
6. **HLD Checklist scaffolding** — confirm Performance / Scale / Security / Resiliency / Multi-tenancy / Upgrade / Flags / Cost are populated with structured TBD bullets (for `criticality: standard | high | mission-critical`), not bare `-` placeholders.

If `draft/graph/schema.yaml` does not exist, set `Graph files queried: NONE` and use justification `graph data unavailable`. Decompose must still propose modules from `.ai-context.md` / source files in that case **and must still Read those files** to satisfy the Citation Gate.

## Graph Usage Report (append to output)

Emit the canonical footer from [core/shared/graph-usage-report.md](../../core/shared/graph-usage-report.md) §Canonical footer. The lint hook `scripts/tools/check-graph-usage-report.sh` validates the section on save.
## Skill Telemetry

As the last step after the completion announcement, emit a metrics record. Best-effort — never block.

**Payload fields:**
```json
{
  "skill": "decompose",
  "scope": "track|project",
  "track_id": "<track_id or null>",
  "modules_count": <N>,
  "lld_generated": true|false,
  "high_complexity_modules": <N>
}
```

**Emit call:**
```bash
DRAFT_TOOLS="${DRAFT_PLUGIN_ROOT:-$HOME/.claude/plugins/draft}/scripts/tools"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$HOME/.cursor/plugins/local/draft/scripts/tools"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$PWD/scripts/tools"
[ -x "$DRAFT_TOOLS/emit-skill-metrics.sh" ] && bash "$DRAFT_TOOLS/emit-skill-metrics.sh" \
  '{"skill":"decompose","scope":"<scope>","track_id":"<id_or_null>","modules_count":<N>,"lld_generated":<bool>,"high_complexity_modules":<N>}'
```
