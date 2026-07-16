# Work Tracker

**Overall: [█████████░] 88% — 30 done · 0 in-progress / 34**

> Canonical status lives here. Detail lives in the linked source docs.
> **Verify-first (before coding any item):** 1) re-read state · 2) verify the gap
> still exists on main (`git log` + grep the symbol) · 3) confirm still required ·
> 4) flip done/obsolete rows to DONE/WON'T-DO with evidence. Only then write code.

Origin: full-codebase code review (2026-07-15), 10 finder angles + per-candidate
adversarial verification + gap sweep. 33 findings CONFIRMED with repros, 1 PLAUSIBLE,
1 REFUTED, 2 sweep additions. Fix pass completed same day; `make test` (70 suites) green.

## Status taxonomy
DONE · IN-PROGRESS · BLOCKED · PLANNED · GAP · DESIGN-ONLY · WON'T-DO · SIGN-OFF

## Workstream rollup
| Workstream | Progress | DONE | PLANNED | GAP | WON'T-DO | Notes |
|---|---|---|---|---|---|---|
| A. Shell-tool correctness | `[██████████] 100%` | 15 | 0 | 0 | 0 | set -e crashes, escaping, validator false-negatives |
| B. Build pipeline & site | `[██████████] 100%` | 6 | 0 | 0 | 0 | Makefile, build scripts, sitemap |
| C. CLI & website JS | `[██████████] 100%` | 4 | 0 | 0 | 0 | installer, marker, upgrade semantics, a11y |
| D. Tests & registries | `[█████░░░░░] 50%` | 2 | 0 | 2 | 0 | 2 unwired failing suites need design decisions |
| E. Docs & metadata | `[██████████] 100%` | 5 | 0 | 0 | 0 | counts, changelog, integrations regenerated |
| F. Deferred cleanups | `[░░░░░░░░░░] 0%` | 0 | 2 | 0 | 2 | refactors deferred by choice |

## Backlog (risk/impact-first)
| Done | ID | Item | WS | Status | Pri | Blocked by | Source |
|---|---|---|---|---|---|---|---|
| [x] | WT-001 | check-track-hygiene.sh — grep pipe killed script on zero TBD | A | DONE | P0 | — | review C35 |
| [x] | WT-002 | verify-doc-anchors.sh — grep-pipe crash on (planned) line with no path | A | DONE | P0 | — | review C36 |
| [x] | WT-003 | okf-validate.sh — multi-line JSON arrays skipped by line-oriented grep | A | DONE | P0 | — | review C30 |
| [x] | WT-004 | verify-citations.sh — range citations truncated to start line | A | DONE | P0 | — | review C31 |
| [x] | WT-005 | gq_escape — backslash not escaped (Cypher literal breakout) | A | DONE | P0 | — | review C17 |
| [x] | WT-006 | graph-impact.sh — hand-built JSON payload fabricated empty-impact success | A | DONE | P0 | — | review C26 |
| [x] | WT-007 | graph-preflight.sh — non-numeric auto_index_limit abort | A | DONE | P1 | — | review C15 |
| [x] | WT-008 | hotspot-rank.sh — jq crash on null qualified_name | A | DONE | P1 | — | review C16 |
| [x] | WT-009 | gq_symbol_status — probe failure now returns probe-failed (+ graph-callers inline copy routed through helper) | A | DONE | P1 | — | review C27 |
| [x] | WT-010 | graph-arch.sh — source:"memory-graph" added on success | A | DONE | P1 | — | review C28 |
| [x] | WT-011 | graph-snapshot.sh — PROJECT/VER escaped for YAML | A | DONE | P1 | — | review C18 |
| [x] | WT-012 | migrate-track-frontmatter.sh — EOF newline restored | A | DONE | P1 | — | review C32 |
| [x] | WT-013 | emit-skill-metrics.sh — payload trimmed + object-shape guard | A | DONE | P1 | — | review C33 |
| [x] | WT-014 | check-track-hygiene.sh — hygiene_budget caps wired from metadata.json | A | DONE | P2 | — | sweep S2 |
| [x] | WT-015 | _lib.sh — dead .draft-install-path fallback deleted | A | DONE | P2 | — | review C29 |
| [x] | WT-016 | Makefile clean — now removes integrations/agents/AGENTS.md | B | DONE | P2 | — | review C20 |
| [x] | WT-017 | fetch-memory-engine.sh — --help sed range fixed (2,20p) | B | DONE | P2 | — | review C21 |
| [x] | WT-018 | build-integrations.sh — @draft transform repeated to catch adjacent mentions | B | DONE | P2 | — | review C22 |
| [x] | WT-019 | package.sh — verify-graph-binary failure now echoes | B | DONE | P3 | — | review C24 |
| [x] | WT-020 | validate_skill_body_format accepts pre-extracted body (halves parses) | B | DONE | P3 | — | review C10 |
| [x] | WT-021 | build-book.sh — sitemap blog URLs derived from web/blog/*/ | B | DONE | P1 | — | sweep S1 |
| [x] | WT-022 | cli marker.js — install plan's actual root passed as hint | C | DONE | P1 | — | review C12 |
| [x] | WT-023 | cli fsx.js copyTree — mirror semantics (rm before cp) | C | DONE | P1 | — | review C13 |
| [x] | WT-024 | cli installer.js — spawnSync shell:true on win32 | C | DONE | P2 | — | review C11 (PLAUSIBLE) |
| [x] | WT-025 | web terminal.js — focusout release added | C | DONE | P2 | — | review C14 |
| [x] | WT-026 | foo.sh placeholder → git-metadata.sh; test-cross-references.sh wired into Makefile | D | DONE | P1 | — | review C1a |
| [x] | WT-027 | Tests added + wired for check-graph-usage-report, check-template-noop, emit-skill-metrics | D | DONE | P1 | — | review C7 |
| [ ] | WT-028 | test-hld-lld-contract.sh unwired & failing — approvers-key drift + retired track-architecture.md template still in CORE_FILES; needs template-contract decision | D | GAP | P2 | — | review C1b |
| [ ] | WT-029 | test-skill-script-invocation.sh unwired & failing — 22 bare tool invocations in graph-query.md; 22 non-canonical DRAFT_TOOLS preambles; wide content migration | D | GAP | P2 | — | review C1c |
| [x] | WT-030 | CHANGELOG.md — 3.5.0–3.5.3 entries added | E | DONE | P2 | — | review C2 |
| [x] | WT-031 | CLAUDE.md — counts corrected (51 tools, 70 test suites, 67 core files) | E | DONE | P2 | — | review C3/C4/C5 |
| [x] | WT-032 | scan-markers.sh — unimplemented --include-untracked removed from usage | E | DONE | P3 | — | review C34 |
| [x] | WT-033 | tool-resolver.md — resolution order matches resolve-tools.sh (dogfood = step 2) | E | DONE | P3 | — | review C37 |
| [x] | WT-034 | Integrations regenerated (make build) after init/OKF + core doc changes | E | DONE | P0 | — | review C6 |
| [ ] | WT-035 | Dedupe 6-line engine bootstrap across 12 graph wrappers into shared helper | F | PLANNED | P3 | — | review C8 (deferred refactor) |
| [ ] | WT-036 | Collapse get_skill_header/get_copilot_trigger parallel case tables into one data table | F | PLANNED | P3 | — | review C9 (deferred refactor) |
| [x] | ~~WT-037~~ | arg-parse `$2` guards across 18 tools (85 sites) — crash already exits 1; only message quality differs | F | WON'T-DO | — | — | review C19 |
| [x] | ~~WT-038~~ | validate_skill_body_format `\|\| true` masking — REFUTED as active bug | F | WON'T-DO | — | — | review C23 |

## Per-workstream detail
Open items only (done rows carry their fix description inline above):
- **WT-028** — decide the approvers-key contract (spec.md `tech_leads/arb_leads/...` vs hld/lld expectations), remove or re-legitimize `core/templates/track-architecture.md` (test says retired, CORE_FILES still ships it), then wire the suite into Makefile TEST_SCRIPTS.
- **WT-029** — migrate `core/shared/graph-query.md` (22 bare `scripts/tools/*.sh` mentions) and 22 skill/core files to the canonical 3–4-line DRAFT_TOOLS preamble, then wire the suite in.
- **WT-035** — add `graph_bootstrap()` to `_lib.sh`/`_graph_queries.sh`; 11 uniform wrappers call it directly, graph-traces keeps its spliced validation line, graph-impact needs a target/kind-parameterized bail. All 12 have dedicated tests covering both paths.
- **WT-036** — one table (skill → header/trigger) next to SKILL_ORDER in scripts/lib.sh; keep the wildcard fallback; tests/test-trigger-functions.sh guards the refactor.

## Source-document map
| Source doc | Covers IDs |
|---|---|
| Session review evidence (finder/verifier transcripts, 2026-07-15) | WT-001…WT-038 |
| Makefile (comment block under TEST_SCRIPTS) | WT-028, WT-029 |
| core/shared/tool-resolver.md | WT-026, WT-033 |
| core/shared/graph-query.md | WT-010, WT-026, WT-029 |
| core/templates/metadata.json + core/shared/discovery-schema.md | WT-014 |
| CLAUDE.md / CHANGELOG.md | WT-030, WT-031 |

## Reconciliation log
| Date | ID | Change | Evidence |
|---|---|---|---|
| 2026-07-15 | WT-037 | WON'T-DO — low severity, wide surface, no behavioral gain | verifier C19: exit 1 either way |
| 2026-07-15 | WT-038 | WON'T-DO — REFUTED; latent only | verifier C23: both call sites gate extract_body first |
| 2026-07-15 | WT-001…027, 030…034 | DONE — fix pass applied in one change-set | `make test` all 70 suites green incl. new regression cases (zero-TBD, planned-no-path, multi-line path-index, range citation, EOF newline, gq_escape backslash, metrics trailing-newline) |
| 2026-07-15 | WT-028/029 | GAP — left unwired deliberately | Makefile comment documents both, pointing here |
