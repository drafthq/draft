# Graph Query Subroutine

Shared procedure for querying the knowledge graph from any skill. The graph provides precise, deterministic structural data about the codebase — module boundaries, dependency edges, hotspots, proto API surface, and symbol indexes.

This is the **single source of truth** for graph lookup procedure. Consumer skills MUST reference this file rather than inlining their own lookup logic.

Referenced by: `/draft:init`, `/draft:implement`, `/draft:bughunt`, `/draft:review`, `/draft:deep-review`, `/draft:quick-review`, `/draft:debug`, `/draft:decompose`, `/draft:new-track`, `/draft:tech-debt`, `/draft:deploy-checklist`, `/draft:learn`, `/draft:graph`

## Mandatory Lookup Contract

Any code-touching skill that needs to discover files, modules, symbols, callers, or blast-radius **MUST** follow this lookup order whenever `draft/graph/schema.yaml` exists:

1. **Graph first** — live engine queries via the query tools (`scripts/tools/graph-callers.sh`, `graph-impact.sh`, `cycle-detect.sh`, `hotspot-rank.sh`, `mermaid-from-graph.sh`), which drive the local `codebase-memory-mcp` engine on demand. Draft is **engine-only**: there is no committed machine-readable graph to read — `draft/graph/` holds only `schema.yaml` (the gate marker).
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

1. **Concept → modules** — query the engine for the package list (`scripts/tools/graph-arch.sh --repo . | jq -r '.packages[].name'`) and cross-reference `draft/.ai-context.md` (module headings). Record the candidate module list. For an **intent/concept** name (not an exact symbol), start with semantic search: `scripts/tools/graph-search.sh --repo . --query "<concept>"` returns ranked candidate symbols directly.
2. **Concept → symbols/callers** — for a named function, run `scripts/tools/graph-callers.sh --repo . --symbol <name>` to find call sites, and `scripts/tools/graph-impact.sh --repo . --symbol <name>` for transitive dependents. These are the authoritative structural answers.
3. **Modules → risk ranking** — rank with `scripts/tools/hotspot-rank.sh --repo . [--top N]`. High-fanIn symbols are the most likely entry points for impact.
4. **Concept → public API** — for API-shaped concepts, read the engine's `.routes` (`get_architecture` output, detected HTTP/gRPC/GraphQL routes) for matching service surface.
5. **Graph miss → grep fallback** — only if steps 1–4 return nothing relevant, emit the fallback sentence and use `grep`/`find`. Narrow the search by file extension and exclude `node_modules`, `vendor`, `dist`, `build`, `.git`.

## Graph Usage Report (Mandatory Footer)

Every code-touching skill output MUST end with this footer block. The lint check `scripts/tools/check-graph-usage-report.sh` rejects outputs missing the section.

```md
## Graph Usage Report

- Graph files queried: <comma-separated list of query tools invoked, e.g. `graph-callers.sh, hotspot-rank.sh` — or `NONE` with justification below>
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
| `bash "$DRAFT_TOOLS/hotspot-rank.sh" [--top N]` | complexity-weighted hotspots | Emits `{hotspots:[],source:"unavailable"}` and exits 2 |
| `bash "$DRAFT_TOOLS/cycle-detect.sh"` | call cycles | Emits `{cycles:[],source:"unavailable"}` and exits 2 |
| `bash "$DRAFT_TOOLS/mermaid-from-graph.sh" [--diagram module-deps\|co-change\|proto-map]` | diagram text | Emits an empty mermaid block and exits 2 |
| `bash "$DRAFT_TOOLS/graph-callers.sh" --symbol N [--transitive[=N]] [--prod-only] [--qualified]` | callers | `{callers:[],status:"unavailable",source:"unavailable"}`, exit 2 |
| `bash "$DRAFT_TOOLS/graph-snippet.sh" --qualified N` | verified source + caller/callee counts | `{status:"unavailable",source:"unavailable"}`, exit 2 |
| `bash "$DRAFT_TOOLS/graph-search.sh" --query "STR" [--limit N]` | semantic/ranked search | `{results:[],source:"unavailable"}`, exit 2 |
| `bash "$DRAFT_TOOLS/graph-tests.sh" (--symbol N \| --untested)` | test→symbol coverage | `{tests:[]/untested:[],source:"unavailable"}`, exit 2 |
| `bash "$DRAFT_TOOLS/graph-deps.sh" [--file PATH]` | real IMPORTS graph | `{imports:[],source:"unavailable"}`, exit 2 |
| `bash "$DRAFT_TOOLS/graph-hierarchy.sh" [--symbol N \| --derived N]` | INHERITS tree | `{edges:[],source:"unavailable"}`, exit 2 |
| `bash "$DRAFT_TOOLS/graph-errors.sh" (--symbol N \| --type N)` | RAISES/THROWS | `{raises:[]/raisers:[],source:"unavailable"}`, exit 2 |
| `bash "$DRAFT_TOOLS/graph-risk.sh" [--min-complexity N]` | pre-computed risk flags | `{risky:[],source:"unavailable"}`, exit 2 |
| `bash "$DRAFT_TOOLS/graph-query.sh" (--cypher STR \| --tool NAME --json '{...}')` | generic read-only passthrough | `{source:"unavailable"}`, exit 2 |
| `bash "$DRAFT_TOOLS/graph-traces.sh" ingest --file F --experimental` | runtime traces (experimental write) | `{source:"unavailable"}`, exit 2 |

For lower-level modes, call the engine directly: `codebase-memory-mcp cli <tool> '<json>'` (see the tool list in [bin/README.md](../../bin/README.md)).

### Capability wrappers & dialect limits (graph-tooling-v2)

All Cypher lives in `scripts/tools/_graph_queries.sh` (the single source of query
truth). Wrappers are thin arg-parse → builder → fail-loud JSON. Three contracts
matter when consuming them:

**Fail-loud status.** Symbol-scoped wrappers (`graph-callers`, `graph-snippet`,
`graph-tests --symbol`, `graph-hierarchy --symbol/--derived`, `graph-errors`)
emit a `status` field that distinguishes the three real outcomes — never read a
bare `[]` as a confirmed true negative:

| `status` | Meaning |
|---|---|
| `ok` | node found, edges returned |
| `no-edges` | node exists but has no matching edge (a *real* negative) |
| `no-match` | the named symbol was not found at all (check the name / try `--qualified`) |
| `unavailable` | engine could not be resolved (exit 2) |

**Verified engine param shapes** (engine v0.8.x — the runtime source of truth is
`get_graph_schema`; do not hardcode a property set):

```bash
get_code_snippet '{"project":P,"qualified_name":"pkg.Mod.Class.method"}'   # → source + callers/callees counts + transitive_loop_depth
search_graph     '{"project":P,"query":"order submission to broker","limit":5}'  # → {results:[{name,qualified_name,label,file_path,rank}]}
trace_path       '{"project":P,"function_name":"submit_order","depth":3,"direction":"both"}'  # depth-bounded caller EXPANDER, not an A→B pathfinder
detect_changes   '{"project":P}'    # → {changed_files, changed_count, impacted_symbols, depth}
get_graph_schema '{"project":P}'    # → {node_labels:[{label,count,properties}], edge_types:[{type,count}]}
```

**Cypher dialect — keep queries inside the SAFE set:**

- ✅ SAFE: fixed-length patterns, single/multi-hop explicit patterns, `=`, `<`,
  `STARTS WITH`, `NOT x STARTS WITH`, `AND`, `OR`, relationship-type alternation
  `[:A|B]`, simple `count(x)`.
- ❌ UNSAFE (rejected or silently empty): `coalesce()`, `<>` / `!=` / `<=` / `>=`,
  `NOT EXISTS(...)`, `NOT (pattern)`, `WITH`-grouping aggregation, multi-pattern
  joins. `graph-query.sh --cypher` returns the engine's raw error, not a silent
  empty — but the builders never emit these forms.

**Caveats consumers must respect:**

- **`--prod-only` is best-effort.** It filters `is_test=false AND NOT file_path
  STARTS WITH 'tests/'`. `is_test` is partially populated by the engine, so test
  helpers/mocks can leak through. Treat it as a heuristic, not a guarantee.
- **`--transitive` uses the `trace_path` expander** (a depth-bounded caller
  expansion from one symbol), not a from→to pathfinder. "Path between A and B"
  still needs an explicit fixed-length `graph-query.sh --cypher` pattern.
- **Honest caps.** `cycle-detect`, `graph-deps`, `graph-risk`, `graph-tests
  --untested` cap their output and report `"truncated": true` when the cap is
  hit — results are a sample, not exhaustive.
- **`graph-tests --untested`** is a set difference (exported symbols minus TESTS
  targets) because the dialect has no anti-join; coverage depends on the engine
  resolving test→symbol links, which varies by language/framework.

## Pre-Check

Verify graph data exists before any graph operation:

```bash
ls draft/graph/schema.yaml 2>/dev/null
```

If absent, **skip all graph operations silently**. Graph enriches analysis — it never gates it. All skills must work identically without graph data.

## Engine model (engine-only)

The graph is produced by the **codebase-memory-mcp** engine (a single binary; see [bin/README.md](../../bin/README.md)). Draft is **engine-only and opinionated**: the engine is the one structural source of truth, queried live. There is **no committed machine-readable mirror** of the graph — no `architecture.json`, `hotspots.jsonl`, `*.mermaid`, or `okf/`. Those were lossy, went stale on the next commit, and duplicated what the engine serves precisely on demand.

The only committed file is the gate marker:

| File | Role |
|------|------|
| `draft/graph/schema.yaml` | Engine + project metadata and point-of-index counts (provenance, not authoritative). Carries **no graph data**. Its presence is the **gate** (see Pre-Check) — it signals the engine is wired for this repo. Written by `scripts/tools/graph-snapshot.sh`. |

All structural data is obtained live by shelling out to the engine — either through the query-tool wrappers under `scripts/tools/` or directly via `codebase-memory-mcp cli <tool> '<json>'`. The shell tools auto-index the repo into the engine's own cache on demand, so no committed files are required.

### How skills query (engine is the interface; jq is optional)

- **The engine is the query.** `codebase-memory-mcp cli <tool> '<json>'` (and the wrappers that call it) is how you ask — it takes JSON args and returns JSON. There is no other query surface.
- **Prefer the wrappers — they resolve the engine for you.** `graph-arch.sh` (architecture view: packages/routes/layers/hotspots), `graph-callers.sh`, `hotspot-rank.sh`, `graph-impact.sh`, `cycle-detect.sh`, `mermaid-from-graph.sh` return already-shaped JSON. The engine binary is usually **not on `$PATH`** (it lives under `~/.cache/draft/bin/`); the wrappers locate it via `_lib.sh:find_memory_bin`, so a skill using a wrapper needs no resolution step.
- **Raw `codebase-memory-mcp cli` requires resolving the binary first** (it is not on `$PATH`): `CM="${DRAFT_MEMORY_BIN:-$HOME/.cache/draft/bin/codebase-memory-mcp}"; "$CM" cli <tool> '<json>'`. Reach for this only for tools without a wrapper (`search_graph`, `search_code`, `trace_path`).
- **`jq` is not a query tool — it only trims output.** Reach for it solely to slice a *large* response (chiefly the `get_architecture` blob) down to the field you need, for token economy. The agent can read raw JSON directly; jq is an optimization, not a requirement. Don't pipe wrapper output through jq unless you genuinely need a sub-field.

The engine uses a **unified, language-agnostic** node model — `Function`, `Method`, `Class`, `Module`, `File`, `Folder`, `Route`, `Section`, `Variable` (language is inferred from file extension) — and edges `CALLS`, `DEFINES`, `CONTAINS_FILE`, `IMPORTS`, `HTTP_CALLS`, `FILE_CHANGES_WITH`, `SEMANTICALLY_RELATED`, `SIMILAR_TO`. Each node carries `file_path` + `start_line`/`end_line` and rich `properties` (complexity, signature, parent_class), and the engine exposes full-text (`search_code`) and semantic search — none of which a committed snapshot reproduced.

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

Query the engine's architecture view live with the `graph-arch.sh` wrapper (it resolves the engine, indexes on demand, and auto-resolves the project):

```bash
scripts/tools/graph-arch.sh --repo . \
  | jq '{packages, node_labels, edge_types, routes, layers, boundaries}'
```

`.packages` gives module fan-in/out, `.node_labels`/`.edge_types` the shape, `.routes` the service surface, `.layers`/`.boundaries` the dependency direction.

### Mermaid — diagram text

```bash
scripts/tools/mermaid-from-graph.sh --repo . --diagram module-deps   # co-change coupling
scripts/tools/mermaid-from-graph.sh --repo . --diagram proto-map     # detected routes
```

Emits a ready-to-inject ` ```mermaid ``` ` block on the fly (computed live by the engine), or an empty stub (exit 2) when the engine is unavailable. Diagrams are generated at the moment of use — they are never committed.

### Snippet — verified source + caller/callee counts

```bash
scripts/tools/graph-snippet.sh --repo . --qualified <pkg.Mod.Class.method>
```

Output: `{qualified_name, file, start_line, end_line, callers, callees, transitive_loop_depth, complexity, code, status, source}`. Prefer this over grep+Read when you have a qualified name — it returns the engine's attributed source plus pre-computed counts.

### Search — semantic / ranked symbol lookup

```bash
scripts/tools/graph-search.sh --repo . --query "auth token refresh" [--limit N]
```

Output: `{query, results[{name, qualified_name, label, file, rank}], total, source}`. Use when the user names an **intent/concept** rather than an exact symbol — this is the first move in the Concept-to-Files recipe.

### Tests — coverage edges and untested surface

```bash
scripts/tools/graph-tests.sh --repo . --symbol <name>     # tests covering a symbol
scripts/tools/graph-tests.sh --repo . --untested          # exported symbols with no TESTS edge
```

Output: `{symbol, tests[{test,file}], status, source}` or `{untested[{symbol,file}], total, truncated, source}`. Feeds coverage gaps for `init`/`testing-strategy`/`coverage`.

### Deps — real module/file import graph

```bash
scripts/tools/graph-deps.sh --repo . [--file PATH]
```

Output: `{imports[{src,dst}], total, truncated, source}` from actual `IMPORTS` edges (self-imports filtered). This is the auto-derived dependency graph behind `mermaid-from-graph.sh --diagram module-deps` and `architecture.md §9`.

### Hierarchy — class inheritance

```bash
scripts/tools/graph-hierarchy.sh --repo . [--symbol <Class> | --derived <Base>]
```

Output: `{edges[{child,parent}], status, source}`. `--derived` gives the blast radius of changing a base class.

### Errors — error-propagation paths

```bash
scripts/tools/graph-errors.sh --repo . --symbol <name>   # what it raises/throws
scripts/tools/graph-errors.sh --repo . --type <ErrType>  # who raises/throws that type
```

Output: `{symbol, raises[...], status, source}` or `{type, raisers[...], status, source}`. `--type` drives fail-closed audits.

### Risk — pre-computed risk hotspots

```bash
scripts/tools/graph-risk.sh --repo . [--min-complexity N]
```

Output: `{risky[{symbol, file, complexity, flags}], total, truncated, source}` from the engine's pre-computed flags (`unguarded_recursion`, `recursion_in_loop`, `alloc_in_loop`, `linear_scan_in_loop`). High-signal input for `bughunt`/`deep-review` — the engine already found these.

### Generic — read-only escape hatch (all 20 edges / ~30 properties)

```bash
scripts/tools/graph-query.sh --repo . --cypher 'MATCH (f)-[:WRITES]->(v) RETURN f.name, v.name LIMIT 50'
scripts/tools/graph-query.sh --repo . --tool get_graph_schema --json '{}'
```

Unlocks any edge type or node property without a purpose-built wrapper. Write verbs are rejected; stay inside the SAFE dialect set (above). Emits raw engine JSON.

### Indexing / refreshing the gate marker

```bash
scripts/tools/graph-snapshot.sh --repo .
```

Indexes the repo into the engine and writes the `draft/graph/schema.yaml` gate marker (now including the `detect_changes` delta: `changed_files`/`impacted_symbols`). It writes **no** graph data. Run during `/draft:init` and `/draft:graph`, or whenever the index should be refreshed.

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

## Indexing the Repo

Run during `draft:init` / `draft:graph`, or manually:

```bash
scripts/tools/graph-snapshot.sh --repo .
```

The engine indexes C/C++, Go, Python, TypeScript/JS, and more (tree-sitter, 159 languages) plus LSP-assisted resolution for the major ones, and detects HTTP/gRPC/GraphQL routes. Indexing is incremental in the engine (content-based, git-aware). This refreshes the engine index and rewrites the `schema.yaml` gate marker; it produces no committed graph data.

## Graceful Degradation

| Scenario | Behavior |
|----------|----------|
| No engine resolvable (or `DRAFT_MEMORY_DISABLE=1`) | Skip graph indexing in init; all skills proceed without graph data; tools emit `source: unavailable` |
| Engine present but a query fails | Warn and proceed; skills work without graph data |
| `draft/graph/schema.yaml` exists | Engine is wired — use live query tools as needed during the run |
| Engine index out of date | The engine indexes incrementally (content-based, git-aware) on each query, so it self-freshens. Re-run `graph-snapshot.sh` (or init) to force a reindex and refresh the marker. |
