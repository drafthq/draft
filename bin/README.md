# Knowledge-Graph Engine

Draft's knowledge graph is powered by **[codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp)** — a single static binary that indexes a repository into a SQLite knowledge graph (functions, classes, modules, files, routes, and their CALLS/DEFINES/IMPORTS edges) and answers structural queries.

## Not vendored — fetched on install

Unlike the previous Aether `graph` binary, the engine is **not committed to this repo** (it is ~250 MB per platform). Instead it is downloaded on install:

```bash
scripts/fetch-memory-engine.sh          # fetch pinned version for this host
CMM_VERSION=latest scripts/fetch-memory-engine.sh   # or a specific tag / latest
```

This installs the binary to the **Draft-managed location**:

```
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

## Offline / air-gapped distributions

To ship the engine in-tree, place the binary at `bin/<os>-<arch>/codebase-memory-mcp` (resolution step 4). This is optional and not the default; the managed fetch is preferred.
