---
name: init
description: "Initialize Draft project context for Context-Driven Development. Run once per project to create product.md, tech-stack.md, workflow.md, tracks.md, architecture.md (brownfield), .ai-context.md (derived), and .ai-profile.md (ultra-compact profile). Always performs deep analysis. Use when the user asks to 'init draft', 'set up Draft for this project', 'bootstrap context', or says 'start using Draft', 'I want to use Draft here'."
---

# Draft Init

Initialize a Draft project for Context-Driven Development.

## Red Flags - STOP if you're:

- Re-initializing a project that already has `draft/` without using `refresh` mode
- Skipping brownfield analysis for an existing codebase
- Rushing through product definition questions without probing for detail
- Auto-generating tech-stack.md without verifying detected dependencies
- Not presenting .ai-context.md for developer review before proceeding
- Overwriting existing tracks.md (this destroys track history)
- **Producing copy-paste module descriptions** — if 3+ modules share identical Responsibilities or description text, you have NOT analyzed the source files
- **Writing sequence diagrams under 15 lines** of Mermaid code — shallow diagrams without alt/opt blocks, payloads, and error paths are useless
- **Writing module deep-dives that ignore the graph or lack a workflow/state diagram** — the graph is ground truth; every significant module must have at least one synthesized diagram showing its primary flow or lifecycle. Prose volume without diagram fidelity is a failure.
- **Using "See X/" or "follow BUILD patterns"** as a substitute for reading actual source files and documenting real content
- **Ignoring detected high-quality existing agent context** (e.g. CLAUDE.md + docs/INVARIANTS.md written explicitly for AI agents) and regenerating large volumes of duplicative prose instead of a graph-primary overlay with strong cross-references and explicit Relationship section — this creates documentation debt and divergence risk in mature brownfield systems
- **Retaining any legacy 28-section or volume-oriented language** in generated architecture.md or in the reasoning process — the modern 10-section graph-primary template is the only accepted format.

**Initialize once, refresh to update. Never overwrite without confirmation.**

---

## MANDATORY SECTION CHECKLIST — architecture.md (Graph-Primary)

> **READ THIS BEFORE WRITING A SINGLE LINE OF architecture.md.**
> The document MUST use the EXACT modern graph-primary structure below. Freeform sections, renamed headings, or missing mandatory sections are FAILURES. This is the single forward-looking format — no legacy 28-section or volume-oriented material is accepted.

```
## 1. Executive Summary + Graph Health Dashboard
## 2. Critical Invariants & Safety Rules (with provenance)
## 3. Primary Control & Data Flows (Graph + Synthesis)
## 4. Module & Dependency Map (Primarily Graph-Derived)
## 5. Concurrency, Ownership & Isolation Model
## 6. Error Handling & Failure Mode Catalog
## 7. State & Data Truth Sources + Reconciliation
## 8. Extension Points & Safe Mutation Patterns
## 9. Graph Coverage Gaps & Known Limitations (MANDATORY)
## 10. Relationship to Other Authoritative Documentation (MANDATORY on high/medium Context Audit)
```

**Self-check before finalizing**: Confirm every one of the 10 sections above exists with the required fidelity declarations, provenance tags on claims, and (where applicable) Mermaid diagrams grounded in the graph. The Graph Health Dashboard + §9 Gaps + §10 Relationship are the highest-leverage sections for future agents.

> **If you are a subagent**: your prompt is a summary. The 10-section graph-primary structure above is authoritative. Use the exact headings. No legacy 28-section material is permitted.

---

## Graph Fidelity & Diagram-First Priority (MANDATORY)

The knowledge graph in `draft/graph/` (architecture.json with packages, languages, routes, and fan-in/out; hotspots.jsonl) is the **deterministic structural ground truth** for the system's actual architecture.

**You are running inside a powerful agentic coding environment** (Cursor, Claude Code, Copilot, Windsurf, etc.) that maintains its own rich, continuously updated index of the entire codebase. **Use that indexed knowledge aggressively** in addition to the explicit graph data and direct source reads. Your environment's index often captures higher-level intent, naming patterns, cross-file workflows, and architectural signals that the static graph may not fully express yet. Combine both sources:
- Graph = authoritative modules, edges, public surfaces, hotspots, call relationships.
- Your IDE/Agent index + full project understanding = semantic layer, workflow discovery, intent, and validation of the graph.

Cross-validate: if your index suggests a workflow, lifecycle, or design pattern that the graph does not yet surface, read the relevant source to confirm and then synthesize an accurate diagram that reflects reality.

**LLM role is faithful, high-fidelity synthesis** — not invention.

- Every structural claim must be consistent with the graph records. Contradiction = failure.
- **Diagrams are first-class deliverables.** For each major module or pipeline, produce at least one accurate Mermaid workflow, state, or sequence diagram.
- **Accuracy and correctness > document length.** Short, precise synthesis + good diagrams is superior to long prose or file lists.
- **Workflow and state focus.** Prioritize understanding primary control flows and state transitions so you can draw accurate diagrams.

This rule takes precedence over older volume-oriented language in this file.

---

## Standard File Metadata

**ALL files in `draft/` MUST include this metadata header.** This enables refresh tracking, sync verification, and traceability.

### Gathering Git Information

Before generating any file, run these commands to gather metadata:

```bash
# Project name (from manifest or directory)
basename "$(pwd)"

# Check if inside a git repository
if git rev-parse --is-inside-work-tree 2>/dev/null; then
  # Git branch
  git branch --show-current

  # Git remote tracking branch
  git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null || echo "none"

  # Git commit SHA (full) — fails on repos with zero commits
  git rev-parse HEAD 2>/dev/null || echo "none"

  # Git commit SHA (short)
  git rev-parse --short HEAD 2>/dev/null || echo "none"

  # Git commit date
  git log -1 --format="%ci" 2>/dev/null || echo "none"

  # Git commit message (first line)
  git log -1 --format="%s" 2>/dev/null || echo "none"

  # Check for uncommitted changes
  git status --porcelain | head -1
else
  # Non-git project: use fallback values
  echo "none"  # branch
  echo "none"  # remote
  echo "none"  # commit
  echo "none"  # commit_short
  echo "none"  # commit_date
  echo "none"  # commit_message
  # dirty: N/A for non-git projects
fi
```

> **Non-git projects:** If the project is not a git repository, all git metadata fields will be set to `"none"` and `git.dirty` to `false`. Refresh mode's incremental sync (`synced_to_commit`) will not function — full re-analysis is required on each refresh.

### Metadata Template

Insert this YAML frontmatter block at the **top of every draft/ file**:

```yaml
---
project: "{PROJECT_NAME}"
module: "{MODULE_NAME or 'root'}"
generated_by: "draft:{COMMAND_NAME}"
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

### Field Definitions

| Field | Description | Example |
|-------|-------------|---------|
| `project` | Project name from package.json/go.mod/Cargo.toml or directory name | `my-api-service` |
| `module` | Module name if in monorepo, otherwise `root` | `auth-service` |
| `generated_by` | The Draft command that created/updated this file | `draft:init` |
| `generated_at` | ISO 8601 timestamp when file was generated | `2024-01-15T14:30:00Z` |
| `git.branch` | Current local branch name | `main` |
| `git.remote` | Upstream tracking branch | `origin/main` |
| `git.commit` | Full SHA of HEAD when generated | `a1b2c3d4e5f6...` |
| `git.commit_short` | Short SHA (7 chars) | `a1b2c3d` |
| `git.commit_date` | Commit timestamp | `2024-01-15 10:00:00 -0500` |
| `git.commit_message` | First line of commit message | `feat: add user auth` |
| `git.dirty` | Were there uncommitted changes? | `true` or `false` |
| `synced_to_commit` | The commit SHA this doc is synchronized to | `a1b2c3d4e5f6...` |

### Usage in Refresh

The `synced_to_commit` field is critical for incremental refresh:
- `/draft:init refresh` reads this field to find changed files since last sync
- If `git.dirty: true`, warn user that docs may not reflect committed state
- After refresh, update `synced_to_commit` to current HEAD

### Example Header

```yaml
---
project: "payment-gateway"
module: "root"
generated_by: "draft:init"
generated_at: "2024-01-15T14:30:00Z"
git:
  branch: "main"
  remote: "origin/main"
  commit: "a1b2c3d4e5f6789012345678901234567890abcd"
  commit_short: "a1b2c3d"
  commit_date: "2024-01-15 10:00:00 -0500"
  commit_message: "feat: add stripe integration"
  dirty: false
synced_to_commit: "a1b2c3d4e5f6789012345678901234567890abcd"
---
```

---

## Pre-Check

Check for arguments:
- `refresh`: Update existing context without full re-init
- `index`: Route to `/draft:index`
- `discover`: Route to `/draft:discover`

### Route Explicit Modes Before Initialization

If the user explicitly invoked a specialist mode, route directly:

- `/draft:init index` → follow `/draft:index`
- `/draft:init discover` → follow `/draft:discover`

Explicit mode always wins. Do not perform standard initialization if an explicit mode is requested.

### Standard Init Check

```bash
ls draft/ 2>/dev/null
```

If `draft/` exists with context files:
- Announce: "Project already initialized. Use `/draft:init refresh` to update context or `/draft:new-track` to create a feature."
- Stop here.

### Atomic File Staging

To prevent partial initialization from leaving a broken `draft/` directory:

1. **Stage all files** in a temporary directory (`draft.tmp/`) during init
2. **On success**: `mv draft.tmp/ draft/` (atomic rename on POSIX)
3. **On failure**: `rm -rf draft.tmp/` — no half-initialized state left behind

```bash
# Before writing any files:
mkdir -p draft.tmp/tracks

# Write all files to draft.tmp/ instead of draft/
# ... (product.md, tech-stack.md, workflow.md, tracks.md, architecture.md, .ai-context.md)

# After all files are written and verified:
mv draft.tmp/ draft/
```

> **Forced re-init:** If `draft/` exists and the user explicitly requests a fresh init (not refresh), confirm with user before removing the existing `draft/` directory.

### Monorepo Detection

Check for monorepo indicators:
- Multiple `package.json` / `go.mod` / `Cargo.toml` in child directories
- `lerna.json`, `pnpm-workspace.yaml`, `nx.json`, or `turbo.json` at root
- `packages/`, `apps/`, `services/` directories with independent manifests

If monorepo detected:
- Announce: "Detected monorepo structure. Consider using `/draft:init index` at root level to aggregate service context, or run `/draft:init` within individual service directories."
- Ask user to confirm: initialize here (single service) or abort (use /draft:init index instead)

### Migration Detection

If `draft/architecture.md` exists WITHOUT `draft/.ai-context.md`:
- Announce: "Detected architecture.md without .ai-context.md. Would you like to generate .ai-context.md? This will condense your existing architecture.md into a token-optimized AI context file."
- If user accepts: Run the Condensation Subroutine to derive `.ai-context.md` from existing `architecture.md`
- If user declines: Continue without .ai-context.md

If `draft/.ai-context.md` exists WITHOUT `draft/architecture.md`:
- Announce: "Detected .ai-context.md without its source architecture.md. The derived file exists but its primary source is missing (may have been accidentally deleted). Recommend running `/draft:init refresh` to regenerate architecture.md from codebase analysis."
- Do NOT delete the existing `.ai-context.md` — it still provides useful context until `architecture.md` is regenerated

### Refresh Mode

If the user runs `/draft:init refresh`:

**0. State-Aware Pre-Check** (before any refresh work):

   **a. Check for interrupted previous run:**
   ```bash
   cat draft/.state/run-memory.json 2>/dev/null
   ```
   If `status` is `"in_progress"`, offer to resume from `resumable_checkpoint` or start fresh.

   **b. Load freshness state (if available):**
   ```bash
   cat draft/.state/freshness.json 2>/dev/null
   ```
   If `freshness.json` exists, compute current file hashes and diff against stored hashes:
   - **Changed files**: Hash differs from stored → these files need re-analysis
   - **New files**: Present in current tree but not in stored → new modules/components to document
   - **Deleted files**: Present in stored but not in current tree → sections to prune
   - **Unchanged files**: Hash matches → skip re-reading these files entirely

   If NO files changed (all hashes match AND no new/deleted files), announce:
   "No source file changes detected since last init/refresh ({generated_at}). Architecture context is current. Nothing to refresh."
   Stop here unless the user insists.

   **c. Load signal state (if available):**
   ```bash
   cat draft/.state/signals.json 2>/dev/null
   ```
   If `signals.json` exists, re-run signal classification (Phase 1 step 5) and diff against stored signals:
   - **New signal categories** (0→N): A new architectural concern appeared (e.g., auth files added for the first time). Flag these — new architecture.md sections may need to be generated.
   - **Removed signal categories** (N→0): An architectural concern was removed. Flag for section pruning.
   - **Signal count changes**: Significant growth (>50% increase) suggests the section needs deeper treatment.

   Report signal drift:
   ```
   Signal drift detected:
     NEW:     auth_files (0 → 5) — §16 Security Architecture needs generation
     GROWN:   backend_routes (12 → 24) — §12 API Definitions, §14 Cross-Module Integration need expansion
     REMOVED: background_jobs (3 → 0) — §8 Concurrency can be simplified
     STABLE:  services (8 → 9), test_infra (15 → 16)
   ```

   **d. Create refresh run memory:**
   If starting fresh: write new `draft/.state/run-memory.json` with `run_type: "refresh"` and `status: "in_progress"`.
   If resuming from a checkpoint (step 0a): preserve existing fields (`phases_completed`, `resumable_checkpoint`, `active_focus_areas`) and only update `started_at` to current timestamp.

   **e. Load previous unresolved questions:**
   If the previous run had `unresolved_questions`, display them:
   "Previous run flagged these unresolved questions: {list}. Keep these in mind during refresh."

1. **Tech Stack Refresh**: Re-scan `package.json`, `go.mod`, etc. Compare with `draft/tech-stack.md`. Propose updates.

2. **Architecture Refresh**: If `draft/architecture.md` exists, use metadata-based incremental analysis. If freshness state is available from step 0b, use file-level deltas to scope the refresh more precisely than git-diff alone:

   **a. Read synced commit from metadata:**
   ```bash
   # Extract synced_to_commit from YAML frontmatter
   SYNCED_SHA=$(grep "synced_to_commit:" draft/architecture.md | head -1 | sed 's/.*synced_to_commit:[[:space:]]*"\{0,1\}\([^"]*\)"\{0,1\}/\1/')

   # Validate extracted SHA is a real git object
   if [ -z "$SYNCED_SHA" ] || ! git cat-file -t "$SYNCED_SHA" 2>/dev/null; then
     echo "Invalid or missing synced_to_commit — falling back to full refresh"
     # Jump to step (i) — full refresh
   fi
   ```
   This returns the commit SHA the docs were last synced to (more reliable than file modification time). The SHA is validated before use to prevent silent failures in `git diff`.

   **b. Get changed files since that commit:**
   ```bash
   git diff --name-only <SYNCED_SHA> HEAD -- . ':!draft/'
   ```
   This lists all source files changed since the last architecture sync, excluding the draft/ directory itself.

   **c. Check if docs were generated with dirty state:**
   If the original `git.dirty: true`, warn: "Previous generation had uncommitted changes. Full refresh recommended."

   **d. Categorize changes:**
   - **Added files**: New modules, components, or features to document
   - **Modified files**: Existing sections that may need updates
   - **Deleted files**: Components to remove from documentation
   - **Renamed files**: Update file references

   **e. Targeted analysis (only changed files):**
   > **Guardrail:** If more than 100 files changed since last sync, recommend full 5-phase refresh instead of incremental analysis. Too many changes means the incremental approach loses its token-efficiency advantage.

   - Read each changed file to understand modifications (up to 100 files; if more, fall back to full refresh)
   - Identify which architecture.md sections are affected:
     - New files → Component Map, Implementation Catalog, File Structure
     - Modified interfaces → API Definitions, Interface Contracts
     - Changed dependencies → External Dependencies, Dependency Graph
     - New tests → Testing Infrastructure
     - Config changes → Configuration & Tuning
   - Preserve unchanged sections exactly as-is
   - Preserve modules added by `/draft:decompose` (planned modules)

   **f. Present incremental diff:**
   Show user:
   - Files analyzed: `N changed files since <date>`
   - Sections updated: list of affected sections
   - Summary of changes per section

   **g. On user approval:**
   - Update only the affected sections in `draft/architecture.md`
   - Regenerate `draft/.ai-context.md` and `draft/.ai-profile.md` using the Condensation Subroutine

   **h. On user rejection:**
   - No changes made to `draft/architecture.md`
   - However, verify `.ai-context.md` consistency: if `.ai-context.md` is missing or its `synced_to_commit` differs from `architecture.md`, offer to regenerate it from the current (unchanged) `architecture.md`

   **i. Fallback to full refresh:**
   If `synced_to_commit` is missing from metadata, or the commit SHA doesn't exist in git history:
   ```bash
   git cat-file -t <SYNCED_SHA> 2>/dev/null || echo "not found"
   ```
   If this returns "not found", run full 5-phase architecture discovery instead.

   - If `draft/architecture.md` does NOT exist and the project is brownfield, offer to generate it now

   **j. Update metadata after refresh:**
   After successful refresh, update the YAML frontmatter in all modified files:
   - `generated_by`: `draft:init refresh`
   - `generated_at`: current timestamp
   - `git.*`: current git state
   - `synced_to_commit`: current HEAD SHA

   **k. Refresh state files:**
   After successful architecture refresh, regenerate all state files:
   - `draft/.state/facts.json` — re-extract atomic facts, perform contradiction detection (see step 2l)
   - `draft/.state/freshness.json` — recompute hashes of all source files (new baseline)
   - `draft/.state/signals.json` — re-run signal classification (update baseline)
   - `draft/.state/run-memory.json` — set `status: "completed"`, `completed_at: "{ISO_TIMESTAMP}"`, preserve `unresolved_questions`

   **l. Contradiction detection (if facts.json exists):**
   If `draft/.state/facts.json` exists from a previous run, perform fact-level diff:

   1. **Re-extract facts** from changed files identified in step 2b
   2. **Compare against existing facts** sourced from those files:
      - **CONFIRMED**: Fact still holds — update `last_verified_at` and `last_active_at`
      - **UPDATED**: Fact changed (e.g., API endpoint renamed) — mark old fact with `superseded_by` edge, create new fact
      - **EXTENDED**: Fact refined with new detail — add `extends` edge to original fact
      - **NEW**: Fact not previously recorded — add with full timestamps
      - **STALE**: Fact's source file was deleted — mark `last_active_at` as stale, reduce confidence
   3. **Generate Fact Evolution Report** — display summary to user:
      ```
      Fact Evolution Report:
        CONFIRMED:  N facts unchanged
        UPDATED:    N facts superseded (old → new)
        EXTENDED:   N facts refined
        NEW:        N facts discovered
        STALE:      N facts from deleted files
      ```
   4. **Update relationship edges** in `facts.json` knowledge graph

3. **Product Refinement**: Ask if product vision/goals in `draft/product.md` need updates.
4. **Workflow Review**: Ask if `draft/workflow.md` settings (TDD, commits) need changing.
5. **Preserve**: Do NOT modify `draft/tracks.md` unless explicitly requested.
6. **Pattern Re-Discovery**: Run `/draft:learn` (no arguments — full codebase scan) to update `draft/guardrails.md` with any new or changed patterns since the last init/refresh. This keeps learned conventions and anti-patterns in sync with codebase evolution.

Stop here after refreshing. Continue to standard steps ONLY for fresh init.

## Existing High-Quality Agent Context Audit (MANDATORY)

Before any architecture discovery or large document generation, scan for known high-signal, agent-optimized documentation that may already serve as authoritative source of truth:

```bash
find . -maxdepth 4 \( -name "CLAUDE.md" -o -name "AGENTS.md" -o -name "INVARIANTS.md" -o -name "AUDIT_STANDARDS.md" -o -name "ARCHITECTURE.md" \) -not -path "./draft/*" -not -path "./node_modules/*" -not -path "./.git/*" 2>/dev/null | head -20
ls -d docs/ADRs 2>/dev/null && echo "ADR directory present ($(ls docs/ADRs/*.md 2>/dev/null | wc -l) records)" || true
```

Classify and emit **Context Quality Report** (always, even if none found):

- High: Multiple strong files with explicit AI/agent focus (e.g. "written so future AI agents don't have to re-read source", machine-verified INVARIANTS with test backing).
- Medium: Partial (README + some docs/).
- Low/None: Standard project.

If High or Medium:
- Emit terminal report with file list, sizes/signals, and explicit warning:
  ```
  Context Quality Report:
    High-quality agent-optimized docs detected:
    - CLAUDE.md (10k+ lines, purpose-built for AI coding assistants)
    - docs/INVARIANTS.md (single source of truth, test-referenced)
    - docs/AUDIT_STANDARDS.md
  Duplication risk: Generating a large parallel architecture.md can create divergence in safety-critical systems. Highest risk is inconsistent documentation, not insufficient volume.
  Action: architecture.md will be graph-primary (Full mode) with mandatory "Graph Coverage Gaps" and "Relationship to Existing Authoritative Documentation" sections. Strong cross-references + provenance tags required. Prose duplication of existing high-fidelity material is a verification failure.
  ```
- Set internal flag `EXISTING_CONTEXT_QUALITY=high` (propagate to synthesis, writing, and Completion Verification steps).
- Force §30 (Relationship) and §29 (Gaps) as non-skippable in later phases.
- In Completion Verification: add explicit check that Relationship section defers appropriately and adds only graph-derived or synthesized value.

This audit ensures Draft is safe and effective for mature brownfield projects that have already solved the "permanent AI agent context" problem at high fidelity.

## Step 1: Project Discovery

Analyze the current directory to classify the project:

**Brownfield (Existing)** indicators:
- Has `package.json`, `requirements.txt`, `go.mod`, `Cargo.toml`, etc.
- Has `src/`, `lib/`, or similar code directories
- Has git history with commits

**Greenfield (New)** indicators:
- Empty or near-empty directory
- Only has README or basic config

Respect `.gitignore` and `.claudeignore` when scanning.

If **Brownfield**: proceed to Step 1.5 (Architecture Discovery).
If **Greenfield**: skip to Step 2 (Product Definition).

---

## Step 1.4: Graph Analysis (Automated, Before Manual Discovery)

**IMPORTANT**: Before reading any source files manually, run the graph builder to get precise structural data. This step is fast (seconds, not minutes) and dramatically accelerates all subsequent phases.

**CRITICAL ORDERING**: Phase 0 (this step) MUST complete before writing any section of architecture.md. The graph provides: (a) exhaustive module list, (b) hotspot-ranked module priority, (c) authoritative proto API surface, (d) mermaid diagrams ready for slot injection, (e) codebase tier for .ai-context.md budget.

### 1. Build the graph snapshot

The knowledge-graph engine is `codebase-memory-mcp`, resolved by `scripts/tools/_lib.sh:find_memory_bin` (`DRAFT_MEMORY_BIN` > PATH > `~/.cache/draft/bin` > vendored `bin/<arch>/`). `scripts/install.sh` fetches it; install manually with `scripts/fetch-memory-engine.sh`. Set `DRAFT_MEMORY_DISABLE=1` to opt out.

One command resolves the engine, indexes the repo, and writes the committed snapshot under `draft/graph/`:

```bash
if scripts/tools/graph-snapshot.sh --repo .; then
    echo "Graph snapshot written to draft/graph/ (schema.yaml, architecture.json, hotspots.jsonl, *.mermaid)."
else
    echo "Graph engine unavailable — skipping automated graph analysis. Downstream skills degrade gracefully."
fi
```

Optionally record which engine was selected (usage-report contract):

```bash
scripts/tools/verify-graph-binary.sh --repo . --json 2>/dev/null || true
```

See `core/shared/graph-query.md` and `bin/README.md` for the query contract and engine resolution.

If the snapshot succeeds, `draft/graph/` is populated and later steps consume the always-load artifacts + injection slots.

### 2. If graph build succeeds, load the always-load artifacts

Read these files to get structural context for all subsequent phases:
- `draft/graph/schema.yaml` — module count, file count, edge count, language stats per module
- `draft/graph/architecture.json` — module list (`.packages`) with fan-in/out
- `draft/graph/architecture.json` `.routes` — detected service endpoints
- `draft/graph/hotspots.jsonl` — all complexity hotspots (files ranked by lines + fanIn * 50)

### 3. Use graph data to accelerate Step 1.5

- **Module boundaries**: Exact module list with file counts — skip manual directory tree mapping
- **Dependency wiring**: Exact inter-module edges with weights — skip manual `#include` / import tracing
- **Proto API surface**: Exact services, RPCs, and message definitions — skip manual proto discovery
- **Hotspots**: Know which high-complexity, high-fanIn files to prioritize reading
- **Language mix**: Exact `.cc`, `.h`, `.go`, `.proto`, `.py` counts per module
- **Cycle detection**: Circular dependency paths between modules — flag for architecture.md

### 4. Compute codebase tier and module priority

**Step 1.4.5 — Compute Codebase Tier:**
Read `draft/graph/schema.yaml`. Extract:
- `M = stats.modules`
- `F = stats.go_functions + stats.py_functions`
- `P = stats.proto_rpcs`

Apply tier table:

| Tier | Label  | Condition                              | .ai-context.md Budget |
|------|--------|----------------------------------------|-----------------------|
| 1    | micro  | M≤5 AND F≤50 AND P≤10                 | 100–180 lines         |
| 2    | small  | M≤15 AND F≤300 AND P≤30               | 180–280 lines         |
| 3    | medium | M≤40 AND F≤1000 AND P≤100             | 280–400 lines         |
| 4    | large  | M≤100 AND F≤5000 AND P≤500            | 400–600 lines         |
| 5    | XL     | M>100 OR F>5000 OR P>500              | 600–900 lines         |

Hold tier in memory. This governs: architecture.md length minimum, .ai-context.md budget, and module deep-dive depth.

**Step 1.4.6 — Build Module Priority List:**
From `draft/graph/hotspots.jsonl`: count hotspot files per module (group by `module` field).
From `draft/graph/architecture.json` `.packages[]`: read `fan_in` per module.
Rank modules by: `(hotspot_count × 2) + fan_in_count`.
Top-ranked modules drive Section 6 deep-dive ordering and depth. Modules ranked zero on both: summary treatment only.
Hold ranked list in memory — it replaces directory scanning for module discovery.

**Step 1.4.7 — Populate Graph Injection Slots:**
Query for diagram content and write into architecture.md slots using the standard marker format.

For Section 4.4 (module-deps slot):
```bash
scripts/tools/mermaid-from-graph.sh --repo . --diagram module-deps
```
The tool emits a ready-to-inject ` ```mermaid ``` ` block (or an empty stub on exit 2). Write between the markers:
```
<!-- GRAPH:module-deps:START -->
{mermaid block from the tool}
<!-- GRAPH:module-deps:END -->
```

For Section 20 (hotspots slot):
Read `draft/graph/hotspots.jsonl` (or run `scripts/tools/hotspot-rank.sh --repo . --top 10`), take the top 10 by fanIn, build a markdown table:
```
<!-- GRAPH:hotspots:START -->
| Symbol | fanIn |
|--------|-------|
| {name} | {fanIn} |
...
<!-- GRAPH:hotspots:END -->
```

For Appendix E (proto-map slot):
```bash
scripts/tools/mermaid-from-graph.sh --repo . --diagram proto-map
```
The tool emits a ` ```mermaid ``` ` block from detected routes (empty stub if none). Write:
```
<!-- GRAPH:proto-map:START -->
```mermaid
{diagram content}
```
<!-- GRAPH:proto-map:END -->
```

**If slot markers are absent** (first run on a repo that has no prior slot structure): write the slot content at the designated location in the template. The markers are always present in `core/templates/architecture.md`, so this path is only hit if a user has an older pre-slot architecture.md.

### 5. If graph binary not found or build fails

Proceed with standard Step 1.5 manual discovery. No degradation — the 5-phase analysis works as before. Architecture.md length minimum defaults to tier-2 guidance (medium-depth treatment).

See `core/shared/graph-query.md` for the full graph query subroutine reference.

---

## Step 1.5: Architecture Discovery (Brownfield Only)

Perform a **one-time, exhaustive analysis** of the existing codebase. This is NOT a summary — it is a comprehensive reference document that enables future AI agents and engineers to work without re-reading source files.

**Outputs**:
- `draft/architecture.md` — Human-readable, **comprehensive** engineering reference (PRIMARY)
- `draft/.ai-context.md` — Token-optimized, tier-scaled budget, condensed from architecture.md (DERIVED)
- `draft/.ai-profile.md` — Ultra-compact, 20-50 lines, always-injected project profile (DERIVED)
- `draft/graph/` — Knowledge graph artifacts (module-graph, proto-index, hotspots, per-module files) from Step 1.4

**Target output**: A single self-contained reference document designed for **dual consumption**:
1. **LLM / AI-agent context** — enabling future code changes, Q&A, and onboarding without re-reading source files.
2. **Engineer reference** — enabling debugging, extension, and operational understanding.

### Graph + Indexed Knowledge Fidelity Mandate

**CRITICAL**: The output must be **faithful to the deterministic graph and your environment's full indexed understanding** of the project. This is not "read every file" exhaustiveness — it is correctness and completeness of the *model*.

- The knowledge graph (`draft/graph/`) + your agent/IDE's rich codebase index together form the authoritative view.
- Use direct source reads strategically (hotspots, interfaces, key implementation paths) to validate, enrich, and draw accurate diagrams — not as a brute-force enumeration exercise.
- **Prioritize synthesis of accurate workflow, state, sequence, and component diagrams** that make the graph's facts and the project's higher-level design immediately usable.
- **Include real, verified code snippets and invariants** only where they add understanding not already visible in the graph or diagrams.
- **Target: highest possible correctness** of the generated architecture model. A concise, diagram-rich document that an agent or engineer can trust is the goal. Volume without fidelity is noise.

If the codebase is large (200+ files), focus on the module boundaries but still enumerate exhaustively within each module.

> **Large codebase guardrail:** If the codebase exceeds 500 source files, limit Section 7 deep dives to the top 20 most-imported modules and summarize others in a table. Rank modules by the number of unique files that import/reference them (descending) — use `draft/graph/architecture.json` `.packages[].fan_in` if graph data is available. For dynamic languages where static import counting is impractical, rank by file count within each module directory (larger modules first). **Even for summarized modules, enumerate immediate sub-directories with file counts** (one-line per sub-dir) — this is cheap with graph data and provides essential navigation context.

### Parallel Analysis Protocol (Tiers 3–5)

**MANDATORY for tiers 3–5 (medium / large / XL).** Uses Map → IR+Prose → Reduce: parallel reader agents each produce both structured IR metadata and full §7 deep-dive prose, then a synthesis agent composes the final document. Cuts wall clock by ~55% at XL tier while preserving depth — readers write the module narratives from source; synthesis assembles the cross-cutting sections.

**For tiers 1–2 (micro / small): skip this protocol entirely.** Use the Sequential Generation Protocol below. At small scale, parallelism adds overhead with no speed benefit, and the IR intermediate step discards source-level depth that a direct sequential pass produces cheaply.

> Full protocol details, IR schema, and prompt templates are in `core/shared/parallel-analysis.md`.

#### Tier-Adaptive Agent Counts

From the tier computed in Step 1.4.5, determine reader agent count:

| Tier | Label  | Reader Agents                        | Strategy                             |
|------|--------|--------------------------------------|--------------------------------------|
| 1    | micro  | 1 (all modules in one agent)         | 1 reader → 1 synthesizer             |
| 2    | small  | 1–2 (all or half modules each)       | 1–2 readers → 1 synthesizer          |
| 3    | medium | 2–3 (ceil(M/6) agents)               | parallel readers → 1 synthesizer     |
| 4    | large  | ceil(M/4) agents                     | parallel readers → 1 synthesizer + parallel finalizers |
| 5    | XL     | ceil(M/4) agents                     | parallel readers → 1 synthesizer + parallel finalizers |

For tiers 1–2, the "parallel" phase is just a single reader agent — no overhead, same clean IR boundary.
For tier 3+, readers run simultaneously; wall clock = slowest reader, not the sum.

#### Phase 0: Graph Data (already done in Step 1.4)

The graph binary has already run. Use its output throughout this protocol:
- `draft.tmp/graph/schema.yaml` — module list, file counts, tier metrics
- `draft.tmp/graph/architecture.json` — `.packages[].fan_in` per module (for grouping)
- `draft.tmp/graph/hotspots.jsonl` — top hotspot files per module (feed to readers)

#### Phase 1: Spawn Parallel Module Readers

**Step 1: Group modules.**

From `draft.tmp/graph/architecture.json` `.packages[]`, extract all module names and their `fan_in` counts.
Apply dependency-aware grouping (see `core/shared/parallel-analysis.md`).
Use the modules-per-agent count from the tier table above (4 for tier 4/5; all modules in one agent for tier 1):
- Assign highest fan-in modules to separate readers (tier 3+)
- Co-locate coupled module pairs in the same reader
- Target balanced token budgets across groups

**Step 2: Build graph data summary per group.**

For each reader group, prepare a compact summary from graph artifacts:
```
Modules: [execution, fill_processor, order_manager]
Hotspot files:
  execution/engine.go (847 lines, fanIn=12)
  execution/router.go (412 lines, fanIn=8)
  fill_processor/handler.go (623 lines, fanIn=5)
Module edges (from architecture.json .packages fan-in/out):
  execution → [risk, data, services]
  fill_processor → [execution, persistence]
```

**Step 3: Spawn all reader agents in parallel using the Agent tool.**

Spawn `ceil(module_count / 4)` agents simultaneously. Use the Module Reader Prompt Template from `core/shared/parallel-analysis.md`, replacing:
- `{MODULE_LIST}` — comma-separated module names for this agent
- `{REPO_ROOT}` — absolute path to repository root
- `{GRAPH_DATA_SUMMARY}` — the compact summary built in Step 2

Each reader agent:
- Reads source files in its assigned modules only
- Outputs a JSON array of IR objects (one per module)
- Produces NO prose, NO documentation

**Critical constraints to include in reader prompts:**
```
MUST output IR JSON array only.
MUST NOT write any documentation or architecture sections.
MUST NOT read files outside assigned modules.
Token budget: max 600 tokens per module in IR output.
```

**Step 4: Collect and validate reader outputs.**

Each reader produces two outputs, separated by `## IR` and `## Deep-Dives` headings.

After all readers complete:
1. Extract the `## IR` section from each reader output and parse as JSON. If parse fails, retry that reader (see failure modes in `core/shared/parallel-analysis.md`).
2. Check IR `token_budget_used` — if < 150 for a module with >20 files AND deep-dive for that module is < 100 lines, re-run that reader with explicit instruction to read more files.
3. Concatenate all IR objects into a single JSON array → `draft.tmp/.state/reader-irs.json`
4. Concatenate all `## Deep-Dives` sections from all readers → `draft.tmp/.state/reader-deep-dives.md`

#### Phase 2: Synthesis

Collect reader outputs before spawning synthesis:
1. Parse and concatenate all IR JSON arrays → `draft.tmp/.state/reader-irs.json`
2. Concatenate all reader deep-dive Markdown sections → `draft.tmp/.state/reader-deep-dives.md`

Spawn a **single synthesis agent** with the Synthesis Coordinator Prompt from `core/shared/parallel-analysis.md`, replacing:
- `{CONCATENATED_DEEP_DIVES}` — content of `draft.tmp/.state/reader-deep-dives.md`
- `{CONCATENATED_IRS}` — content of `draft.tmp/.state/reader-irs.json`
- `{GRAPH_DEPENDENCY_DIAGRAM}` — mermaid output from `--query --mode mermaid --symbol module-deps`
- `{ARCHITECTURE_TEMPLATE_STRUCTURE}` — the modern 10-section graph-primary outline from `core/templates/architecture.md` (the single source of truth)

The synthesis agent:
- Integrates the reader outputs (now graph + one high-quality workflow/state diagram + minimal notes per module) into §7 with light editing only for consistency and cross-references.
- Derives the true cross-cutting sections (§4 topology, §5 component map, §6 operational flows, §8 concurrency, §14 integration sequences, §15 invariants, etc.) by combining IR data, reader diagrams, and additional targeted source reads.
- Aggressively uses its own full indexed project knowledge (from the host Cursor/Claude Code/Copilot environment) to improve accuracy of workflows, state machines, and higher-level design synthesis beyond what the static graph snapshot provides.
- Produces a document whose primary value is faithful, visual, diagram-rich representation of the actual system design.

**Source reading policy for synthesis agent (enforce in prompt):**
```
Read source (and aggressively use your full project index) for:
- §6 Core Operational Flows — the most important system-level workflows, lifecycles, and state machines (this is the highest-ROI section for future coding accuracy)
- §12 API / Interface surface
- §14 Cross-module integration sequences
- §15 Critical Invariants (verification against actual code)
- §18 Key Design Patterns

All other sections: compose primarily from the graph + reader outputs + IR, with light additional reads only where needed for diagram accuracy.
```

#### Phase 3: Parallel Finalization

Once `draft.tmp/architecture.md` is written, spawn two agents simultaneously:

**Finalizer A — Context Derivation:**
Run the Condensation Subroutine (defined later in this skill) to generate:
- `draft.tmp/.ai-context.md`
- `draft.tmp/.ai-profile.md`

**Finalizer B — State Files:**
Write all `.state/` artifacts from the concatenated IRs:
- `draft.tmp/.state/facts.json` — extract atomic facts from IR fields (key_classes, invariants, state, error_handling)
- `draft.tmp/.state/freshness.json` — compute hashes of all source files read (baseline for incremental refresh)
- `draft.tmp/.state/signals.json` — derive signal classification from IR module roles and graph data
- `draft.tmp/.state/run-memory.json` — set `status: "completed"`, record phase timings

Finalizers A and B have no dependency on each other — run truly in parallel.

#### Phase 4: Quality Gate

After both finalizers complete, run the Completion Verification (defined later in this skill) against the standard hard minimum thresholds. If any metric fails:
1. Identify the sparse sections (most likely cross-cutting sections: §14 Integration, §16 Security, §8 Concurrency)
2. Request the synthesis agent to expand those sections, providing the relevant IR fields as targeted input
3. Only proceed to atomic rename (`mv draft.tmp/ draft/`) after all metrics pass

#### Failure Recovery

If any reader agent fails to produce valid JSON after one retry:
- Log which modules failed: `draft.tmp/.state/failed-readers.json`
- Run those modules through the standard sequential analysis (Phase 3 in the Large Codebase Protocol below)
- Merge the resulting content into the IR set before synthesis
- The other readers' IRs remain valid — only the failed group needs re-work

---

### Sequential Fallback (when parallel IR pipeline unavailable)

When the Agent tool is unavailable or reader agents fail after retry, write `draft/architecture.md` using the **10-section graph-primary structure** (checklist above + `core/templates/architecture.md`). Do not use legacy 28-section or Pass 1/2/3 volume protocols.

1. Use the ranked module list from Step 1.4.6 (graph-first — do not re-scan by directory if Phase 0 succeeded).
2. For each top module (up to 20 by fan-in), read `draft/graph/modules/{name}.jsonl`, hotspot files, and 3–5 key sources; embed graph blocks and at least one workflow/state diagram per significant module inside §4–§8 as appropriate.
3. Always include §9 Graph Coverage Gaps and §10 Relationship when the Context Audit requires them.
4. Run Completion Verification (defined later in this skill) before condensation. Fidelity, provenance, and gap honesty block completion — not line counts.

---

### Execution Strategy for Depth

**Mindset**: You are creating a PERMANENT reference document. Future AI agents and engineers will use this instead of reading source code. Incomplete analysis means they'll make mistakes.

**File Reading Strategy**:
1. **Read broadly first** (Phase 1-2): Map the entire codebase structure
2. **Read deeply second** (Phase 3-4): For each major module, read the FULL implementation
3. **Cross-reference** (Phase 5): Verify every component appears in all relevant sections

**Diagram Generation Strategy**:
1. **Generate diagrams AFTER understanding** — not during exploration
2. **Use proper Mermaid syntax** — validate mentally before writing
3. **One diagram per concept** — don't combine unrelated flows
4. **Annotate arrows** — show what data moves between nodes

**Iteration Guidance**:
- After initial generation, review each HIGH-priority section
- If any section is thin (< 1 page for HIGH priority), expand it
- If any required diagram is missing, add it
- If tables have < 5 rows, verify you've enumerated exhaustively

---

### Adaptive Sections

Not every codebase has every concept. Apply these rules:

| If the codebase... | Then... |
|---------------------|---------|
| Has no plugin / algorithm / handler system | Skip Section 9 (Framework & Extension Points) and Section 10 (Full Catalog) |
| Has no V1/V2 generational split | Skip Section 11 (Secondary Subsystem) |
| Has no RPC / proto / API definitions | Skip Section 12, or retitle to "API Definitions" and cover REST / GraphQL / OpenAPI |
| Is a library (no binary / process) | Adapt Section 4.2 (Process Lifecycle) to "Usage Lifecycle" — how consumers integrate it |
| Is a frontend / UI module | Add: Component hierarchy, route map, state management, styling system |
| Uses a database directly | Add to Section 19: schema definitions, migration system, ORM models |
| Is containerized / has infra config | Add: Dockerfile, Kubernetes manifests, Helm charts, Terraform, CI/CD pipeline |
| Is a single-threaded / simple module | Simplify Section 8 (Concurrency) to note "single-threaded" and skip detailed thread maps |
| Has no configuration flags | Adapt Section 22 to cover whatever config mechanism exists (env vars, YAML, JSON, TOML, .env) |

---

### Language-Specific Exploration Guide

#### C / C++
| What to Find | Where to Look |
|-------------|--------------|
| Build targets & deps | `BUILD`, `CMakeLists.txt`, `Makefile` |
| Entry point | `main()` in `*_exec.cc`, `main.cc`, `*_main.cc` |
| Interfaces | `.h` header files (class declarations, virtual methods) |
| Implementation | `.cc` / `.cpp` files |
| API definitions | `.proto` files (protobuf), `.thrift` files |
| Config / flags | gflags: `DEFINE_*` macros in `flags.cc` / `flags.h` |
| Tests | `*_test.cc`, `*_unittest.cc`, files in `test/` or `qa/` dirs |

#### Go
| What to Find | Where to Look |
|-------------|--------------|
| Build targets & deps | `go.mod`, `go.sum`, `BUILD` (if Bazel) |
| Entry point | `func main()` in `main.go` or `cmd/*/main.go` |
| Interfaces | `type XxxInterface interface` in `*.go` files |
| Implementation | `*.go` files (non-test) |
| API definitions | `.proto` files, or handler registrations in router setup |
| Config / flags | `flag.*`, Viper config, environment variables |
| Tests | `*_test.go` files |

#### Python
| What to Find | Where to Look |
|-------------|--------------|
| Build targets & deps | `requirements.txt`, `pyproject.toml`, `setup.py`, `setup.cfg`, `Pipfile` |
| Entry point | `if __name__ == "__main__"` blocks, `app.py`, `main.py`, CLI entry points in pyproject.toml |
| Interfaces | Abstract base classes (`ABC`), Protocol classes, type hints |
| Implementation | `.py` files |
| API definitions | FastAPI/Flask route decorators, OpenAPI spec, `.proto` files |
| Config / flags | `settings.py`, `.env`, `config.yaml`, `argparse`, Pydantic Settings |
| Tests | `test_*.py`, `*_test.py`, files in `tests/` dirs |

#### TypeScript / JavaScript
| What to Find | Where to Look |
|-------------|--------------|
| Build targets & deps | `package.json`, `tsconfig.json`, `yarn.lock` / `package-lock.json` |
| Entry point | `"main"` in package.json, `index.ts`, `app.ts`, `server.ts` |
| Interfaces | TypeScript `interface` / `type` definitions in `*.ts` / `*.d.ts` |
| Implementation | `*.ts` / `*.js` files |
| API definitions | Route files, OpenAPI spec, GraphQL `.graphql` / `.gql` files |
| Config / flags | `.env`, `config.ts`, environment variables, `process.env.*` |
| Tests | `*.test.ts`, `*.spec.ts`, files in `__tests__/` dirs |

#### Java / Kotlin
| What to Find | Where to Look |
|-------------|--------------|
| Build targets & deps | `pom.xml` (Maven), `build.gradle` / `build.gradle.kts` (Gradle), `BUILD` (Bazel) |
| Entry point | `public static void main(String[] args)`, Spring Boot `@SpringBootApplication` |
| Interfaces | Java `interface` declarations, abstract classes |
| Implementation | `*.java` / `*.kt` files in `src/main/` |
| API definitions | `@RestController` / `@RequestMapping` annotations, `.proto` files, OpenAPI |
| Config / flags | `application.yml` / `application.properties`, Spring `@Value`, env vars |
| Tests | `*Test.java`, `*Spec.kt`, files in `src/test/` |

#### Rust
| What to Find | Where to Look |
|-------------|--------------|
| Build targets & deps | `Cargo.toml`, `Cargo.lock` |
| Entry point | `fn main()` in `src/main.rs` or `src/bin/*.rs` |
| Interfaces | `trait` definitions |
| Implementation | `*.rs` files |
| API definitions | Handler registrations (Actix/Axum routes), `.proto` files |
| Config / flags | `clap` structs, `config` crate, `.env`, `config.toml` |
| Tests | `#[test]` functions, `tests/` directory, `#[cfg(test)]` modules |

---

### Analysis Strategy — How to Explore the Codebase

Follow these steps in order. The specific files to look for depend on the language — use the Language-Specific Exploration Guide above.

#### Phase 1: Discovery (Broad Scan)

1. **Map the directory tree**: Recursively list the project to understand the file layout. Note subdirectory groupings. (If Step 1.4 graph analysis succeeded, use `draft.tmp/graph/schema.yaml` module list instead — it is exhaustive and includes file counts.)

2. **Read build / dependency files**: These reveal the module structure, dependencies, and targets. (See language guide above for which files.)

3. **Read API definition files**: These define the module's data model and service interfaces. (See language guide above for which files. If Step 1.4 succeeded, `draft.tmp/graph/architecture.json` `.routes` already has all detected service endpoints.)

4. **Read interface / type definition files**: Class declarations, interface definitions, and type annotations reveal the public API and design intent.

5. **Classify codebase signals**: Walk the file tree from step 1 and tag every file that matches one or more signal categories. This drives adaptive section depth in later phases — sections with strong signals get deep treatment, sections with no signals get marked SKIP. (If Step 1.4 succeeded, use module file counts and dependency edges to accelerate signal classification.)

   | Signal Category | Detection Patterns | Drives Section(s) |
   |----------------|-------------------|-------------------|
   | `backend_routes` | `routes/`, `handlers/`, `controllers/`, `**/api/**`, route decorators (`@app.route`, `@router`, `@RequestMapping`) | §12 API Definitions, §14 Cross-Module Integration |
   | `frontend_routes` | `pages/`, `views/`, `**/routes.*`, `**/router.*`, React Router, Next.js `app/` dir | §4 Architecture (add UI topology) |
   | `components` | `components/`, `widgets/`, `*.component.ts`, `*.tsx` in component dirs | §7 Core Modules (add component hierarchy) |
   | `services` | `services/`, `*Service.*`, `*_service.*`, `**/service/**` | §5 Component Map, §7 Core Modules |
   | `data_models` | `models/`, `entities/`, `schemas/`, `*.model.*`, `*.entity.*`, `migrations/` | §19 State Management, §12 API Definitions |
   | `auth_files` | `auth/`, `**/auth/**`, `middleware/auth*`, `guards/`, JWT/OAuth imports | §16 Security Architecture |
   | `state_management` | `store/`, `reducers/`, `**/state/**`, Redux/Vuex/Zustand/Pinia imports | §19 State Management (frontend state) |
   | `background_jobs` | `jobs/`, `workers/`, `tasks/`, `queues/`, `**/cron/**`, Celery/Sidekiq/Bull imports | §8 Concurrency, §22 Configuration |
   | `persistence` | `repositories/`, `dao/`, `**/db/**`, ORM config files, migration directories | §19 State Management |
   | `test_infra` | `test/`, `tests/`, `__tests__/`, `*.test.*`, `*.spec.*`, test config files | §26 Testing Infrastructure |
   | `config_files` | `.env*`, `config/`, `*.config.*`, `application.yml`, `settings.*` | §22 Configuration |

   **Procedure:**

   ```bash
   # Count files matching each signal category
   # Example for backend_routes:
   find . -type f \( -path "*/routes/*" -o -path "*/handlers/*" -o -path "*/controllers/*" -o -path "*/api/*" \) \
     ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/vendor/*" ! -path "*/draft/*" | head -50

   # Repeat for each category, adapting patterns to the detected language
   ```

   **Build a signal summary** (hold in memory for Phase 5):

   ```
   Signal Classification:
     backend_routes:    12 files  → §12, §14 HIGH
     services:           8 files  → §5, §7 HIGH
     data_models:        6 files  → §19, §12 HIGH
     test_infra:        15 files  → §26 HIGH
     auth_files:         3 files  → §16 HIGH
     components:         0 files  → §7 (skip component hierarchy)
     frontend_routes:    0 files  → §4 (skip UI topology)
     state_management:   0 files  → §19 (skip frontend state)
     background_jobs:    0 files  → §8 (simplify concurrency)
     persistence:        4 files  → §19 HIGH
     config_files:       5 files  → §22 HIGH
   ```

   **Integration with Adaptive Sections table (above):** Use signal counts to override the default skip rules. A signal count of 0 means the section should be skipped or simplified. A count ≥ 3 means the section warrants deep treatment. Between 1-2, include the section but keep it brief.

#### Phase 2: Wiring (Trace the Graph)

6. **Find the entry point**: (See language guide above for common entry-point patterns.) Trace the initialization sequence.

7. **Follow the orchestrator**: From the top-level controller / app / server, trace how it creates, initializes, and wires all owned components.

8. **Find the registry / registration code**: Look for files that register handlers, plugins, routes, middleware, algorithms, etc. This reveals the full catalog.

9. **Map the dependency wiring**: Find the DI container, context struct, module system, or import graph that connects components.

#### Phase 3: Depth (Trace the Flows)

10. **Trace data flows end-to-end**: For each major flow, start at the data source / entry point and follow the code through processing stages to the output.

11. **Read implementation files**: For core modules, read the implementation to understand algorithms, error handling, retry logic, and state management.

12. **Identify concurrency model**: Find where thread pools, async executors, goroutines, or worker processes are created and what work is dispatched to each.

13. **Find safety checks**: Look for invariant assertions, validation logic, auth checks, version checks, lock acquisitions, and transaction boundaries.

#### Phase 4: Periphery

14. **Catalog external dependencies**: Check build/dependency files and import statements to map all external library and service dependencies.

15. **Examine test infrastructure**: Read test files and test utilities to understand the testing approach, mock patterns, and test harness.

16. **Scan for configuration**: Find all configuration mechanisms (flags, env vars, config files, feature gates, constants).

17. **Look for documentation**: Check for existing README, docs/, architecture decision records (ADRs), or inline comments that provide architectural context.

#### Phase 5: Synthesis

18. **Cross-reference**: Ensure every component mentioned in one section appears in all relevant sections (architecture, data flow, interaction matrix, etc.).

19. **Validate completeness**: Confirm ALL handlers / endpoints / plugins / schemas / dependencies are listed. Do not sample — enumerate exhaustively.

20. **Identify patterns**: Look for recurring design patterns and document them.

21. **Generate diagrams**: Create Mermaid diagrams AFTER understanding the full picture, not during exploration.

---

## architecture.md Specification (Graph-Primary — Forward Only)

Generate `draft/architecture.md` using the modern 10-section graph-primary structure defined in the **MANDATORY SECTION CHECKLIST** above and in `core/templates/architecture.md`.

The document is:
- Primarily derived from the deterministic knowledge graph (`draft/graph/`).
- Explicit about fidelity (frontmatter `graph:` block + Dashboard).
- Required to carry provenance/fidelity tags on all significant claims.
- Duplication-aware when high-quality agent docs (CLAUDE.md, INVARIANTS.md, etc.) are detected by the Context Audit.

**Full details, per-section guidance, provenance rules, and examples** live in:
- `core/templates/architecture.md` (the source of truth for the 10 sections + Generation Contract)
- `docs/research/proposed-graph-backed-architecture-template.md` (design rationale and fidelity rules)
- `references/architecture-spec.md` (deprecated legacy notes — **10-section template wins on any conflict**)

There is no legacy 28-section structure and no volume targets. The template itself is the contract.

**After completing analysis AND passing verification**, write to `draft/architecture.md`. This is the PRIMARY output. Then run the Condensation Subroutine.

## .ai-context.md Specification

**Authoritative procedure:** [core/shared/condensation.md](../../core/shared/condensation.md). Git state lives in `draft/metadata.json` only — do not copy `git.*` into `.ai-context.md` frontmatter.

Generate `draft/.ai-context.md` — a **machine-optimized** context file for AI/LLM consumption (200-400 lines).

### Design Principles

This file is **NOT for humans**. It is optimized for:
1. **Token efficiency** — minimize tokens while maximizing information density
2. **Machine parseability** — use consistent, structured formats that LLMs process efficiently
3. **Self-containment** — complete context without referencing other files
4. **Action-orientation** — everything an AI needs to make safe, correct code changes

**Format choices**:
- Use YAML-like key-value pairs (not prose paragraphs)
- Use arrow notation for graphs (not Mermaid)
- Use compact tables with `|` separators
- Use structured lists with consistent prefixes
- Abbreviate common patterns (e.g., `fn` for function, `ret` for returns)
- No markdown formatting for emphasis (no `**bold**` or `_italic_`)

### MANDATORY Header Format

**CRITICAL**: Every .ai-context.md file MUST start with this exact structure:

```markdown
---
project: "{PROJECT_NAME}"
module: "root"
generated_by: "draft:init"
generated_at: "{ISO_TIMESTAMP}"
git:
  branch: "{LOCAL_BRANCH}"
  remote: "{REMOTE/BRANCH}"
  commit: "{FULL_SHA}"
  commit_short: "{SHORT_SHA}"
  commit_date: "{COMMIT_DATE}"
  commit_message: "{COMMIT_MESSAGE}"
  dirty: {true|false}
synced_to_commit: "{FULL_SHA}"
---
```

**Do NOT skip the YAML frontmatter. It enables incremental refresh tracking.**

---

### Required Sections (all mandatory)

```markdown
# {PROJECT_NAME}

## META
type: {microservice|cli|library|daemon|webapp|api}
lang: {language} {version}
pattern: {Hexagonal|MVC|Pipeline|Event-driven|Layered}
build: {exact command}
test: {exact command}
entry: {file}:{function|class}
config: {mechanism}@{location}

## GRAPH:COMPONENTS
{ComponentA}
  ├─{SubComponentA1}: {5-word purpose}
  ├─{SubComponentA2}: {5-word purpose}
  └─{SubComponentA3}
      ├─{NestedComponent}: {purpose}
      └─{NestedComponent}: {purpose}
{ComponentB}
  └─...

## GRAPH:DEPENDENCIES
{Internal} -[{protocol}]-> {External}
{Internal} -[{protocol}]-> {External}
Examples:
  AuthService -[gRPC]-> UserDB
  API -[HTTP/REST]-> PaymentGateway
  Worker -[AMQP]-> MessageQueue

## GRAPH:DATAFLOW
FLOW:{FlowName}
  {source} --{data_type}--> {stage1} --{data_type}--> {stage2} --> {sink}
FLOW:{AnotherFlow}
  {source} --> {stage} --> {sink}
FLOW:ERROR
  {component} --{error_type}--> {handler} --> {recovery_action}

## WIRING
mechanism: {constructor_injection|context_struct|module_imports|DI_container|singleton}
tokens: [{token1}, {token2}, {token3}]
getters: [{getter1}, {getter2}]

## INVARIANTS
[DATA] {name}: {rule} @{file}:{line}
[DATA] {name}: {rule} @{file}:{line}
[SEC] {name}: {rule} @{file}:{line}
[CONC] {name}: {rule} @{file}:{line}
[ORD] {name}: {rule} @{file}:{line}
[COMPAT] {name}: {rule} @{file}:{line}
[IDEM] {name}: {rule} @{file}:{line}

## INTERFACES
```{language}
// Condensed interface definitions - signatures only
interface {Name} {
  {method}({params}): {return}  // {one-line purpose}
  {method}?({params}): {return} // optional
}
```

## CATALOG:{Category}
{id}|{type}|{file}|{purpose}
{id}|{type}|{file}|{purpose}

## CATALOG:{AnotherCategory}
{id}|{type}|{file}|{purpose}

## THREADS
{pool_name}|{count}|{runs_what}
{pool_name}|{count}|{runs_what}

## CONFIG
{param}|{default}|{critical:Y/N}|{purpose}
{param}|{default}|{critical:Y/N}|{purpose}

## ERRORS
{scenario}: {recovery}
{scenario}: {recovery}
retry_policy: {policy}
backoff: {strategy}

## CONCURRENCY
{component}: {rule} -> {violation_consequence}
{component}: {rule} -> {violation_consequence}
locks: [{lock1}@{file}, {lock2}@{file}]
lock_order: {lock1} < {lock2} < {lock3}

## EXTEND:{ExtensionType}
create: {path/pattern}
implement: {interface}@{file}
required: [{method1}, {method2}]
optional: [{method3}]
register: {registry}@{file}:{function}
deps: [{dep1}, {dep2}]
test: {test_pattern}

## EXTEND:{AnotherType}
...

## TEST
unit: {command}
integration: {command}
hooks: [{hook1}@{file}, {hook2}@{file}]

## FILES
entry: {path}
config: {path}
routes: {path}
models: {path}
services: {path}
tests: {path}
build: {path}

## VOCAB
{term}: {definition}
{term}: {definition}

## REFS
tech_stack: draft/tech-stack.md
workflow: draft/workflow.md
product: draft/product.md
```

### Machine-Readable Graph Notation

Use these consistent notations for graphs:

**Component hierarchy** (tree notation):
```
Root
  ├─Child1: purpose
  ├─Child2: purpose
  │   ├─Grandchild1: purpose
  │   └─Grandchild2: purpose
  └─Child3: purpose
```

**Dependency arrows** (directed graph):
```
A -[protocol]-> B      # A depends on B via protocol
A --> B                # A depends on B (direct call)
A -.-> B               # A optionally depends on B
A <--> B               # bidirectional dependency
```

**Data flow** (pipeline notation):
```
Source --{DataType}--> Transform --{DataType}--> Sink
         |
         +--> Branch --{DataType}--> AlternateSink
```

**State transitions**:
```
State1 --(event)--> State2
State2 --(event)--> State3 | State4  # conditional
```

### Compression Techniques

Apply these to minimize tokens:

1. **Abbreviate common words**:
   - `fn` = function, `ret` = returns, `req` = required, `opt` = optional
   - `cfg` = config, `impl` = implementation, `dep` = dependency
   - `auth` = authentication, `authz` = authorization

2. **Use symbols**:
   - `@` = at/in file, `->` = leads to/calls, `|` = or/separator
   - `?` = optional, `!` = critical/required, `~` = approximate

3. **Omit obvious context**:
   - Skip "The" and "This" at start of descriptions
   - Skip file extensions when unambiguous
   - Skip common prefixes (e.g., `src/` if all files are there)

4. **Use consistent column formats**:
   - Tables: `col1|col2|col3` (no spaces around `|`)
   - Key-value: `key: value` (single space after colon)
   - Lists: `[item1, item2, item3]` (comma-space separator)

### What to EXCLUDE from .ai-context.md

Exclude (belongs only in architecture.md):
- Mermaid diagram syntax (use text graphs)
- Full code implementations (use signatures only)
- Prose explanations (use structured key-values)
- Human formatting (bold, italic, headers beyond ##)
- Redundant information (don't repeat across sections)
- Historical context (focus on current state)
- Performance details (unless critical for correctness)
- Security details (unless needed for code changes)

### Quality Checklist for .ai-context.md

Verify before writing:
- [ ] Agent can implement new extension using ONLY this file
- [ ] Agent knows correct thread pool for async work
- [ ] Agent knows invariants to check before side effects
- [ ] Agent knows error handling pattern
- [ ] Agent can find correct file for any modification
- [ ] Agent knows test command and patterns
- [ ] Agent knows V1/V2 boundary (if applicable)
- [ ] No prose paragraphs (all structured data)
- [ ] No references to architecture.md
- [ ] 200-400 lines total

---

## Architecture Discovery Output (End of Step 1.5)

After completing the 5-phase analysis:

1. **Gather git metadata FIRST**: Run these commands to collect current state:
   ```bash
   PROJECT_NAME=$(basename "$(pwd)")
   GIT_BRANCH=$(git branch --show-current)
   GIT_REMOTE=$(git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null || echo "none")
   GIT_COMMIT=$(git rev-parse HEAD)
   GIT_COMMIT_SHORT=$(git rev-parse --short HEAD)
   GIT_COMMIT_DATE=$(git log -1 --format="%ci")
   GIT_COMMIT_MSG=$(git log -1 --format="%s")
   GIT_DIRTY=$([ -n "$(git status --porcelain)" ] && echo "true" || echo "false")
   ISO_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
   ```

2. **Write `draft/architecture.md`** with this EXACT structure:
   ```markdown
   ---
   project: "{PROJECT_NAME from above}"
   module: "root"
   generated_by: "draft:init"
   generated_at: "{ISO_TIMESTAMP from above}"
   git:
     branch: "{GIT_BRANCH}"
     remote: "{GIT_REMOTE}"
     commit: "{GIT_COMMIT}"
     commit_short: "{GIT_COMMIT_SHORT}"
     commit_date: "{GIT_COMMIT_DATE}"
     commit_message: "{GIT_COMMIT_MSG}"
     dirty: {GIT_DIRTY}
   synced_to_commit: "{GIT_COMMIT}"
   ---

   # Architecture: {PROJECT_NAME}

   > Graph-primary high-signal engineering reference (10-section modern structure).
   > For token-optimized AI context, see `draft/.ai-context.md`.

   ---

   ## Table of Contents
   ... (the 10 sections from the current `core/templates/architecture.md`)
   ```

3. **Run Completion Verification (MANDATORY)** — Before proceeding to `.ai-context.md`, verify architecture.md meets signal-quality, fidelity, and duplication-aware requirements (volume is now guidance only, secondary to provenance and honesty):

   ```
   SIGNAL QUALITY & FIDELITY VERIFICATION (replaces volume proxy)

   Hard (blocking) checks — all must PASS:

   1. Graph fidelity frontmatter block present and populated (graph: build_status, overall_fidelity, language_fidelity, stats, notes).
      → PASS / FAIL: ___

   2. Graph Health & Fidelity Dashboard table rendered in header area with real data from this run (no placeholders).
      → PASS / FAIL: ___

   3. §29 Graph Coverage Gaps & Known Limitations present, substantive (≥150 words or explicit "Full coverage — justification"), and enumerates the actual shortfalls observed (cross-refs Dashboard and frontmatter).
      → PASS / FAIL: ___

   4. §30 Relationship to Existing Authoritative Documentation present. When Context Audit = high/medium: contains concrete cross-references to detected files (CLAUDE.md, INVARIANTS.md, etc.), states what this doc adds (graph spine + diagrams + synthesis) vs. defers, and confirms no large prose duplication occurred.
      → PASS / FAIL: ___

   5. Sample of ≥5 critical claims (invariants §15, key flows §6, modules §7) carry explicit fidelity/provenance tags (e.g. [Graph:High], [Existing:CLAUDE.md §3], [Human:Synthesis]).
      → PASS / FAIL: ___

   6. All <!-- GRAPH:*:START/END --> injection slots either populated from graph or explicitly marked unavailable with fidelity impact note.
      → PASS / FAIL: ___

   7. Per-module Graph Fidelity & Diagram Report complete for all modules that have graph data; no synthesis contradictions with graph; low-fidelity areas explicitly called out in §9.
      → PASS / FAIL: ___

   Soft / guidance (low-context runs only; high-context runs may legitimately be shorter when deferring to authoritative sources):
   - Lines / Mermaid / tables / file refs / invariants / glossary as historical targets (no longer hard gates).
   - For 500+ file low-context: still expect substantial depth in graph-covered areas.

   OVERALL: If ANY hard check is FAIL, identify the weakest area (most often Gaps/Relationship or missing tags when audit was high) and expand/re-synthesize. Do NOT proceed to .ai-context.md until all hard checks PASS.
   ```

   If any verification step fails:
   - Re-run synthesis (or the specific reader) with explicit instruction to address the failing check using the Context Audit flag + graph data + provenance requirements.
   - Re-run verification.
   - Repeat until all hard checks pass.

4. **Derive `draft/.ai-context.md`** with the SAME metadata header, then use the Condensation Subroutine to transform architecture.md content into machine-optimized format.

5. **Derive `draft/.ai-profile.md`** — ultra-compact 20-50 line always-injected profile using the Profile Generation Subroutine (defined at the end of this skill).

6. **Present for review**: Show the user a summary of what was discovered, including the Completion Verification scores, before proceeding to Step 2.

**CRITICAL**:
- Do NOT skip the YAML frontmatter metadata block — it enables incremental refresh
- Do NOT skip the Completion Verification — it catches shallow output before it becomes permanent
- Generate architecture.md FIRST, verify it meets thresholds, then derive .ai-context.md, then .ai-profile.md
- All three files MUST have the metadata header at the very top

---

> **Note:** After generating or updating `architecture.md`, run the **Completion Verification** above, then the **Condensation Subroutine** (defined at the end of this skill) to derive `.ai-context.md`.

## Step 1.7: Persist State (Brownfield Only)

**Skip for Greenfield projects** — there are no source files to hash and no signals to classify. Greenfield projects only get `run-memory.json` (written during Completion).

After generating `architecture.md`, `.ai-context.md`, and `.ai-profile.md`, persist four state files to `draft/.state/` for incremental refresh and cross-session continuity.

### 1.7.0 Fact Registry (`draft/.state/facts.json`)

Extract atomic architectural facts discovered during Phases 1-5. Each fact is a single, verifiable claim about the codebase with dual-layer timestamps and relationship edges.

```json
{
  "generated_at": "{ISO_TIMESTAMP}",
  "git_commit": "{FULL_SHA}",
  "total_facts": 0,
  "categories": ["data-flow", "architecture", "invariant", "dependency", "api", "security", "concurrency", "configuration", "testing", "convention"],
  "facts": [
    {
      "id": "fact-001",
      "category": "architecture",
      "statement": "Express app uses service layer pattern — routes delegate to services, services access repositories",
      "confidence": 0.95,
      "source_files": ["src/routes/users.ts", "src/services/user.service.ts", "src/repositories/user.repo.ts"],
      "discovered_at": "{ISO_TIMESTAMP}",
      "established_at": "{ISO_TIMESTAMP from git blame}",
      "last_verified_at": "{ISO_TIMESTAMP}",
      "last_active_at": "{ISO_TIMESTAMP from file modification}",
      "access_count": 0,
      "edges": {
        "updates": [],
        "extends": [],
        "derives": ["fact-003"],
        "superseded_by": null
      }
    }
  ]
}
```

**Fact categories:**
- `data-flow` — How data moves through the system
- `architecture` — Structural patterns and module organization
- `invariant` — Rules that must always hold true
- `dependency` — External service and library dependencies
- `api` — Endpoint definitions and contracts
- `security` — Auth, authz, crypto, and access control patterns
- `concurrency` — Thread safety, async patterns, lock ordering
- `configuration` — Config mechanisms and critical settings
- `testing` — Test infrastructure and patterns
- `convention` — Coding conventions and naming patterns

**Target:** 50-150 facts per typical project. Focus on facts that are actionable for AI agents making code changes.

### 1.7.1 Freshness State (`draft/.state/freshness.json`)

Compute SHA-256 hashes of all source files analyzed during Phases 1-5. This enables **file-level staleness detection** on subsequent refreshes — more granular than `synced_to_commit` which only detects that _some_ commits happened.

```bash
# Generate SHA-256 hashes for all analyzed source files (exclude draft/, node_modules/, .git/, vendor/)
find . -type f \
  ! -path "./draft/*" ! -path "./.git/*" ! -path "*/node_modules/*" ! -path "*/vendor/*" \
  ! -path "*/__pycache__/*" ! -path "*/dist/*" ! -path "*/build/*" \
  \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
     -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.java" -o -name "*.kt" \
     -o -name "*.c" -o -name "*.cc" -o -name "*.cpp" -o -name "*.h" \
     -o -name "*.rb" -o -name "*.php" -o -name "*.swift" -o -name "*.cs" \
     -o -name "*.proto" -o -name "*.graphql" -o -name "*.gql" \
     -o -name "*.yaml" -o -name "*.yml" -o -name "*.toml" -o -name "*.json" \
     -o -name "*.sql" -o -name "*.md" -o -name "Dockerfile" -o -name "Makefile" \) \
  -exec sha256sum {} \; 2>/dev/null | sort -k2
```

Write `draft/.state/freshness.json`:

```json
{
  "generated_at": "{ISO_TIMESTAMP}",
  "git_commit": "{FULL_SHA}",
  "total_files": 0,
  "files": {
    "src/index.ts": "sha256:a1b2c3d4...",
    "src/auth/login.ts": "sha256:e5f6a7b8...",
    "package.json": "sha256:c9d0e1f2..."
  }
}
```

**On refresh:** Compare stored hashes against current file hashes. Files with changed/new/deleted hashes are the delta that drives targeted section updates.

### 1.7.2 Signal State (`draft/.state/signals.json`)

Persist the signal classification from Phase 1 step 5:

```json
{
  "generated_at": "{ISO_TIMESTAMP}",
  "git_commit": "{FULL_SHA}",
  "total_files_scanned": 0,
  "signals": {
    "backend_routes": { "count": 12, "sample_files": ["src/routes/auth.ts", "src/routes/users.ts"] },
    "frontend_routes": { "count": 0, "sample_files": [] },
    "components": { "count": 0, "sample_files": [] },
    "services": { "count": 8, "sample_files": ["src/services/auth.service.ts"] },
    "data_models": { "count": 6, "sample_files": ["src/models/user.ts"] },
    "auth_files": { "count": 3, "sample_files": ["src/auth/guard.ts"] },
    "state_management": { "count": 0, "sample_files": [] },
    "background_jobs": { "count": 0, "sample_files": [] },
    "persistence": { "count": 4, "sample_files": ["src/db/repository.ts"] },
    "test_infra": { "count": 15, "sample_files": ["tests/auth.test.ts"] },
    "config_files": { "count": 5, "sample_files": [".env.example", "config/default.yml"] }
  }
}
```

**Section relevance is derived at read-time**, not persisted. Use the signal counts and the "Drives Section(s)" column from the Phase 1 step 5 signal table to determine which architecture.md sections need deep treatment (signal count ≥ 3), brief treatment (1-2), or can be skipped (0).

**On refresh:** Compare current signals against stored signals. New signal categories appearing (e.g., `auth_files` going from 0→3) indicate **structural drift** — new architecture sections may need to be generated for the first time.

### 1.7.3 Run Memory (`draft/.state/run-memory.json`)

Persist run state for cross-session continuity. If `draft:init` is interrupted mid-analysis, the next invocation can detect the incomplete run and offer to resume.

```json
{
  "run_id": "{UUID}",
  "started_at": "{ISO_TIMESTAMP}",
  "completed_at": null,
  "run_type": "init",
  "status": "in_progress",
  "phases_completed": ["phase_1", "phase_2", "phase_3"],
  "phases_remaining": ["phase_4", "phase_5"],
  "files_analyzed": 142,
  "files_generated": ["draft/architecture.md", "draft/.ai-context.md", "draft/.ai-profile.md"],
  "unresolved_questions": [
    "Could not determine if src/legacy/ is actively used or deprecated",
    "Multiple auth patterns detected — unclear which is canonical"
  ],
  "active_focus_areas": ["backend_routes", "services", "data_models"],
  "resumable_checkpoint": {
    "last_phase": "phase_3",
    "last_file_read": "src/services/billing.service.ts",
    "pending_sections": ["§14 Cross-Module Integration", "§15 Critical Invariants"]
  }
}
```

**On completion:** Update `status` to `"completed"` and set `completed_at`. Keep `unresolved_questions` — these are surfaced to the user in the completion report and are valuable context for future refreshes.

**On next invocation:** If `run-memory.json` exists with `status: "in_progress"`:
- Announce: "Detected incomplete previous run (started {started_at}, completed phases: {list}). Resume from {last_phase} or start fresh?"
- If resume: Skip completed phases, continue from `resumable_checkpoint`
- If fresh: Overwrite run memory and start from Phase 1

---

## Step 2: Product Definition

Create `draft/product.md` using the template from `core/templates/product.md`.

**Include the Standard File Metadata header at the top of the file.**

Engage in structured dialogue:

1. **Vision**: "What does this product do and why does it matter?"
2. **Users**: "Who uses this? What are their primary needs?"
3. **Core Features**: "What are the must-have (P0), should-have (P1), and nice-to-have (P2) features?"
4. **Success Criteria**: "How will you measure if this product is successful?"
5. **Constraints**: "What technical, business, or timeline constraints exist?"
6. **Non-Goals**: "What is explicitly out of scope?"

Present for approval, iterate if needed, then write to `draft/product.md`.

## Step 3: Tech Stack

For Brownfield projects, auto-detect from:
- `package.json` → Node.js/TypeScript
- `requirements.txt` / `pyproject.toml` → Python
- `go.mod` → Go
- `Cargo.toml` → Rust

Create `draft/tech-stack.md` using the template from `core/templates/tech-stack.md`.

**Include the Standard File Metadata header at the top of the file.**

Present detected stack for verification before writing.

## Step 4: Workflow Configuration

Create `draft/workflow.md` using the template from `core/templates/workflow.md`.

**Include the Standard File Metadata header at the top of the file.**

Ask about:
- TDD preference (strict/flexible/none)
- Commit style and frequency
- Validation settings (auto-validate, blocking behavior)

## Step 4.1: Guardrails Configuration

Create `draft/guardrails.md` using the template from `core/templates/guardrails.md`.

**Include the Standard File Metadata header at the top of the file.**

The template includes general hard guardrails (Git, Code Quality, Security, Testing) — ask which to enable for this project. The Learned Conventions and Learned Anti-Patterns sections start empty — they are populated automatically by the learn step at the end of init (brownfield only) and by quality commands over time.

## Step 5: Initialize Tracks

Create `draft/tracks.md` with metadata header:

```markdown
---
project: "{PROJECT_NAME}"
module: "root"
generated_by: "draft:init"
generated_at: "{ISO_TIMESTAMP}"
git:
  branch: "{LOCAL_BRANCH}"
  remote: "{REMOTE/BRANCH}"
  commit: "{FULL_SHA}"
  commit_short: "{SHORT_SHA}"
  commit_date: "{COMMIT_DATE}"
  commit_message: "{COMMIT_MESSAGE}"
  dirty: {true|false}
synced_to_commit: "{FULL_SHA}"
---

# Tracks

## Active
<!-- No active tracks -->

## Completed
<!-- No completed tracks -->

## Archived
<!-- No archived tracks -->
```

## Step 6: Create Directory Structure

```bash
mkdir -p draft/tracks draft/.state
```

## Step 7: Pattern Discovery (Brownfield Only)

For **brownfield** projects, run `/draft:learn` (no arguments — full codebase scan) to populate `draft/guardrails.md` with initial learned conventions and anti-patterns. This ensures quality commands (`/draft:bughunt`, `/draft:review`, `/draft:deep-review`) have guardrails data from the first run.

**Skip this step for greenfield projects** — there is no existing codebase to scan.

> **Note:** This is the same full scan that `/draft:learn` performs when run standalone. The guardrails can be further refined later with `/draft:learn promote` or by quality commands that discover new patterns.

---

## Completion

**Finalize run memory:** Update `draft/.state/run-memory.json`:
- `status`: `"completed"`
- `completed_at`: current ISO timestamp
- Preserve `unresolved_questions` — these are displayed in the completion report below

For **Brownfield** projects, announce:
"Draft initialized successfully with comprehensive analysis!

Created:
- draft/.ai-profile.md (20-50 lines — ultra-compact always-injected profile, Tier 0)
- draft/.ai-context.md (200-400 lines — token-optimized AI context, self-contained, Tier 1)
- draft/architecture.md (comprehensive human-readable engineering reference, Tier 2)
- draft/product.md
- draft/tech-stack.md
- draft/workflow.md
- draft/guardrails.md (populated with learned conventions and anti-patterns from codebase scan)
- draft/tracks.md
- draft/.state/facts.json (atomic fact registry with knowledge graph edges)
- draft/.state/freshness.json (file-level hash baseline for incremental refresh)
- draft/.state/signals.json (codebase signal classification)
- draft/.state/run-memory.json (run metadata and unresolved questions)

{Include /draft:learn summary report here — conventions learned, anti-patterns detected, skipped entries}

{If unresolved_questions is non-empty, show:}
Unresolved questions from analysis:
{list each question — these are areas where the AI couldn't determine the answer with confidence}

Next steps:
1. Review draft/product.md — verify product vision, users, and goals reflect current reality
2. Review draft/tech-stack.md — verify languages, frameworks, and accepted patterns are accurate
3. Review draft/workflow.md — verify TDD, commit, and review settings match your team's process
4. Review draft/guardrails.md — verify learned conventions and anti-patterns are accurate
5. Review draft/.ai-context.md — verify the AI context is complete and accurate
6. Review draft/architecture.md — human-friendly version for team onboarding
7. Run `/draft:new-track` to start planning a feature
8. Run `/draft:init refresh` after significant codebase changes — refresh is now incremental (only stale files re-analyzed)
9. Run `/draft:learn promote` to promote high-confidence patterns to Hard Guardrails"

For **Greenfield** projects, announce:
"Draft initialized successfully!

Created:
- draft/product.md
- draft/tech-stack.md
- draft/workflow.md
- draft/guardrails.md
- draft/tracks.md
- draft/.state/run-memory.json (run metadata)

Next steps:
1. Review draft/product.md — verify product vision, users, and goals reflect current reality
2. Review draft/tech-stack.md — verify languages, frameworks, and accepted patterns are accurate
3. Review draft/workflow.md — verify TDD, commit, and review settings match your team's process
4. Review draft/guardrails.md — configure hard guardrails for your project
5. Run `/draft:new-track` to start planning a feature
6. Run `/draft:init refresh` after adding substantial code — this will generate architecture context and auto-run `/draft:learn` to populate guardrails"

---

## Condensation Subroutine

A self-contained procedure for generating `draft/.ai-context.md` from `draft/architecture.md`. Any skill that mutates `architecture.md` should execute this subroutine afterward to keep derived context in sync.

**Authoritative definition** lives at `core/shared/condensation.md` (already inlined into integrations). It covers inputs, outputs, tier-scaled budgets, the META/GRAPH/INVARIANTS/INTERFACES/CATALOG/THREADS/CONFIG/ERRORS/EXTEND sections, and the GRAPH:MODULE-HOTSPOTS / GRAPH:FAN-IN / GRAPH:PROTO-MAP enrichments.

After running condensation, also run the **Profile Generation Subroutine** below to regenerate `draft/.ai-profile.md`.


## Profile Generation Subroutine

This is a self-contained procedure for generating `draft/.ai-profile.md` from `draft/.ai-context.md`. Run after every Condensation Subroutine execution.

### Purpose

The profile is the **Tier 0 context** — an ultra-compact 20-50 line file always loaded by every Draft command. It provides the absolute minimum context needed for simple tasks (quick edits, config changes, small fixes) without requiring the full `.ai-context.md`.

### Procedure

#### Step 1: Read Source

Read `draft/.ai-context.md`. Extract the YAML frontmatter metadata block.

#### Step 2: Write YAML Frontmatter

Start `draft/.ai-profile.md` with an updated YAML frontmatter block. Copy all `git.*` and `synced_to_commit` fields. Set:
- `generated_by`: the calling command (e.g., `draft:init`, `draft:implement`)
- `generated_at`: current ISO 8601 timestamp

#### Step 3: Extract Profile Content

From `.ai-context.md`, extract:

1. **Stack** — Language, framework, database, auth method, API style, test framework, deploy target, build command, entry point (from `## META`)
2. **INVARIANTS** — Top 3-5 critical invariants with `file:line` references (from `## INVARIANTS`)
3. **NEVER** — 2-3 safety rules — the most dangerous things that must never happen (from `## INVARIANTS` or architecture.md safety rules)
4. **Active Tracks** — List of currently active track IDs and one-line descriptions (from `draft/tracks.md`)
5. **Recent Changes** — Last 3-5 significant commits (from `git log --oneline -5`)

#### Step 4: Write Output

Write to `draft/.ai-profile.md` using the template from `core/templates/ai-profile.md`.

#### Step 5: Size Check

- **Minimum**: 20 lines
- **Maximum**: 50 lines
- If over 50 lines, trim Recent Changes and reduce INVARIANTS to top 3

---

## Cross-Skill Dispatch

After initialization completes, suggest relevant follow-up skills based on project type:

### Brownfield Projects (Debt Signals Detected)

If during architecture discovery (Step 1.5), anti-patterns or technical debt signals are detected in signal classification:

```
"Detected architectural debt patterns in this codebase. Consider running:
  → /draft:tech-debt — Catalog and prioritize existing technical debt"
```

### All Projects (Post-Init Suggestions)

At completion (Step 6), after announcing next steps, present categorized follow-up skills:

```
What's Next:
─────────────────────────────
Start building:
  → /draft:new-track "description" — Start a feature, bug fix, or refactor

Quality & Testing:
  → /draft:testing-strategy — Establish test coverage targets and testing pyramid
  → /draft:tech-debt — Catalog technical debt (recommended for brownfield projects)

Documentation:
  → /draft:documentation readme — Generate README from discovered context

Debugging & Operations:
  → /draft:debug — Investigate a specific bug
  → /draft:standup — Generate standup from recent activity
```

### Jira Sync

If Jira MCP is available and a project ticket is linked, sync initialization artifacts via `core/shared/jira-sync.md`.
