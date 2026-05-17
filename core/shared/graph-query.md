# Graph Query Subroutine

Shared procedure for querying the knowledge graph from any skill. The graph provides precise, deterministic structural data about the codebase — module boundaries, dependency edges, hotspots, proto API surface, and symbol indexes.

This is the **single source of truth** for graph lookup procedure. Consumer skills MUST reference this file rather than inlining their own lookup logic.

Referenced by: `/draft:init`, `/draft:implement`, `/draft:bughunt`, `/draft:review`, `/draft:deep-review`, `/draft:quick-review`, `/draft:debug`, `/draft:decompose`, `/draft:new-track`, `/draft:tech-debt`, `/draft:deploy-checklist`, `/draft:learn`, `/draft:index`

## Mandatory Lookup Contract

Any code-touching skill that needs to discover files, modules, symbols, callers, or blast-radius **MUST** follow this lookup order whenever `draft/graph/schema.yaml` exists:

1. **Graph artifacts first** — `module-graph.jsonl`, `hotspots.jsonl`, `modules/<name>.jsonl`, `proto-index.jsonl`, `{go,python,ts,c,call}-index.jsonl`.
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

1. **Concept → modules** — `grep` the concept token against `draft/graph/module-graph.jsonl` (`name`, `description` fields) and `draft/.ai-context.md` (module headings). Record the candidate module list.
2. **Modules → files/symbols** — for each candidate module, load `draft/graph/modules/<name>.jsonl`. Enumerate `file`, `*-func`, `*-class`, `ctags-sym` records. This is the authoritative file list for the module.
3. **Modules → risk ranking** — cross-reference `draft/graph/hotspots.jsonl`. High-fanIn files in the candidate modules are the most likely entry points for impact.
4. **Modules → public API** — for API-shaped concepts, consult `draft/graph/proto-index.jsonl` to find RPCs/services whose names or descriptions match.
5. **Graph miss → grep fallback** — only if steps 1–4 return nothing relevant, emit the fallback sentence and use `grep`/`find`. Narrow the search by file extension and exclude `node_modules`, `vendor`, `dist`, `build`, `.git`.

## Graph Usage Report (Mandatory Footer)

Every code-touching skill output MUST end with this footer block. The lint check `scripts/tools/check-graph-usage-report.sh` rejects outputs missing the section.

```md
## Graph Usage Report

- Graph files queried: <comma-separated list, e.g. `module-graph.jsonl, hotspots.jsonl, modules/scribe.jsonl` — or `NONE` with justification below>
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
| `graph_queries` | int | Number of graph artifacts loaded plus live `graph --query` invocations during the run |
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

## Graph Artifacts

When `draft/graph/` exists, it contains:

| File | Load | Content |
|------|------|---------|
| `schema.yaml` | Always | Metadata, stats, module list with file counts |
| `module-graph.jsonl` | Always | Module nodes + weighted inter-module dependency edges |
| `hotspots.jsonl` | Always | Files ranked by complexity score (lines + fanIn * 50) |
| `proto-index.jsonl` | Always | All proto services, RPCs, messages, enums |
| `go-index.jsonl` | When working in Go | Go functions, types, imports, `go-call` edges |
| `python-index.jsonl` | When working in Python | Python functions, classes, imports, `py-call` edges |
| `ts-index.jsonl` | When working in TS/JS | TypeScript/JS functions, classes, imports, `ts-call` edges |
| `c-index.jsonl` | When working in C/C++ | C/C++ functions, types, `c-call` edges |
| `call-index.jsonl` | When tracing call paths | All intra-file call edges across all languages |
| `hashes.json` | Never (build artifact) | Per-module SHA-256 hashes for `--incremental` builds |
| `modules/<name>.jsonl` | On demand | Per-module file graph: file nodes, include edges, cross-module edges, all language symbols + call edges |

### Per-Module JSONL Record Schema

All records in `modules/<name>.jsonl` have a `kind` field. Defined kinds:

| kind | Fields | Description |
|----------------|--------|-------------|
| `module` | `name, sizeKB, files` | Module metadata header (first record) |
| `file` | `id, lines, module, sizeKB` | C++ source file node |
| `include` | `source, target` | Intra-module C++ include edge |
| `cross-include`| `source, target` | Cross-module C++ include edge |
| `go-func` | `name, receiver, qualified, file, module, package, line, lines` | Go function/method (`receiver=null` for top-level) |
| `go-type` | `name, file, module, package, line, kind` | Go type (kind: struct/interface/alias/type) |
| `go-call` | `from, to, fromFile, module, line, resolved: false, confidence` | Go intra-file call edge (tree-sitter only). `confidence: direct` for bare identifier callees, `inferred` for selector calls (`obj.Foo`) where the receiver is collapsed away. |
| `py-func` | `name, receiver, file, module, line, lines` | Python function/method (receiver=null for top-level) |
| `py-class` | `name, bases[], file, module, line` | Python class definition |
| `py-call` | `from, to, fromFile, module, line, resolved: false, confidence` | Python intra-file call edge (tree-sitter only). `confidence: direct` for bare identifier callees, `inferred` for attribute calls (`obj.foo`). |
| `ts-func` | `name, file, module, line, lines, exported, class, async` | TypeScript/JS function, method, or arrow function |
| `ts-class` | `name, file, module, line, lines, exported, kind` | TS/JS class/interface/type (kind: class/interface/type) |
| `ts-call` | `from, to, fromFile, module, line, resolved: false, confidence` | TS/JS intra-file call edge (tree-sitter only). `confidence: direct` for bare identifier callees, `inferred` for member calls (`obj.foo`). |
| `c-func` | `name, file, module, line, lines, language, namespace` | C/C++ function definition |
| `c-type` | `name, file, module, line, kind, language` | C/C++ struct/class/enum definition |
| `c-call` | `from, to, fromFile, module, line, resolved: false, confidence` | C/C++ intra-file call edge (tree-sitter only). `confidence: direct` for bare identifier or qualified (`Foo::bar`) callees, `inferred` for field calls (`obj.foo` / `ptr->foo`). |
| `ctags-sym` | `name, file, module, line, ctagsKind, language` | Symbol from universal-ctags (Java, Rust, Ruby, etc.) |

**Call edge notes**: All `*-call` records have `resolved: false` — callee names are syntactic (as written in source), with no type resolution. The same logical call may appear multiple times if the same function calls the target repeatedly. Call edges are **intra-file only** — cross-file resolution requires type information not available in tree-sitter.

**Confidence field**: Each `*-call` record carries a `confidence` value:
- `direct` — callee is a bare identifier (e.g. `foo()` in Go/Python/TS/C, or `Foo::bar()` in C++). Higher signal: the name appeared as written without receiver collapsing.
- `inferred` — callee is the trailing name of a member/selector/attribute/field expression (`obj.foo()`, `ptr->foo()`, `bar.foo()`). Receivers with different types collapse to the same name, so name collisions across distinct functions are likely. Treat as a candidate set, not an authoritative edge.

Skills consuming call edges (`bughunt`, `review`, `debug`) should weight `direct` edges more strongly and treat `inferred` edges as exploratory leads rather than confirmed call paths.

**Always-load files** are compact and should be read during context loading for any task that touches code structure. **Per-module files** are loaded only when working within a specific module — limit to 2-3 module files per task.

## Query Modes

The graph binary supports live queries against the built graph. Use these when you need precise answers beyond what the always-load files provide.

### Callers — who depends on this file or calls this function?

**File callers** (path with `/` or extension — uses include-edge graph):

```bash
graph --repo . --out draft/graph --query --file auth/auth.h --mode callers
```

Output: `{target, callers[{file, module, type}], summary{intra, cross, total}}`

Use when: tracing who will be affected by changing a header or interface file.

**Function callers** (bare symbol name — uses call-index.jsonl):

```bash
graph --repo . --out draft/graph --query --symbol buildGoIndex --mode callers
```

Output: `{target, callers[{func, file, module, line, kind}], total, by_module{}, note}`

Use when: finding all functions that call a specific function, across all languages. Requires call-index.jsonl (generated during full graph build with tree-sitter enabled). Results are intra-file only — cross-file callers are not resolved.

### Impact — blast radius of changing a file

```bash
graph --repo . --out draft/graph --query --file <path> --mode impact
```

Output: `{target, impact{files, modules, affected_modules[], by_category{code,test,doc,config}, files_by_depth{}, files_by_category{}}, warning}`

Each impacted file is classified as `code | test | doc | config` (matching `scripts/tools/classify-files.sh`). `by_category` gives counts; `files_by_category` gives the file lists. Use the test bucket to size regression work, the doc bucket to flag stale references, and the config bucket to spot deployment-time risk.

Use when: assessing risk before modifying a file, especially hotspot files with high fanIn.

### Hotspots — complexity ranking

```bash
graph --repo . --out draft/graph --query --mode hotspots
```

Output: `{hotspots[{id, module, lines, fanIn}]}`

Optionally filter to a module: `--symbol <module_name>`

### Modules — dependency overview with cycles

```bash
graph --repo . --out draft/graph --query --mode modules
```

Output: `{modules[], dependencies[], cycles[], summary{modules, edges, cycles, hub_modules[]}}`

### Cycles — circular dependency detection

```bash
graph --repo . --out draft/graph --query --mode cycles
```

Output: `{cycles[], count, warning}`

### Mermaid — generate diagram text from existing graph

```bash
# Both diagrams as markdown-ready fenced blocks (raw text output)
graph --repo . --out draft/graph --query --mode mermaid

# Specific diagram as JSON with metadata
graph --repo . --out draft/graph --query --mode mermaid --symbol module-deps
graph --repo . --out draft/graph --query --mode mermaid --symbol proto-map
```

**Output format split** — important for skills consuming this mode:

| Invocation | Output format | Fields |
|---|---|---|
| No `--symbol` | Raw Markdown text | Fenced ` ```mermaid ``` ` blocks ready for injection into `.ai-context.md` |
| `--symbol module-deps` | JSON | `{ mermaid: string, filtered: boolean, stats: { nodes, edges, totalNodes, totalEdges } }` |
| `--symbol proto-map` | JSON | `{ mermaid: string, stats: { services, rpcs, modules } }` |

Use the no-`--symbol` form for direct injection. Use `--symbol` forms when you need metadata (whether the diagram was filtered, edge counts) alongside the diagram text.

Note: `draft/graph/module-deps.mermaid` and `draft/graph/proto-map.mermaid` are static files written only during a full graph build (`graph --repo`). Running `--query --mode mermaid` reads the current JSONL and is always current — prefer it over the static files.

## Finding the Graph Binary

The graph binary ships with the draft plugin. Detect it at runtime using the breadcrumb file written by `install.sh`, then fallback to known paths:

```bash
GRAPH_BIN=""

# Method 1: .draft-install-path breadcrumb (written by install.sh)
for breadcrumb in \
    "$HOME/.cursor/plugins/local/draft/.draft-install-path" \
    "$HOME/.claude-plugin/../.draft-install-path" \
    ; do
    if [ -f "$breadcrumb" ]; then
        PLUGIN_ROOT="$(cat "$breadcrumb")"
        if [ -x "$PLUGIN_ROOT/graph/bin/graph" ]; then
            GRAPH_BIN="$PLUGIN_ROOT/graph/bin/graph"
            break
        fi
    fi
done

# Method 2: search common install paths
if [ -z "$GRAPH_BIN" ]; then
    for candidate in \
        "$HOME/.cursor/plugins/local/draft/graph/bin/graph" \
        "$HOME/.claude/plugins/draft/graph/bin/graph" \
        "graph/bin/graph" \
        ; do
        # "graph/bin/graph" only resolves when CWD is the plugin root
        if [ -x "$candidate" ]; then
            GRAPH_BIN="$candidate"
            break
        fi
    done
fi

# Method 3: check PATH
if [ -z "$GRAPH_BIN" ]; then
    GRAPH_BIN="$(command -v graph 2>/dev/null || true)"
fi
```

## Building the Graph

Run during `draft:init` or manually:

```bash
"$GRAPH_BIN" --repo . --out draft/graph/
```

This analyzes C/C++, Go, Python, TypeScript/JS, and Proto source files. For Java/Rust/Ruby/Swift, universal-ctags is used if installed. Excludes generated files (`*.pb.*`, `*_generated*`), test files (`*_test.cc`, `*_test.go`), and vendored code.

**Incremental rebuild** (skip unchanged modules):

```bash
"$GRAPH_BIN" --repo . --out draft/graph/ --incremental
```

Uses `hashes.json` to detect which modules changed (content-based SHA-256, not mtime). Only changed modules are re-extracted. Always-load files (module-graph, hotspots, call-index, schema) are always recomputed.

## Graceful Degradation

| Scenario | Behavior |
|----------|----------|
| No graph binary | Skip graph build in init; all skills proceed without graph data |
| Graph binary but build fails | Warn and proceed; skills work without graph data |
| `draft/graph/` exists | Load always-load files during context loading; use on-demand queries as needed |
| Stale graph data | Graph data is still useful — structural changes are infrequent. Suggest re-running init to refresh. |
