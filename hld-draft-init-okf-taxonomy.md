# HLD — `/draft:init` Reimplementation: OKF Emitter + AutoWiki Taxonomy

**Status:** Draft for review
**Scope:** Replace monolithic `architecture.md` output with an OKF-conformant, AutoWiki-style navigable taxonomy. Repurpose `.ai-context.md` as the progressive-disclosure index root. Validate via branch-isolated A/B benchmark on a large repo.
**Author/owner:** Mayur
**Engine reused:** codebase-memory-mcp (tree-sitter graph, 159 langs, local), existing `scripts/tools/` deterministic helpers, `.state/` incremental hashing.

---

## 1. Goals / Non-goals

**Goals**
- `G1` — Standardize `/draft:init` output as an OKF v0.1 bundle (markdown + YAML frontmatter, one concept per file, cross-links form the graph).
- `G2` — Replace the single `architecture.md` with a navigable concept taxonomy better suited for agent drill-down.
- `G3` — Make `.ai-context.md` the index root: condensed synopsis + routing entry into the taxonomy.
- `G4` — Preserve incremental refresh at concept granularity.
- `G5` — Prove agent-task performance vs. the current monolith on a large repo before deprecating the old path.

**Non-goals**
- Not adopting AutoWiki's multi-agent generation pipeline (the local call graph grounds better than embedding retrieval).
- Not adopting video walkthroughs or any cloud sync.
- Not changing `/draft:review` or downstream commands' contracts in this track (compat shim covers them — §9).

---

## 2. Current state (baseline)

`/draft:init` (5-phase analysis) emits:
- `architecture.md` — 10-section, graph-primary, Mermaid as source of truth.
- `.ai-context.md` — 200–400 lines, token-optimized, condensed standalone context.
- `.state/` — freshness hashes, signal classification, run memory (drives `init refresh`).

Consumers today: brownfield Context Quality Audit reads `architecture.md`; downstream commands and skills consume `.ai-context.md`; humans read both.

---

## 3. Target architecture

```
.draft/
├── ai-context.md          # INDEX ROOT: synopsis (150–250 lines) + routing into taxonomy
├── architecture.md        # RENDERED VIEW (generated from bundle; not source of truth)
├── wiki/                   # OKF bundle (the new source of truth)
│   ├── index.md
│   ├── overview/
│   │   ├── index.md
│   │   ├── architecture.md      # system map, Mermaid
│   │   ├── getting-started.md
│   │   └── glossary.md
│   ├── systems/
│   │   ├── index.md
│   │   └── <subsystem>.md
│   ├── features/
│   │   ├── index.md
│   │   └── <feature>.md
│   ├── reference/
│   │   ├── index.md             # config, dependencies, data models
│   │   └── <ref>.md
│   ├── entrypoints/
│   │   └── <app>.md
│   └── log.md                   # chronological change history (from .state run memory)
└── .state/
    ├── hashes.json              # file → content hash (existing)
    ├── path-to-concept.json     # NEW: source path → concept page(s) it grounds
    └── signals.json             # existing
```

**Layering:** OKF is the *serialization contract*. The AutoWiki taxonomy is the *concept layout* inside the bundle. The call graph is the *grounding source*. `ai-context.md` is the *consumption entry point*.

---

## 4. Concept `type` vocabulary (code repos)

OKF requires `type` on every concept; producer defines the set. Frozen vocabulary for code (changing later churns every file):

| type | Maps to | Taxonomy home |
|------|---------|---------------|
| `Subsystem` | Major graph cluster / package boundary | `systems/` |
| `Module` | Single package/crate/dir with cohesive responsibility | `systems/` |
| `Feature` | User-facing capability spanning modules | `features/` |
| `Entrypoint` | Binary / main / CLI / handler root | `entrypoints/` |
| `API` | Public interface, route group, RPC surface | `reference/` |
| `DataModel` | Schema, table, core struct/type | `reference/` |
| `Dependency` | Notable external dep + how it's used | `reference/` |
| `ADR` | Architecture decision record | `reference/` |
| `Runbook` | Operational procedure | `reference/` |

Type set is versioned in the bundle (`index.md` frontmatter: `okf_types_version`).

---

## 5. Frontmatter contract

Per concept (OKF queryable fields + Draft routing extensions):

```yaml
---
type: Subsystem                    # required (OKF)
title: Auth Pipeline               # OKF
description: >                     # OKF — LOAD-BEARING: this is the agent's routing key.
  Login, session, token issuance/refresh. Open for anything touching
  authentication, identity, or session lifecycle.
resource: src/auth/                # OKF — canonical source path(s)
tags: [auth, security]             # OKF
timestamp: 2026-06-19T00:00:00Z    # OKF — last regeneration
# Draft extensions (ignored by generic OKF consumers):
x-grounded-paths: [src/auth/login.go, src/auth/session.go]
x-hotspot-score: 0.82
x-callers: [api/handlers, middleware/authz]
---
```

**Design rule:** `description` is written as a *routing decision*, not a summary. It must answer "should the agent open this file for the task at hand?" from the index alone.

---

## 6. `.ai-context.md` — index root design (refinement 1+2)

Resolves the pre-condensed vs progressive-disclosure tension by being both:

```
# <Repo> — AI Context Index

## Synopsis            ← 150–250 lines: the cheap broad-context path (current value preserved)
  Architecture in brief, key invariants, where to start, top hotspots.

## Concept Map         ← routing table built from frontmatter `description` fields
  systems/   — <one-line routing desc per subsystem>
  features/  — <one-line routing desc per feature>
  reference/ — <config, schemas, APIs>

## How to navigate
  Read Synopsis for broad tasks. Open specific concepts via Concept Map
  for focused tasks. Each concept lists x-grounded-paths.
```

Agent reads this one file first. Broad tasks terminate here. Focused tasks route to ≤N concept files. This is the bet under test in the benchmark (§13).

---

## 7. Generation pipeline

Reuses existing analysis; adds decomposition + serialization. No new LLM analysis engine.

```
1. Survey        → existing /draft:init 5-phase + graph snapshot (codebase-memory-mcp)
2. Plan          → derive concept list from graph clusters + entrypoints + features
                   topo-sort by dependency (overview/architecture first)
3. Generate      → per-concept page: pull grounding from graph (callers, blast radius,
                   hotspot), write body + frontmatter, record x-grounded-paths
4. Render views  → ai-context.md (synopsis+map), architecture.md (concat view), log.md
5. Validate      → okf-validate.sh: every cross-link resolves; every concept has type;
                   path-to-concept.json complete  → FAIL build on dangle
6. Emit          → write bundle; update .state/
```

Topo order matters: pages referenced by others (overview, core subsystems) generate first so cross-links resolve forward.

---

## 8. `scripts/tools/` helper → frontmatter/page mapping

Existing deterministic helpers feed generation (JSON out, exit-code contract — no new pattern):

| Helper | Feeds |
|--------|-------|
| `graph-callers.sh` | `x-callers`, "used by" section, cross-links |
| `graph-impact.sh` | `x-grounded-paths`, blast-radius section, path→concept index |
| `hotspot-rank.sh` | `x-hotspot-score`, hotspot ordering in synopsis |
| `cycle-detect.sh` | reference/ warnings, architecture.md view |
| `mermaid-from-graph.sh` | `overview/architecture.md` diagrams |
| (new) `okf-validate.sh` | step 5 — cross-link + type + index integrity |

`okf-validate.sh` is the only new helper. Verification against the call graph (ground truth), not heuristic.

---

## 9. Backward compatibility (refinement 3)

`architecture.md` is **demoted, not deleted**:
- Generated as a concatenated view from the bundle (TOC + section concat + Mermaid). Deterministic, cheap.
- Brownfield Context Quality Audit continues to read it.
- Any command/skill grepping `architecture.md` keeps working.
- Humans wanting one file keep it.

Downstream consumers of `.ai-context.md` keep working: the synopsis section preserves the prior content shape; the new Concept Map is additive.

---

## 10. Incremental refresh (refinement 6)

`init refresh` at concept granularity:

```
1. git diff hashes.json vs working tree → changed source paths
2. path-to-concept.json → affected concept pages
3. regenerate affected concepts only; carry rest verbatim
4. re-render ai-context.md / architecture.md (cheap; always regenerated)
5. re-validate cross-links touching changed concepts
6. append log.md; update hashes.json + path-to-concept.json
```

Unchanged concepts are byte-identical across runs (deterministic generation where graph-derived; LLM-narrated sections cached by source hash).

---

## 11. Branch strategy

```
main
└── feat/draft-init-okf-taxonomy        # the reimplementation, isolated
    - new generator under skills/init/ (OKF emitter)
    - okf-validate.sh under scripts/tools/
    - feature flag: DRAFT_INIT_MODE = {monolith | okf}  (default monolith on this branch)
```

- Flag-gated so both code paths coexist for A/B without a fork of the whole command.
- `monolith` mode = current behavior untouched (clean baseline).
- `okf` mode = new pipeline.
- Merge gate: benchmark (§13) shows okf mode ≥ baseline on task accuracy at acceptable token cost.

Conventional commits; no push until green CI + benchmark captured.

---

## 12. Benchmark methodology (A/B on a large repo)

**Target repo:** `finbrainiac-platform`. Methodology is repo-agnostic; task suite below is tailored to a multi-microservice trading platform.

**Setup**
- Same repo, same commit, same model, same agent host.
- Arm A: `DRAFT_INIT_MODE=monolith` → `.ai-context.md` (condensed standalone).
- Arm B: `DRAFT_INIT_MODE=okf` → index root + taxonomy bundle.

**Task suite** (representative of real `/draft:*` usage; 20–40 tasks, fixed; tailored to `finbrainiac-platform`):
- Broad-context: "summarize the service topology", "which service owns order execution".
- Focused: "what breaks if I change the broker adapter interface", "add a field to the position/fill data model".
- Cross-cutting: "trace an equity trade from signal generation through broker submission to TimescaleDB persistence".

**Metrics (per task, per arm)**
| Metric | Why |
|--------|-----|
| Task accuracy (rubric-scored, blind) | Primary — does navigation help or hurt correctness |
| Input tokens consumed | Cost of context assembly |
| Tool calls / file reads | Detects over-fetch (taxonomy read defeated) |
| Wall-clock to first action | Latency cost of navigation |
| Cross-link follow rate | Did the agent actually navigate vs. read-all |

**Decision rule**
- Adopt `okf` as default if accuracy ≥ baseline AND token cost not materially worse on focused tasks.
- If agent over-fetches (read-all behavior), refinement 1's synopsis is the fallback; do not deprecate monolith.
- Generation cost (one-time `/draft:init` runtime) tracked separately — informational, not a merge gate.

**Artifacts**: results table committed under `docs/audit/` per repo + commit.

---

## 13. Risks

| Risk | Mitigation |
|------|------------|
| Agent over-fetches, taxonomy adds cost for no gain | Synopsis-in-root (R1); benchmark gate before deprecation |
| Dangling cross-links from page-by-page gen | `okf-validate.sh` fails build (R5) |
| `type` vocabulary churn | Frozen + versioned up front (§4) |
| Brownfield audit / grep breakage | `architecture.md` rendered view retained (R3) |
| OKF v0.1 spec churn (1 wk old, single vendor) | Emit as markdown+YAML; near-zero migration cost; extensions namespaced `x-` |
| Incremental refresh misses a concept | path→concept index built from `graph-impact.sh` ground truth, validated each run |

---

## 14. Sequencing / milestones

```
M1  Type vocabulary + frontmatter contract + taxonomy layout frozen   → verify: schema doc reviewed
M2  okf-validate.sh (cross-link + type + index integrity)             → verify: catches injected dangle
M3  Generator: graph → concept pages + path-to-concept.json           → verify: bundle validates on small repo
M4  Render views: ai-context.md (synopsis+map), architecture.md, log  → verify: brownfield audit still passes
M5  init refresh at concept granularity                              → verify: 1-file change → only affected concepts regen
M6  Flag-gate both modes; wire benchmark harness                      → verify: both arms run on large repo
M7  Run A/B; capture results                                          → verify: decision rule evaluated
```

M1–M2 are cheap and unblock everything. M7 is the gate for making `okf` the default on `main`.

---

## Open decisions (pre-M1)

1. Concept granularity for `Module` vs `Subsystem` — graph-cluster threshold (fan-in? LOC? package boundary?). Affects page count and navigation depth.
2. LLM-narrated vs purely graph-derived page bodies — narrated reads better but breaks byte-identical incremental carry-forward; resolve by caching narration on source hash.
3. Benchmark repo + frozen task suite selection.
