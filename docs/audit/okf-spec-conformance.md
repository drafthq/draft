# OKF Spec Conformance Audit

**Spec:** Open Knowledge Format (OKF) v0.1 — `GoogleCloudPlatform/knowledge-catalog/okf/SPEC.md`
**Scope:** the bundle Draft emits in `DRAFT_INIT_MODE=okf` (`draft/wiki/`) and the tooling that builds/validates it.
**Date:** 2026-06-25 · **Status:** 2 violations found → fixed; verified via `make test` (all suites) + `make lint`.

## Bottom line

Draft's OKF emitter was **structurally conformant for concept pages** but emitted **two non-conformant artifacts**: index files carried concept frontmatter (forbidden by §6/§11), and the generated `coverage.md` lacked the typed frontmatter every non-reserved file must have (§9.1/§9.2). Both are fixed. The bundle Draft produces now satisfies the OKF v0.1 conformance rules.

## Conformance matrix

| OKF rule | Requirement | Before | After |
|----------|-------------|--------|-------|
| §2 Bundle | Directory tree of markdown | ✅ | ✅ |
| §3 Concept frontmatter | Parseable YAML, non-empty `type` | ✅ | ✅ |
| §3 Recommended fields | `title`/`description`/`resource`/`tags`/`timestamp` | ✅ (required by Draft) | ✅ |
| §3 Body | Free-form, optional `# Schema`/`# Examples`/`# Citations` | ✅ (uses own H2s — allowed) | ✅ |
| §5 Cross-links | Absolute or relative; broken links tolerated | ✅ (relative — §5 permits) | ✅ |
| **§6 Index files** | **No frontmatter** | ❌ concept frontmatter on every index | ✅ no frontmatter |
| §7 Log files | `## YYYY-MM-DD` newest-first | ✅ (reserved, handled) | ✅ |
| §8 Citations | `# Citations` when external sources claimed | N/A (internal grounding via `x-grounded-paths`) | N/A |
| **§9.1/§9.2 Non-reserved files** | **Parseable frontmatter + non-empty `type`** | ❌ `coverage.md` had neither | ✅ typed `Report` frontmatter |
| §9.3 Reserved files | `index.md`/`log.md` follow §6/§7 | ❌ (see §6) | ✅ |
| **§11 Versioning** | Root `index.md` may declare **only** `okf_version` | ❌ also carried concept keys + `okf_types_version` | ✅ `okf_version` only |

## Gap A — index files carried concept frontmatter (§6 / §11)

`wiki/index.md` and every `<section>/index.md` were emitted with full concept
frontmatter (`type`, `title`, `description`, `resource`, `tags`, `timestamp`, and
`okf_types_version`). OKF §6: an index file contains **no frontmatter**; §11: the
root `index.md` may declare **only** `okf_version`. A strict OKF consumer treats
`index.md`/`log.md` as reserved and would reject the concept frontmatter.

**Fix**
- `core/templates/okf/index.md` — frontmatter reduced to `okf_version: "0.1"`; the
  Draft-internal frozen-vocab version moved to an `okf-types-version` body comment.
- `core/templates/okf/section-index.md` — frontmatter removed entirely.
- `scripts/tools/okf-validate.sh` — meta pages (`index.md`/`log.md`/`coverage.md` +
  the `<!-- okf:coverage-generated -->` marker) are now short-circuited **before**
  the concept checks, so frontmatter-less index files validate and are not counted
  as concepts.
- `scripts/tools/okf-render-views.sh` — added a `page_title()` H1-fallback so the
  rendered `architecture.md` TOC and the offline HTML nav stay readable once index
  pages lose their `title` frontmatter.

## Gap B — `coverage.md` was a non-reserved file with no typed frontmatter (§9.1 / §9.2)

`wiki/systems/coverage.md` is tool-generated and is **not** a reserved filename
(only `index.md`/`log.md` are reserved). OKF §9.1/§9.2 therefore require it to
carry parseable frontmatter with a non-empty `type`. It had neither.

**Fix**
- `scripts/tools/okf-coverage-check.sh` — `write_coverage_page` now emits an OKF
  frontmatter block (`type: Report`, `title`, `description`, `resource`) before the
  generated marker. `Report` is a descriptive (non-frozen) type — OKF permits
  producer-chosen types; Draft's frozen vocabulary applies only to code concepts,
  and the validator exempts the page via `is_meta_page`.
- `scripts/tools/okf-render-views.sh` — `build_concept_map` now skips
  `coverage.md`/`log.md`/the coverage marker so the now-typed coverage page does not
  leak into the routing table.

## Accepted deviations (spec-permitted, no change)

- **Relative cross-links.** §5 supports both; absolute is *recommended* for
  stability, not required. Draft uses relative links (they resolve in the validator
  and the offline viewer).
- **Table-form index listings.** §6 illustrates bullet listings; a markdown table is
  still a concept listing and consumers tolerate it. Draft's tables are
  tool-generated between `CONCEPT-MAP` markers (links cannot dangle).
- **Internal grounding instead of `# Citations`.** §8 applies only when a concept
  claims *external* sources. Draft grounds concepts in the call graph via
  `x-grounded-paths`/`Blast radius`, not external citations.

## Gap B follow-on — `coverage.md` dangling links for non-`systems/` concepts

Surfaced while testing on a real repo (see below). `write_coverage_page` linked each
row as `${cid#systems/}`, which resolves correctly only for `systems/*` concepts.
For `entrypoints/*` (and any other section) the link dangled from
`systems/coverage.md` and failed structure validation — so **any** OKF bundle with
entrypoints could not be promoted. Fixed to prefix `../` for non-`systems/`
concepts (`scripts/tools/okf-coverage-check.sh`); regression test added.

## Verification

- `make build` — integrations regenerated from the changed templates (OK).
- `make test` — all 38 suites pass, including `okf-validate`, `okf-render-views`,
  `okf-coverage-check`, `okf-validate-all`, `okf-validate-quality`. New cases:
  index files counted as meta (concept count 3→1), a typed `coverage.md` accepted
  as meta, and `coverage.md` entrypoints links resolve (`../` prefix).
- `bash -n` on all edited scripts — clean.

### Real-repo end-to-end (`finbrainiac-platform`, 1665 files)

Drove the modified emitter pipeline (`graph-snapshot` → `okf-plan-concepts` →
generate → `okf-coverage-check` → `okf-render-views` → `okf-validate-all`) to
produce a 35-concept OKF bundle (15 Module + 20 Entrypoint + overview/coverage).

- Full gate: `structure:pass quality:pass coverage:pass → valid:true`.
- Direct OKF v0.1 §-by-§ scan of the emitted bundle:
  - §11/§6 root `index.md` frontmatter = `okf_version` only ✅
  - §6 every section `index.md` frontmatter-free ✅
  - §9.1/§9.2 all 37 non-reserved `.md` carry a non-empty `type` ✅
  - `coverage.md` typed (`type: Report`) ✅
  - §7 `log.md` ISO date heading ✅
- Verdict: **OKF v0.1 conformant.** Test artifact (`draft.tmp/`) removed; the
  repo's existing curated `draft/` was left untouched (page prose in the test bundle
  is graph-grounded but templated — a conformance fixture, not a curated wiki).
