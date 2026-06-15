# Chapter 18: Monorepo Federation

Part VI: Enterprise· Chapter 18

4 min read

Draft has no separate index command. Monorepo support is built directly into `/draft:init`, which is scope-aware and root-first. Run it at the repo root to build the whole-repo knowledge graph; run it inside a sub-module and it resolves the repo root automatically, builds that module's snapshot, and writes `draft/graph/root-link.json` pointing up to the root graph — so every module has full cross-module understanding without an extra step. Federation is the root-link mechanism, not a separate command.

## The Monorepo Context Problem

A monorepo with twelve services raises a cross-module question that per-service context cannot answer: what happens when the auth service changes? Which services share PostgreSQL? Which team owns the notification API? Per-service `/draft:init` runs produce excellent local context — detailed `.ai-context.md` files for each service — but answering cross-service questions requires connecting those views.

Draft solves this through the root-link mechanism built into `/draft:init`. There is no separate aggregation step. Running `/draft:init` anywhere in the monorepo is enough.

## How Scope-Aware Init Works

`/draft:init` is root-first. When invoked at the repo root, it builds the whole-repo knowledge graph in `draft/graph/`. When invoked inside a sub-module (for example, `services/billing/`), it:

1. **Resolves the repo root** — walks ancestor directories looking for an existing `draft/` directory, then falls back to `git rev-parse --show-toplevel`, then falls back to cwd.
2. **Builds the module snapshot** — runs full analysis for the sub-module and writes its graph under the module's own `draft/graph/`.
3. **Writes `draft/graph/root-link.json`** — a pointer from the module's graph to the root graph. This file tells any Draft command running inside the module where the whole-repo graph lives.

The result: a Draft command running inside `services/billing/` can answer cross-module questions by following the root link to the root graph, without re-running any analysis at the root level.

## The root-link.json File

`draft/graph/root-link.json` is a small JSON file written by `/draft:init` when it detects it is running inside a sub-module. It contains the absolute path to the root `draft/graph/` directory and metadata about when the link was established. Commands that need cross-module context read this file and query the root graph directly.

If no root graph exists yet, the root link points to a pending state and falls back gracefully to module-local context. Running `/draft:init` at the repo root later fills the gap — no re-initialization of sub-modules required.

## The Committed Graph: Only schema.yaml

The knowledge graph itself is engine-only. The `codebase-memory-mcp` engine (by DeusData, 159 languages, 100% local) maintains the structural graph in-process. No `architecture.json`, `hotspots.jsonl`, or `*.mermaid` files are committed to the repository.

The only committed file in `draft/graph/` is `schema.yaml` — a gate marker containing engine metadata, project identity, and point-of-index counts. Its `access: engine-live` field signals that structural data is queried live from the engine, not read from committed files.

## Flags

`/draft:init` supports two flags relevant to monorepo workflows:

* `--module-only` — Analyzes only the current sub-module; skips root-level synthesis. Use when you want to refresh a single service without touching the root graph.
* `--graph-only` — Builds or refreshes the graph without regenerating prose context files (architecture.md, .ai-context.md, etc.). Use for fast graph updates after code changes.

## The Workflow

A typical monorepo onboarding sequence:

1. Run `/draft:init` at the repo root — builds the whole-repo graph and generates root-level context files.
2. Run `/draft:init` inside each sub-module that needs its own spec/plan context — each one generates module-local context and writes a `draft/graph/root-link.json` pointing to the root.
3. Work inside any sub-module — Draft automatically loads module-local context for implementation tasks and follows the root link for cross-module analysis (impact, deep-review, bughunt across services).

Re-run `/draft:init` (or `/draft:init --graph-only`) after significant architecture changes to any service, before major cross-service planning, or as part of documentation hygiene. The graph engine handles incremental updates; unchanged modules are not re-analyzed.

## Cross-Module Analysis

Once root links are in place, any graph-aware Draft command can scope across modules:

* `/draft:impact` — follows the root link to find downstream dependencies across service boundaries.
* `/draft:deep-review` — loads cross-module invariants from the root graph when reviewing a service that calls others.
* `/draft:bughunt` — can be scoped to a single service or run against the root graph for a system-wide sweep.

The federation is transparent: commands do not need to know whether they are running in a mono-module repo or a large monorepo. The root-link mechanism handles the routing.
