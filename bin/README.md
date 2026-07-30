# Knowledge-Graph Engine

Draft's knowledge graph is powered by **[codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp)** — a single static binary that indexes a repository into a SQLite knowledge graph (functions, classes, modules, files, routes, and their CALLS/DEFINES/IMPORTS edges) and answers structural queries.

## Not vendored — fetched on install

Unlike the previous Aether `graph` binary, the engine is **not committed to this repo** (it is ~250 MB per platform). Instead it is downloaded on install:

```bash
scripts/fetch-memory-engine.sh          # fetch pinned version for this host
CMM_VERSION=latest scripts/fetch-memory-engine.sh   # or a specific tag / latest
```

This installs the binary to the **Draft-managed location**:

```text
~/.cache/draft/bin/codebase-memory-mcp
```

The fetch script picks the right release archive for the host OS/arch, verifies its SHA-256 against the published `checksums.txt`, extracts it, and installs it there. `draft install claude-code` / `draft install cursor` run this automatically (best-effort, network-gated); skip it with `--no-graph`.

## Resolution order

`scripts/tools/_lib.sh:find_memory_bin()` resolves the engine in this order:

1. `DRAFT_MEMORY_BIN` — explicit override (pinned installs, testing)
2. `codebase-memory-mcp` on `$PATH` — global/dev installs
3. `~/.cache/draft/bin/codebase-memory-mcp` — the managed install location
4. `bin/<os>-<arch>/codebase-memory-mcp` under the plugin/repo root — optional vendored fallback (offline/air-gapped distributions only)

Architecture strings are normalized to `linux-amd64`, `linux-arm64`, `darwin-amd64`, `darwin-arm64`.

There is **no legacy fallback** to the retired Aether `graph` / `graph-clang` binaries.

## Opting out

Set `DRAFT_MEMORY_DISABLE=1` to force the engine off. All graph-backed skills and tools degrade gracefully (they report `source: unavailable` / emit empty stubs) when the engine cannot be resolved.

## How tools use it

Shell helpers under `scripts/tools/` drive the engine via its CLI
(`codebase-memory-mcp cli <tool> '<json>'`) and shape results into Draft's
contracts — see `hotspot-rank.sh`, `cycle-detect.sh`, `mermaid-from-graph.sh`,
and `verify-graph-binary.sh`. The shared wrappers (`memory_cli`,
`memory_ensure_index`, `memory_project_for_repo`) live in `_lib.sh`.

## Snapshot artifacts

`draft/graph/` holds a single committed file:

| Artifact | Content |
|----------|---------|
| `schema.yaml` | Engine + project metadata, node/edge counts, point-of-index counts (gates graph use). |

Structural graph data (architecture, hotspots, module deps, service routes) is queried **live** from the `codebase-memory-mcp` engine — either via the wrapper scripts under `scripts/tools/` (`graph-callers.sh`, `graph-impact.sh`, `hotspot-rank.sh`, `cycle-detect.sh`, `mermaid-from-graph.sh`) or directly with `codebase-memory-mcp cli <tool> '<json>'`.

## Offline / air-gapped distributions

To ship the engine in-tree, place the binary at `bin/<os>-<arch>/codebase-memory-mcp` (resolution step 4). This is optional and not the default; the managed fetch is preferred.

---

## Trust story

Draft's differentiator depends on a binary published by a third party ([DeusData](https://github.com/DeusData)). That is a real supply-chain dependency and deserves a stated position rather than an implied one.

### What is actually guaranteed

| Property | Status |
|---|---|
| Version pinned | Yes — `DEFAULT_VERSION` in `scripts/fetch-memory-engine.sh`. Bumps are deliberate commits, never floating. `CMM_VERSION` overrides per-install. |
| SHA-256 verified | Yes when the release publishes `checksums.txt` and lists the archive. A **mismatch is always fatal.** |
| Missing checksum | **Warns and installs by default.** Set `DRAFT_STRICT_VERIFY=1` to make an unverifiable download fatal instead. |
| Signature / attestation | **No.** There is no code signing or SLSA provenance today. Verification is checksum-only. |
| Source available | Yes — the engine is open source at [DeusData/codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp). |
| Reproducible build | Not verified by Draft. We check the archive matches the publisher's checksum, not that the checksum matches the source. |

Be explicit about the residual risk: a checksum proves the download matches what the publisher released. It does not prove the publisher released what the source says.

### What the engine does at runtime

- Reads the repository you point it at and writes a SQLite graph under its own cache.
- Runs entirely locally. No API key, no telemetry endpoint, no outbound calls during indexing or querying.
- Network is used exactly once, by `fetch-memory-engine.sh`, to download the release archive.

Draft invokes it only through `codebase-memory-mcp cli <tool> '<json>'` (see `_lib.sh:memory_cli`). It is never given credentials and never writes into your source tree.

### If you cannot run an unvetted binary

Three supported postures, in increasing strictness:

1. **Strict verification** — `DRAFT_STRICT_VERIFY=1 scripts/fetch-memory-engine.sh`. Refuses to install anything it cannot checksum.
2. **Vendor it yourself** — review the source, build the binary in your own pipeline, and place it at `bin/<os>-<arch>/codebase-memory-mcp` (resolution step 4) or point `DRAFT_MEMORY_BIN` at it. Draft never re-downloads when a binary already resolves.
3. **Run without it** — `DRAFT_MEMORY_DISABLE=1`, or `draft install <host> --no-graph`. Every graph-backed skill degrades to a documented reduced-context mode; `/draft:review` still runs (see `skills/review/references/zero-setup-mode.md`). You lose blast radius, caller enumeration, hotspot ranking, and cycle detection — nothing silently returns wrong answers.

### Contingency if the upstream project stalls

The dependency is bounded by design, which is what makes this survivable:

- **The interface is small.** Draft consumes a documented CLI (`cli <tool> '<json>'`), not a library. The entire coupling lives in `scripts/tools/_lib.sh` (`memory_cli`, `memory_ensure_index`, `memory_project_for_repo`) and `_graph_queries.sh`. Swapping engines means reimplementing those, not rewriting skills.
- **Skills never call the engine directly.** They call `graph-*.sh` wrappers, all of which already fail loud with `source: "unavailable"`. An engine that disappears degrades the product; it does not break it.
- **Pinning buys time.** A stalled upstream keeps working at the pinned version; only new language support would be lost.
- **The graph contract is replaceable.** The queries are ordinary Cypher-shaped structural lookups (callers, callees, fan-in, cycles, routes) over a tree-sitter/LSP index — reproducible on another indexer.

If upstream goes unmaintained, the migration path is: fork at the pinned tag for continuity, then reimplement `_lib.sh`'s three wrappers against a replacement indexer. No skill markdown changes.
