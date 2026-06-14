# Design: Collapse `index` into a scope-aware `init` with a root-first graph spine

Status: LOCKED — ready to implement
Date: 2026-06-14

## Goal

One entry point for building context. Remove `/draft:index` as a separate concept.
Running `/draft:init` anywhere (root or sub-module) must guarantee the whole-repo
code-graph knowledge memory exists, and every module's graph must link up to the
root graph so an agent has full cross-module understanding regardless of where init ran.

## Core invariant

**Root graph is the spine and is always built first.** It is the single structural
source of truth (alongside git). Module graphs are *views/pointers* into it — never
divergent copies.

Grounding fact: the engine (`codebase-memory-mcp`) indexes the **whole repo from root
into one project**, recursing every file at every depth. Its `architecture.json`
already carries per-package (module) breakdowns (`.packages[]` with fan-in/out). So the
root graph *already contains* every module's graph. A module needs a **pointer up to
root**, not its own independent index.

## Storage & git-tracking (LOCKED)

Three layers, three policies — do not conflate them:

| Layer | What | Policy |
|---|---|---|
| Source of truth | The code | git |
| **Committed code-graph memory** | `draft/graph/` snapshot (schema.yaml, architecture.json, hotspots.jsonl, *.mermaid) | **git-tracked** — small, derived, PR-reviewable; travels with repo; works offline + Copilot/Gemini |
| Engine working index | `codebase-memory-mcp` SQLite store in `~/.cache` | **never committed** — large, machine/arch-specific, absolute paths, rebuildable; a build cache like `node_modules` |

- The committed `draft/graph/` snapshot **is** the "code graph knowledge memory." Commit it
  at root and at each module.
- `.gitignore` must not ignore `draft/graph/`. The engine cache lives outside the repo, so
  nothing to ignore — but never `git add` it.
- Links between module and root reference the **committed snapshot path** (primary, survives
  clone) + the engine project (live accelerator when present).

## What the committed snapshot covers — and why the engine is preferred

The snapshot is a **structural skeleton**, not a queryable graph DB. Verified: the
traversal tools (`graph-callers.sh`, `graph-impact.sh`) call the live engine
(`query_graph` / `trace_path`) and return `source: "unavailable"` (empty) when the binary
is absent — they do **not** fall back to reading `architecture.json`.

| Capability | Committed `draft/graph/` (no engine) | Live engine |
|---|---|---|
| Module map, dependency topology, fan-in/out | ✅ | ✅ |
| Hotspots, routes/API surface, entry points, languages | ✅ | ✅ |
| "Who calls symbol X" | ❌ | ✅ `query_graph` |
| "Trace path A → B" / blast radius | ❌ | ✅ `trace_path` |
| Symbol-level change impact / fresh deltas | ❌ | ✅ `trace_path` / `detect_changes` |

**Capability tiers (preference order):**

1. **Live engine — the default.** `init` ensures it is installed and the whole-repo index is
   built (rebuild cost accepted, not gated). Deterministic graph traversal (exact callers,
   call paths, blast radius, fresh deltas) outperforms grep/glob for structural questions:
   text search is noisy, misses indirect edges, and can't trace paths. Graph-backed skills
   prefer engine queries whenever `source != unavailable`.
2. **Committed snapshot — fallback only.** Structural skeleton that survives clone with no
   engine; powers offline use, Copilot/Gemini, and PR review. Used only when the engine is
   genuinely unavailable — not as the normal path.
3. **grep/glob + source reads — last resort**, for semantics the graph doesn't model.

**Design consequence:** `init` **ensures the engine is installed and the index is built**,
including on a fresh clone. It fetches the engine when missing
(`scripts/fetch-memory-engine.sh`, blocking, with progress — rebuild/download time is
accepted, never gated on cost) and builds/refreshes the whole-repo index. This holds even
if Draft was installed with `--no-graph`: the first `init` installs the engine. The engine
is the default, not opt-in. Draft falls back to the committed snapshot **only** on explicit
opt-out (`DRAFT_MEMORY_DISABLE=1`) or an impossible fetch (offline/air-gapped) — and then it
**warns loudly** with install instructions rather than degrading silently.

## `init` algorithm (scope-aware)

1. **Resolve scope.** `ROOT` = nearest ancestor containing a `draft/` root marker
   → else `git rev-parse --show-toplevel` → else cwd. `SCOPE` = cwd.
   `is_root = (SCOPE == ROOT)`.
2. **Ensure root graph (runs regardless of where init was invoked).**
   - **Ensure the engine is installed.** Normally it is already present — `draft install`
     fetches it at install time, so this is a no-op in the common case. `init` fetches only
     as a fallback when the binary is missing (`scripts/fetch-memory-engine.sh`, blocking;
     download/rebuild time accepted). Skip only on explicit opt-out / offline, then warn
     loudly with install steps.
   - Always **index root into the engine** (whole repo, incremental after first build) so
     queries and the module link are live. A first-time full index is expected and fine.
   - Write/refresh the committed **`<root>/draft/graph/` snapshot** via
     `graph-snapshot.sh --repo ROOT` (engine recurses all levels → one unified whole-repo
     graph). *This is the git-tracked code-graph memory.*
   - Announce when invoked from a sub-module: "Sub-module of `<root>` detected — building the
     root code-graph spine so this module links to whole-repo understanding."
3. **Root init (`is_root`):**
   - Graph: done in step 2.
   - Markdown: **sparse root context** — high-level system map (module list from
     `architecture.json .packages`, top hotspots, cross-module topology), with links
     **down** to each module's `draft/.ai-context.md`. No deep per-module prose (repo is huge).
4. **Module init (`!is_root`):**
   - Graph: write `SCOPE/draft/graph/` as a **module view** (git-tracked):
     - `root-link.json` (the upward link): `{ root_graph: <relpath to ROOT/draft/graph>,
       root_project, root_commit, module_packages: [...] }`.
     - Filtered slice of `architecture.json`/`hotspots.jsonl` (path-prefix) for fast local
       queries; cross-module always defers to root via the link.
   - Markdown: **detailed module context** — full architecture.md / .ai-context.md /
     .ai-profile.md scoped to the module subtree (init's current behavior, module-scoped).

## Sub-module init: root traversal behavior (LOCKED)

When `init` runs in a sub-module and the root graph is missing:

- **Always** index root into the engine (cheap; no markdown).
- **Default: write the small committed `<root>/draft/graph/` snapshot** and announce it — this
  is the git-tracked memory the user wants, and it makes the module link a committed target.
- **Never** auto-generate root *markdown* from a sub-module init. Print:
  "Run `/draft:init` at `<root>` for the system-level overview."
- Write the module's `root-link.json` → committed root snapshot (+ engine project).
- **Escape hatch:** `--module-only` skips root entirely; records the link as `status: pending`
  (resolved when root init later runs).
- **Edges:** no git / `root == module` / root unresolvable → go module-local, no traversal.
  If `<root>/draft/` already exists (owned root) → refresh its spine respectfully.

## Flags

- `--graph-only` → steps 1–2 (+ module view in 4); skip markdown. **This is the original
  "recursively build the code graph knowledge memory" request.** At root: whole-repo graph.
  In a module: ensure root graph + write module pointer/slice.
- `--module-only` → do not traverse to root; module-local graph + link marked `pending`.
- default → graph + markdown for the scope.
- refresh is implicit/incremental (re-run; engine indexes incrementally, snapshot rewrites).

## Removing `/draft:index` — where its jobs go

| index job | New home |
|---|---|
| Federated markdown aggregation (service-index, dependency-graph, tech-matrix, synthesized root product/arch/tech) | Root init's **sparse markdown** (links down to modules) |
| Graph injection-slot refresh (Step 8.5) | Part of `init` refresh |
| `index bughunt` multi-dir mode | **Rehome** → `/draft:bughunt` (accept dir list / auto-discover) |
| `index --init-missing` | Dropped (use `init` per module; root links existing modules) |

## Churn (published plugin — ~30 files)

- **Core behavior (small):** `skills/init/SKILL.md` rewrite; graph pointer emission.
- **Wiring:** `scripts/lib.sh` SKILL_ORDER (drop `index`); `build-integrations.sh`
  `get_skill_header()` + `get_copilot_trigger()` (drop index cases); routers
  `skills/discover/SKILL.md`, `skills/draft/SKILL.md`, `skills/draft/intent-mapping.md`.
- **Templates:** `core/templates/{service-index,dependency-graph,tech-matrix,root-architecture,root-product,root-tech-stack}.md` — repurpose for root sparse markdown or delete.
- **Docs/build/test:** README, CHANGELOG, `core/methodology.md`, `core/shared/*`,
  `make build && make test`, tests (`test-trigger-functions`, frontmatter, any index test).
- **Web/book (follow-up pass, non-blocking):** `web/book/chapters/18-monorepo-federation.html`,
  command-reference pages, `web/llms-full.txt`.

## Phasing

- **P1** Core: scope-aware `init` (root-first invariant, `--graph-only`, `--module-only`,
  module pointer-up, markdown asymmetry). Templates for root-sparse vs module-detailed.
- **P2** Graph tooling: emit `root-link.json`; optional module path-filter on snapshot.
- **P3** Remove `index`: skill, SKILL_ORDER, trigger fns, router dispatch, rehome bughunt.
- **P4** Docs/build/test: README, CHANGELOG, methodology, `make build && make test`, fix tests.
- **P5** Web/book cleanup (separate, non-blocking).

## Locked defaults

1. **Module-graph form:** pointer (`root-link.json`) + filtered slice from root.
2. **`index` removal:** hard-delete skill + wiring now; defer book/web cleanup to P5.
3. **`index bughunt`:** fold into `/draft:bughunt` multi-dir.
4. **Sub-module root traversal:** always index root into engine; **write committed
   `<root>/draft/graph/` snapshot by default** (announce it); never auto-generate root
   markdown; `--module-only` opts out with a `pending` link.
5. **git-tracking:** commit `draft/graph/` snapshots (root + module); never commit the
   `~/.cache` engine index; git stays source of truth.
6. **ROOT resolution order:** nearest ancestor with `draft/` → `git rev-parse --show-toplevel`
   → cwd.
7. **Engine by default (not opt-in):** `init` ensures the engine is installed and the
   whole-repo index is built — including on a fresh clone, accepting download/rebuild time
   (never gated on cost), even if Draft was installed with `--no-graph`. Fetch is blocking
   with progress. Fallback to the committed snapshot happens **only** on explicit opt-out
   (`DRAFT_MEMORY_DISABLE=1`) or impossible fetch (offline), and then Draft warns loudly
   with install steps. Graph-backed skills prefer engine queries over grep/glob whenever
   available.
