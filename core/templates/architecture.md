---
project: "{PROJECT_NAME}"
module: "root"
generated_by: "draft:init"
generated_at: "{ISO_TIMESTAMP}"

# Classification — drives which sections are Required vs skippable.
# Do not leave placeholders. If unknown, ask during draft:init interview.

# Ownership — enterprise accountability. Populate from CODEOWNERS / docs / interview.
ownership:
  codeowners_file: "{path-to-CODEOWNERS or 'none'}"
  primary_owners: ["{team-or-person}"]
  security_contact: "{email-or-channel-or-'N/A'}"
  oncall: "{pagerduty/opsgenie URL or 'none'}"

# Verification — stamped by draft:init at render time.
verification:
  citations_verified: "{true | false | unchecked}"
  staleness_hash: "{sha256 of tracked source set at synced_to_commit}"
  graph_schema_version: "{semver or 'absent'}"
graph:
  build_status: "{success | failed | absent}"
  overall_fidelity: "{high | mixed | low | stub}"
  language_fidelity:
    python: "{stub (directory-level only) | approximate | high}"
    typescript: "{stub | approximate | high}"
    rust: "{approximate | high}"
    cpp: "{high}"
    go: "{approximate | high}"
  stats:
    modules: "{N from schema.yaml}"
    edges: "{N from module-graph.jsonl}"
    hotspots: "{N}"
  notes: "{explicit fidelity summary, e.g. 'Python: stub (0 edges, dir-level only); C++: high from graph-clang'}"
generation_notes: "{High existing context detected via audit — see §30 Relationship for deference and cross-refs | Standard generation}"
---

# Architecture: {PROJECT_NAME}

> Enterprise, mission-critical-grade engineering reference.
> For token-optimized AI context, see `draft/.ai-context.md`.
> The knowledge graph (`draft/graph/`) is the deterministic source of truth for modules, dependencies, APIs, and structure. LLM synthesis produces faithful workflow, state, and sequence diagrams plus minimal narrative that makes the graph's facts actionable. Accuracy and diagram correctness > prose volume.
> Structure is fixed at 28 sections + 5 appendices. Read the **Generation Contract** (especially "Graph as Ground Truth") before authoring any section.

| Field | Value |
|-------|-------|
| **Branch** | `{LOCAL_BRANCH}` → `{REMOTE/BRANCH}` |
| **Commit** | `{SHORT_SHA}` — {COMMIT_MESSAGE} |
| **Generated** | {ISO_TIMESTAMP} |
| **Synced To** | `{FULL_SHA}` |
| **Criticality** | `{classification.criticality}` |
| **Data Class** | `{classification.data_classification}` |

**Graph Health & Fidelity Dashboard** (mandatory; populated from frontmatter `graph:` block at generation time; future agents calibrate trust here first):

| Language/Area | Fidelity | Modules | Edges | Hotspots | Notes |
|---------------|----------|---------|-------|----------|-------|
| Python        | {low/stub} | {N} | {N} | {N} | {e.g. directory-level only, 0 edges, 0 symbols} |
| Rust          | {approx/high} | {N} | {N} | {N} | {graph-derived or host index} |
| C++           | {high} | {N} | {N} | {N} | {full symbols via graph-clang} |
| ...           | ... | ... | ... | ... | ... |

> This table + the `graph:` frontmatter block is the single source of truth for "how much of this document is deterministic vs. synthesized." Low-fidelity areas must be explicitly called out in §29 Graph Coverage Gaps.

---

## Generation Contract (read first)

Every agent or human editor of this file MUST observe the following rules. Violations are completeness failures.

### Sources

Every `##` heading carries a `Source:` marker. Author content only from that source:

| Source | Meaning | Who writes it |
|---|---|---|
| `graph` | Rendered from `draft/graph/` between `<!-- GRAPH:*:START/END -->` fences | `draft:init` render pass, not the LLM |
| `manifest` | Extracted deterministically from `package.json` / `go.mod` / `Cargo.toml` / `requirements.txt` / `pom.xml` / Bazel `BUILD` / `pyproject.toml` | Scanner, not the LLM |
| `code-scan` | Deterministic scan (file tree, CODEOWNERS, OpenAPI, `.proto`, config parsers) | Scanner, not the LLM |
| `user-input` | Captured during `draft:init` interview; never inferred from code | User, captured verbatim |
| `llm-synthesis` | Narrative from reading code. Word budget is mandatory | LLM, bounded |

### Graph as Ground Truth for System Design

The knowledge graph produced by the `graph` binary (`draft/graph/module-graph.jsonl`, `proto-index.jsonl`, `hotspots.jsonl`, per-module file records, public API tables, and edge data) is the **authoritative, deterministic model** of the system's actual static architecture.

When you (the LLM) are executing inside Cursor, Claude Code, Copilot, or a similar environment, you also possess a powerful, continuously updated semantic index of the entire project. Use that indexed knowledge to cross-validate the graph, discover higher-level workflows and design intent, and synthesize more accurate and useful diagrams and notes. The graph is structural truth; your index + direct reads provide the semantic and workflow layer. Both must be combined for maximum correctness.

- **LLM role is synthesis, not invention.** The LLM must derive all claims about modules, dependencies, entry points, call relationships, data flows, and APIs from the graph or from direct source reads that are consistent with the graph.
- **Diagrams over paragraphs.** Prefer Mermaid state machines, sequence diagrams, flowcharts, and component interaction diagrams that make the graph's facts (modules, weighted edges, hotspots, entry/exit points) immediately comprehensible. A correct 25-line sequence diagram that accurately reflects a real call path from the graph is more valuable than 300 words of prose.
- **Accuracy > completeness of prose.** It is acceptable (and preferred) for narrative sections to be short when the graph + diagrams already convey the design. Do not pad with generic descriptions to reach historical line-count targets.
- **No contradiction.** Any prose description of a module boundary, dependency, or public surface must not contradict the corresponding graph record. If source reading reveals behavior the graph did not capture, the graph slot still governs the structural truth; the discrepancy must be noted explicitly.
- **Workflow and state focus.** For each major module or pipeline, synthesize at least one logical workflow or state transition diagram (stateDiagram-v2, sequenceDiagram, or flowchart with clear stages) that captures the primary control or data flow. These diagrams are first-class deliverables, not optional illustrations.

The previous sentence "Graph data enriches — it does not replace — this structure" is superseded for structural facts: the graph *defines* the structural facts. Prose and additional diagrams *interpret and visualize* those facts.

### Absence is signal

There are **no quotas** in this template. Do not pad to hit a count. If a section does not apply:

```
N/A — reason: {one-sentence justification referencing classification or codebase facts}.
```

Examples:
- `N/A — reason: project_type == 'library'; no HTTP surface.`
- `N/A — reason: single-threaded CLI; no concurrency primitives in use.`
- `N/A — reason: no proto/OpenAPI/GraphQL definitions present in repository.`

### Citations

Every `path:line` reference must resolve at `synced_to_commit`. If a citation cannot be verified (file moved, line out of range, commit unknown), write it as:

```
[unverified] path/to/file.ext:123
```

`draft:init` runs a post-generation verification pass that rewrites unresolved citations to this form. Do not attempt to guess or invent locations.

### Word budgets

Every `llm-synthesis` section carries a hard word cap. Exceeding the cap is a failure, not a feature. Cut to fit; do not expand neighbor sections to compensate.

### Classification gates

Each section declares `Required:` at one of four levels:
- `always` — every codebase, every run. Cannot be N/A.
- `standard+` — required when `criticality ∈ {standard, high, mission-critical}`.
- `high+` — required when `criticality ∈ {high, mission-critical}`.
- `mission-critical` — required only at that criticality.

Sections below the declared level MAY be N/A with reason; sections at or above MUST be populated.

### Do not regenerate untouched sections

If a section's source set (the files or graph tables it depends on) has not changed since the last run, leave the section byte-identical. `draft/.state/freshness.json` records per-section hashes. Re-derivation without source change is the single largest cause of cross-model divergence and is prohibited.

### Section metadata block

Every `##` heading is immediately followed by:

```
> **Source:** <one of the 5 sources above>
> **Required:** always | standard+ | high+ | mission-critical
> **Length:** rendered | ≤N words | ≤N rows | table | N/A
> **N/A when:** {precise, machine-checkable condition}
> **Verification:** graph-fence | citation-check | schema-check | manifest-diff | none
```

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [AI Agent Quick Reference](#2-ai-agent-quick-reference)
3. [System Identity & Purpose](#3-system-identity--purpose)
4. [Architecture Overview](#4-architecture-overview)
5. [Component Map & Interactions](#5-component-map--interactions)
6. [Core Operational Flows, Lifecycles & State Machines](#6-core-operational-flows-lifecycles--state-machines)
7. [Core Modules Deep Dive](#7-core-modules-deep-dive)
8. [Concurrency Model & Thread Safety](#8-concurrency-model--thread-safety)
9. [Framework & Extension Points](#9-framework--extension-points)
10. [Full Catalog of Implementations](#10-full-catalog-of-implementations)
11. [Secondary Subsystem (V2 / Redesign)](#11-secondary-subsystem-v2--redesign)
12. [API & Interface Definitions](#12-api--interface-definitions)
13. [External Dependencies](#13-external-dependencies)
14. [Cross-Module Integration Points](#14-cross-module-integration-points)
15. [Critical Invariants & Safety Rules](#15-critical-invariants--safety-rules)
16. [Security Architecture](#16-security-architecture)
17. [Observability & Telemetry](#17-observability--telemetry)
18. [Error Handling & Failure Modes](#18-error-handling--failure-modes)
19. [State Management & Persistence](#19-state-management--persistence)
20. [Reusable Modules for Future Projects](#20-reusable-modules-for-future-projects)
21. [Key Design Patterns](#21-key-design-patterns)
22. [Configuration & Tuning](#22-configuration--tuning)
23. [Performance Characteristics & Hot Paths](#23-performance-characteristics--hot-paths)
24. [How to Extend — Step-by-Step Cookbooks](#24-how-to-extend--step-by-step-cookbooks)
25. [Build System & Development Workflow](#25-build-system--development-workflow)
26. [Testing Infrastructure](#26-testing-infrastructure)
27. [Known Technical Debt & Limitations](#27-known-technical-debt--limitations)
28. [Glossary](#28-glossary)
- [Appendix A: File Structure Summary](#appendix-a-file-structure-summary)
- [Appendix B: Data Source → Implementation Mapping](#appendix-b-data-source--implementation-mapping)
- [Appendix C: Output Flow — Implementation to Target](#appendix-c-output-flow--implementation-to-target)
- [Appendix D: Mermaid Sequence Diagrams — Critical Flows](#appendix-d-mermaid-sequence-diagrams--critical-flows)
- [Appendix E: Proto Service Map (graph-derived)](#appendix-e-proto-service-map-graph-derived)

---

## 1. Executive Summary

> **Source:** llm-synthesis
> **Required:** always
> **Length:** ≤200 words
> **N/A when:** never
> **Verification:** citation-check

One paragraph, plain prose, no bullets. State what the system IS, what it DOES, and its role. Open with a single sentence that would stand alone as the whole summary if truncated. No marketing language.

**Key Facts** (exactly these rows, fill or mark N/A):

| Field | Value |
|-------|-------|
| Language & Version | {e.g., TypeScript 5.3} |
| Entry Point | `{path:line}` → `{symbol}` |
| Architecture Style | {Hexagonal / Layered / Microservice / Pipeline / Actor / N/A} |
| Component Count | {integer from graph} |
| Primary Data Sources | {databases, queues, APIs read from — or N/A} |
| Primary Action Targets | {databases, services, files written to — or N/A} |
| Deployment Model | {binary / container / lambda / library artifact / daemon / N/A} |

---

## 2. AI Agent Quick Reference

> **Source:** code-scan + manifest + user-input
> **Required:** always
> **Length:** table, fixed rows
> **N/A when:** never
> **Verification:** citation-check + manifest-diff

Compact block optimized for agent context loading. Every field populated or explicit "N/A".

```
Module : {PROJECT_NAME}
Root Path : ./
Language : {e.g., Go 1.21, Python 3.12, TypeScript 5.3}
Build : {exact command, e.g., `bazel build //path:target`, `npm run build`}
Test : {exact command, e.g., `pytest -q`, `go test ./...`}
Entry Point : {file:line → symbol}
Config System : {gflags / .env + YAML / Viper / Spring / environment / N/A}
Extension Point : {interface + registration site — or N/A}
API Definition : {path to .proto / OpenAPI / GraphQL — or N/A}
Key Config Prefix : {MODULE_* env / module.* YAML / --module-* CLI — or N/A}
CODEOWNERS : {path — or "none"}
Security Contact : {from ownership block}
On-Call : {from ownership block — or "none"}
```

**Before Making Changes, Always:**

1. {Primary invariant check — the #1 thing that must not break, citing §15 entry}
2. {Thread-safety / async-safety consideration — or "single-threaded — no concerns"}
3. {Test command to run after changes — copy from `Test` row above}
4. {API / schema versioning rule — or "N/A"}

**Never:**

- {Critical safety rule 1 — cite §15 or §16}
- {Critical safety rule 2}
- {Critical safety rule 3}

List exactly the rules that apply. If fewer than three apply, list fewer. Do not pad.

---

## 3. System Identity & Purpose

> **Source:** user-input
> **Required:** always
> **Length:** ≤300 words
> **N/A when:** never
> **Verification:** none

Captured during `draft:init` interview. Do not infer purpose or business rationale from code — ask the user.

**What this system IS** (≤60 words).

**What this system DOES** (≤60 words, bullet list of top-level capabilities).

**Who uses it** (≤40 words — internal teams / external customers / automated systems).

**Non-Goals** (explicit list; what this system will not do, to prevent scope creep).

**Upstream producers** (systems that send data or requests into this one — or N/A).

**Downstream consumers** (systems that receive data or requests from this one — or N/A).

---

## 4. Architecture Overview

> **Source:** llm-synthesis + graph
> **Required:** always
> **Length:** ≤400 words + one Mermaid diagram
> **N/A when:** never
> **Verification:** graph-fence (topology)

### 4.1 High-Level Topology

<!-- GRAPH:module-topology:START -->
<!-- Rendered by draft:init. If absent, emit:
     N/A — reason: graph artifacts not present. Run '/draft:init' or 'graph --repo . --out draft/graph' to populate. -->
<!-- GRAPH:module-topology:END -->

### 4.2 Narrative

≤400 words describing the topology in prose. Name the architectural style (hexagonal, layered, pipeline, actor, event-driven, plugin-host, monorepo, polyrepo) and justify from observable evidence (directory structure, dep graph, call boundaries).

### 4.3 Lifecycle Model

Choose one applicable model and fill only its rows. Delete rows that do not apply; do not force-fit.

| Model | Phases | Describe only if applicable |
|---|---|---|
| Long-running service | startup → ready → steady-state → drain → shutdown | |
| Short-lived CLI | parse-args → execute → exit | |
| Batch/ETL | trigger → extract → transform → load → ack | |
| Library | no lifecycle — N/A | |
| Actor/reactive | spawn → receive → handle → terminate | |

---

## 5. Component Map & Interactions

> **Source:** graph
> **Required:** always
> **Length:** rendered
> **N/A when:** never (graph absent → explicit N/A with reason)
> **Verification:** graph-fence

### 5.1 Module Dependency Graph

<!-- GRAPH:module-deps:START -->
<!-- Rendered from draft/graph/module-graph.jsonl (nodes + edges).
     Emits Mermaid graph + dependency matrix. No LLM prose inside fence. -->
<!-- GRAPH:module-deps:END -->

### 5.2 Component Interaction Matrix

<!-- GRAPH:integration-edges:START -->
<!-- Rendered matrix: rows = source module, cols = target module, cells = edge kind
     (calls / imports / emits-event / reads-schema). -->
<!-- GRAPH:integration-edges:END -->

### 5.3 Boundary Types

A short table listing the interaction kinds present. Rendered from graph edge taxonomy.

| Boundary Kind | Count | Example |
|---|---|---|
| in-process call | {n} | `moduleA.Foo` → `moduleB.Bar` |
| inter-process RPC | {n} | {service → service} |
| async message | {n} | {producer → topic → consumer} |
| shared database | {n} | {table} |

---

## 6. Core Operational Flows, Lifecycles & State Machines

> **Source:** llm-synthesis + graph (primary structural truth) + full project index
> **Required:** high+
> **Length:** 2–5 high-quality diagrams + minimal supporting prose
> **N/A when:** the system is trivial (single linear script with no meaningful state or branching) — write explicit N/A.
> **Verification:** diagram fidelity to graph + indexed understanding + citation-check

**Purpose**: This is one of the highest-value sections for any downstream coding assistant. It captures the **real behavioral architecture** — the primary ways the system moves through time and state.

The LLM **must** use:
- The deterministic knowledge graph (modules, edges, entry points, public surfaces, hotspots)
- Its full indexed project understanding from the host environment (Cursor, Claude Code, etc.)
- Targeted source reads for confirmation

to identify and accurately diagram the **most important operational models** of the system.

### 6.1 Primary Operational Models (MANDATORY — 2 to 5 diagrams)

Synthesize the 2–5 most important operational views. These are usually:

- The dominant request / job / user-action lifecycle (end-to-end, with key decision points and error paths)
- The main state machine(s) for stateful components or the overall system
- Critical background / async / batch pipelines
- Startup / initialization / shutdown lifecycle (especially valuable for services and tooling)
- For plugin / meta-tooling / agent platforms: the core execution or dispatch model

Each diagram should be a **stateDiagram-v2**, **sequenceDiagram**, or detailed **flowchart** with:
- Real actor / state / stage names from the codebase
- Labeled transitions with actual function, message, or event names where possible
- alt / opt / loop where branching or repetition exists

Prioritize **accuracy and usefulness for code generation** over visual beauty.

### 6.2 Error & Recovery Paths

For the primary flows above, explicitly call out or include in the diagrams the main error classification, retry, circuit-breaker, fallback, and recovery behaviors.

### 6.3 Cross-Cutting Concerns in Flows

Only if material: authentication/authorization checkpoints, distributed transaction boundaries, observability hooks, etc. inside the operational models.

**For meta-tooling and plugin platforms**: This section must include clear diagrams of the primary internal processes (initialization pipeline, skill/agent dispatch and contract enforcement, generation pipelines, etc.).

---

## 7. Core Modules Deep Dive

> **Source:** graph (primary) + llm-synthesis (secondary)
> **Required:** always
> **Length:** Graph block + one high-signal workflow/state diagram + ≤120 words synthesis per module
> **N/A when:** never
> **Verification:** graph-fence fidelity + diagram correctness + citation-check

**Core rule:** The graph is the source of truth for structure. LLM synthesis exists only to interpret the graph into actionable design understanding (primarily via diagrams).

For each module emitted by `draft/graph/module-graph.jsonl` (and its per-module file records), produce a subsection whose primary content is the deterministic graph block. Every module gets a slot; do not sample.

### 7.{N} {module-name}

<!-- GRAPH:module-deep/{module-name}:START -->
<!-- Rendered deterministic block: path, file count, public API list, fan-in/fan-out, hotspot score,
     primary incoming/outgoing edges with weights, entry points if known. No LLM prose inside fence. -->
<!-- GRAPH:module-deep/{module-name}:END -->

**Role** (≤25 words, derived strictly from graph role + primary source files read).

**Primary Workflow / State** (MANDATORY — one diagram per module)
Synthesize a single, accurate Mermaid diagram (stateDiagram-v2, sequenceDiagram, or flowchart LR/TD with clear stages) that captures the dominant control flow, data transformation pipeline, or lifecycle state machine for this module, grounded in the call graph / entry points / public surface from the graph record. Label transitions with the actual function or message names where possible. This diagram is more important than any prose.

**Public Surface** (from graph `public_api` + verified source). Enumerate only the highest-fan-in or architecturally significant symbols. Format: `symbol (kind) — path:line`. No exhaustive dump of every getter.

**Design Notes** (≤80 words total). Only what the graph + one or two key source reads reveal about invariants, error boundaries, or concurrency that is not already visible in the graph block or the workflow diagram. Cite specific `path:line`.

**Sub-modules / Subsystems**. Recurse only when the graph shows a clear internal boundary (distinct sub-directories with their own public surface or high internal fan-in). Each child follows the identical pattern (graph block + one workflow diagram + minimal notes). Depth is strictly bounded by observable graph structure, never by a desire for "completeness."

**Anti-pattern:** Do not emit long "Responsibilities" paragraphs or exhaustive file lists. If the graph block + workflow diagram already communicate the design, the synthesis may be two sentences. Accuracy and diagram correctness are the success criteria.

---

## 8. Concurrency Model & Thread Safety

> **Source:** llm-synthesis
> **Required:** standard+
> **Length:** ≤400 words
> **N/A when:** single-threaded (no goroutines, threads, async runtime, workers) — write `N/A — reason: single-threaded {language} {entry-point}. No shared mutable state across execution contexts.`
> **Verification:** citation-check

### 8.1 Execution Model

One-sentence statement. E.g., "Go runtime with bounded worker pool sized from `GOMAXPROCS`." Cite the entry-point `path:line`.

### 8.2 Shared State

Enumerate every location of shared mutable state. One row per location. If zero, write `None.`

| Kind | Location `path:line` | Protection | Contention Risk |
|---|---|---|---|
| {mutex / atomic / channel / DB row / cache entry} | | {lock / CAS / transaction / actor ownership} | {low / medium / high — with rationale} |

### 8.3 Locking & Ordering

If multiple locks are acquired, state the global acquisition order. If violating the order causes deadlock, mark the rule as an invariant and cite §15.

### 8.4 Async/Await Surface

Languages with async runtimes (TS, Python asyncio, Rust tokio, Kotlin coroutines): describe the executor, cancellation policy, and any blocking calls. Otherwise omit.

---

## 9. Framework & Extension Points

> **Source:** code-scan
> **Required:** standard+ (when plugin/handler/middleware system exists)
> **Length:** tables, no minimum
> **N/A when:** no plugin, handler, middleware, strategy, or visitor system exists — write `N/A — reason: monolithic; no extension surface.`
> **Verification:** citation-check

### 9.1 Extension Types

| Type | Interface | Registration Site `path:line` | Example Impl `path:line` |
|---|---|---|---|

### 9.2 Registration Mechanism

One sentence: explicit-call / decorator / convention-based-scan / config-driven / DI-container. Cite the mechanism's `path:line`.

### 9.3 Core Interfaces

For each interface in §9.1, show the exact declaration, citing `path:line`. Do not paraphrase. If the declaration exceeds 25 lines, show signature only and link to `path:line`.

```{language}
// path:line — verbatim
```

---

## 10. Full Catalog of Implementations

> **Source:** graph
> **Required:** standard+ (when §9 is populated or operation/handler pattern exists)
> **Length:** rendered
> **N/A when:** §9 is N/A AND no operation/handler directories exist
> **Verification:** graph-fence

### 10.1 By Category

<!-- GRAPH:catalog:START -->
<!-- Rendered from draft/graph/{go,python,ts,c}-index.jsonl (per-language symbol indexes).
     Group implementations by category (handlers, operations, strategies, extractors, etc.).
     One row per implementation. No sampling, no summarization. -->
<!-- GRAPH:catalog:END -->

### 10.2 Per-Directory Operation Lists

For each operation-bearing directory, render a complete list from the graph. One table per directory.

<!-- GRAPH:catalog-per-dir:START -->
<!-- Rendered per-directory enumeration. -->
<!-- GRAPH:catalog-per-dir:END -->

---

## 11. Secondary Subsystem (V2 / Redesign)

> **Source:** user-input
> **Required:** standard+ (when V2/redesign present)
> **Length:** ≤400 words
> **N/A when:** no parallel or next-generation subsystem exists — write `N/A — reason: single subsystem; no parallel V2 or redesign in flight.`
> **Verification:** citation-check

### 11.1 Architecture

One Mermaid flowchart of the redesigned subsystem. Same notation as §5.

### 11.2 Key Differences from V1

| Aspect | V1 / Legacy | V2 / Current |
|---|---|---|

Enumerate only differences that materially affect behavior or operations. Cosmetic differences (renames, reorg) do not belong here.

### 11.3 Coexistence & Migration

State how V1 and V2 coexist (traffic split, feature flag, shadow mode, dual-write) and the cutover criterion. Cite the flag or switch `path:line`.

### 11.4 Framework Details

Key source files and their roles. Enumerate; do not sample.

---

## 12. API & Interface Definitions

> **Source:** code-scan (proto / OpenAPI / GraphQL / route registration)
> **Required:** standard+ (when any external API exists)
> **Length:** rendered
> **N/A when:** project_type == 'library' AND no network-exposed surface — write `N/A — reason: library artifact; public surface documented in §7 Public Surface tables.`
> **Verification:** graph-fence + schema-check

### 12.1 Endpoints

<!-- GRAPH:api-endpoints:START -->
<!-- Rendered from OpenAPI / proto / route-registration parsers.
     Columns: Method, Path, Handler path:line, Auth, Rate Limit, SLO. -->
<!-- GRAPH:api-endpoints:END -->

### 12.2 Proto / Schema Definitions

<!-- GRAPH:api-proto:START -->
<!-- Rendered from draft/graph/proto-index.jsonl. One row per service and message. -->
<!-- GRAPH:api-proto:END -->

### 12.3 Data Models

Table of the top-level request/response/event models the API exposes. Cite declaration `path:line` for each.

| Model | Kind (request / response / event / shared) | Declaration `path:line` | Versioning Rule |
|---|---|---|---|

### 12.4 Definition Files

Enumerate every `.proto`, `openapi.yaml`, `schema.graphql`, or equivalent. Give the file path and its role.

---

## 13. External Dependencies

> **Source:** manifest
> **Required:** always
> **Length:** rendered table
> **N/A when:** never (zero deps → table with one row: "None. Language standard library only.")
> **Verification:** manifest-diff

### 13.1 Runtime Dependencies

<!-- GRAPH:external-deps:kind=runtime:START -->
<!-- Rendered from package manifest(s). Columns: Name, Version, License, Source, Transitive Count, Used-In (top 3 modules). -->
<!-- GRAPH:external-deps:kind=runtime:END -->

### 13.2 Build / Dev Dependencies

<!-- GRAPH:external-deps:kind=dev:START -->
<!-- Rendered for dev/test/build-only deps. -->
<!-- GRAPH:external-deps:kind=dev:END -->

### 13.3 Service Dependencies (network-reachable)

| Service | Protocol | Client Path `path:line` | Criticality | Failure Mode |
|---|---|---|---|---|

Only for systems the runtime reaches over the network (databases, queues, third-party APIs). For libraries or pure CPU workloads: `None.`

---

## 14. Cross-Module Integration Points

> **Source:** graph + llm-synthesis
> **Required:** standard+
> **Length:** ≤300 words per integration
> **N/A when:** single-module system — write `N/A — reason: single-module; no cross-module integration surface.`
> **Verification:** graph-fence + citation-check

For each integration edge of kind `rpc` / `queue` / `shared-db` / `shared-schema` in the graph:

### 14.{N} {Source} ↔ {Target}

- **Contract** — API version, schema revision, response format, latency SLO.
- **Failure Isolation** — circuit breaker, timeout, retry, bulkhead, fallback. Cite `path:line`.
- **Version Coupling** — compatibility window; who upgrades first; flag gating.
- **Integration Tests** — how tested; where the tests live `path:line`.

---

## 15. Critical Invariants & Safety Rules

> **Source:** llm-synthesis
> **Required:** always (may be `None.`)
> **Length:** ≤30 words per invariant; enumerate all that apply; do not pad
> **N/A when:** never — if the codebase has zero invariants, write `None. No data-integrity, concurrency, or security invariants identified.`
> **Verification:** citation-check

No quota. Enumerate every invariant that actually exists. One row per invariant.

| # | Invariant | Category | Where Enforced `path:line` | Enforcement Mechanism | Violation Consequence |
|---|---|---|---|---|---|
| 1 | {precise statement} | {data / concurrency / security / resource / ordering} | `{path:line}` | {type-system / runtime-assert / test / code-review / none} | {what breaks if violated} |

**Mission-critical rule.** Any invariant in categories `data` or `security` with `Enforcement Mechanism == none` MUST be flagged for review. List such invariants at the end of the table with `⚠ unenforced` prefix.

---

## 16. Security Architecture

> **Source:** llm-synthesis + user-input
> **Required:** high+
> **Length:** ≤500 words
> **N/A when:** criticality == low AND no authentication, authorization, crypto, PII, or network ingress — write `N/A — reason: criticality=low; no auth, crypto, PII, or external ingress.`
> **Verification:** citation-check

### 16.1 Threat Model Scope

Name the threat model's in-scope and out-of-scope items. Cite the threat-model doc if one exists; if not, state `No formal threat model on file.` and list the top three assumed threats.

### 16.2 Authentication & Authorization

Mechanism(s) in use. Cite the primary auth middleware or guard `path:line`. State the authorization model (RBAC / ABAC / ACL / capability / none).

### 16.3 Crypto Primitives

| Purpose | Library + Version | Algorithm | Key Source | `path:line` |
|---|---|---|---|---|

Mark `None.` if no crypto in use.

### 16.4 Secret Handling

How secrets are loaded (env / vault / KMS / file). Where rotation is triggered. Cite config loader `path:line`.

### 16.5 Known CVE Mitigations (mission-critical only)

Only if any dependency's CVE required explicit mitigation. Otherwise omit the subsection.

---

## 17. Observability & Telemetry

> **Source:** code-scan + llm-synthesis
> **Required:** high+
> **Length:** ≤400 words
> **N/A when:** criticality == low OR project_type == 'library' — write `N/A — reason: {...}`.
> **Verification:** citation-check + graph-fence (metrics)

### 17.1 Golden Signals

| Signal | Metric Name | Dashboard URL | Alert URL |
|---|---|---|---|
| Latency | | | |
| Traffic | | | |
| Errors | | | |
| Saturation | | | |

### 17.2 Logging

Log library + version. Log level policy. Structured vs free-form. PII redaction policy. Cite `path:line` for the logger init.

### 17.3 Tracing

Tracing library (OpenTelemetry / Zipkin / X-Ray / none). Trace context propagation points. Sampling policy.

### 17.4 Alert Runbook

Link to runbook(s). Mission-critical requires at least one runbook URL or inline entry.

### 17.5 Log Retention

Retention period. Where logs are stored. Who has read access.

---

## 18. Error Handling & Failure Modes

> **Source:** llm-synthesis
> **Required:** standard+
> **Length:** ≤400 words
> **N/A when:** project_type == 'library' AND errors are returned unchanged to the caller — write `N/A — reason: pure library; errors propagate verbatim to caller.`
> **Verification:** citation-check

### 18.1 Error Taxonomy

| Error Class | Source | Retry Policy | User-Visible? | `path:line` |
|---|---|---|---|---|

Enumerate classes that actually exist. Do not invent categories.

### 18.2 Failure Modes Beyond Errors

| Mode | Trigger | Detection | Recovery |
|---|---|---|---|
| {timeout / partial write / data loss / deadlock / corruption / OOM / thundering herd} | | | |

Only rows for modes the codebase or deployment actually exhibits. Omit if none.

### 18.3 Graceful Degradation

If any component has fallback behavior, describe it here with `path:line`. Otherwise write `None — all failures surface as errors to caller.`

---

## 19. State Management & Persistence

> **Source:** code-scan + user-input
> **Required:** standard+ (when persistence exists); mission-critical sections below are `high+`
> **Length:** ≤400 words + SLO table for mission-critical
> **N/A when:** stateless — write `N/A — reason: stateless; all state is request-scoped.`
> **Verification:** citation-check

### 19.1 State Stores

| Store | Kind (SQL / KV / blob / cache / queue / filesystem) | Library `path:line` | Durability |
|---|---|---|---|

### 19.2 Schema & Migrations

Migration tool name + version. Migration directory path. Cite the migration runner `path:line`. State forward/backward compatibility policy.

### 19.3 Durability, RPO, RTO (mission-critical only)

| Store | Durability Model | RPO | RTO | Backup Cadence | Restore Drill Cadence |
|---|---|---|---|---|---|

Mission-critical requires every row populated. Unknown values → mark `⚠ undefined` and raise as §27 debt.

### 19.4 Caching

Layers, invalidation policy, TTLs. Cite `path:line` for each cache.

---

## 20. Reusable Modules for Future Projects

> **Source:** llm-synthesis + graph
> **Required:** standard+
> **Length:** tables
> **N/A when:** project_type == 'cli' AND fewer than 3 modules — write `N/A — reason: monolithic CLI; no modules separable for reuse.`
> **Verification:** graph-fence

Tiered by how much of the module's surface is reusable outside this project.

### 20.1 Highly Reusable (Framework-Level)

<!-- GRAPH:reusable:tier=framework:START -->
<!-- Rendered: modules with low external coupling + documented public API. -->
<!-- GRAPH:reusable:tier=framework:END -->

| Module | Path | What makes it reusable |
|---|---|---|

### 20.2 Moderately Reusable (Pattern-Level)

| Module | Path | Extraction cost |
|---|---|---|

### 20.3 Pattern Templates (Design-Level)

| Pattern | Where Used `path:line` | When to copy |
|---|---|---|

---

## 21. Key Design Patterns

> **Source:** llm-synthesis
> **Required:** standard+
> **Length:** ≤150 words per pattern + one verified code reference
> **N/A when:** no non-trivial patterns identified — write `None. Codebase follows straight-line procedural design.`
> **Verification:** citation-check

For each pattern that materially shapes the codebase:

### 21.{N} {Pattern name}

- **Intent** — one sentence.
- **Where used** — list occurrences with `path:line`. At least one citation must verify.
- **Why chosen** — one sentence referencing observable constraint (not aesthetic).
- **Reference snippet** — ≤15 lines, verbatim from `path:line`.

Do not enumerate every GoF pattern. Only patterns that recur or are load-bearing.

---

## 22. Configuration & Tuning

> **Source:** code-scan
> **Required:** always
> **Length:** rendered
> **N/A when:** never (zero config → `None. No runtime configuration surface.`)
> **Verification:** graph-fence + citation-check

### 22.1 Configuration Surface

<!-- GRAPH:config:START -->
<!-- Rendered from config parsers: env vars, CLI flags, YAML keys.
     Columns: Key, Type, Default, Where Read path:line, Valid Range / Enum. -->
<!-- GRAPH:config:END -->

### 22.2 Tuning Guidance

Only for knobs with non-obvious tradeoffs. One row per knob. Omit if none.

| Knob | Default | Raise when | Lower when | Risk of wrong value |
|---|---|---|---|---|

---

## 23. Performance Characteristics & Hot Paths

> **Source:** graph (hotspots) + llm-synthesis
> **Required:** standard+
> **Length:** ≤200 words per hot path
> **N/A when:** project_type == 'library' AND no measured performance constraint — write `N/A — reason: library; performance characterization is caller-dependent.`
> **Verification:** graph-fence

### 23.1 Hotspots (graph-derived)

<!-- GRAPH:hotspots:START -->
<!-- Rendered from draft/graph/hotspots.jsonl. Columns: Path, Fan-In, Fan-Out, Change-Frequency, Hotspot Score. -->
<!-- GRAPH:hotspots:END -->

### 23.2 Critical Hot Paths

For each hot path that matters operationally:

#### 23.2.{N} {Path name}

- **Trace** — entry-point `path:line` → terminal `path:line`.
- **Observed characteristic** — measured latency / throughput / memory. Cite the measurement source (benchmark file, load test, production metric URL). If unmeasured, write `⚠ unmeasured` and log a §27 debt item.
- **Known optimizations** — what has already been done.
- **Known risks** — what would slow this path.

**Mission-critical rule.** Every hot path must have a measured baseline. `⚠ unmeasured` on a mission-critical system is a release blocker.

### 23.3 Measured Baselines (mission-critical only)

| Hot Path | p50 | p95 | p99 | Measured At (commit + date) | Source |
|---|---|---|---|---|---|

---

## 24. How to Extend — Step-by-Step Cookbooks

> **Source:** llm-synthesis
> **Required:** standard+ (when §9 or §10 populated)
> **Length:** ≤400 words per cookbook
> **N/A when:** §9 is N/A — write `N/A — reason: no extension surface (see §9).`
> **Verification:** citation-check

One cookbook per extension type in §9.1. Each cookbook is an ordered step list. Every step cites `path:line` or a command. Test every step as you write by resolving citations.

### 24.{N} How to add a new {extension type}

1. ...
2. ...
3. Register at `path:line`.
4. Test with `{command}`.

No invented extension types. If a pattern is theoretically supported but has never been exercised, say so explicitly.

---

## 25. Build System & Development Workflow

> **Source:** manifest + code-scan
> **Required:** always
> **Length:** rendered
> **N/A when:** never
> **Verification:** graph-fence + manifest-diff

### 25.1 Build Tooling

| Tool | Version | Config File | Notes |
|---|---|---|---|

### 25.2 Key Build Targets

<!-- GRAPH:build-targets:START -->
<!-- Rendered from Makefile / BUILD / package.json scripts / pyproject scripts. -->
<!-- GRAPH:build-targets:END -->

### 25.3 Developer Setup

Ordered command list, starting from a fresh clone. Every command must run to completion on a supported OS/arch. Cite the OS/arch matrix.

### 25.4 CI Pipeline

| Stage | Tool | Config `path:line` | Required for merge? |
|---|---|---|---|

---

## 26. Testing Infrastructure

> **Source:** code-scan
> **Required:** always
> **Length:** rendered table + ≤200 words
> **N/A when:** never (zero tests → `None. No automated tests present.` + flag as §27 debt item)
> **Verification:** citation-check

### 26.1 Test Suites

| Suite | Location | Command | Kind (unit / integration / e2e / property / fuzz / load) | Coverage |
|---|---|---|---|---|

### 26.2 Test Data & Fixtures

Where fixtures live. How they are generated or maintained. Cite `path:line`.

### 26.3 Flaky Test Policy

If flaky tests exist and have a known handling policy (quarantine, retry, skip-with-ticket), describe it. Otherwise omit.

---

## 27. Known Technical Debt & Limitations

> **Source:** user-input (debt items must be acknowledged, not inferred)
> **Required:** always (may be `None.`)
> **Length:** ≤30 words per item
> **N/A when:** never — zero debt → `None. No known debt items at synced_to_commit.`
> **Verification:** citation-check

No quota. Enumerate every real item. One row per item.

| # | Item | Severity | Blast Radius | Owner | ETA | `path:line` or ticket |
|---|---|---|---|---|---|---|
| 1 | {statement} | {low / medium / high / critical} | {module / subsystem / org} | {team-or-person} | {date or "backlog"} | `{path:line}` or `JIRA-1234` |

**Mission-critical rule.** Every high/critical row must have Owner and ETA populated.

---

## 28. Glossary

> **Source:** user-input + code-scan
> **Required:** always
> **Length:** table
> **N/A when:** never (zero jargon → `None. Codebase uses standard terminology only.`)
> **Verification:** none

| Term | Definition | First Appears `path:line` or §ref |
|---|---|---|

Only terms that are non-standard in the broader industry OR carry project-specific meaning. Do not define standard terms ("mutex", "HTTP").

---

## 29. Graph Coverage Gaps & Known Limitations (MANDATORY)

> **Source:** graph + llm-synthesis + Context Audit
> **Required:** always (non-skippable)
> **Length:** substantive (≥150 words or explicit "Full coverage" + justification)
> **Verification:** must enumerate real shortfalls from this run's graph build and audit; cross-reference the frontmatter `graph:` block and Dashboard table

**Purpose**: Tell future AI agents exactly where this document (and the underlying graph) has weak or absent coverage so they calibrate trust and know where to read source or defer to other authoritative material.

**Mandatory content**:
- Per-language and per-major-area fidelity summary (copy/adapt from frontmatter Dashboard + notes).
- Specific modules/flows where graph provided only directory stubs (0 edges, 0 symbols) and synthesis relied on host index + targeted reads.
- Any areas where high-quality existing docs (from Pre-Check Context Audit) were treated as ground truth with cross-references instead of re-documenting.
- Explicit remaining risk statement: "Future agents should re-verify [specific claims] against source before acting in these areas."

Example (low-graph Python-heavy mature project):
> Python modules: stub (directory-level only, 0 edges, 0 symbols in graph). Host index + 18 targeted source reads used for workflows and invariants. See §30 for deference to CLAUDE.md (agent protocols) and docs/INVARIANTS.md (verified rules). Gaps: dynamic lock ordering, runtime state machines, and cross-language FFI boundaries only partially visible in static graph.

This section is high-value for safety-critical and low-fidelity-graph codebases.

---

## 30. Relationship to Existing Authoritative Documentation (MANDATORY when Context Audit = high/medium)

> **Source:** Context Audit + user-input + llm-synthesis
> **Required:** non-skippable when high/medium context detected in Pre-Check; otherwise include with "None detected" note
> **Length:** table or clear bullets with cross-references
> **Verification:** must name the exact files from the audit, state what this document adds vs. defers, and confirm absence of large prose duplication

**Purpose**: Prevent drift and duplication. Explicitly position this graph-primary architecture.md relative to any pre-existing high-signal agent-optimized sources.

**Mandatory content** (when audit high):
- List of detected files with one-line signal (e.g. "CLAUDE.md — 10k+ lines, purpose-built so future AI agents do not re-read source").
- What this architecture.md supplies: the deterministic graph-derived structural spine (modules, dependencies, public surfaces, hotspots), visual diagrams (Mermaid workflows/state), and synthesis for dynamic behavior or low-graph areas.
- What it defers to (with concrete refs): "Defers to CLAUDE.md §X for agent behavioral specifications and docs/INVARIANTS.md:INV-042 for machine-verified system rules (test-backed)."
- Confirmation: "No large-scale prose duplication of existing authoritative material occurred. This document is an overlay and navigation aid, not a replacement."

If no high context detected:
> No high-quality agent-optimized documentation (CLAUDE.md / INVARIANTS.md / ADRs) detected beyond standard project README and inline comments. This architecture.md is the primary self-contained engineering reference.

Cross-references in this section must be resolvable (file paths or § numbers that exist).

---

## Appendix A: File Structure Summary

> **Source:** code-scan
> **Required:** always
> **Length:** rendered tree
> **N/A when:** never
> **Verification:** graph-fence

<!-- GRAPH:file-tree:START -->
<!-- Rendered from filesystem walk at synced_to_commit.
     Depth and exclusions configurable in draft/graph/config.json. -->
<!-- GRAPH:file-tree:END -->

---

## Appendix B: Data Source → Implementation Mapping

> **Source:** graph
> **Required:** standard+
> **Length:** rendered
> **N/A when:** §13.3 is `None.` AND no local data stores — write `N/A — reason: no data sources.`
> **Verification:** graph-fence

<!-- GRAPH:source-sink:direction=source:START -->
<!-- Rendered: rows = external source, cols = modules that read it, cells = call path:line. -->
<!-- GRAPH:source-sink:direction=source:END -->

---

## Appendix C: Output Flow — Implementation to Target

> **Source:** graph
> **Required:** standard+
> **Length:** rendered
> **N/A when:** no external write surface — write `N/A — reason: no outputs beyond process return value.`
> **Verification:** graph-fence

<!-- GRAPH:source-sink:direction=sink:START -->
<!-- Rendered: rows = module, cols = external target, cells = call path:line. -->
<!-- GRAPH:source-sink:direction=sink:END -->

---

## Appendix D: Mermaid Sequence Diagrams — Critical Flows

> **Source:** llm-synthesis
> **Required:** high+
> **Length:** 1–N diagrams, no minimum, no maximum
> **N/A when:** criticality < high AND no flow crosses more than two modules — write `N/A — reason: {...}`.
> **Verification:** citation-check (every participant must map to a §5 component)

Diagrams for flows that are operationally critical and NOT already covered by §6. Each diagram must:

- name every participant with the exact component name from §5;
- label every arrow with the call/message kind;
- cite the entry-point and terminal `path:line` below the diagram.

Do not duplicate §6 diagrams. If §6 already covers the flow, skip it here.

---

## Appendix E: Proto Service Map (graph-derived)

> **Source:** graph
> **Required:** standard+ (when proto definitions exist)
> **Length:** rendered
> **N/A when:** no `.proto` files in repository — write `N/A — reason: no gRPC/proto definitions present.`
> **Verification:** graph-fence

<!-- GRAPH:proto-map:START -->
<!-- Rendered from draft/graph/proto-index.jsonl. Services × methods × request/response types. -->
<!-- GRAPH:proto-map:END -->

---

End of document. Completion verification is owned by `skills/init/SKILL.md` §Completion Verification. For AI-optimized context, see `draft/.ai-context.md`.
