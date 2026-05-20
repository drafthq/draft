# Draft Knowledge Graph

The graph subsystem builds a **deterministic, language-aware knowledge graph** of a codebase and stores it as compact JSONL files under `draft/graph/`. Every Draft skill that needs structural information — module boundaries, dependency edges, call graphs, hotspots, proto RPC surfaces — reads from this graph instead of re-scanning source files.

The engine itself is a native binary (from the Aether graph project) vendored under `graph/bin/<arch>/graph`. It replaces the previous Node.js + tree-sitter WASM implementation. The **output schema and query contract are unchanged**.

## Binary Layout

See [graph/bin/README.md](bin/README.md) for the vendored binary layout, architecture selection, Git LFS requirements, and detection order (PATH > bundled arch-specific > none).

## Output Artifacts (`draft/graph/`)

All consumers read these files (when present):

- `schema.yaml` — metadata (module count, language stats, commit)
- `module-graph.jsonl` — inter-module nodes + weighted dependency edges (always load)
- `hotspots.jsonl` — top files by complexity (`lines + fanIn*50`)
- `proto-index.jsonl` — gRPC services, RPCs, messages, enums
- `go-index.jsonl`, `python-index.jsonl`, `ts-index.jsonl`, `c-index.jsonl`, `call-index.jsonl` — per-language symbol + call indexes
- `modules/<name>.jsonl` — per-module exhaustive file/symbol records (load on demand)
- Optional mermaid diagrams and hashes for incremental builds

## Usage Contract

**All code-touching skills MUST follow the graph-first lookup contract** defined in:

- [`core/shared/graph-query.md`](../core/shared/graph-query.md) — mandatory order, query modes (`--mode impact|callers|hotspots|...`), usage-report footer
- [`core/shared/red-flags.md`](../core/shared/red-flags.md) — graph usage red flags

Skills invoke the engine via the thin shell wrappers under `scripts/tools/` (resolved at runtime):

```bash
bash "$DRAFT_TOOLS/hotspot-rank.sh"
bash "$DRAFT_TOOLS/cycle-detect.sh"
bash "$DRAFT_TOOLS/mermaid-from-graph.sh"
```

Direct CLI (after `graph` is in PATH or resolved):

```bash
graph --repo . --out draft/graph/
graph --repo . --query --file path/to/file.cc --mode impact
graph --repo . --query --mode hotspots
```

## Invoking the Builder

The native binary is discovered automatically during `/draft:init` (see `skills/init/SKILL.md` Step 1.4) and by `scripts/tools/verify-graph-binary.sh`.

When no binary is found, graph-dependent features degrade gracefully (`Graph files queried: NONE — graph data unavailable`).

## Schema Stability

The JSONL schema is stable. Changes to the engine (new languages, better C++ fidelity via the companion `graph-clang` binary, etc.) do not affect consumers as long as the record kinds and field contracts are preserved.

---

**Historical note:** The original engine lived under `graph/src/` (Node + tree-sitter WASM). It was removed in favor of the higher-fidelity native implementation from Aether. All behavioral contracts and output formats were preserved during the cutover.
