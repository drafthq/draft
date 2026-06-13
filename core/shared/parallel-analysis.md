# Parallel Analysis Protocol

> Shared procedure for `draft:init`. Applies to tiers 3–5.
> Tiers 1–2 use the Sequential Generation Protocol directly — no parallelism needed, and the IR bottleneck hurts depth more than parallelism helps speed at small scale.
> Implements Map → IR+Prose → Reduce to cut wall clock by ~60% at XL tier while preserving deep per-module content.

---

## Architecture

```
Phase 1 (Map) N parallel reader agents bounded scope per agent (4 modules each)
                 each agent reads source files in its assigned modules
                 each agent outputs (A) IR JSON array — structured metadata for tables/diagrams
                                           (B) Markdown deep-dives — per-module prose (§7 sections)

Phase 2 (Reduce) 1 synthesis agent receives all IRs + all reader deep-dives
                 assembles architecture.md by composing reader prose (§7) + deriving cross-cutting
                                           sections from IR; targeted source reads for §6, §14, §15, §18
                 context budget: ~20K tokens (reader prose replaces need to re-read source)

Phase 3 (Finalize) 2 parallel agents .ai-context.md + .ai-profile.md
                                           state files (facts.json, freshness.json, etc.)
```

The **Intermediate Representation (IR)** carries structured metadata — edges, enums, hotspots.
The **Reader Deep-Dives** carry the prose that IR cannot express — mechanisms, rationale, operational detail.
Both outputs are produced by the same reader agent in one pass; no extra source reads needed.

---

## IR Schema (language-agnostic)

Each reader agent outputs a JSON array of objects matching this schema — one object per assigned module:

```json
{
  "module": "<module_name>",
  "path": "<source_path_relative_to_repo_root>",
  "role": "<1-sentence description of what this module does>",
  "files_read": 12,
  "token_budget_used": 420,

  "key_classes": [
    {
      "name": "<ClassName or key type>",
      "file": "<path>:<line>",
      "pattern": "<facade|singleton|actor|factory|strategy|observer|coordinator>",
      "public_methods": 14,
      "state_protected_by": "<lock_name or null>"
    }
  ],

  "state": [
    {
      "field": "<field_name>",
      "type": "<type>",
      "lock": "<lock_name or null>",
      "persistence": "<PostgreSQL|Redis|file|memory|none>"
    }
  ],

  "dependencies_out": ["<ModuleA>", "<ModuleB>"],
  "dependencies_in": ["<CallerA>", "<CallerB>"],

  "invariants": [
    "<rule that must always hold>",
    "<another invariant>"
  ],

  "hotspots": ["<file>:<lines>L", "<file>:<lines>L"],

  "extension_point": "<how to add new functionality to this module, or null>",

  "state_machine": {
    "states": ["STATE_A", "STATE_B"],
    "transitions": [["STATE_A", "event", "STATE_B"]]
  },

  "error_handling": "<fail-closed|retry|propagate|circuit-breaker|ignore>",

  "concurrency_model": "<single-threaded|async-await|mutex-lock|rwlock|actor-queue|goroutine-pool|thread-pool>"
}
```

**Token budget per module in IR output: 400–600 tokens.**
A module with 0 interesting state/concurrency/invariants still needs a valid IR — just shorter.

**Reader deep-dive budget per module: minimum 1500 tokens, no upper limit.**
This prose is the §7 deep-dive section — it must reflect actual source file content.
Large modules with deep sub-module hierarchies (e.g., 500+ files with 5+ sub-modules) should produce 5000–10000+ tokens of prose covering ALL sub-modules at the same depth as top-level modules. The synthesis agent will paste this verbatim — do NOT abbreviate to save tokens.

---

## Module Reader Prompt Template

Use this verbatim as the `prompt` field when spawning each reader agent via the `Agent` tool.
Replace `{MODULE_LIST}`, `{REPO_ROOT}`, and `{GRAPH_DATA_SUMMARY}` before sending.

```
You are a module reader agent. You have two jobs for each assigned module:
(A) Extract structured IR JSON — metadata for tables and diagrams
(B) Write a full §7 deep-dive section in Markdown — prose the synthesis agent will paste verbatim into architecture.md

ASSIGNED MODULES: {MODULE_LIST}
Repository root: {REPO_ROOT}

Graph context (use to prioritize which files to read):
{GRAPH_DATA_SUMMARY}

## Instructions

For each assigned module:
1. Read the module's directory structure (use Glob/LS)
2. Read the top-3 hotspot files (highest complexity from graph data above)
3. Read the interface/header or main entry file
4. For modules with 200+ files, read at least 5 source files total
5. Extract one IR JSON object matching the IR Schema below
6. Write one Markdown deep-dive section matching the Deep-Dive Template below

## IR Schema

Output a JSON array after the "## IR" heading. Each element is one module:

## IR
[
  {
    "module": "<name>",
    "path": "<source_path>",
    "role": "<1-sentence>",
    "files_read": <N>,
    "key_classes": [{"name":"","file":"","pattern":"","public_methods":0,"state_protected_by":null}],
    "state": [{"field":"","type":"","lock":null,"persistence":"memory"}],
    "dependencies_out": [],
    "dependencies_in": [],
    "invariants": ["<invariant>"],
    "hotspots": ["<file>:<lines>L"],
    "extension_point": null,
    "state_machine": {"states":[],"transitions":[]},
    "error_handling": "propagate",
    "concurrency_model": "single-threaded"
  }
]

## Deep-Dives

For each module, write a **graph-first, diagram-centric** Markdown section under the "## Deep-Dives" heading. The primary artifacts are the deterministic graph data and one synthesized workflow/state diagram. Prose is minimal supporting narrative.

#### 7.X {ModuleName}

**Role** (≤25 words, derived from graph role + primary source).

**Primary Workflow / State Diagram** (MANDATORY — highest value output)
One accurate Mermaid diagram (stateDiagram-v2, sequenceDiagram, or flowchart) that visualizes the dominant control flow, lifecycle, or data transformation for this module, using facts from the graph (entry points, public surface, call targets, hotspots). This diagram is more important than any other text in the section.

**Graph Summary** (from the module's graph record)
- Fan-in / Fan-out, hotspot files, key public symbols (only the architecturally significant ones).

**Design Notes** (≤60 words total)
Only observations from source that add understanding *not already visible* in the graph block or the workflow diagram (e.g., a subtle invariant, error boundary, or concurrency rule). Cite `path:line`.

**Sub-modules / Internal Boundaries**
Only when the graph shows clear internal structure with its own public surface or high internal fan-in. Each child follows the same pattern (graph facts + one workflow diagram + minimal notes).

**Anti-patterns for this output:**
- Do not start with "Source Files:" lists or exhaustive sub-directory tables.
- Do not emit long "Responsibilities (1. 2. 3.)" paragraphs when the graph + diagram already communicate the design.
- Short, precise synthesis + one excellent diagram is the goal. Volume is not a virtue.

Then, for EACH sub-module within this module:

##### 7.X.Y {ParentModule}/{SubModuleName} (if the graph shows a distinct boundary)

**Role**: One-line description.

**Graph Summary** (from the module's graph record)
- Fan-in / Fan-out, hotspot files, key public symbols (only the architecturally significant ones).

**Design Notes** (≤60 words total)
Only observations from source that add understanding *not already visible* in the graph block or the workflow diagram (e.g., a subtle invariant, error boundary, or concurrency rule). Cite `path:line`.

**Sub-modules / Internal Boundaries**
Only when the graph shows clear internal structure with its own public surface or high internal fan-in. Each child follows the same pattern (graph facts + one workflow diagram + minimal notes).

**Anti-patterns for sub-modules:**
- Do not produce long "Source Files + Responsibilities + 5+ operations" templates when the graph + one diagram suffice.
- Recurse only on boundaries the graph itself makes visible.

---

## Constraints

- IR: max 600 tokens per module; null unknown fields; never omit keys.
- Deep-dive output per module is graph block + **one mandatory workflow/state diagram** + ≤60 words Design Notes. Volume is not the goal.
- The diagram must be grounded in the module's graph record (entry points, public surface, call targets).
- Sub-modules receive their own subsection **only** when the graph data shows a distinct public surface or high internal fan-in. No descent "because the module is large."
- Ops/handler directories that are primary extension points may receive a short numbered catalog (focus on high-signal operations; exhaustive enumeration of every internal helper is not required).
- Do NOT read files outside your assigned modules.
- If a field is unknown in IR, use null or empty array.
```

---

## Synthesis Coordinator Prompt Template

Use this as the prompt for the single synthesis agent in Phase 2.
Replace `{CONCATENATED_IRS}`, `{GRAPH_DEPENDENCY_DIAGRAM}`, and `{ARCHITECTURE_TEMPLATE_STRUCTURE}`.

```
You are the synthesis agent. Your job is to assemble draft/architecture.md from reader outputs.

## Inputs

Reader deep-dive sections (Markdown prose, one §7.X block per module):
{CONCATENATED_DEEP_DIVES}

IR summaries for all modules (structured metadata):
{CONCATENATED_IRS}

Module dependency diagram (from graph binary):
{GRAPH_DEPENDENCY_DIAGRAM}

Architecture template structure to follow:
{ARCHITECTURE_TEMPLATE_STRUCTURE}

## Your Role

You are a composer, not an analyst. Readers already did the source analysis.
Your job:
1. Paste reader deep-dives verbatim into Section 7 — do not rewrite them, do not summarize them.
2. Derive cross-cutting sections from IR fields (edges, enums, invariants).
3. Read source directly for sections that require it (see policy below).

## CRITICAL: Template Compliance

Your output MUST follow the EXACT numbered section structure from {ARCHITECTURE_TEMPLATE_STRUCTURE}.
- Use the EXACT section numbers: ## 1. Executive Summary, ## 2. AI Agent Quick Reference, ## 3. System Identity & Purpose, ... through ## 28. Glossary, then Appendix A–E.
- Do NOT create custom/freeform sections. Do NOT rename sections. Do NOT skip section numbers.
- Do NOT collapse multiple template sections into one. Do NOT invent new section names.
- Every section from the template must appear in your output — if a section does not apply, write the heading and state "N/A — {reason}" beneath it.
- Sub-modules within Section 7 MUST get the SAME depth of analysis as top-level modules. A sub-module with 50+ files gets a full deep-dive (role, responsibilities, key ops table, state machine, mechanisms). There is no page limit — if the codebase has 14 modules each with 5 sub-modules, Section 7 alone may be 50+ pages. That is correct and expected.

## Source Reading Policy

Read source files for these sections — IR and reader prose are insufficient:
- §6 Core Operational Flows — read entry points, stateful services, dispatchers, and generation pipelines to synthesize accurate state/sequence diagrams (use full host indexed knowledge)
- §12 API Definitions — read route/handler files for endpoint enumeration
- §14 Integration Points — read adapter/client files for external dependency detail
- §15 Critical Invariants — verify invariants[] from IR against actual source assertions
- §18 Key Design Patterns — read 3–5 implementation files for concrete pattern examples
- §22 Configuration — read config/settings files for the configuration catalog

For all other sections (§1–5, §8–11, §13, §16–17, §19–21, §23–28, appendices):
derive from IR fields and reader deep-dives. Do not read source files for these.

## What to Derive from IR

- Component map (§4): use dependencies_out + dependencies_in edges across all IRs
- Concurrency model (§8): collect concurrency_model + state[].lock fields
- Extension points (§9): collect extension_point fields
- State machines (§10): collect state_machine fields across IRs
- Error handling patterns (§17): collect error_handling fields
- Hotspot catalog (§appendix): collect hotspots[] fields

## Output

Write the full `draft/architecture.md` following the **10-section graph-primary template** in `core/templates/architecture.md`.
Begin immediately with the YAML frontmatter, then the mandatory section headings. Do not explain your plan first.

MANDATORY output structure (in this exact order):
1. YAML frontmatter (`project`, `module`, `generated_by`, `generated_at`, graph fidelity block when available)
2. `# Architecture: {PROJECT_NAME}`
3. `## 1. Executive Summary + Graph Health Dashboard`
4. `## 2. Critical Invariants & Safety Rules (with provenance)`
5. `## 3. Primary Control & Data Flows (Graph + Synthesis)`
6. `## 4. Module & Dependency Map (Primarily Graph-Derived)`
7. `## 5. Concurrency, Ownership & Isolation Model`
8. `## 6. Error Handling & Failure Mode Catalog`
9. `## 7. State & Data Truth Sources + Reconciliation`
10. `## 8. Extension Points & Safe Mutation Patterns`
11. `## 9. Graph Coverage Gaps & Known Limitations (MANDATORY)`
12. `## 10. Relationship to Other Authoritative Documentation` (when Context Audit is high/medium)

Embed reader IR insights inside §3–§8 as graph-grounded diagrams and concise synthesis — not as a separate legacy Section 7 volume.
Do NOT produce freeform sections or resurrect 28-section numbering.
```

---

## Tier-Adaptive Agent Counts

| Tier | Label | Reader Agents |
|------|--------|--------------------------------|
| 1 | micro | 1 (all modules) |
| 2 | small | 1–2 |
| 3 | medium | ceil(M/6) |
| 4 | large | ceil(M/4) |
| 5 | XL | ceil(M/4) |

For tier 1–2, skip parallelism — one reader agent handles all modules sequentially.

---

## Dependency-Aware Module Grouping

When assigning modules to reader agents (tier 3+), apply this priority ordering:

```
Rule 1: Assign high fan-in modules to separate readers
        (modules with many callers produce IRs that many other IRs reference)

Rule 2: Co-locate modules with shared dependencies in the same reader
        (reader already has context about the dependency → richer IR)

Rule 3: Separate state-heavy modules from stateless utilities
        (state-heavy modules produce larger IRs; balance reader token budgets)

Rule 4: Use tier table above for modules-per-agent target
```

Example grouping heuristic (adapt to actual fan-in data from graph):
```
reader_A: [highest fan-in module alone] — never share high-fan-in with others
reader_B: [coupled pair: module_X + module_Y] — modules that call each other
reader_C: [data layer modules] — shared persistence/cache modules together
reader_D: [consumer/feature modules] — modules that call many others
reader_E: [infra/bootstrap modules] — low fan-in, foundational
```

---

## Failure Modes and Recovery

### Reader produces prose instead of IR
**Detection:** Output doesn't start with `[` or fails JSON.parse.
**Recovery:** Retry that reader with stricter constraint:
```
RETRY INSTRUCTION: Your previous output was not valid JSON. Output ONLY the JSON array.
The first character of your response MUST be `[`. No preamble. No explanation.
```
**Fallback:** If retry fails, run those modules through the standard sequential analysis.

### IR is too sparse AND deep-dive is too short
**Detection:** IR `token_budget_used < 150` for a module with >20 files AND deep-dive < 100 lines.
**Recovery:** Re-run that reader with explicit instruction to read more source files and expand the deep-dive.
If only the IR is sparse but the deep-dive is substantive, no action needed — prose is the primary output.

### Synthesis agent re-reads source outside policy
**Detection:** Tool calls to Read for files not in the permitted-sections list during synthesis.
**Prevention:** The synthesis prompt lists exactly which sections permit source reads. Outside those, synthesis derives from reader prose and IR.

### One reader agent fails entirely
**Detection:** Agent returns error or times out.
**Recovery:** Run the failed module group through standard sequential analysis.
The other readers' IRs are still valid — only the failed group needs re-work.
This is the blast-radius advantage over single-agent: a reader failure is a partial retry.

---

## Token Budget Model

```
Phase 1 readers (parallel, ceil(M/4) agents):
  Per agent: 4 modules × ~4K source tokens = ~16K input
                 IR output: ~2K tokens/agent
                 Deep-dive output: ~8K tokens/agent (4 modules × ~2K prose each)
                 Total per agent: ~26K

  Total Phase 1: ceil(M/4) agents × 26K (parallel — wall clock = slowest reader)

Phase 2 synthesis:
  Input: N modules × ~450 IR tokens + N modules × ~2K prose tokens + 4K instructions
                 ≈ 20K context at XL tier (vs 60K+ for raw source re-reads)
  Output: §7 paste (from readers) + cross-cutting sections ≈ 30K output tokens
  Total: ~50K tokens

Phase 3 finalizers (parallel, 2 agents):
  ~20K tokens total

vs single-agent baseline:
  ~350K source read tokens + ~34K generation = ~384K total
  ~50 min wall clock

Savings at XL tier: ~50% fewer tokens, ~55% faster wall clock
Depth vs single-agent: equivalent (readers read the same source; synthesis composes from prose)
```
