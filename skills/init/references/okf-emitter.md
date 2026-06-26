## Init — OKF Taxonomy Emitter (DRAFT_INIT_MODE=okf)

> Progressive-disclosure reference for `/draft:init`. Covers the OKF emitter:
> type vocabulary, frontmatter contract, generation pipeline, render views,
> incremental refresh, and the `okf-validate.sh` gate. Authoritative HLD:
> `hld-draft-init-okf-taxonomy.md` at the repo root.

This is the `/draft:init` output mode for **tier 3+ repos**, where it is the
**tier-gated default** (`DRAFT_INIT_MODE` unset → tier 1–2 `monolith`, tier 3–5
`okf`; an explicit `DRAFT_INIT_MODE=monolith|okf` overrides). `monolith` is
retained — the tier-1/2 default, the A/B baseline, and the over-fetch fallback.
The default rests on maintainability/readability, not the benchmark (parity).

```bash
# Mode gate — default is tier-gated 'auto', finalized after Step 1.4.5 (tier):
DRAFT_INIT_MODE="${DRAFT_INIT_MODE:-auto}"
case "$DRAFT_INIT_MODE" in
  monolith|okf) : ;;             # explicit override — honored as-is
  auto) : ;;                     # resolve from tier: 1–2 → monolith, 3–5 → okf
  *) echo "Unknown DRAFT_INIT_MODE='$DRAFT_INIT_MODE' (monolith|okf|auto); using auto" >&2
     DRAFT_INIT_MODE=auto ;;
esac
```

Everything else in `/draft:init` (5-phase analysis, graph snapshot, `.state/`
hashing, scope detection, atomic staging) is **reused unchanged**. This mode adds
a decomposition + serialization stage. It introduces **no new LLM analysis
engine**; its deterministic helpers are `okf-plan-concepts.sh` (expected-concept
set), `okf-validate.sh` (structure), `okf-validate-quality.sh` (per-type
anti-stub), `okf-coverage-check.sh` (completeness), and `okf-validate-all.sh`
(the single promotion gate that runs all three), plus `okf-render-views.sh`.

## Target layout

`okf` mode changes **only** the `architecture.md` / `.ai-context.md` packaging
and adds `wiki/`. **Every other standard `/draft:init` file is still produced**
— `product.md`, `tech-stack.md`, `workflow.md`, `guardrails.md`, `index.md`,
`.ai-profile.md`, `tracks/` + `tracks.md`, `.state/`, `graph/` — exactly as in
`monolith` mode. Do **not** skip them: emitting only the bundle is a regression.

```
draft/
├── .ai-context.md         # INDEX ROOT: synopsis (150–250 lines) + Concept Map
├── architecture.md        # RENDERED VIEW (generated from bundle; not source of truth)
├── .ai-profile.md         # always-injected profile (derived from .ai-context.md)  [SAME AS MONOLITH]
├── product.md             # [SAME AS MONOLITH]
├── tech-stack.md          # [SAME AS MONOLITH]
├── workflow.md            # [SAME AS MONOLITH]
├── guardrails.md          # [SAME AS MONOLITH]
├── index.md               # docs index — lists prose files + wiki/  [SAME AS MONOLITH, +wiki link]
├── tracks.md  +  tracks/  # [SAME AS MONOLITH]
├── wiki/                   # OKF bundle (source of truth) — okf-mode ONLY
│   ├── index.md            # bundle root + Concept Map
│   ├── overview/{index,architecture,getting-started,glossary}.md
│   ├── systems/{index,<subsystem>}.md
│   ├── features/{index,<feature>}.md
│   ├── reference/{index,<ref>}.md      # config, deps, data models, ADRs, runbooks
│   ├── entrypoints/<app>.md
│   ├── web/index.html      # optional offline viewer (okf-render-views.sh --web)
│   └── log.md              # chronological change history (from .state run memory)
├── graph/schema.yaml       # [SAME AS MONOLITH] engine gate marker
└── .state/
    ├── hashes.json             # file → content hash  [SAME AS MONOLITH]
    ├── path-to-concept.json    # NEW: source path → concept page(s) it grounds
    └── signals.json            # [SAME AS MONOLITH]
```

The standard project files come from the same generators as `monolith` mode
(intake questions → `product.md`; tech detection → `tech-stack.md`; `/draft:learn`
→ `guardrails.md`; templates → `workflow.md`, `index.md`, `tracks.md`,
`.ai-profile.md`). The OKF emitter only *replaces the architecture packaging*; it
never owns or removes the rest of the context directory.

Templates for each bundle page live in `core/templates/okf/` (`index.md`,
`concept.md`, `section-index.md`, `ai-context-index.md`).

## Frozen `type` vocabulary

Every concept carries a `type` from this frozen set (changing it churns every
file; versioned via the `okf-types-version` comment in the wiki root `index.md`
body — OKF §6/§11 permit only `okf_version` in an index file's frontmatter):

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

**Meta pages are not concepts.** Index files (`wiki/index.md` and every
`<section>/index.md`) carry **no concept frontmatter**: per OKF §6 an index file
has no frontmatter, and per §11 the root `index.md` may declare **only**
`okf_version`. The tool-generated `systems/coverage.md` is a non-reserved file, so
OKF §9.1/§9.2 require it to carry a typed frontmatter block; it uses a descriptive
`type: Report` and is exempt from the frozen vocabulary via `is_meta_page`
(basename + the `<!-- okf:coverage-generated -->` marker). `okf-validate.sh`
short-circuits all meta pages before the concept checks, so they are never
vocab-checked or counted as concepts.

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
2. Plan          → DETERMINISTIC. okf-plan-concepts.sh derives the expected-concept
                   set from the graph. EVERY package the graph knows about is
                   required (fan_in ≥ floor → Subsystem; below floor → Module — the
                   floor only types/orders, it never exempts); entrypoints → required;
                   only --allow-defer matches are deferred (with a reason). Writes
                   draft.tmp/.state/concept-plan.json.
                     okf-plan-concepts.sh --repo . [--scope PATH] \
                       [--manifest FILE] [--min-fan-in 2] [--allow-defer GLOB]... \
                       --out draft.tmp/.state/concept-plan.json
                   This replaces the old in-context concept enumeration — the boundary
                   of the work is now a tool output, not an LLM judgment, so modules
                   and sub-modules cannot be silently dropped. (Legacy fan-in
                   exemption is opt-in via --defer-below-floor.) LOG the counts
                   (expected/required/deferred) BEFORE writing any page.
                   `generated_order` is topo-ish (required + high-fan-in first) so
                   forward cross-links resolve.
3. Generate      → iterate concept-plan.generated_order; write ONE page per REQUIRED
                   entry, grounding each from the graph:
                     x-callers        ← graph-callers.sh --symbol <c>
                     x-grounded-paths  ← graph-impact.sh  --symbol <c>  (blast radius)
                     x-hotspot-score   ← hotspot-rank.sh
                     overview diagrams ← mermaid-from-graph.sh
                   Record each source path → page in .state/path-to-concept.json.
                   Loop post-condition: every required concept_id has an output file.
                   ⚠ Writing pages via shell heredoc without reading x-grounded-paths
                   sources, or finishing while any required entry is unwritten, is a
                   completeness failure — not a stylistic one.
4. Render views  → ai-context.md (synopsis + Concept Map), architecture.md
                   (concatenated view + coverage banner), wiki/log.md  (see M4).
5. Validate      → the promotion gate. Run all layers via the orchestrator:
                     5a. okf-validate-all.sh draft.tmp/wiki \
                           --repo . \
                           --plan draft.tmp/.state/concept-plan.json \
                           --path-index draft.tmp/.state/path-to-concept.json \
                           --strict --report draft.tmp/.state/validation-report.json
                   It runs, in order: okf-validate.sh (structure + reverse index +
                   empty/untyped-page + leftover-template-token + dangling-link checks),
                   okf-validate-quality.sh (per-type anti-stub / depth / per-section
                   content / mermaid lint), okf-coverage-check.sh (every required plan
                   entry → real page).
                   ANY layer failing ⇒ exit non-zero ⇒ DO NOT atomic-rename.
                   coverage.md (systems/coverage.md) is regenerated by the coverage
                   layer; it is tool-owned (marker <!-- okf:coverage-generated -->) —
                   never hand-author it except deferral reasons in the manifest.
6. Emit          → mv draft.tmp/ draft/  ONLY IF step 5 exit 0 ; update .state/.
                   On failure keep draft.tmp/ and surface validation-report.json.
```

### Validation report schema (`.state/validation-report.json`)

```json
{ "valid": false, "bundle": "draft.tmp/wiki",
  "layers": { "structure": "pass", "quality": "pass", "coverage": "fail" } }
```

### Component manifest (optional — `--manifest FILE`)

When the graph engine is unavailable (or a repo wants an authoritative list), pass
a plain-text manifest: one component name per line, `#` comments and blanks ignored.
Every listed component becomes a REQUIRED concept; `--allow-defer GLOB` still moves
matches to deferred. Without a manifest the plan comes from the graph, and only if
both are unavailable does it fall back to a heuristic top-level-dir scan (which it
marks `degraded: true`).

Page bodies are LLM-narrated for readability **but** the graph-derived
frontmatter and the `Blast radius`/`Used by` sections are deterministic. To keep
incremental carry-forward byte-identical (open decision 2), cache the narrated
prose keyed by the source hash of `x-grounded-paths` — unchanged sources reuse
the cached narration verbatim.

## Render views (M4)

Both are produced by the deterministic helper `okf-render-views.sh` (no LLM) —
regenerated on every init/refresh so they never drift from the bundle:

```bash
okf-render-views.sh draft/wiki \
  --arch-out draft/architecture.md \
  --section-indexes \
  --concept-map-into draft/wiki/index.md \
  --concept-map-into draft/.ai-context.md \
  --web draft/wiki/web/index.html
```

- `--arch-out` renders the linear `architecture.md` (banner + TOC + every concept
  page in canonical section order, frontmatter stripped, Mermaid preserved).
- `--section-indexes` rebuilds each `<section>/index.md` concept table (between its
  `CONCEPT-MAP` markers) from the pages that actually exist in that directory. This
  is mandatory: section indexes are NOT hand-authored — building them from real
  files is what makes their links impossible to dangle. Never write a section
  index "Concepts" table by hand.
- `--concept-map-into` rebuilds the routing table between the
  `<!-- CONCEPT-MAP:START -->` / `:END` markers from each concept's `title` +
  `type` + `description` (section `index.md` pages excluded).
- `--web` writes a **self-contained offline HTML viewer** (single file: all pages
  inlined as JSON + a built-in markdown renderer + sidebar nav + search). Works by
  double-click — no server, no internet, no CDN. Optional, human-facing; regenerate
  on refresh like the other views. (Mermaid blocks render as labeled source since a
  graphical engine can't be inlined offline.)

All views write into `draft/` (the OKF emitter never creates a separate output
dir): `draft/wiki/` is the bundle, `draft/architecture.md` + `draft/.ai-context.md`
are the rendered views, `draft/wiki/web/index.html` is the optional viewer.

The two views:

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
1. Re-derive the plan: okf-plan-concepts.sh (modules added since last run become
   REQUIRED — a new package can't slip through a refresh either)
2. Diff hashes.json vs working tree     → changed source paths
3. path-to-concept.json                 → affected concept pages
4. Regenerate ONLY affected concepts; carry the rest verbatim (cached narration)
5. Re-render ai-context.md / architecture.md / log.md (cheap; always regenerated)
6. Re-validate (full gate): okf-validate-all.sh on the bundle with --plan and
   --path-index. Refresh re-runs structure + quality + coverage — a changed
   concept must still clear the quality bar, and a newly-required module must
   still be present.
7. Append log.md; update hashes.json + path-to-concept.json
```

A 1-file change regenerates only the concept(s) that file grounds. Unchanged
concepts are byte-identical across runs. The full gate still runs, so refresh
cannot promote a bundle that a newly-added module left incomplete.

## Backward compatibility (§9)

- `architecture.md` is retained as a rendered view (brownfield audit + grep keep
  working).
- `ai-context.md`'s Synopsis preserves the prior content shape; the Concept Map
  is additive.
- `/draft:review` and downstream command contracts are unchanged — they consume
  `architecture.md` / `ai-context.md`, both of which still exist.

## Default policy & retirement of `monolith`

`okf` is the **tier-gated default** (tier 3+); `monolith` is the tier-1/2 default
and remains in place as the A/B baseline + over-fetch fallback. Full retirement of
`monolith` is deferred until **both**: (1) the large-monolith A/B run shows `okf` ≥
baseline on tokens at parity accuracy (the regime the §12 benchmark flagged), and
(2) a human-onboarding eval confirms the wiki + generated `architecture.md` covers
linear onboarding. Note: retiring `monolith` would not remove `architecture.md` —
it is generated from the bundle regardless — so there is no readability gain from
deletion, only lost optionality.
