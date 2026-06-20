# OKF Tree-Search Retrieval

Reasoning-based retrieval over the OKF knowledge bundle. When a project was emitted in `okf` mode (`draft/wiki/` exists), agents locate relevant context by **navigating the concept tree** — reading routing descriptions and descending only the matching subtrees — instead of loading sections by a static heuristic. No embeddings, no chunking, no similarity search: relevance is decided by reasoning over the tree, the same way a human expert scans a table of contents.

Referenced by: `core/shared/draft-context-loading.md` (Relevance-Scored Context Loading). Applies to every command that loads focused project context (`/draft:implement`, `/draft:bughunt`, `/draft:review`, `/draft:debug`, `/draft:change`).

> **Prior art.** This adapts the navigation model of [PageIndex](https://github.com/VectifyAI/PageIndex) (vectorless, reasoning-based RAG) to Draft's self-authored artifacts. Draft already builds the tree — the OKF bundle (`index.md` → section indexes → concept pages) is a table-of-contents whose `description` frontmatter is the per-node routing key. What this procedure adds is the **retrieval loop**: a reasoning descent over that tree. Draft does not need PageIndex's tree-*generation* engine (it authors the tree itself) and stays vectorless by design.

## When this applies

Apply tree-search retrieval when ALL of these hold:

1. `draft/wiki/` exists (project emitted in `okf` mode) **and** `draft/wiki/index.md` carries a populated `<!-- CONCEPT-MAP:START -->…:END -->` block.
2. A specific track or task is active (focused retrieval — broad tasks terminate at the Synopsis, see below).
3. The command benefits from focused context (the relevance-scoring conditions in `draft-context-loading.md`).

If `draft/wiki/` does **not** exist (monolith mode), skip this procedure entirely and use the static section-scoring table in `draft-context-loading.md`. The two are mutually exclusive: tree-search is the okf-mode retrieval path; section-scoring is the monolith path.

## The retrieval loop

The bundle is a tree: `.ai-context.md` (index root: Synopsis + Concept Map) → section indexes (`systems/`, `features/`, `reference/`, `entrypoints/`, `overview/`) → concept pages. Each node advertises a `description` routing key. Navigate it, do not flatten it.

```
1. Frame the query
   Extract routing terms from the active task: domain nouns from spec.md
   acceptance criteria, file paths / module names / tech terms from plan.md,
   and the primary concern (data flow, API, security, perf, config, …).

2. Enter at the root
   Read draft/.ai-context.md. The Synopsis is the cheap broad-context path —
   for a BROAD task (onboarding, architecture overview, "how does X work
   end-to-end") it is sufficient: TERMINATE here, do not descend.
   For a FOCUSED task, read the Concept Map (the root routing table).

3. Select subtrees (reason, don't match strings)
   For each Concept Map row, judge the `description` as a ROUTING DECISION:
   "does opening this concept help THIS task?" Score each candidate:
     - strong   — description names the task's responsibility or its own terms
     - possible — adjacent/depends-on the task area
     - skip     — unrelated
   Descend `strong` first; hold `possible` as a frontier for step 5.

4. Descend to leaves
   For a selected section, open its index.md and repeat step 3 against the
   section's concept rows (one routing description per concept). Open the
   matching concept page(s). A concept page is a LEAF — its `x-grounded-paths`
   are the exact source files the task should open; `Used by` / `x-callers`
   give the next hop if the task spans callers.

5. Expand only if under-covered
   If the opened leaves do not cover the task's routing terms, expand the
   highest-scored `possible` frontier node (step 3) and recurse. Otherwise stop.
```

## Routing decision criteria

The `description` frontmatter is load-bearing — it is written as a routing decision, not a summary (`core/templates/okf/concept.md`). Judge each node by:

| Signal | Descend when… |
|--------|---------------|
| Responsibility match | The description names the capability/module the task changes |
| Term overlap | Task's domain nouns / file paths appear in the description or `x-grounded-paths` |
| Caller/blast-radius reach | Task modifies a symbol whose `x-callers` / `Used by` point at this node |
| Concern alignment | Task's primary concern (security, perf, data flow) is this node's stated focus |

Reason about relevance — do not keyword-match. A concept whose description does not justify opening it for the task at hand is skipped even if a term coincidentally overlaps (similarity ≠ relevance).

## Termination & budget

- **Broad task** → terminate at the Synopsis (step 2). Do not open concept pages.
- **Focused task** → terminate when opened leaves cover the task's routing terms, or when **≤ 5 concept pages** have been opened (default budget; raise only if the task explicitly spans many subsystems, e.g. a cross-cutting refactor).
- **Depth** → the tree is shallow by construction (root → section → concept ≈ 2 hops). If a descent has not reached a leaf in 3 hops, stop and open the best leaf seen so far.
- **No match** → if no Concept Map row scores above `skip`, fall back to the Synopsis plus `## INVARIANTS` / `## FILES` / `## TEST` floor from `draft-context-loading.md`.

The minimum context floor from `draft-context-loading.md` (`META`, `INVARIANTS`, `TEST`, `FILES`) still applies and is always loaded regardless of the descent.

## Output contract (traceability)

Tree-search retrieval is explainable by construction — record the path taken, mirroring PageIndex's node-ID grounding:

- **Opened concepts** — the leaf pages selected, each with the one-line reason it was opened.
- **Grounded paths** — the union of `x-grounded-paths` across opened leaves: the precise source files the task will read or modify.
- **Skipped frontier** — `possible` nodes held but not expanded (so a follow-up task can resume from them).

Surface this trace when the command reports which context it loaded (e.g. `/draft:implement` plan preamble, `/draft:review` scope note). It replaces "loaded sections A, B, C" with "navigated to concepts X, Y because …".

## Degradation

| Scenario | Behavior |
|----------|----------|
| `draft/wiki/` missing | Skip; use monolith section-scoring in `draft-context-loading.md` |
| Concept Map markers empty/absent | Fall back to reading `wiki/*/index.md` section tables directly; if those are missing, use the Synopsis + floor |
| Routing descriptions thin/uninformative | Open the section `index.md` and skim concept titles; flag for `/draft:init refresh` to regenerate descriptions |
| Task is broad | Terminate at Synopsis — descending is over-fetch (a Red Flag per `red-flags.md`) |
