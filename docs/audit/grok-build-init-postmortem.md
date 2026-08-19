# Postmortem: `/draft:init` on `grok-build` (Rust Cargo monorepo)

**Date:** 2026-07-15  
**Target repo:** `mayurpise/grok-build` (fork of `xai-org/grok-build`)  
**Draft source of truth:** `~/workspace/draft`  
**Runtime used:** `~/.cursor/plugins/local/draft` (lags workspace on some tools)  
**Symptom:** Init “passed” gates but produced incomplete context; many follow-up fixes required before `draft/` was usable.  
**Status (same day):** P0/P1 tooling fixes landed in `~/workspace/draft` and synced to the Cursor plugin — see “Remediation shipped” at bottom.

---

## Bottom line

Failures were **not** random LLM flakiness alone. Three structural gaps stacked:

1. **Wrong unit of modularity** — plan/coverage keyed off graph `.packages` that for this Rust workspace are *directory tokens + noise*, not Cargo crates.
2. **Gates measure the wrong completeness** — 16/16 “required” pages ≠ 79 crates + features documented.
3. **Derived views / validators have link bugs** — `architecture.md` TOC anchors, post-coverage structure order, grounded-path parsing, basename collisions.

Until (1)+(2)+(3) are fixed in `~/workspace/draft`, **init/refresh cannot be one-shot reliable** on large Cargo (and similar) monorepos.

---

## What happened on grok-build (timeline)

| Stage | Observed | Gate said |
|-------|----------|-----------|
| Graph build | 87k nodes / 580k edges — success | OK |
| Tier | XL (F≈51k) → `okf` mode | OK |
| `okf-plan-concepts` | **16** required concepts from `.packages` | OK |
| Plan contents | `codegen`, `common`, third_party, **noise:** `str`,`list`,`dict`,`int`,`Cargo`,`profile`,`workspace` | “Complete” |
| First wiki write | Parent maps + noise stubs; **no** per-crate pages | Coverage 16/16 PASS |
| Quality | Failed until multi-line `x-grounded-paths` rewritten to inline `[…]` | Fail then pass |
| Coverage page | `systems/coverage.md` linked `entrypoints/main.md` (wrong relative path from `systems/`) | Structure fail / flake |
| User feedback | “Lots of pages missing” | Correct — plan set was wrong |
| Manual expansion | 79 crate pages + 24 features + reference | Content usable |
| `architecture.md` | TOC anchors dead; basename collision `getting-started.md` | Links “dead” |
| Plugin vs workspace | Plugin `okf-coverage-check.sh` **missing** `../` relative-link fix present in workspace | Repro of link bug |

---

## Root causes (ordered by impact)

### RC1 — Graph `.packages` ≠ Cargo workspace members (critical)

**Evidence (live graph-arch on grok-build):**

```text
codegen, common, mermaid-to-svg, dagre_rust, mc, graphlib_rust,
ordered_hashmap, build, profile, workspace, str, list, dict, Cargo, int
```

- Real modularity: **79** `[workspace].members` crates (`xai-grok-pager`, `xai-grok-shell`, …).
- Graph “packages” are coarse path clusters + tokenizer noise (`str`, `int`, `Cargo`).
- `fan_in` on these packages was often **0**, so layering/typing is useless.

**Where:** engine `get_architecture` package clustering +  
`scripts/tools/okf-plan-concepts.sh` `plan_from_graph()` (lines ~145–168) which does:

```bash
jq -r '.packages[]? | [.name, (.fan_in // 0)] | @tsv'
```

**Effect:** Deterministic plan is complete w.r.t. **noise**, incomplete w.r.t. **crates**. Coverage gate cannot save you.

---

### RC2 — Completeness gate is plan-relative, not codebase-relative (critical)

`okf-coverage-check.sh` only checks: *every required plan entry has a non-stub page*.

It does **not** check:

- Every `Cargo.toml` workspace member
- Every top-level app crate with `[[bin]]`
- Every user-guide chapter / route surface

So a run can legitimately print `16/16 (100%)` while 90% of engineering surfaces have no concept page.

**Related:** `docs/okf-completeness-plan.md` fixed *LLM under-enumeration* by introducing the plan tool — but still **trusts graph packages as the universe**. On Rust monorepos that universe is wrong.

---

### RC3 — Init still depends on agent bulk generation (high)

Even with a perfect plan, **page bodies are LLM-written**. At XL:

- Context pressure → shallow or parent-only pages
- No deterministic emitter for “catalog rows from Cargo.toml”
- Skill allows “sparse root map” but OKF still expects every plan page to be narrated

**Effect:** Multi-round human/agent repair (crate pages, features, getting-started).

---

### RC4 — Validator / render link bugs (high — user-visible “dead links”)

| Bug | Location | Failure mode |
|-----|----------|--------------|
| `grounded_count` only parses `x-grounded-paths: [a, b]` on **one line** | `okf-validate-quality.sh` | Multi-line YAML arrays count as 0 or 1 → mass Q-GROUND false fails |
| Structure before coverage rewrite | `okf-validate-all.sh` L1→L2→L3 | L3 regenerates `coverage.md` **after** L1; can introduce dangling links that L1 never rechecks |
| Coverage relative links (plugin lag) | plugin `okf-coverage-check.sh` | Workspace has `systems/*` vs `../$cid`; **plugin does not** → `entrypoints/main.md` dangles from `systems/` |
| Rendered `architecture.md` sibling links | `okf-render-views.sh` concat | Links like `codegen.md` work in `wiki/systems/` but break at `draft/architecture.md` |
| TOC anchor slug mismatch | render TOC | e.g. `dagre-rust` vs heading `dagre_rust`; `/` stripped inconsistently (`FS/VCS` → `fsvcs`) |
| Basename collisions | render link rewrite / concept map | `features/getting-started.md` vs `overview/getting-started.md` → wrong target |
| Rustdoc bleed | agent copy of `//!` docs | `` [`Foo`](xai_foo::Bar) `` becomes dangling MD links |

---

### RC5 — Refresh cannot “heal” a bad plan (medium)

`refresh` is hash/delta driven. If the first plan missed crates:

- Freshness sees no *source* change for “missing concept”
- Re-plan from same graph packages → same incomplete set
- Incremental refresh **locks in** under-coverage until forced full re-init with a better planner

---

### RC6 — Dual install surfaces (medium ops)

| Tree | Role |
|------|------|
| `~/workspace/draft` | Development source (has some coverage link fixes) |
| `~/.cursor/plugins/local/draft` | What agents actually run |

Init on grok-build used the **plugin**. Fixes only in workspace draft do not apply until install/sync.

---

## What “good” looks like

**`/draft:init` one shot:**

1. Discover modules with **language-aware** sources (Cargo members, go modules, npm workspaces) **plus** graph packages.
2. Plan = union, noise-filtered, stable IDs.
3. Emit catalog pages (deterministic) + LLM deep-dives only for top-N hotspots.
4. Render views with **link rewrite** to `wiki/...` from draft root; TOC anchors = GFM(heading).
5. Validate: structure **after** coverage write; quality accepts multi-line grounded paths; optional cargo-coverage layer.
6. Atomic promote only if all gates pass.

**`/draft:init refresh` one shot:**

1. Re-run plan (or plan diff vs previous `concept-plan.json`).
2. **New** required concepts → generate pages even if source hashes unchanged.
3. Changed sources → regenerate mapped concepts via `path-to-concept.json`.
4. Always re-render + full link check.

---

## Fixes in `~/workspace/draft` (recommended work items)

### P0 — Plan truth for monorepos

**File:** `scripts/tools/okf-plan-concepts.sh`

1. Add `plan_from_cargo_workspace()`:
   - Parse root `Cargo.toml` `[workspace].members` (and optional `default-members`).
   - Each member → required `systems/<crate-name-slug>.md`, `resource: <path>`, type Module (or Entrypoint if `[[bin]]` only package).
2. Discovery priority:

   ```text
   --manifest > cargo|go|npm workspace discovery > graph packages > heuristic dirs
   ```

3. When cargo discovery succeeds, **do not** require graph noise packages (`str`,`list`,`dict`,`int`,`Cargo`, single-node tokens) unless they map to a real path.
4. Graph packages that *do* map to dirs (`codegen` → `crates/codegen`) become **Subsystem** parents, not substitutes for crates.
5. Emit `plan.meta.discovery = ["cargo","graph"]` and `plan.meta.crate_count` for diagnostics.

**Tests:** fixture Cargo workspace with 5 members + noisy graph JSON → plan has 5 crate IDs, zero `str`/`int`.

---

### P0 — Second coverage gate: language inventory

**New:** `scripts/tools/okf-coverage-inventory.sh` (or flag on coverage-check)

- `--inventory cargo` → every workspace member must map to a concept page (`resource` or `x-grounded-paths` contains crate path / page slug matches package name).
- Fail init if inventory miss > 0 (unless `--allow-defer`).

This makes “100% coverage” mean **repo-complete**, not **plan-complete**.

---

### P0 — Validation order + grounded paths

**File:** `scripts/tools/okf-validate-all.sh`

```text
L2 quality → L3 coverage (writes coverage.md) → L1 structure (link check last)
```

or: L1 → L2 → L3 → **L1b structure re-run**.

**File:** `scripts/tools/okf-validate-quality.sh` `grounded_count()`

- Support:

  ```yaml
  x-grounded-paths:
    - "a.rs"
    - "b.rs"
  ```

  and inline `[a, b]`.

- Count list items under the key until next non-indented key.

---

### P0 — Sync plugin install

- `make install` / documented copy: workspace `scripts/tools/*` → `~/.cursor/plugins/local/draft/scripts/tools/`.
- CI check: plugin tree hash == released build artifact.
- **Ship** workspace coverage relative-link fix into plugin (currently diverged).

---

### P1 — Render views link hygiene

**File:** `scripts/tools/okf-render-views.sh`

1. After concat, rewrite every relative MD link in `architecture.md` to `wiki/<section>/<file>.md` using a **full path map**, not basename (fixes getting-started collision).
2. Generate TOC anchors with **GFM slug algorithm** identical to what validators use (share a `gfm_slug()` in `_lib.sh`).
3. Optionally inject HTML `id="..."` on headings if viewer slug rules differ.
4. Strip rustdoc-style links `](foo::bar)` when ingesting page bodies.

**New helper:** `scripts/tools/okf-fix-links.sh draft/` — runnable post-init; exit 1 on dead links (architecture + wiki + .ai-context).

Wire into init skill final step and refresh.

---

### P1 — Deterministic catalog generation (reduce LLM load)

**New or extend emitter:**

- For each cargo member, generate a **minimum viable Module page** from:

  - path, package name, lib.rs first `//!` paragraph, deps from Cargo.toml  
  - standard mermaid stub + sections  
  without waiting for LLM  

- LLM pass only enriches top-N by hotspot / fan-in.

This makes XL init finish in one run with complete page set.

---

### P1 — Features / entrypoints discovery

**Init / plan:**

- If `**/docs/user-guide/*.md` or similar exists → optional Feature concepts from filenames.
- If `[[bin]]` / `src/main.rs` → Entrypoint concepts (not a single generic `main`).

---

### P2 — Skill contract updates

**File:** `skills/init/SKILL.md` + `skills/init/references/okf-emitter.md`

1. Explicit: **Cargo/npm/go workspace inventory is mandatory** for plan when manifests exist.
2. Completeness verification checklist includes inventory gate, not only plan gate.
3. After `okf-render-views.sh`, **must** run `okf-fix-links.sh`.
4. Refresh: always re-plan; generate pages for new required IDs.
5. Document plugin vs workspace install path.

---

### P2 — Graph engine package quality (upstream of Draft)

If `codebase-memory-mcp` is in scope:

- Rust package = crate root (`Cargo.toml` directory), not arbitrary path segment.
- Drop or namespace primitives (`str`, `int`) as packages.
- Populate real `fan_in`/`fan_out` at crate granularity.

Draft can work around this with cargo discovery even if engine stays coarse.

---

## Suggested implementation order

```text
1. grounded_count multi-line + validate-all re-check structure after coverage
2. plan_from_cargo_workspace + noise filter + tests
3. inventory coverage gate
4. okf-fix-links + render link rewrite + shared gfm_slug
5. deterministic catalog page emitter for plan entries
6. plugin install sync in Makefile
7. skill.md contract update + refresh re-plan
8. (optional) engine package clustering for Rust
```

---

## Verification recipe (acceptance)

On `grok-build` (or a fixture with ≥20 cargo members):

```bash
# clean
rm -rf draft
# init via tools the skill uses
okf-plan-concepts.sh --repo . --out /tmp/plan.json
jq '.counts.required, [.expected[].concept_id] | length' /tmp/plan.json
# required >= workspace member count (or members - deferred)

# after full init
test -f draft/wiki/systems/xai-grok-pager.md
test -f draft/wiki/systems/xai-grok-shell.md
okf-validate-all.sh draft/wiki --plan draft/.state/concept-plan.json --strict
okf-fix-links.sh draft   # 0 broken including architecture.md
# refresh no-op then touch one crate → only that concept regenerates, plan still full
```

**Pass criteria:** one init, zero manual link/page repair, architecture TOC anchors work, crate pages exist for all workspace members.

---

## Mapping: session pain → fix ID

| Session pain | Fix |
|--------------|-----|
| Only 16 concepts / missing crates | P0 cargo plan + inventory gate |
| Graph noise pages (`str`, `int`) | P0 noise filter |
| Q-GROUND false failures | P0 multi-line grounded_count |
| coverage.md dangling entrypoints link | P0 structure-after-coverage + plugin sync |
| architecture.md dead TOC / wrong getting-started | P1 render rewrite + gfm_slug + basename map |
| Multi-round generation | P1 deterministic catalog emitter |
| Refresh won’t add missing crates | P2 refresh re-plan |
| Plugin ≠ workspace behavior | P0 install sync |

---

## Out of scope / non-goals

- Making LLM prose perfect on first pass for every crate deep-dive  
- Replacing graph engine entirely  
- Changing OKF type vocabulary  

---

## References

- `docs/okf-completeness-plan.md` — original completeness design (plan-from-graph)  
- `scripts/tools/okf-plan-concepts.sh`  
- `scripts/tools/okf-validate-all.sh`  
- `scripts/tools/okf-validate-quality.sh`  
- `scripts/tools/okf-coverage-check.sh`  
- `scripts/tools/okf-render-views.sh`  
- Live evidence: `xai-org/grok-build` / `mayurpise/grok-build` draft init 2026-07-15  

---

## Remediation shipped (2026-07-15)

| Fix | Location |
|-----|----------|
| Multi-line `x-grounded-paths` count | `scripts/tools/_lib.sh` `grounded_paths_count` + quality gate |
| Validate order quality → coverage → structure | `okf-validate-all.sh` |
| Cargo/npm/go plan discovery + noise filter | `okf-plan-concepts.sh` |
| Deterministic catalog floor | `okf-emit-catalog.sh` (new) |
| Link rewrite + GFM TOC + post-fix | `okf-render-views.sh`, `okf-fix-links.sh` (new) |
| Skill/emitter contract | `skills/init/SKILL.md`, `references/okf-emitter.md` |
| Tests | `test-tools-okf-plan-concepts-cargo`, emit-catalog, fix-links; quality multi-line |
| Plugin sync | Copied into `~/.cursor/plugins/local/draft` + Claude marketplace caches |

**Smoke (grok-build plan):** `source=cargo+graph`, **84 required**, includes `systems/xai-grok-pager.md`, **excludes** `systems/str.md`.
