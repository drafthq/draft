## Init — OKF Taxonomy Emitter (DRAFT_INIT_MODE=okf)

> Progressive-disclosure reference for `/draft:init`. Covers the OKF emitter:
> type vocabulary, frontmatter contract, generation pipeline, render views,
> incremental refresh, and the `okf-validate.sh` gate. Authoritative HLD:
> `hld-draft-init-okf-taxonomy.md` at the repo root.

This is the **alternate** `/draft:init` output mode. It is **off by default**:
`monolith` mode (the existing `architecture.md` + `.ai-context.md` path) is
untouched and remains the clean A/B baseline. Select this mode only when
`DRAFT_INIT_MODE=okf` is set in the environment.

```bash
# Mode gate (read once, early in init):
DRAFT_INIT_MODE="${DRAFT_INIT_MODE:-monolith}"
case "$DRAFT_INIT_MODE" in
  monolith) : ;;                 # existing behavior — do nothing here
  okf)      : ;;                 # this emitter
  *) echo "Unknown DRAFT_INIT_MODE='$DRAFT_INIT_MODE' (monolith|okf); defaulting to monolith" >&2
     DRAFT_INIT_MODE=monolith ;;
esac
```

Everything else in `/draft:init` (5-phase analysis, graph snapshot, `.state/`
hashing, scope detection, atomic staging) is **reused unchanged**. This mode adds
a decomposition + serialization stage. It introduces **no new LLM analysis
engine** and exactly **one** new deterministic helper, `okf-validate.sh`.

## Target layout

The bundle is the new source of truth. `architecture.md` is demoted to a
rendered view; `ai-context.md` becomes the index root.

```
draft/
├── ai-context.md          # INDEX ROOT: synopsis (150–250 lines) + Concept Map
├── architecture.md        # RENDERED VIEW (concat from bundle; not source of truth)
├── wiki/                   # OKF bundle (source of truth)
│   ├── index.md            # bundle root + Concept Map
│   ├── overview/{index,architecture,getting-started,glossary}.md
│   ├── systems/{index,<subsystem>}.md
│   ├── features/{index,<feature>}.md
│   ├── reference/{index,<ref>}.md      # config, deps, data models, ADRs, runbooks
│   ├── entrypoints/<app>.md
│   └── log.md              # chronological change history (from .state run memory)
└── .state/
    ├── hashes.json             # file → content hash (existing)
    ├── path-to-concept.json    # NEW: source path → concept page(s) it grounds
    └── signals.json            # existing
```

Templates for each page live in `core/templates/okf/` (`index.md`, `concept.md`,
`section-index.md`, `ai-context-index.md`).

## Frozen `type` vocabulary

Every concept carries a `type` from this frozen set (changing it churns every
file; versioned via `index.md` frontmatter `okf_types_version`):

| type | Maps to | Home |
|------|---------|------|
| `Subsystem` | major graph cluster / package boundary | `systems/` |
| `Module` | single package/dir, cohesive responsibility | `systems/` |
| `Feature` | user-facing capability spanning modules | `features/` |
| `Entrypoint` | binary / main / CLI / handler root | `entrypoints/` |
| `API` | public interface, route group, RPC surface | `reference/` |
| `DataModel` | schema, table, core struct/type | `reference/` |
| `Dependency` | notable external dep + how it's used | `reference/` |
| `ADR` | architecture decision record | `reference/` |
| `Runbook` | operational procedure | `reference/` |

`okf-validate.sh` enforces this set as ground truth — an out-of-vocab `type`
fails the build.

## Frontmatter contract

Per concept page (see `core/templates/okf/concept.md`). Required OKF keys:
`type`, `title`, `description`, `resource`. **`description` is the load-bearing
routing key** — write it as a routing decision ("should the agent open this for
the task at hand?"), never a summary. Draft extensions are namespaced `x-` and
ignored by generic OKF consumers: `x-grounded-paths`, `x-hotspot-score`,
`x-callers`.

## Concept granularity (resolves open decision 1)

Derive concepts from the graph, not by hand:

- A **Subsystem** = a graph cluster (package/dir boundary) with `fan_in ≥ 2` from
  other clusters, OR a top-ranked module from `hotspot-rank.sh`.
- A **Module** = a cohesive package/dir below a subsystem that is *not* itself a
  cluster boundary but has its own hotspot or public surface.
- A **Feature** = a capability the graph shows spanning ≥2 modules (shared
  callers / a route group touching multiple packages).
- Default cap: one page per package boundary; do not split a package into
  multiple concept pages unless it has >1 distinct public surface. This keeps
  page count ≈ module count and navigation depth shallow.

## Generation pipeline (M3)

```
1. Survey        → existing /draft:init 5-phase + graph snapshot (graph-snapshot.sh)
2. Plan          → derive the concept list (above) from graph clusters +
                   entrypoints + features. Topo-sort by dependency so pages that
                   others link to (overview, core subsystems) generate FIRST —
                   forward cross-links resolve.
3. Generate      → per concept, pull grounding from the graph and write the page:
                     x-callers        ← graph-callers.sh --symbol <c>
                     x-grounded-paths  ← graph-impact.sh  --symbol <c>  (blast radius)
                     x-hotspot-score   ← hotspot-rank.sh
                     overview diagrams ← mermaid-from-graph.sh
                   Record each source path → page in .state/path-to-concept.json.
4. Render views  → ai-context.md (synopsis + Concept Map), architecture.md
                   (concatenated view), wiki/log.md  (see M4).
5. Validate      → okf-validate.sh draft/wiki \
                     --path-index draft/.state/path-to-concept.json
                   FAIL the build (do not atomic-rename) on any dangle, missing
                   field, bad type, or path-index gap.
6. Emit          → mv draft.tmp/ draft/ ; update .state/.
```

Page bodies are LLM-narrated for readability **but** the graph-derived
frontmatter and the `Blast radius`/`Used by` sections are deterministic. To keep
incremental carry-forward byte-identical (open decision 2), cache the narrated
prose keyed by the source hash of `x-grounded-paths` — unchanged sources reuse
the cached narration verbatim.

## Render views (M4)

Both are cheap, deterministic concatenations from the bundle — regenerated on
every run:

- **`ai-context.md`** (index root) — from `core/templates/okf/ai-context-index.md`:
  the Synopsis preserves the prior `.ai-context.md` content shape (so existing
  downstream consumers keep working); the Concept Map is built from each
  concept's `description`. Broad tasks terminate here.
- **`architecture.md`** (rendered view) — TOC + per-concept section concat +
  Mermaid, in topo order. Demoted, not deleted: the brownfield Context Quality
  Audit and any command grepping `architecture.md` keep working (§9 of the HLD).
- **`wiki/log.md`** — appended from `.state/` run memory.

The `<!-- CONCEPT-MAP:START -->` / `:END` markers in `wiki/index.md` and the
section `index.md` tables are the injection slots for the routing tables.

## Incremental refresh at concept granularity (M5)

`/draft:init refresh` under `okf` mode:

```
1. Diff hashes.json vs working tree     → changed source paths
2. path-to-concept.json                 → affected concept pages
3. Regenerate ONLY affected concepts; carry the rest verbatim (cached narration)
4. Re-render ai-context.md / architecture.md / log.md (cheap; always regenerated)
5. Re-validate: okf-validate.sh on the bundle + path-index (cross-links touching
   changed concepts must still resolve)
6. Append log.md; update hashes.json + path-to-concept.json
```

A 1-file change regenerates only the concept(s) that file grounds. Unchanged
concepts are byte-identical across runs.

## Backward compatibility (§9)

- `architecture.md` is retained as a rendered view (brownfield audit + grep keep
  working).
- `ai-context.md`'s Synopsis preserves the prior content shape; the Concept Map
  is additive.
- `/draft:review` and downstream command contracts are unchanged — they consume
  `architecture.md` / `ai-context.md`, both of which still exist.

## Merge gate

`okf` becomes the default on `main` only after the §12 A/B benchmark shows
`okf` ≥ baseline on task accuracy at acceptable token cost
(`docs/audit/okf-benchmark.md`). Until then this mode is opt-in via
`DRAFT_INIT_MODE=okf`.
