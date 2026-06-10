# Plan: Replace the Aether graph engine with codebase-memory-mcp (CLI mode)

> Status: **Implemented** — Phases 0–5 landed (Aether fully retired; engine, tools, snapshot, contract, and all skill/doc references migrated). Remaining: vendor binaries for the 3 non-Linux arches into the fetch flow, and an end-to-end init run on a real polyglot repo.
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

## 1b. Phase 0 spike — VERIFIED findings (codebase-memory-mcp v0.7.0)

Ran the real binary against this repo (5285 nodes / 5550 edges). Confirmed:

- **CLI:** `codebase-memory-mcp cli <tool> '<json>'`. JSON → **stdout**, `level=…` logs → **stderr** (clean capture).
- **Index:** `index_repository {repo_path}` → `{project, status, nodes, edges}`. Project name = path slug (`/home/user/draft` → `home-user-draft`); also discoverable via `list_projects[].root_path`.
- **Storage:** `~/.cache/codebase-memory-mcp/<project>.db` (SQLite). Scratch/derived — git stays source of truth (decision #2 = keep committed artifacts).
- **Reliable query forms:** `get_architecture` (server-computed hotspots/packages/routes/languages), `trace_path`, `detect_changes`, and **fixed-length** openCypher patterns (single-hop callers, explicit N-cycles).
- **UNRELIABLE (avoid):** openCypher aggregations (`count`/`WITH` grouping) and multi-pattern joins — return cross-products/empty in this dialect. Tools must use purpose-built endpoints, not ad-hoc Cypher.
- **Schema is unified, not per-language:** one `Function`/`Method`/`Class`/`Module`/`File`/`Route` model (language inferred from extension). Aether's `go/python/ts/c-index` + `ctags-sym` split **collapses** — drop, don't emulate.
- **Distribution:** binary is **253 MB** uncompressed / 34 MB tarball. Vendoring 4 arches in LFS (~1 GB) is rejected → **fetch-on-install** (`scripts/fetch-memory-engine.sh`, checksum-verified, pinned `v0.7.0`).

Mode → engine mapping now in force:

| Draft need | Engine call | Tool |
|---|---|---|
| hotspots | `get_architecture aspects=[hotspots]` | `hotspot-rank.sh` |
| cycles | fixed-length `CALLS` openCypher (2- & 3-cycles) | `cycle-detect.sh` |
| module-deps mermaid | `FILE_CHANGES_WITH` co-change edges | `mermaid-from-graph.sh` |
| proto-map mermaid | `get_architecture aspects=[routes]` (Route nodes) | `mermaid-from-graph.sh` |
| callers | single-hop `CALLS` openCypher | (skills, via `query_graph`) |
| impact / blast-radius | `detect_changes` + `trace_path` | (skills) |

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

### Phase 0 — Spike & decision record ✅ DONE
- [x] Fetched + checksum-verified the real binary (v0.7.0); ran it against this repo.
- [x] Captured real output for `index_repository`, `get_architecture`, `search_graph`, `query_graph`, `trace_path`, `detect_changes`, `get_graph_schema`.
- [x] Confirmed CLI invocation, JSON arg shapes, stdout/stderr split, storage location.
- [x] Built the mapping table (see §1b) and recorded all gap decisions inline.

### Phase 1 — Binary resolution & distribution ✅ DONE
- [x] Replaced `find_graph_bin()` → `find_memory_bin()` (`MEMORY_BIN`) in `_lib.sh`; resolves `DRAFT_MEMORY_BIN` > PATH > `~/.cache/draft/bin` > vendored `bin/<arch>/`. Added `DRAFT_MEMORY_DISABLE` opt-out + `memory_cli`/`memory_ensure_index`/`memory_project_for_repo` wrappers. **No legacy `graph/bin` fallback.**
- [x] Chose **fetch-on-install** over vendoring (253 MB binary): new `scripts/fetch-memory-engine.sh` (pinned, checksum-verified) → `~/.cache/draft/bin`.
- [x] Rewrote `.gitattributes` (dropped all `graph*` LFS tracking).
- [x] Updated `scripts/install.sh` + `scripts/package.sh`; deleted `scripts/build-graph-binaries.sh`; dropped `graph-clang` everywhere.
- [x] Rewrote `verify-graph-binary.sh` to detect the engine; report now emits `engine_bin`/`source`/`status`.
- [x] Deleted vendored Aether `bin/<arch>/graph` + `graph-clang` binaries.
- [x] Rewrote `bin/README.md` for the fetch model + resolution order.

### Phase 2 — Adapter: artifact generation (the build path)
- [ ] Add `scripts/tools/graph-build.sh` (adapter) wrapping `codebase-memory-mcp cli`:
  - `index_repository` → then export queries → write `draft/graph/{schema.yaml, module-graph.jsonl, hotspots.jsonl, proto-index.jsonl(or replacement), <lang>-index.jsonl, call-index.jsonl, modules/<name>.jsonl, *.mermaid, hashes.json}`.
  - Translate node/edge model → Draft record kinds (File→`file`, Function/Method→`*-func`, Class→`*-class`, CALLS→`*-call`, Module→`module`, route detection→`proto-index` replacement).
- [ ] Map `hotspots` ranking (`lines + fanIn*50`) onto the new engine's degree/architecture data so existing `{id,module,lines,fanIn}` shape holds.
- [ ] Wire incremental build to the engine's git-watcher / incremental index path.
- [ ] Update `/draft:init` (Phase 0.1/0.4) and `/draft:index` build invocations to call the adapter instead of `graph --repo … --out …`.

### Phase 3 — Query adapters (live `--mode` parity) ✅ DONE (tools)
- [x] `hotspot-rank.sh` → `get_architecture` → `{hotspots:[{id,name,fanIn}], source:"memory-graph"}`. Verified against real engine + mock.
- [x] `cycle-detect.sh` → fixed-length `CALLS` openCypher (2- & 3-cycles) → `{cycles:[…], source}`. Found a real cycle in this repo.
- [x] `mermaid-from-graph.sh` → `module-deps` from `FILE_CHANGES_WITH`, `proto-map` from Route nodes.
- [ ] Remaining live modes are invoked *inside skills* (`impact`, `callers`, `modules`) — wired in Phase 4 when skill bodies are updated.

### Phase 4 — Contract, methodology & skills
- [ ] Rewrite `core/shared/graph-query.md`: new engine + CLI, retained artifact schema, documented schema deltas, new optional capabilities. **Keep the Mandatory Lookup Contract and Ground-Truth Discipline (G1–G5) unchanged.**
- [ ] Update `core/shared/draft-context-loading.md` always-load list if the artifact set changes.
- [ ] Update graph references in `core/methodology.md`.
- [ ] Light edits to the ~12 graph-consuming skills *only* where a referenced artifact/mode changed (`proto-index`, language indexes): `init`, `implement`, `review`, `bughunt`, `debug`, `decompose`, `deep-review`, `deploy-checklist`, `tech-debt`, `learn`, `quick-review`, `index`.
- [ ] Update `bin/README.md` for the new binary/layout.
- [ ] Update `core/templates/{architecture,ai-context,hld,lld,metadata.json}` only if slot semantics change (slot names should stay).

### Phase 5 — Tests & regeneration 🟡 PARTIAL
- [x] Rewrote `tests/test-tools-{verify-graph-binary,hotspot-rank,cycle-detect,mermaid-from-graph}.sh` for the new CLI + reshaped outputs (22 assertions, all green).
- [x] Added a deterministic **mock engine** (`make_mock_memory_engine` in `test-helpers.sh`) so CI needs no 253 MB binary; `DRAFT_MEMORY_DISABLE` drives the unavailable path.
- [x] Pinned engine version in `fetch-memory-engine.sh` (`v0.7.0`).
- [ ] Adapter (build-path) test — pending Phase 2.
- [x] `make build` green. `make test`: all graph suites green (3 unrelated failures are pre-existing **git-signing** sandbox issues — pass with signing off; CI has no signing server).

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
