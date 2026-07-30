# Adoption audit remediation

> Verify-first: 1) re-read row + source doc · 2) `git log` + grep the symbol on main ·
> 3) confirm still required · 4) flip shipped/obsolete rows with evidence. Then code.

Source: `docs/internal/audit/draft-adoption-audit.md` (audit of v3.6.0).

- [x] AUD-1 · namespace consolidation · already shipped in 9080d6b; audit stale. Guard added: `tests/test-canonical-namespace.sh`
- [x] AUD-2 · GitHub Releases per tag · `scripts/release-notes.sh` + `.github/workflows/release.yml`; backfill of v3.3.0…v3.6.0 pending owner action
- [x] AUD-3 · zero-setup graph-less `/draft:review` · `skills/review/references/zero-setup-mode.md` + Step 0 in `skills/review/SKILL.md`
- [x] AUD-4 · README cut to 5 commands · full table moved to `docs/COMMANDS.md`
- [x] AUD-5 · maturity-level copy deleted · replaced by real findings + graph query in `web/index.html`
- [x] AUD-6 · CI gates · `.github/workflows/ci.yml` + `check-repo-size.sh` + `install-smoke-test.sh`
- [ ] AUD-7 · 20-PR efficacy benchmark · P2 · `docs/internal/benchmark/README.md`
  - [x] protocol + harness (`scripts/benchmark/`)
  - [ ] collect and freeze the 20-PR corpus
  - [ ] run both configurations per entry, grade, publish
- [x] AUD-8 · graph-engine trust story + `DRAFT_STRICT_VERIFY` · `bin/README.md` §Trust story

Owner actions (outside the repo):

- [ ] AUD-12 · backfill GitHub Releases for v3.3.0…v3.6.0 · `gh workflow run release.yml -f tag=vX.Y.Z` per tag
- [ ] AUD-13 · update the Medium post and YouTube descriptions to `drafthq/draft`

Out of scope (recorded, not actioned):

- [ ] ~~AUD-9~~ · rename away from bare "Draft" (audit §2) · won't-do · brand decision, not an engineering change
- [ ] ~~AUD-10~~ · de-escalate MANDATORY/STOP prompt style across 33 skills (audit secondary) · won't-do · behaviour-affecting rewrite of every skill; needs its own track with regression evidence
- [ ] ~~AUD-11~~ · Discord / GitHub Discussions community loop (audit secondary) · won't-do · repo/org settings + ongoing ops, outside the codebase
- [ ] ~~AUD-14~~ · clear the ~4k pre-existing markdownlint violations · won't-do here · CI reports them advisory-only; needs its own track
