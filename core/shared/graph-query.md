# Graph Query Subroutine

Shared procedure for querying the knowledge graph from any skill. The graph provides precise, deterministic structural data about the codebase — module boundaries, dependency edges, hotspots, proto API surface, and symbol indexes.

This is the **single source of truth** for graph lookup procedure. Consumer skills MUST reference this file rather than inlining their own lookup logic.

Referenced by: `/draft:init`, `/draft:implement`, `/draft:bughunt`, `/draft:review`, `/draft:deep-review`, `/draft:quick-review`, `/draft:debug`, `/draft:decompose`, `/draft:new-track`, `/draft:tech-debt`, `/draft:deploy-checklist`, `/draft:learn`, `/draft:index`

## Mandatory Lookup Contract

Any code-touching skill that needs to discover files, modules, symbols, callers, or blast-radius **MUST** follow this lookup order whenever `draft/graph/schema.yaml` exists:

1. **Graph first** — the committed snapshot (`architecture.json`, `hotspots.jsonl`) and the live query tools (`scripts/tools/graph-callers.sh`, `graph-impact.sh`, `cycle-detect.sh`, `hotspot-rank.sh`).
2. **Generated context second** — `draft/.ai-context.md`, relevant `draft/architecture.md` slices, track-level `hld.md`/`lld.md`.
3. **Source file reads third** — narrow via tiers 1–2, then **Read** the candidate files. Reading is **not optional**: see §Ground-Truth Discipline below.
4. **Filesystem `grep`/`find`/`rg` last** — only after an explicit graph miss.

**If a lower tier is used before a higher tier, that is a Red Flag** ([red-flags.md](red-flags.md)). The skill must report it in its Graph Usage Report footer (see below) with justification.

**Required fallback sentence format** (verbatim) before any filesystem search after a graph miss:

> `Graph returned no match for <X>; falling back to grep.`

If `draft/graph/schema.yaml` is **absent**, the graph contract is satisfied — proceed directly to tier 2/3/4 as needed and record `Graph files queried: NONE — graph data unavailable` in the report footer.

## Ground-Truth Discipline (mandatory)

The graph is the **index**, not the **territory**. Graph hits identify candidates; **Read** validates them. Skills that ship claims about code behavior, scope coverage, hotspot status, or risk **without opening the cited files** routinely produce confidently-wrong output (e.g. citations marked `TBD` for files that were "found via graph but never opened"; scope statements that exclude the actual code path the problem statement names).

The following rules apply to every code-touching skill output. They are non-negotiable for `criticality: standard | high | mission-critical` work; `criticality: low` (quick) tracks may skip rule **G3** only.

**G1. Read before you cite.** Any `file:line`, `func()`, or `symbol` reference written into a deliverable (spec / hld / lld / plan / review / audit / debug report) must come from a file the skill has actually opened in this run. The graph tells you *which* file; Read confirms the line is what you claim it is.

**G2. Read before you scope.** A track / phase / audit / review may not declare a code path **in-scope** or **out-of-scope** without at least one Read on a representative file in that path. The graph's module list is a candidate set — it does not establish that the candidate contains the cost the problem names.

**G3. No `TBD` citations on `Modified` or `Existing` modules.** When a deliverable's Component / Class / Symbol table marks a module `Status: Modified` or `Status: Existing`, every Citation cell must resolve to a real `path:line` from a file read in this run. `TBD` is reserved for `Status: New` modules whose source files have not been authored yet, and even then the planned file path must be filled (`Citation: path/to/new_file.h (planned)`).

**G4. No claim about code behavior from graph metadata alone.** Statements of the form "*X writes to disk*", "*Y blocks on Z*", "*this is the hotspot*", "*this is the only path*" must be backed by a Read. Graph fan-in / fan-out / complexity scores are necessary signal, not sufficient evidence. If you have only graph data, write *"graph signal suggests X; not yet validated against source"* rather than asserting X.

**G5. Scope-vs-problem coverage check before promote.** Before promoting `spec-draft.md` → `spec.md`, before generating `hld.md` / `lld.md`, and before declaring a review / audit complete: enumerate the cost / behavior / risk terms in the problem statement, and confirm that the in-scope file set (per G2) covers each. If any term is not covered, surface the gap before commit — do not silently ship a scope that excludes the named cost.

### Self-check (run before emitting the Graph Usage Report)

Append the answers to your scratch notes; the skill output need not include them unless asked.

1. Did I open every file whose `path:line` appears in this output? (yes / list misses)
2. Are any `Modified` / `Existing` modules carrying `Citation: TBD`? (no / list)
3. Did I declare anything in-scope or out-of-scope? If yes, did I Read at least one file in that path? (yes / list)
4. Did I make a claim about what code does (writes / blocks / loops / fails) based only on graph metadata? (no / list)
5. Does the in-scope set cover every cost term in the problem statement? (yes / list gaps)

A single "no" / "list" answer is a halt — fix and re-check before output.

## Concept-to-Files Recipe

Use this recipe whenever the user names a concept, feature, or domain term ("in-memory shuffle", "auth flow", "ingest pipeline") and you need to locate the implementing files. **Run it before any filesystem search.**

1. **Concept → modules** — `grep` the concept token against `draft/graph/architecture.json` (`.packages[].name`) and `draft/.ai-context.md` (module headings). Record the candidate module list.
2. **Concept → symbols/callers** — for a named function, run `scripts/tools/graph-callers.sh --repo . --symbol <name>` to find call sites, and `scripts/tools/graph-impact.sh --repo . --symbol <name>` for transitive dependents. These are the authoritative structural answers.
3. **Modules → risk ranking** — cross-reference `draft/graph/hotspots.jsonl` (or `scripts/tools/hotspot-rank.sh`). High-fanIn symbols are the most likely entry points for impact.
4. **Concept → public API** — for API-shaped concepts, consult `architecture.json` `.routes` (detected HTTP/gRPC/GraphQL routes) for matching service surface.
5. **Graph miss → grep fallback** — only if steps 1–4 return nothing relevant, emit the fallback sentence and use `grep`/`find`. Narrow the search by file extension and exclude `node_modules`, `vendor`, `dist`, `build`, `.git`.

## Graph Usage Report (Mandatory Footer)

Every code-touching skill output MUST end with this footer block. The lint check `scripts/tools/check-graph-usage-report.sh` rejects outputs missing the section.

```md
## Graph Usage Report

- Graph files queried: <comma-separated list, e.g. `architecture.json, hotspots.jsonl` and/or query tools like `graph-callers.sh` — or `NONE` with justification below>
- Modules identified via graph: <comma-separated module names, or `none`>
- Files identified via graph: <integer count>
- Filesystem grep fallbacks: <list of `<pattern>` searches with one-line justification each, or `none`>
- Justification (only when `Graph files queried: NONE`): <required — `graph data unavailable` | `non-code task` | `<explicit reason>`>
```

**Gate:** `Graph files queried: NONE` without a populated justification line is a hard failure.

## Telemetry Fields (graph adherence)

Skills that emit telemetry via [emit-skill-metrics.sh](../../scripts/tools/emit-skill-metrics.sh) MUST include these fields in the JSON payload so contract adherence and token-floor trends can be monitored:

| Field | Type | Description |
|---|---|---|
| `graph_queries` | int | Number of graph artifacts loaded plus live graph query-tool invocations during the run |
| `fallback_grep_count` | int | Number of `grep`/`find` fallbacks invoked after an explicit graph miss |

These fields are appended to `~/.draft/metrics.jsonl` along with the existing skill fields (`skill`, `track_id`, etc.) — no new state file is needed. Run `tail -100 ~/.draft/metrics.jsonl | jq -s 'group_by(.skill) | map({skill: .[0].skill, runs: length, avg_graph_queries: ([.[].graph_queries] | add / length), avg_grep_fallbacks: ([.[].fallback_grep_count] | add / length)})'` to monitor adherence per skill.



## Tooling Wrappers

For common query modes, prefer the deterministic wrappers that ship with the plugin. Resolve their location via the canonical tool resolver (see [tool-resolver.md](tool-resolver.md)) before invoking:

```bash
DRAFT_TOOLS="${DRAFT_PLUGIN_ROOT:-$HOME/.claude/plugins/draft}/scripts/tools"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$HOME/.cursor/plugins/local/draft/scripts/tools"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$PWD/scripts/tools"
```

| Wrapper | Graph mode | Behavior on missing graph |
|---|---|---|
| `bash "$DRAFT_TOOLS/hotspot-rank.sh" [--top N] [--module NAME]` | `--mode hotspots` | Emits `{hotspots:[],source:"unavailable"}` and exits 2 |
| `bash "$DRAFT_TOOLS/cycle-detect.sh"` | `--mode cycles` | Emits `{cycles:[],source:"unavailable"}` and exits 2 |
| `bash "$DRAFT_TOOLS/mermaid-from-graph.sh" [--diagram module-deps\|proto-map]` | `--mode mermaid` | Emits an empty mermaid block and exits 2 |

Use the raw `graph` CLI directly for the lower-level modes documented below.

## Pre-Check

Verify graph data exists before any graph operation:

```bash
ls draft/graph/schema.yaml 2>/dev/null
```

If absent, **skip all graph operations silently**. Graph enriches analysis — it never gates it. All skills must work identically without graph data.

## Engine + snapshot model

The graph is produced by the **codebase-memory-mcp** engine (a single binary; see [bin/README.md](../../bin/README.md)). There are two ways skills consume it:

1. **Live queries** (preferred when the engine is resolvable) — the shell tools under `scripts/tools/` drive the engine on demand (it auto-indexes into its own cache). No committed files required.
2. **Committed snapshot** (`draft/graph/`) — a small, derived, PR-reviewable snapshot written by `scripts/tools/graph-snapshot.sh`. It exists for reviewability and for the Copilot/Gemini integrations, which cannot run the engine but can read committed files. Git remains the source of truth.

When `draft/graph/` exists, the snapshot contains:

| File | Load | Content |
|------|------|---------|
| `schema.yaml` | Always | Engine + project metadata, node/edge counts, artifact list. Its presence **gates** graph use (see Pre-Check). |
| `architecture.json` | Always | `get_architecture(all)` output: node labels, edge types, languages, packages (with fan-in/out), entry points, routes, hotspots. |
| `hotspots.jsonl` | Always | Fan-in-ranked symbols, one JSON object per line: `{id, name, fanIn}`. |
| `module-deps.mermaid` | Diagram injection | File co-change coupling diagram (`FILE_CHANGES_WITH`). |
| `proto-map.mermaid` | Diagram injection | Detected service-route diagram (`Route` nodes). |

The engine uses a **unified, language-agnostic** node model — `Function`, `Method`, `Class`, `Module`, `File`, `Folder`, `Route`, `Section`, `Variable` (language is inferred from file extension) — and edges `CALLS`, `DEFINES`, `CONTAINS_FILE`, `IMPORTS`, `HTTP_CALLS`, `FILE_CHANGES_WITH`, `SEMANTICALLY_RELATED`, `SIMILAR_TO`. There are **no** per-language index files and no `ctags-sym` fallback; that detail is served by live queries against the unified model.

**Always-load files** are compact and should be read during context loading for any task that touches code structure.

## Query Tools

Live queries go through the shell tools under `scripts/tools/`, which drive the engine and shape results into stable JSON. Each tool resolves the engine (see Finding the Engine), indexes the repo on demand, and emits `source: "memory-graph"` on success or `source: "unavailable"` (non-zero exit) when the engine cannot be resolved. Set `DRAFT_MEMORY_DISABLE=1` to force the engine off; all tools then degrade gracefully.

### Callers — who calls this function?

```bash
scripts/tools/graph-callers.sh --repo . --symbol <name>
```

Output: `{symbol, callers[{name, file}], source}`. Use when enumerating call sites before claiming "no other usages" or judging breaking-change severity.

### Impact — blast radius of a file or symbol

```bash
scripts/tools/graph-impact.sh --repo . --file <path>      # changed-file impact (working-tree diff)
scripts/tools/graph-impact.sh --repo . --symbol <name>    # transitive callers of a function
```

Output: `{target, kind, impacted[{name, file, hop}], source}`. Use when sizing risk before modifying a file or symbol, especially high-fan-in hotspots.

### Hotspots — fan-in ranking

```bash
scripts/tools/hotspot-rank.sh --repo . [--top N]
```

Output: `{hotspots[{id, name, fanIn}], source}` (server-computed by the engine).

### Cycles — call-cycle detection

```bash
scripts/tools/cycle-detect.sh --repo .
```

Output: `{cycles[[a,b],[a,b,c]], source}` — fixed-length 2- and 3-node `CALLS` cycles (mutual recursion / tight coupling).

### Modules — dependency overview

Read `draft/graph/architecture.json` (`.packages` for module fan-in/out, `.node_labels`/`.edge_types` for shape, `.routes` for service surface), or regenerate it with `scripts/tools/graph-snapshot.sh --repo .`.

### Mermaid — diagram text

```bash
scripts/tools/mermaid-from-graph.sh --repo . --diagram module-deps   # co-change coupling
scripts/tools/mermaid-from-graph.sh --repo . --diagram proto-map     # detected routes
```

Emits a ready-to-inject ` ```mermaid ``` ` block, or an empty stub (exit 2) when the engine is unavailable. The committed `draft/graph/*.mermaid` snapshots are written by `graph-snapshot.sh`.

### Building / refreshing the snapshot

```bash
scripts/tools/graph-snapshot.sh --repo .
```

Writes the committed `draft/graph/` snapshot (`schema.yaml`, `architecture.json`, `hotspots.jsonl`, `*.mermaid`). Run during `/draft:init` and `/draft:index`, or whenever the reviewable graph state should be refreshed.

## Finding the Engine (Resolution + Usage Report)

The engine is the `codebase-memory-mcp` binary. Resolution order (implemented by `scripts/tools/_lib.sh:find_memory_bin`):

1. `DRAFT_MEMORY_BIN` — explicit override (pinned installs, testing).
2. `codebase-memory-mcp` on `$PATH` — global/dev installs.
3. `~/.cache/draft/bin/codebase-memory-mcp` — the Draft-managed location (`scripts/fetch-memory-engine.sh` installs it here; `draft install claude-code`/`draft install cursor` run that on install unless `--no-graph`).
4. `bin/<os>-<arch>/codebase-memory-mcp` under the plugin/repo root — optional vendored fallback (air-gapped only).

`DRAFT_MEMORY_DISABLE=1` forces the engine off. There is **no** legacy `graph`/`graph-clang` fallback.

The canonical verifier is `scripts/tools/verify-graph-binary.sh` (`--json --verbose --strict`). It resolves and liveness-checks the engine and, in a `draft/` context, writes the usage-report side-effect:

```bash
ENGINE_INFO="$(scripts/tools/verify-graph-binary.sh --repo . --json 2>/dev/null || true)"
# {"status":"ok","engine_bin":"...","source":"managed|path|bundled:<arch>|override","arch":"..."}
```

## Usage Report Contract

After successful detection, `draft/.graph-binary-report.json` contains: `detected_at`, `engine_bin`, `source` (`path` | `managed` | `bundled:<arch>` | `override`), `arch`, `status`. It is a derived artifact (safe to prune), regenerated by each graph-using command that calls the verifier.

## Building the Snapshot

Run during `draft:init` / `draft:index`, or manually:

```bash
scripts/tools/graph-snapshot.sh --repo .
```

The engine indexes C/C++, Go, Python, TypeScript/JS, and more (tree-sitter, 159 languages) plus LSP-assisted resolution for the major ones, and detects HTTP/gRPC/GraphQL routes. Indexing is incremental in the engine (content-based, git-aware); the snapshot is re-derived on each run.

## Graceful Degradation

| Scenario | Behavior |
|----------|----------|
| No engine resolvable (or `DRAFT_MEMORY_DISABLE=1`) | Skip graph build in init; all skills proceed without graph data; tools emit `source: unavailable` |
| Engine present but a query fails | Warn and proceed; skills work without graph data |
| `draft/graph/` snapshot exists | Load always-load files during context loading; use live query tools as needed |
| Stale snapshot | Still useful — structural changes are infrequent. Re-run `graph-snapshot.sh` (or init) to refresh. |
