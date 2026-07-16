# Work Tracker

**Overall: [██████████] 100% — 37 done · 0 in-progress / 37**

> Canonical status lives here. Detail lives in the linked source docs.
> **Verify-first (before coding any item):** 1) re-read state · 2) verify the gap
> still exists on main (`git log` + grep the symbol) · 3) confirm still required ·
> 4) flip done/obsolete rows to DONE/WON'T-DO with evidence. Only then write code.

Origin: full-codebase code review (2026-07-15), 10 finder angles + per-candidate
adversarial verification + gap sweep. 33 findings CONFIRMED with repros, 1 PLAUSIBLE,
1 REFUTED, 2 sweep additions. Fix pass completed same day; follow-up pass closed every
remaining row (gaps + deferred refactors). `make test` (72 suites) green.

## Status taxonomy
DONE · IN-PROGRESS · BLOCKED · PLANNED · GAP · DESIGN-ONLY · WON'T-DO · SIGN-OFF

## Workstream rollup
| Workstream | Progress | DONE | PLANNED | GAP | WON'T-DO | Notes |
|---|---|---|---|---|---|---|
| A. Shell-tool correctness | `[██████████] 100%` | 15 | 0 | 0 | 0 | set -e crashes, escaping, validator false-negatives |
| B. Build pipeline & site | `[██████████] 100%` | 6 | 0 | 0 | 0 | Makefile, build scripts, sitemap |
| C. CLI & website JS | `[██████████] 100%` | 4 | 0 | 0 | 0 | installer, marker, upgrade semantics, a11y |
| D. Tests & registries | `[██████████] 100%` | 4 | 0 | 0 | 0 | all suites wired and green |
| E. Docs & metadata | `[██████████] 100%` | 5 | 0 | 0 | 0 | counts, changelog, integrations regenerated |
| F. Deferred cleanups | `[██████████] 100%` | 3 | 0 | 0 | 1 | refactors + arg guards shipped |

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
| [x] | WT-028 | test-hld-lld-contract.sh wired & green — test indent-regex fixed (spec.md already declared all approver keys); track-architecture.md template deleted + dropped from CORE_FILES | D | DONE | P2 | — | review C1b |
| [x] | WT-029 | test-skill-script-invocation.sh wired & green — graph-query.md invocations use "$DRAFT_TOOLS/"; 24 files migrated to the override-first canonical preamble | D | DONE | P2 | — | review C1c |
| [x] | WT-030 | CHANGELOG.md — 3.5.0–3.5.3 entries added | E | DONE | P2 | — | review C2 |
| [x] | WT-031 | CLAUDE.md — counts corrected (now 51 tools / 72 test suites / 66 core files after the follow-up pass) | E | DONE | P2 | — | review C3/C4/C5 |
| [x] | WT-032 | scan-markers.sh — unimplemented --include-untracked removed from usage | E | DONE | P3 | — | review C34 |
| [x] | WT-033 | tool-resolver.md — resolution order matches resolve-tools.sh (dogfood = step 2) | E | DONE | P3 | — | review C37 |
| [x] | WT-034 | Integrations regenerated (make build) after init/OKF + core doc changes | E | DONE | P0 | — | review C6 |
| [x] | WT-035 | graph_bootstrap() in _lib.sh; 15 wrappers deduped (incl. hotspot-rank, cycle-detect, mermaid-from-graph) | F | DONE | P3 | — | review C8 |
| [x] | WT-036 | SKILL_META table in lib.sh replaces both case statements; tests source lib.sh directly | F | DONE | P3 | — | review C9 |
| [x] | WT-037 | arg-parse value guards: 89 sites across 38 tools use ${2:?--flag requires a value} | F | DONE | P3 | — | review C19 |
| [x] | ~~WT-038~~ | validate_skill_body_format `\|\| true` masking — REFUTED as active bug | F | WON'T-DO | — | — | review C23 |

## Per-workstream detail
No open items — every row is DONE except WT-038 (WON'T-DO, refuted finding).

## Source-document map
| Source doc | Covers IDs |
|---|---|
| Session review evidence (finder/verifier transcripts, 2026-07-15) | WT-001…WT-038 |
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
| 2026-07-15 | WT-028/029 | GAP — left unwired deliberately | Makefile comment documented both |
| 2026-07-15 | WT-028, WT-029, WT-035, WT-036 | DONE — follow-up pass | both suites wired into TEST_SCRIPTS; `make test` 72/72 green |
| 2026-07-15 | WT-037 | WON'T-DO → DONE on request ("fix all the issues") | dangling flag now errors `--flag requires a value`, exit 1 |
