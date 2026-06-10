# Plan: Replace the Aether graph engine with codebase-memory-mcp (CLI mode)

> Status: **Proposal — awaiting approval**
> Branch: `claude/seekdb-draft-artifacts-xukf1v`
> Scope: Fully retire the vendored Aether `graph` binary (`bin/<arch>/graph`, `graph-clang`) and replace it with [DeusData/codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp), used **via its CLI** (`codebase-memory-mcp cli <tool> '<json>'`). MCP-server mode is explicitly **out of scope for now**.

---

## 1. The core decision (read this first)

The two engines share *no* interface:

| | Aether `graph` (current) | codebase-memory-mcp (target) |
|---|---|---|
| Binary | `bin/<arch>/graph` (+ `graph-clang`), Git LFS | `codebase-memory-mcp` single static binary per OS |
| Invocation | `graph --repo . --out draft/graph --query --mode <mode>` | `codebase-memory-mcp cli <tool> '<json-args>'` |
| Storage | JSONL/YAML files committed in `draft/graph/` | SQLite KG at `~/.cache/codebase-memory-mcp/` + optional committed zstd snapshot |
| Schema | `module`/`file`/`*-func`/`*-class`/`*-call`/`ctags-sym` records | nodes: Project/Package/Folder/File/Module/Class/Function/Method/Interface/Enum/Type/Route/Resource; edges: CALLS/IMPORTS/HTTP_CALLS/… |
| Query | `--mode {hotspots,cycles,modules,callers,impact,mermaid}` | tools: `search_graph`, `trace_path`, `detect_changes`, `query_graph` (openCypher), `get_architecture`, `get_code_snippet`, … |

Because **~120 touchpoints** in this repo depend on the Aether artifact contract (the JSONL files *and* the `--query --mode X` JSON shapes), "replace the engine" forks into two strategies:

- **Strategy A — Adapter (preserve the contract). ◀ RECOMMENDED.** Swap the binary + resolver, then add a thin adapter that drives `codebase-memory-mcp cli` and **emits the same `draft/graph/` artifacts and the same query JSON** the existing consumers expect. ~12 skills, the templates, and the methodology stay essentially unchanged. New native capabilities (semantic search, dead-code, cross-service links) are layered in later behind the same contract.
- **Strategy B — Native rewrite (adopt the new model).** Delete the JSONL contract and rewrite every consumer to call the new CLI / openCypher directly. Maximum power, maximum blast radius (all skills + methodology + templates + tests), high risk.

This plan executes **Strategy A**. Rationale: it lets us fully delete Aether (the literal ask) while bounding churn and keeping the test suite and Ground-Truth Discipline (G1–G5) intact. Strategy B can follow incrementally once the adapter is stable.

---

## 2. Open decisions to confirm before Phase 1

1. **Strategy A vs B** — proceed with the adapter (recommended) or commit to a full native rewrite?
2. **Artifact storage** — keep emitting git-committed JSONL in `draft/graph/` (recommended; reviewable, deterministic, works for Copilot/Gemini integrations) and treat `~/.cache` as scratch? Or adopt the engine's committed zstd snapshot as the artifact of record?
3. **Schema-gap handling** (per item below) — for each Aether artifact with no clean 1:1 mapping, choose *emulate*, *replace*, or *drop*:
   - `proto-index.jsonl` (proto services/RPCs) → new engine has HTTP/gRPC/GraphQL route detection (`Route` nodes, `HTTP_CALLS`) — **partial** map.
   - `go/python/ts/c-index.jsonl` per-language symbol indexes → derive from `search_graph` by label + language filter.
   - `ctags-sym` fallback (Java/Rust/Ruby/…) → new engine parses 159 langs via tree-sitter — likely *replace*, coverage TBD in spike.
   - `graph-clang` companion → **drop** (no analog; new engine bundles its own parsing).
   - `--mode cycles` → openCypher cycle query via `query_graph`.
   - `--mode mermaid` (`module-deps`, `proto-map`) → generate from `get_architecture`/`query_graph` output in `mermaid-from-graph.sh`.
4. **Version pinning** — pin a specific codebase-memory-mcp release (checksum + Sigstore verify) for reproducible CI; who owns bumps?

---

## 3. Phased plan

### Phase 0 — Spike & decision record (de-risk before touching the repo)
- [ ] Vendor one platform binary (linux-amd64) into a scratch dir; verify checksum + Sigstore signature.
- [ ] Run `codebase-memory-mcp cli index_repository` against this repo; capture real output for `get_architecture`, `search_graph`, `trace_path`, `detect_changes`, `query_graph` (openCypher), `get_code_snippet`.
- [ ] Confirm exact CLI invocation, JSON arg shapes, exit codes, and where output/state lands.
- [ ] Build the **mapping table**: every Aether artifact + `--mode` → codebase-memory-mcp call(s) → transform needed. Record gaps from §2.3.
- [ ] Write a short ADR (`draft/` ADR or `docs/adr/`) capturing the strategy, storage, and gap decisions.

### Phase 1 — Binary resolution & distribution
- [ ] Rewrite `find_graph_bin()` in `scripts/tools/_lib.sh` to resolve `codebase-memory-mcp` (PATH > `bin/<arch>/codebase-memory-mcp` > install breadcrumb). Keep the function name + `GRAPH_BIN` global so callers don't churn (or rename + thin shim).
- [ ] Vendor binaries for all 4 targets (`linux-amd64`, `linux-arm64`, `darwin-amd64`, `darwin-arm64`) under `bin/<arch>/`.
- [ ] Update `.gitattributes` LFS tracking (`bin/*/*/codebase-memory-mcp*` ← was `graph*`/`graph-clang*`).
- [ ] Update `scripts/build-graph-binaries.sh`, `scripts/package.sh`, `scripts/install.sh` to stage/materialize the new binary; drop `graph-clang`.
- [ ] Update `verify-graph-binary.sh` to detect the new binary; preserve the `draft/.graph-binary-report.json` report contract (rename fields as needed).
- [ ] Delete Aether `bin/<arch>/graph` + `graph-clang` binaries and legacy `graph/bin` fallback.

### Phase 2 — Adapter: artifact generation (the build path)
- [ ] Add `scripts/tools/graph-build.sh` (adapter) wrapping `codebase-memory-mcp cli`:
  - `index_repository` → then export queries → write `draft/graph/{schema.yaml, module-graph.jsonl, hotspots.jsonl, proto-index.jsonl(or replacement), <lang>-index.jsonl, call-index.jsonl, modules/<name>.jsonl, *.mermaid, hashes.json}`.
  - Translate node/edge model → Draft record kinds (File→`file`, Function/Method→`*-func`, Class→`*-class`, CALLS→`*-call`, Module→`module`, route detection→`proto-index` replacement).
- [ ] Map `hotspots` ranking (`lines + fanIn*50`) onto the new engine's degree/architecture data so existing `{id,module,lines,fanIn}` shape holds.
- [ ] Wire incremental build to the engine's git-watcher / incremental index path.
- [ ] Update `/draft:init` (Phase 0.1/0.4) and `/draft:index` build invocations to call the adapter instead of `graph --repo … --out …`.

### Phase 3 — Query adapters (live `--mode` parity)
- [ ] `hotspot-rank.sh` → `get_architecture`/`search_graph` reshaped to `{hotspots:[…], source}`.
- [ ] `cycle-detect.sh` → `query_graph` openCypher cycle detection reshaped to `{cycles:[…], source}`.
- [ ] `mermaid-from-graph.sh` → build `module-deps`/`proto-map` mermaid from query output.
- [ ] Provide adapter coverage for the remaining live modes used inside skills: `impact` (`detect_changes`/`trace_path`), `callers` (`query_graph`), `modules` (`get_architecture`).

### Phase 4 — Contract, methodology & skills
- [ ] Rewrite `core/shared/graph-query.md`: new engine + CLI, retained artifact schema, documented schema deltas, new optional capabilities. **Keep the Mandatory Lookup Contract and Ground-Truth Discipline (G1–G5) unchanged.**
- [ ] Update `core/shared/draft-context-loading.md` always-load list if the artifact set changes.
- [ ] Update graph references in `core/methodology.md`.
- [ ] Light edits to the ~12 graph-consuming skills *only* where a referenced artifact/mode changed (`proto-index`, language indexes): `init`, `implement`, `review`, `bughunt`, `debug`, `decompose`, `deep-review`, `deploy-checklist`, `tech-debt`, `learn`, `quick-review`, `index`.
- [ ] Update `bin/README.md` for the new binary/layout.
- [ ] Update `core/templates/{architecture,ai-context,hld,lld,metadata.json}` only if slot semantics change (slot names should stay).

### Phase 5 — Tests & regeneration
- [ ] Update `tests/test-tools-{verify-graph-binary,hotspot-rank,cycle-detect,mermaid-from-graph}.sh` for the new CLI + reshaped outputs.
- [ ] Add an adapter test: index a small fixture repo → assert produced JSONL matches the schema.
- [ ] Pin engine version + use a committed fixture so CI is deterministic.
- [ ] `make build` to regenerate integrations (graph-query.md + skills changed), then `make test` green; `make lint`.

### Phase 6 — Cleanup & docs
- [ ] Remove dead Aether code paths, `graph-clang` references, legacy `graph/bin` fallback.
- [ ] Update `scripts/lib.sh` (`TOOLS`/`CORE_FILES`) if tool/file names changed.
- [ ] Update `README.md`, `CHANGELOG.md`, and `CLAUDE.md` (Architecture → `bin/<arch>/` description, graph-engine paragraph).

---

## 4. Risks
- **Schema fidelity.** Proto/per-language/ctags artifacts may not map cleanly; the spike must prove coverage or we drop/replace them with consumer edits.
- **Determinism in CI.** New engine writes to `~/.cache` and has a background watcher — must be pinned, sandboxed, and driven through a fixture for reproducible tests.
- **Third-party coupling.** Draft binds to the engine's CLI/openCypher schema and cache layout; mitigated by version pinning + Sigstore/SLSA verification.
- **Binary size / LFS churn.** Swapping vendored binaries rewrites LFS pointers across 4 arches.
- **Multi-platform integrations.** Copilot/Gemini integrations rely on committed artifacts, not MCP — the adapter (committed JSONL) is what keeps them working.

## 5. Out of scope (deferred)
- MCP-server mode and live agent queries (`trace_path`/`detect_changes`/semantic search at runtime).
- Native-model rewrite of consumers (Strategy B).
- Adopting `manage_adr` to replace Draft's `adr-index.sh`.
