# Draft Plugin: OKF Wiki **Completeness** Enforcement Plan

**Status:** Proposed (v2 — completeness-first rewrite)
**Audience:** Draft plugin maintainers, skill authors, CI integrators
**Scope:** All repositories using `/draft:init` (and refresh) with `DRAFT_INIT_MODE=okf` (tier 3+ default)
**Related artifacts:** `skills/init/SKILL.md`, `skills/init/references/okf-emitter.md`, `scripts/tools/okf-validate.sh`, `scripts/tools/okf-render-views.sh`, `core/templates/okf/concept.md`

---

## Executive Summary

The observed failure is **incomplete generation**: running `/draft:init` in OKF mode does not produce a concept page for every module, sub-module, and component, and it is **not repeatable** — the set of generated pages varies between runs of the same repo.

Root cause: the bundle's **expected-concept set is decided by the LLM in-context** during the emitter's "Plan" step. Under context/time pressure the agent under-enumerates modules, and the only gate (`okf-validate.sh`) validates *what was written*, never *what should have been written*. A bundle missing half the modules passes validation and is promoted (`draft.tmp/ → draft/`).

This plan makes completeness **deterministic and enforced**:

1. **Derive the expected-concept set from the graph, by tooling** (`okf-plan-concepts.sh`) — before any page is written. Every module / sub-module / component / entrypoint above a fan-in floor becomes a required plan entry.
2. **Drive generation from that plan** — one output page per required entry; the run cannot complete with gaps.
3. **Gate promotion on plan-satisfaction** (`okf-coverage-check.sh`) — `draft.tmp/ → draft/` is blocked unless every required entry has a non-stub page, or it is explicitly deferred with a reason.
4. **Block stubs** (`okf-validate-quality.sh`) so completeness can't be faked with placeholder pages.

**Design principle:** the *set of things to document* and *whether each is actually documented* are both ground truth produced by shell + graph — not agent honor system. LLM narration fills the prose; LLM judgment never decides the boundary of the work.

**Explicitly carried over from v1 review (do not regress):**
- No new runtime dependency. `jq` + the graph engine only — **no Node/Mermaid AST parser**.
- Per-**type** thresholds, not global (ADR/Runbook/Dependency/DataModel are short by nature).
- Extend the **existing** atomic gate and `okf-validate.sh`; don't reinvent them.
- Every new tool carries its `scripts/lib.sh` `TOOLS` entry, `tests/test-tools-*.sh`, and `Makefile` `TEST_SCRIPTS` row; every skill/emitter edit is followed by `make build`.

---

## Problem Statement

### The reported symptom

> "The wiki is not getting generated completely for all modules, sub-modules, components. We have to make sure every time it works, all issues are resolved."

Decomposed:

| Symptom | Today's behavior |
|---------|------------------|
| Modules missing from `wiki/` | No deterministic expected set; agent enumerates concepts in-context and drops some |
| Sub-modules / components skipped | Granularity is agent-judged; nested packages collapse into a parent or vanish |
| Non-repeatable output | Same repo, different runs → different page set (LLM nondeterminism in the Plan step) |
| Missing pages still "pass" | `okf-validate.sh` validates present pages only ([okf-validate.sh:99-118](../scripts/tools/okf-validate.sh#L99-L118)); no coverage concept exists |
| Rendered view hides gaps | `architecture.md` concatenates whatever exists; a long TOC implies depth that isn't there |

### Root cause (the one that matters)

```
okf-emitter "Plan" step is LLM-driven
        │
        ▼
expected-concept set is an in-context judgment, not a tool output
        │
        ├─► agent under-enumerates under context pressure ──► modules missing
        ├─► enumeration differs per run ──────────────────► non-repeatable
        └─► okf-validate.sh checks only what exists ───────► gaps pass, bundle promotes
```

Everything else (stubs, thin pages, bad diagrams) is secondary. **If the expected set is deterministic and promotion is gated on satisfying it, "not generated completely" becomes structurally impossible.**

### What already works (don't rebuild)

| Component | Role | Reuse decision |
|-----------|------|----------------|
| Graph engine + `graph-arch.sh` | Deterministic packages with `name`, `fan_in`, `fan_out` | **Source of the expected set** |
| `hotspot-rank.sh` | Fan-in / complexity ranking | Prioritize required pages |
| `graph-hierarchy.sh` | Package → sub-package nesting | Enumerate sub-modules/components |
| `okf-validate.sh` | Frontmatter, type vocab, cross-links, **forward** path-index | Layer 1, **extended** (reverse check) |
| Atomic staging `draft.tmp/ → draft/` | Promotion gate already exists; FAILs without rename on validate failure | **Extend**, don't reinvent (v1 mis-framed this as absent) |
| `okf-render-views.sh` | Renders `architecture.md`, Concept Map | **Extend** with coverage banner |
| `path-to-concept.json` | Source path → concept pages map | Cross-checked against the plan |

---

## Goals

| ID | Goal |
|----|------|
| **G1** | **Deterministic expected-concept manifest** produced by tooling from the graph — every module, sub-module, and component above a fan-in floor is enumerated **before** generation. |
| **G2** | **Plan-driven generation** — exactly one page per required manifest entry; the generation loop cannot terminate while any required entry is unwritten. |
| **G3** | **Promotion blocked on incompleteness** — `draft.tmp/ → draft/` only if every required entry has a non-stub page **or** is in the deferral allowlist with a written reason. |
| **G4** | **Repeatability** — same repo + same graph snapshot → identical manifest → identical required page set. Variance is logged, not silent. |
| **G5** | **Anti-stub** — a present-but-empty page does **not** satisfy coverage (completeness can't be faked). |
| **G6** | **Refresh parity** — incremental refresh re-derives the manifest and re-runs the full gate; new modules since last run become required. |
| **G7** | **Honest rendered view** — `architecture.md` banner states real coverage (`mapped/expected`, PASS/FAIL); marked INCOMPLETE when the gate fails. |
| **G8** | **Repo-agnostic, no new runtime deps** — works for any language/tier; graph-derived with optional manifest fallback; `jq` + engine only. |

## Non-Goals

- Replacing LLM **narration** of prose sections (graph still grounds frontmatter, the manifest grounds the boundary).
- One wiki page per **source file** — granularity stays at module / sub-module / component (package-cluster), set by the graph hierarchy, not per-file.
- Node/Puppeteer/headless Mermaid rendering in CI.
- Retiring `monolith` mode (tier 1–2 default, unaffected).
- Mandating per-adapter sub-pages for large subtrees — an indexed table satisfies coverage when the parent component page exists and the children are below the fan-in floor.

---

## Target Architecture

### From LLM-judged to tool-derived completeness

```
BEFORE (today)                          AFTER (this plan)
──────────────                          ─────────────────
Survey                                  Survey
Plan      ◄── LLM enumerates concepts   Plan      ◄── okf-plan-concepts.sh (DETERMINISTIC)
Generate  ◄── writes "some" pages        Generate  ◄── plan-driven: one page per required entry
                                                       loop asserts every entry written
Render                                   Render     ◄── coverage banner injected
Validate  ◄── structure only             Validate   ◄── structure + completeness + anti-stub + reverse
Emit (mv) ◄── promotes even if gappy      Emit (mv) ◄── BLOCKED unless coverage gate passes
```

### Validation stack (completeness-first ordering)

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 4: Promotion gate (init / refresh)                     │
│   draft.tmp/ → draft/  IFF  layers 1–3 pass                  │
└─────────────────────────────────────────────────────────────┘
                              ▲
┌─────────────────────────────────────────────────────────────┐
│ Layer 3: COMPLETENESS (okf-coverage-check.sh)  ← PRIMARY      │
│   concept-plan.json (expected)  ↔  wiki pages (produced)     │
│   every required entry has a non-stub page or a defer reason │
└─────────────────────────────────────────────────────────────┘
                              ▲
┌─────────────────────────────────────────────────────────────┐
│ Layer 2: Anti-stub / per-type minimums (okf-validate-quality)│
│   sections, per-type min length, ≥1 mermaid (bash-lint),    │
│   no placeholder tokens, no redirect-only bodies            │
└─────────────────────────────────────────────────────────────┘
                              ▲
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: Structure (okf-validate.sh) — EXISTS, extended      │
│   frontmatter, types, cross-links, forward + REVERSE index   │
└─────────────────────────────────────────────────────────────┘
```

Layer 3 is the answer to "not generated completely." Layer 2 stops the obvious workaround (write empty pages to satisfy Layer 3). Layer 1 is unchanged in spirit, with the reverse index folded in.

---

## New & Changed Tools

Leaner than v1: **3 new tools + 1 orchestrator + 2 extensions.** (v1 proposed 6 new scripts incl. a Node helper.)

### 1. `okf-plan-concepts.sh` — NEW (the crux)

**Purpose:** Deterministically enumerate the expected-concept set from the graph, before generation.

**Inputs:** `--repo DIR`, `--scope PATH` (module-scoped init), `--manifest FILE` (optional override), `--min-fan-in INT` (default 2), `--json`, `--out FILE` (default `draft.tmp/.state/concept-plan.json`).

**Expected-set discovery (priority order):**
1. **Manifest** — `--manifest` / `draft/.state/component-manifest.yaml` if present (authoritative; required when graph unavailable + `--strict`).
2. **Graph** — `graph-arch.sh --repo DIR` packages + `graph-hierarchy.sh` for sub-package nesting. Each package/sub-package/component at or above `--min-fan-in` becomes a required entry; entrypoints and detected features are always required.
3. **Heuristic fallback** — top-level source dirs (excluding `test`, `qa`, `tools`, `vendor`, `node_modules`) when the engine is unavailable; emits `degraded: true`.

**Output `concept-plan.json`:**
```json
{
  "version": 1,
  "repo": ".",
  "scope": ".",
  "source": "graph",            // graph | manifest | heuristic
  "degraded": false,
  "min_fan_in": 2,
  "generated_order": ["systems/auth.md", "systems/auth/session.md", "..."],
  "expected": [
    {
      "concept_id": "systems/auth.md",
      "type": "Subsystem",
      "resource": "src/auth/",
      "grounded_paths": ["src/auth/login.go", "src/auth/session.go"],
      "fan_in": 14,
      "required": true,
      "reason_if_deferred": null
    }
  ],
  "counts": { "expected_total": 63, "required": 58, "deferred": 5 }
}
```

- `generated_order` is a **topological** order (dependencies before dependents) so generation has a stable, repeatable sequence — directly serves **G4**.
- `required: true` entries MUST produce a page; deferred entries MUST carry a reason and land in `coverage.md`.

**Exit:** 0 plan written, 2 graph + manifest both unavailable in `--strict`.

---

### 2. `okf-coverage-check.sh` — NEW (Layer 3, the gate)

**Purpose:** Prove every required plan entry is satisfied by a real page. **This is the block that fixes "not generated completely."**

**Inputs:** `--plan FILE` (concept-plan.json), `--bundle DIR` (`draft/wiki`), `--path-index FILE`, `--config FILE`, `--json`, `--report FILE`.

**Checks:**

| Check | Rule | Severity |
|-------|------|----------|
| **C-PLAN** | Every `required` plan entry has a corresponding bundle page (`concept_id` exists) | **hard** |
| **C-STUB** | Each satisfying page passed Layer 2 (not a stub) | **hard** |
| **C-FANIN** | Every graph package with `fan_in ≥ min_fan_in` is covered by ≥1 page | **hard** |
| **C-DEFER** | Each non-produced required entry appears in `coverage.md` with a one-line reason | **hard** |
| **C-GROUND** | Each page's `x-grounded-paths` resolve to real source paths | warn |
| **C-DRIFT** | Plan count vs produced count delta logged (repeatability signal for G4) | warn |

**Auto-generated `wiki/systems/coverage.md`** (tool-owned, `<!-- okf:coverage-generated -->` marker; agents author only deferral reasons):

| Component | Wiki page | Status | Fan-in |
|-----------|-----------|--------|--------|
| `src/auth/` | `systems/auth.md` | Full | 14 |
| `src/auth/session/` | `systems/auth/session.md` | Full | 6 |
| `tools/lint/` | — | Deferred (below floor, dev tooling) | 1 |
| `src/billing/` | — | **MISSING** | 9 |

A **MISSING** row with `required: true` ⇒ exit 1 ⇒ promotion blocked.

**Exit:** 0 complete, 1 incomplete/missing required, 2 plan or graph unavailable.

---

### 3. `okf-validate-quality.sh` — NEW (Layer 2, anti-stub)

**Purpose:** Ensure a page that *exists* is real, so it can satisfy coverage. Per-type thresholds (fixing v1's universal-threshold false-positives).

**Pages in scope:** `*.md` with a frozen `type:`; **exclude** section `index.md`, `log.md`, and the coverage meta-page.

**Per-type thresholds** (config-overridable; the key v1 fix):

| Type | Required sections | Min body lines | ≥1 Mermaid | Min grounded paths |
|------|-------------------|---------------|-----------|--------------------|
| Subsystem, Module, Feature, Entrypoint | What it is / How it works / Used by / Blast radius / See also | 40 | **yes** | 2 |
| API, DataModel | What it is / How it works / See also | 25 | no | 1 |
| Dependency | What it is / Used by | 12 | no | 0 |
| ADR, Runbook | (type-specific) | 10 | no | 0 |

Required H2 sections match the template exactly ([concept.md:33-54](../core/templates/okf/concept.md#L33-L54)).

**Anti-stub patterns (regex, case-insensitive, all types):**
```
see architecture\.md\b(?!.*because)      # bare redirect, not a contextual cross-ref
deferred to ref-docs
\bTBD\b|TODO:\s*document
\{CONCEPT_TITLE\}|\{CANONICAL_SOURCE_PATH\}|\{[A-Z_]+\}   # unreplaced template tokens
stub page|placeholder page
```

**Duplicate detection (O(n), not v1's O(n²) Jaccard):** hash the normalized "What it is" opening paragraph; flag any hash collision across ≥2 pages (catches copy-paste; cheap on 60+ pages).

**Mermaid lint (pure bash, no Node — v1 fix):** for pages requiring a diagram, assert ≥1 balanced ` ```mermaid ` fence and reject the common breakers — `&`-chained nodes, reserved participant names (`end`, `class`, `click`), unicode arrows (`→`/`⟶`), and unterminated subgraphs. AST-perfect validation is a non-goal; this catches the failure modes that break previewers without a runtime dependency.

**Exit:** 0 pass, 1 fail, 2 bundle not found.

---

### 4. `okf-validate-all.sh` — NEW (orchestrator)

Single entry point for init, refresh, and CI:
```bash
okf-validate-all.sh draft/wiki \
  --repo . --plan draft.tmp/.state/concept-plan.json \
  --path-index draft.tmp/.state/path-to-concept.json \
  --strict --report draft.tmp/.state/validation-report.json
```
Runs Layer 1 (structure + reverse index) → Layer 2 (quality) → Layer 3 (coverage); aggregates one JSON report; exit non-zero on any hard failure. **The promotion `mv` is conditioned on this exit code.**

---

### 5. `okf-validate.sh` — EXTEND (no new tool)

- Add **reverse path-index** check: every concept page (excluding section indexes) appears in ≥1 value array of `path-to-concept.json` (catches orphan pages not tied to a source).
- Add `--structure-only` for backward-compat / Layer-1-only callers during migration.

### 6. `okf-render-views.sh` — EXTEND

Prepend an honesty banner to `architecture.md`:
```markdown
> **Generated view** — source of truth is `draft/wiki/`.
> Coverage: {mapped}/{expected} required components ({pct}%).
> Validated: {ISO_TIMESTAMP} — {PASS|FAIL}.
```
On gate failure (which already blocks promotion), the banner reads **INCOMPLETE — do not use for RCA.** Timestamp is passed in by the caller (tooling has no clock dependency).

---

## Updated OKF Pipeline (`okf-emitter.md`)

```
1. Survey   — existing 5-phase + graph snapshot
2. Plan     — okf-plan-concepts.sh → draft.tmp/.state/concept-plan.json   ◄── NEW, deterministic
              log expected_total / required / deferred BEFORE any write
3. Generate — iterate concept-plan.generated_order; ONE page per required entry,
              grounded in its grounded_paths; record source→page in path-to-concept.json
              loop post-condition: every required concept_id has an output file
4. Render   — okf-render-views.sh (ai-context.md, architecture.md + coverage banner); coverage.md
5. Validate — okf-validate-all.sh ... --strict --report draft.tmp/.state/validation-report.json
6. Emit     — mv draft.tmp/ draft/  ONLY IF step 5 exit 0; else keep draft.tmp/, surface report
```

Step 2 produces the count the run is held to; step 5 enforces it; step 6 cannot promote a gappy bundle.

---

## Configuration Schema

`draft/.state/okf-quality.yaml` (optional; defaults apply when absent):
```yaml
version: 1
completeness:
  min_fan_in: 2                  # components below this are defer-eligible
  require_all_above_floor: true  # hard-fail on any uncovered package >= floor
  allow_defer:                   # explicit, reasoned exceptions only
    - path: "*/tools"
      reason: "dev tooling, not product surface"
    - path: "*/test"
      reason: "test scaffolding"
thresholds_by_type:              # overrides the per-type table above
  Subsystem: { min_body_lines: 40, require_mermaid: true,  min_grounded_paths: 2 }
  Dependency: { min_body_lines: 12, require_mermaid: false, min_grounded_paths: 0 }
manifest:
  source: null                   # path to external component list when graph unavailable
strict: true
```

---

## Skill & Documentation Changes

### `skills/init/SKILL.md`
Add an **OKF Completeness Verification** block mirroring the monolith Completion Verification at [SKILL.md:1378-1410](../skills/init/SKILL.md#L1378-L1410):
```
OKF COMPLETENESS VERIFICATION (blocking — tier 3+ okf mode)
1. okf-plan-concepts.sh ran; expected/required/deferred counts logged BEFORE generation.
2. Every required concept_id in concept-plan.json has a non-stub page.
3. okf-validate-all.sh exit 0 (structure + quality + coverage).
4. coverage.md is tool-generated (verify <!-- okf:coverage-generated --> marker).
5. No required package with fan_in >= floor is MISSING.
→ If any FAIL: do NOT mv draft.tmp/ draft/. Surface validation-report.json.
```
Add red flag:
> **Writing concept pages without first running `okf-plan-concepts.sh`, or finishing generation while any `required` plan entry is unwritten, is a completeness failure — not a stylistic one.**

### `skills/init/references/okf-emitter.md`
- Replace the LLM-judged Plan step with the `okf-plan-concepts.sh` deterministic step (pipeline above).
- Document `concept-plan.json` and `validation-report.json` schemas.
- State: prose may be LLM-generated; **the concept plan, coverage.md, and validation reports are tool-generated only.**

### `core/templates/okf/concept.md`
- Add footer marker `<!-- okf:concept-template v1 -->`.
- Note: "Stub or redirect-only pages fail `okf-validate-quality.sh` and do not satisfy coverage."

### `core/templates/okf/coverage.md` — NEW
- Tool-owned, `<!-- okf:coverage-generated -->`; agents supply only deferral reasons.

### `core/templates/component-manifest.yaml` — NEW (optional)
- Schema + example for graph-unavailable repos.

### Integration build
- After editing `okf-emitter.md` / `SKILL.md`: run `make build` to regenerate the Copilot integration; `make test` to cover new tools.

---

## Implementation Phases (completeness-first, de-scoped)

### Phase 1 — Deterministic plan + coverage gate (the fix) — 2 weeks
**Deliverables:** `okf-plan-concepts.sh`, `okf-coverage-check.sh`, `coverage.md` generator + template, `okf-validate.sh` reverse-index extension, `concept-plan.json` schema, fixtures `valid-complete` / `missing-module` / `low-coverage`.
**Per-tool overhead (don't forget):** `TOOLS` entries in `scripts/lib.sh`, `tests/test-tools-okf-plan-concepts.sh` + `tests/test-tools-okf-coverage-check.sh`, `Makefile` `TEST_SCRIPTS` rows.
**Acceptance:** a bundle missing a `fan_in ≥ 2` package **fails** coverage and is **not** promoted; `valid-complete` passes. Same fixture repo → identical plan across two runs.

### Phase 2 — Anti-stub quality gate — 1.5 weeks
**Deliverables:** `okf-validate-quality.sh` (per-type thresholds, bash mermaid lint, O(n) dup), fixtures `stub-redirect` / `no-mermaid` / `bad-mermaid` / `duplicate-bodies`.
**Acceptance:** stub pages fail; a present-but-empty page no longer satisfies coverage (Layer 3 + Layer 2 compose).

### Phase 3 — Orchestrator + pipeline integration — 1 week
**Deliverables:** `okf-validate-all.sh`, `okf-render-views.sh` banner, `validation-report.json`, emitter pipeline rewrite (steps 2/5/6), SKILL Completeness Verification block, `make build`.
**Acceptance:** an init that stops before the gate leaves `draft/` untouched; refresh of one module re-derives the full plan and re-runs all layers.

### Phase 4 — Refresh & repeatability hardening — 1 week
**Deliverables:** refresh path re-derives manifest; new-since-last-run modules become `required`; `C-DRIFT` logged; `component-manifest.yaml` template for graph-unavailable repos.
**Acceptance:** adding a module to the test repo and refreshing makes that module `required` and fails the gate until documented.

### Phase 5 — CI & ergonomics — 0.5 week
**Deliverables:** `scripts/hooks/validate-wiki.sh` (optional pre-commit), README "OKF completeness gates" section, `--loosen` emergency bypass (logs `validation_report.bypassed: true`).
**Acceptance:** documented escape hatch; default stays strict for init/refresh.

**Total ≈ 6 weeks** (v1 was ~11). The completeness fix (Phases 1–3) lands in ~4.5 weeks.

---

## Testing Strategy

### Fixture bundles (no live-repo dependency)

| Fixture | Intended result |
|---------|-----------------|
| `valid-complete` | plan == produced; all gates pass |
| `missing-module` | one `required` package has no page → **coverage fail, promotion blocked** |
| `low-coverage` | 10 graph packages, 3 pages → **fail at floor** |
| `stub-redirect` | pages point to architecture.md → Layer 2 fail (and so coverage fail) |
| `no-mermaid` / `bad-mermaid` | missing/broken diagrams on diagram-required types |
| `duplicate-bodies` | copy-paste opening paragraphs → dup flag |
| `deferred-ok` | below-floor packages deferred with reasons in coverage.md → pass |
| `dangling-grounding` | `x-grounded-paths` not in repo → C-GROUND warn |

### Integration
- Full `/draft:init` (okf) on a small synthetic multi-module repo → must complete and pass with **every** module documented.
- Same repo with a module's pages deleted before validate → must **fail** promotion.
- **Repeatability:** run plan twice on the synthetic repo → byte-identical `expected[]` set.

### Regression
- `okf-validate.sh --structure-only` reproduces today's behavior exactly (migration safety).

---

## Rollout & Migration

| Stage | Action |
|-------|--------|
| R0 | Ship behind `DRAFT_OKF_STRICT=0` (gates run, warn-only) for one release |
| R1 | `DRAFT_OKF_STRICT=1` default for **new** inits; refresh warns on legacy bundles |
| R2 | Refresh auto-upgrades stub/missing pages when sources changed; fails if still incomplete |
| R3 | Migration doc: `okf-validate-all.sh` → fix gaps → commit |

Legacy thin wikis: ship `okf-quality.yaml` with a temporary lower `min_fan_in` and reduced per-type minimums. `monolith` mode unaffected.

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Required packages (`fan_in ≥ floor`) missing a page in a **promoted** bundle | **0** |
| Init promotion with any uncovered required component | **0% (blocked)** |
| Plan variance across two runs of the same snapshot | 0 (byte-identical `expected[]`) |
| Stub-pattern pages in promoted bundles | 0 |
| Deferred components without a written reason | 0 |
| False-positive rate (valid page failing its per-type gate) | < 5% |
| Validation time on a 60-page bundle | < 30s (no Node spawn) |

---

## Open Questions

1. **Sub-module granularity floor.** Is `fan_in ≥ 2` the right default boundary between "required page" and "defer-eligible", or should depth in `graph-hierarchy.sh` also gate (e.g. always require depth ≤ 2, defer deeper)? *Proposal: fan-in floor primary, depth as a config knob.*
2. **Components without graph coverage** (generated code, dynamic dispatch). *Proposal: heuristic-discovered dirs become `required` only when the engine is healthy; otherwise `deferred` + logged, never silently dropped.*
3. **Monorepo scope.** For `--module-only` init, does the plan enumerate only the scoped sub-tree, or also its direct dependencies? *Proposal: scoped sub-tree required; cross-scope deps referenced as links, not required pages.*
4. **Should coverage gate also run on `/draft:upload`?** *Proposal: yes — reuse `okf-validate-all.sh` so handoff can't ship an incomplete bundle.*
5. **Per-language min line counts?** *Proposal: per-type first; per-language only if false positives exceed target.*

---

## File Touch List

| Path | Change |
|------|--------|
| `scripts/tools/okf-plan-concepts.sh` | **NEW** (crux — deterministic expected set) |
| `scripts/tools/okf-coverage-check.sh` | **NEW** (Layer 3 completeness gate) |
| `scripts/tools/okf-validate-quality.sh` | **NEW** (Layer 2 anti-stub, per-type, bash mermaid lint) |
| `scripts/tools/okf-validate-all.sh` | **NEW** (orchestrator) |
| `scripts/tools/okf-validate.sh` | reverse path-index check + `--structure-only` |
| `scripts/tools/okf-render-views.sh` | coverage banner |
| `scripts/lib.sh` | `TOOLS` entries for the 4 new tools |
| `Makefile` | `TEST_SCRIPTS` rows for the 4 new tool tests |
| `tests/test-tools-okf-*.sh` | **NEW** (one per new tool) |
| `tests/fixtures/okf-*` | **NEW** golden bundles (see Testing) |
| `skills/init/SKILL.md` | OKF Completeness Verification block + anti-skip red flag |
| `skills/init/references/okf-emitter.md` | deterministic Plan step, pipeline 2/5/6, schemas |
| `core/templates/okf/concept.md` | template marker + anti-stub note |
| `core/templates/okf/coverage.md` | **NEW** tool template |
| `core/templates/okf-quality.yaml` | **NEW** default config |
| `core/templates/component-manifest.yaml` | **NEW** optional fallback |
| `README.md` | OKF completeness gates section |
| *(after edits)* | `make build && make test` |

---

## Summary

The wiki is incomplete because the **boundary of the work is an LLM judgment, not a tool output**. This rewrite moves that boundary into `okf-plan-concepts.sh` (graph-derived, repeatable), drives generation from it, and **blocks promotion** until every required module/sub-module/component has a real (non-stub) page or an explicit reasoned deferral. Anti-stub and structural layers stop the bundle from faking completeness. No new runtime dependency, per-type thresholds, and reuse of the existing atomic gate keep it aligned with the plugin's deterministic-shell design. Result: every init, every refresh, the same complete bundle — or a hard, legible failure that says exactly which component is missing.
