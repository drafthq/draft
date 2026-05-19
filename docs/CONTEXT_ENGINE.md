# Draft Context Engine

## Status

Design proposal for scaling Draft to very large brownfield repositories (10M+ LOC, monorepos, multi-language estates) without losing context fidelity or blowing prompt budgets.

---

## Summary

Draft's current artifact model is correct:

- Filesystem-backed project context (`draft/.ai-context.md`, `draft/.ai-profile.md`)
- State snapshots (`draft/.state/*.json`)
- Structural graph artifacts (`draft/graph/*.jsonl`)

That model should remain the canonical source of truth.

What changes at large-repo scale is the serving layer. For 20-30 million line repositories, Draft should stop treating those artifacts as files to be repeatedly opened and scanned by skills. Instead, Draft should introduce a long-lived **Context Engine**:

- Canonical artifacts remain on disk
- A Rust runtime ingests them into memory-resident typed indexes
- Skills query the engine for bounded, task-shaped context packs
- Incremental invalidation keeps indexes fresh as the repo changes
- Token efficiency becomes a first-class contract, not an afterthought

The engine is not a RAM mirror of the repository. It is a query and packing runtime optimized for:

- low-latency retrieval
- high-fidelity repo understanding
- bounded prompt construction
- incremental refresh at monorepo scale

---

## Problem

Draft works well today because it reduces raw repository complexity into structured artifacts. At very large scale, new bottlenecks appear:

1. Graph and state artifacts become large enough that repeated file reads and reparsing create latency.
2. Skills pay repeated lookup costs for common operations:
   - file-to-module resolution
   - caller and impact traversal
   - fact lookup by file or concern
   - recent-track overlap
   - invariant discovery
3. Prompt budgets become a harder constraint than storage:
   - large repos have too many relevant-looking neighbors
   - broad architecture context drowns task-local context
   - duplicated graph, fact, summary, and source snippets waste tokens
4. Incremental refresh becomes mandatory:
   - full regeneration is too expensive
   - broad rescans increase drift and response time

The core scaling problem is therefore:

> How does Draft preserve precise repo context for very large codebases while keeping both retrieval latency and prompt size bounded?

---

## Goals

1. Preserve Draft's current artifact model and deterministic behavior.
2. Make common context queries effectively constant-time or close to it.
3. Support very large, multi-language, brownfield repositories.
4. Generate the smallest correct context pack for a task.
5. Keep source-of-truth explainable and inspectable on disk.
6. Support incremental invalidation and partial rebuilds.
7. Degrade gracefully when the engine is unavailable.

## Non-Goals

1. Replacing `draft/` files with an opaque database.
2. Mirroring the entire repository into a RAM filesystem.
3. Sending raw graph/state artifacts directly to the model.
4. Making LLM-generated summaries the canonical truth of the repo.
5. Introducing a distributed service in the first iteration.

---

## Design Principles

### 1. Disk Is Canonical, Memory Serves

Draft artifacts remain durable, portable, debuggable, and versionable on disk. Memory exists to accelerate retrieval and packing, not to replace the file model.

### 2. Store Rich, Send Sparse

The engine may maintain deep indexes and multiple summary resolutions internally. The model should receive only the minimal task-relevant projection.

### 3. Query by Intent, Not by File Scan

Skills should stop thinking in terms of "open these 12 files and grep for clues." They should ask typed questions:

- what modules are relevant?
- what invariants apply?
- what prior tracks overlap?
- what code path is on the critical path?
- what is the smallest sufficient context pack?

### 4. Incremental by Default

At monorepo scale, recomputation should be partitioned by file, module, fact, and track dependency.

### 5. Stable Summaries Beat Regenerated Prose

Repeated freeform summarization increases drift and wastes tokens. Draft should prefer stable, canonical, incrementally refreshed summaries.

---

## Proposed Architecture

```text
┌──────────────────────────────────────────────────────────────────┐
│                        Source Repository                         │
│                    20M-30M LOC brownfield repo                  │
└──────────────────────────────┬───────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│                       Draft Artifact Pipeline                    │
│  /draft:init, /draft:index, graph build, condensation, state    │
│  Outputs: draft/.ai-context.md, draft/.state/*, draft/graph/*   │
└──────────────────────────────┬───────────────────────────────────┘
                               │ canonical artifacts
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│                     Rust Context Engine Runtime                  │
│                                                                  │
│  Loaders          Indexes           Invalidation   Packers        │
│  - graph          - module map      - file watch   - review       │
│  - facts          - reverse deps    - hash delta   - implement    │
│  - tracks         - symbol map      - shard dirt   - debug        │
│  - summaries      - fact index      - partial      - bughunt      │
│                   - track overlap      recompute    - custom       │
│                   - invariant map                                  │
└──────────────────────────────┬───────────────────────────────────┘
                               │ local IPC / CLI
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│                           Draft Skills                           │
│    /draft:review /draft:implement /draft:bughunt /draft:debug    │
│      request bounded context packs and focused query results      │
└──────────────────────────────────────────────────────────────────┘
```

---

## Core Components

## 1. Artifact Loaders

The engine ingests existing Draft artifacts rather than replacing their generation pipeline.

### Inputs

- `draft/.ai-profile.md`
- `draft/.ai-context.md`
- `draft/.state/facts.json`
- `draft/.state/freshness.json`
- `draft/.state/signals.json`
- `draft/.state/run-memory.json`
- `draft/tracks/**`
- `draft/graph/schema.yaml`
- `draft/graph/*.jsonl`

### Loader Responsibilities

1. Parse canonical artifacts into typed records.
2. Normalize paths, module names, symbols, and fact categories.
3. Intern repeated strings to reduce memory pressure.
4. Build reverse lookup tables during load.
5. Detect artifact version mismatch and schema drift.

---

## 2. In-Memory Indexes

The first implementation should prioritize the indexes that directly reduce prompt bloat and query latency.

### Required Indexes

#### File Index

Maps:

- file -> module
- file -> language
- file -> fact ids
- file -> touched tracks
- file -> hotspot score
- file -> freshness hash

#### Module Index

Maps:

- module -> files
- module -> inbound dependencies
- module -> outbound dependencies
- module -> invariants
- module -> summary variants
- module -> risk profile

#### Symbol Index

Maps:

- symbol -> file(s)
- symbol -> module(s)
- symbol -> caller edges
- symbol -> callee edges

#### Fact Index

Maps:

- fact id -> source files
- fact id -> categories
- fact id -> recency/confidence metadata
- file/module/concern -> relevant facts

#### Track Index

Maps:

- track -> files
- track -> modules
- track -> impact snapshot
- file/module -> recent overlapping tracks

#### Invariant Index

Maps:

- invariant -> owning modules
- invariant -> affected files
- invariant -> severity
- concern -> applicable invariants

### Useful Later Indexes

- ownership index
- test coverage adjacency
- config surface index
- deployment risk index
- ADR decision index

---

## 3. Incremental Sync and Invalidation

The engine should not rely on full reloads except on cold start, corruption recovery, or schema upgrade.

### Sync Sources

1. File watcher events for source repo changes.
2. Draft artifact updates after `init`, `refresh`, `index`, `learn`, track mutations.
3. Explicit invalidation commands from Draft skills.

### Invalidation Strategy

Invalidate by the smallest possible unit:

- file shard
- module shard
- fact shard
- track shard
- summary shard

### Refresh Flow

1. Detect source or artifact changes.
2. Identify affected files/modules/facts/tracks.
3. Re-run only the required Draft artifact producers.
4. Reload only affected engine shards.
5. Recompute dependent summaries and rankings.
6. Mark pack cache entries that are now stale.

### Why This Matters

Prompt efficiency depends on freshness. A stale summary that points to the wrong module is worse than no summary.

---

## 4. Context Packer

This is the most important new subsystem.

The engine should not merely retrieve records. It should produce **task-shaped context packs** under a fixed token budget.

### Contract

Given:

- task type
- task description
- mentioned files/modules/symbols/concepts
- optional track scope
- optional changed files
- token budget

Produce:

- a ranked, deduplicated, bounded context pack
- with explicit sections and provenance
- preserving the most important source-grounded context first

### Supported Task Types

- `review`
- `implement`
- `debug`
- `bughunt`
- `decompose`
- `architecture`
- `refresh`
- `coverage`
- `adr`

### Context Pack Structure

#### Layer 0: Task Contract

- user intent
- task type
- active track
- hard budget
- packing rationale

#### Layer 1: Global Minimum Context

- `.ai-profile.md` projection
- global critical invariants
- hard guardrails relevant to the task

#### Layer 2: Task-Local Structural Context

- relevant modules
- relevant facts
- graph paths
- overlapping tracks
- local risk markers

#### Layer 3: Evidence Excerpts

- narrow source excerpts
- exact interface contracts
- exact config fragments
- exact validation failures

Layer 3 is the most expensive and should be added last.

---

## Token Efficiency Strategy

## 1. Multi-Resolution Summaries

Every major object should support more than one representation.

### Module Summary Levels

#### Level A: One-Line Card

- module name
- purpose
- key dependencies
- primary risk

#### Level B: Compact Card

- Level A
- owned files/classes/services
- invariants
- key interfaces
- hotspot flag

#### Level C: Extended Module Brief

- Level B
- dependency edges
- extension points
- failure modes
- recent track overlap

The packer should choose the cheapest sufficient level for the current task.

## 2. Relevance Scoring

Every candidate context unit should receive a score.

### Candidate Types

- profile section
- invariant
- module summary
- fact
- track summary
- graph path
- source excerpt
- validation result

### Suggested Scoring Signals

- direct file overlap
- direct symbol overlap
- same module
- graph distance from touched file
- invariant severity
- hotspot score
- recent track overlap
- fact recency
- fact confidence
- user-mentioned concept match
- task-type affinity

### Suggested Penalties

- duplicate information
- stale artifact confidence
- low-specificity prose
- large token footprint
- weak provenance

### Example Rank Intuition

For a `review` task on `payments/refund.go`:

- invariants tied to refund ordering should outrank broad repo architecture
- impacted tests should outrank unrelated module summaries
- compact cards for neighboring modules should outrank full architecture prose

## 3. Deduplication

The same concept may appear in:

- `.ai-context.md`
- `facts.json`
- graph summaries
- track docs
- source excerpts

The packer should keep the highest-signal shortest representation unless exact source evidence is required.

### Preferred Retention Order

1. exact source excerpt when behavior must be proven
2. invariant or fact with exact provenance
3. compact module summary
4. broad narrative summary

## 4. Budgeted Packing

Context assembly should be budget-first, not best-effort.

### Example Budget Policy

For a pack budget of `N` tokens:

- 5-10% task contract and packing metadata
- 10-15% global profile and critical invariants
- 35-45% local modules, facts, graph paths
- 20-30% source excerpts and validation evidence
- 10-20% track spec/plan or runtime outputs

The exact policy should vary by task type.

### Review Bias

Review packs should emphasize:

- changed files
- local invariants
- impacted callers/dependents
- tests
- validation failures

### Implementation Bias

Implementation packs should emphasize:

- track spec
- plan
- touched module briefs
- accepted patterns
- exact interfaces

### Debug Bias

Debug packs should emphasize:

- failing path
- caller chain
- state transitions
- invariants
- recent regressions

---

## Query API

The engine should expose typed queries, not just "give me file contents."

### Core Queries

- `resolve-file <path>`
- `resolve-symbol <symbol>`
- `module-brief <module> [--level A|B|C]`
- `impact <path>`
- `callers <symbol-or-file>`
- `facts-for-files <file...>`
- `facts-for-concern <concern>`
- `invariants-for-files <file...>`
- `related-tracks <file-or-module>`
- `context-pack --task <type> ...`

### Example

```bash
draft-engine context-pack \
  --task review \
  --files services/refund/refund.go tests/refund_test.go \
  --track 042-refund-ordering \
  --budget 12000
```

### Response Properties

Every response should include:

- machine-readable payload
- token estimate
- provenance
- staleness status
- pack rationale

---

## Suggested Internal Data Model

The exact storage engine can vary, but the in-memory model should be explicit.

### Core Entities

- `FileRecord`
- `ModuleRecord`
- `SymbolRecord`
- `FactRecord`
- `InvariantRecord`
- `TrackRecord`
- `SummaryRecord`
- `PackRecord`

### Important Relationships

- file belongs to module
- file references symbols
- file is touched by tracks
- module depends on module
- fact references files/modules/concerns
- invariant applies to files/modules/concerns
- summary belongs to object at a defined resolution

### Implementation Notes

Good candidates for the first version:

- `mmap` for large immutable segments
- string interning for paths and symbols
- roaring bitmaps for membership sets
- shard-local caches
- append-only change log for invalidation events

Storage engine options:

- pure in-memory plus on-disk Draft artifacts
- LMDB
- SQLite with memory cache
- RocksDB for large persistent indexes

The first version should prefer operational simplicity over maximal theoretical performance.

---

## Changes to Draft Skill Workflow

Skills should move from file-centric context loading to engine-backed packing.

## Current Pattern

1. Load layered context files
2. Query graph artifacts
3. Read source files
4. Manually assemble context in prompt

## Proposed Pattern

1. Ask engine for bounded context pack
2. Inspect returned rationale and provenance
3. Read exact source files only for final grounding where needed
4. Execute task

This keeps the graph-as-index discipline while reducing repetitive prompt assembly logic across skills.

### Impact on Existing Shared Docs

#### `core/shared/draft-context-loading.md`

Should evolve to specify:

- engine-first packing when engine is available
- existing layered file fallback when unavailable
- hard rule that source reads remain mandatory before behavioral claims

#### `core/shared/graph-query.md`

Should evolve to specify:

- query engine as the preferred lookup front-end
- graph artifacts as canonical underlying evidence
- source validation remains mandatory

---

## Rollout Plan

## Phase 1: Sidecar Read Path

Build a local Rust sidecar that:

- loads existing Draft artifacts
- exposes read-only typed queries
- serves context packs for a small set of tasks
- does not change artifact generation

Success criteria:

- materially lower latency for `review`, `implement`, `bughunt`
- smaller prompts with no regression in review quality

## Phase 2: Incremental Invalidations

Add:

- file watching
- shard invalidation
- partial reloads
- pack cache invalidation

Success criteria:

- refresh operations avoid full reload
- packs remain fresh during active repo churn

## Phase 3: Stable Summary Store

Add:

- multi-resolution summary generation
- summary versioning
- summary refresh only on relevant source change

Success criteria:

- prompt size drops further
- summary drift reduces

## Phase 4: Skill Integration

Update high-value skills:

- `/draft:review`
- `/draft:implement`
- `/draft:bughunt`
- `/draft:debug`
- `/draft:deep-review`

Success criteria:

- skills request typed packs instead of reimplementing retrieval logic

## Phase 5: Optional Persistent Index Backend

If cold start or memory pressure is still too high, add:

- persistent local index store
- memory-mapped segments
- boot-time fast restore

---

## Risks

## 1. Serving Stale Context

Fast wrong context is worse than slow right context.

Mitigation:

- strict invalidation
- artifact version checks
- staleness flags in every pack
- source-grounding discipline remains mandatory

## 2. Summary Drift

Summaries can become detached from the code.

Mitigation:

- summaries derived from canonical artifacts
- refresh on source shard change
- exact source excerpts for behavior-critical claims

## 3. Over-Compression

Token efficiency can hide critical detail.

Mitigation:

- task-specific minimum floors
- evidence slots protected from eviction
- per-task packing policy

## 4. Operational Complexity

A daemon, indexes, watchers, and invalidation add complexity.

Mitigation:

- phase rollout
- read-only first
- fallback to current file-based behavior

## 5. Memory Footprint

Large monorepos can create large indexes.

Mitigation:

- shard loading
- memory-mapped segments
- interned strings
- compact bitset representations

---

## Open Questions

1. Should the first engine be a long-lived daemon or a fast CLI with warm cache files?
2. Which tasks benefit most from engine-backed packing in the first release?
3. What is the right summary refresh trigger: source file hash change, module change, or fact change?
4. Should track overlap and test adjacency be promoted to first-class indexes in v1?
5. Should token budgeting be model-specific or normalized around rough token classes?
6. Do we keep JSONL as the canonical graph artifact long-term, or introduce a denser serving format while preserving JSONL for inspection?

---

## Recommendation

Draft should adopt a **Context Engine** for very large brownfield repositories.

The design should be:

- disk-backed canonical Draft artifacts
- Rust in-memory query runtime
- typed indexes for graph, facts, invariants, and tracks
- budgeted task-specific context packing
- incremental invalidation and stable summaries

Draft should not adopt:

- a RAM filesystem mirror as the primary architecture
- freeform broad-context prompt assembly
- raw artifact scans as the main retrieval path at monorepo scale

The major product insight is:

> At brownfield monorepo scale, Draft does not need more memory artifacts. It needs a repo-aware context serving engine with token discipline.

---

## Appendix: Example `review` Context Pack

```text
TASK
- review
- track: 042-refund-ordering
- changed files: refund.go, refund_test.go
- budget: 12000

GLOBAL
- API style: gRPC
- critical invariant: refund events must remain idempotent per request id
- hard guardrail: no direct DB writes from handlers

LOCAL MODULES
- payments/refunds [Level B]
- payments/ledger [Level A]
- shared/idempotency [Level B]

RELEVANT FACTS
- refund state derived from ledger event sequence
- duplicate request ids are deduplicated before persistence
- refund tests assert ordering after replay

GRAPH
- callers of RefundService.ProcessRefund
- impact set for refund.go

TRACK MEMORY
- recent overlap with track 037-ledger-replay-fix

EVIDENCE
- interface excerpt for RefundRepository
- failing test snippet
- exact invariant excerpt from source/config
```

This is the target user-facing outcome: precise, bounded, source-grounded context without loading broad repo prose by default.
