# xreview — whole-codebase audit (blind-spot pass)

**Date:** 2026-08-18 · **Mode:** audit (no diff) · **Scope:** repo root · **Base:** `9339ac0`

Second audit pass of the same day. The first
([`xreview-codebase-2026-08-18.md`](xreview-codebase-2026-08-18.md)) fixed 15 findings
and closed by naming exactly what it had **not** read:

> ~40 of the 53 `scripts/tools/*.sh` (≈6,000 lines), notably the OKF cluster and the
> `check-*`/`verify-*` family. **This is the largest blind spot.** … `tests/` (81 files,
> ≈8,000 lines) — executed, not read.

This pass targets that list rather than re-covering ground. All seven Important findings
below were reproduced by running the code; four flip an exit status.

`make test` — **80/80 suites, 1,023 assertions, exit 0** (before and after).
`make build` reproduces byte-identical integrations.

---

## Important (7)

### 1. `[security]` `scripts/tools/okf-render-views.sh:395` — the offline viewer executes attacker-controlled page titles

`render_web` inlines every page as JSON inside a `<script>` block. The **markdown body**
was passed through `sed 's#</#<\\/#g'`; `rel`, `title`, and `type` were not. JSON escaping
does not neutralize a literal `</script>` — the browser's tokenizer ends the script
element before the JSON parser ever sees the string.

**Failure (demonstrated):** a concept page with

```yaml
title: "Pwn</script><script>alert(1)</script>"
```

produced a viewer whose data block carries a raw `</script>`:

```console
$ grep -n 'alert(1)' viewer.html
51:"systems/xss.md": {"title": "Pwn</script><script>alert(1)</script>", "type": "Module", …
```

Opening `wiki/web/index.html` runs the injected script. Page titles are derived from
repo content by the OKF emitter, so on an untrusted repository this is
repo-content → JS execution in the reader's browser.

**Fix:** the whole emitted data block is piped through the `</` filter, so every field
is covered instead of one. **Regression test:** `test-tools-okf-render-views.sh` asserts
no raw `</script>` survives anywhere in the `PAGES` object.

### 2. `[bug]` `scripts/tools/okf-validate.sh:186` — a page that documents `${HOME}` cannot be promoted

The §3b template-token scan is `grep -qE '\{[A-Z][A-Z0-9_]+\}'`, which matches the
`{HOME}` **inside** `${HOME}`. Any wiki page quoting a shell or CI variable — or a fenced
code block containing one — fails structure validation, and `okf-validate-all.sh` gates the
atomic `draft.tmp/ → draft/` promotion on that exit code.

**Failure (demonstrated):**

```console
$ okf-validate.sh wiki
OKF bundle INVALID: wiki (2 pages, 1 concepts)
  - systems/shelly.md: unreplaced template token '{HOME}'
exit=1
```

The page's only sin was the sentence *"Reads the `${HOME}` and `${PATH_INDEX}` variables
at startup."* `okf-validate-quality.sh:148` (`TOKEN_RE='\{[A-Z_]+\}'`) has the same flaw.

**Fix:** a shared `template_scan_text` / `template_scan_body` helper strips fenced code
blocks and masks `${VAR}` before scanning, in both tools. A genuine `{SECTION_TITLE}` in
prose still fails — asserted.

### 3. `[bug]` `scripts/tools/verify-doc-anchors.sh:76` — every anchor to an underscored heading is reported missing

`md_slugs` builds the slug with `gsub(/[^a-z0-9-]/, "", s)`, stripping `_`. GitHub keeps
underscores in heading ids, and so does this repo's own `_lib.sh:gfm_slug`
("Keeps underscores; strips other punctuation"). Two slug implementations, one wrong.

**Failure:** heading `## draft_init modes` → GitHub anchor `#draft_init-modes`;
`md_slugs` yields `draftinit-modes`; the correct link
`[modes](./hld.md#draft_init-modes)` is recorded as `missing-anchor` and the tool exits 1.

**Fix:** `gsub(/[^a-z0-9_-]/, "", s)`. A genuinely absent anchor still fails — asserted.

### 4. `[bug]` `scripts/tools/okf-fix-links.sh:228` — link validation can be defeated by an unrelated file in the caller's cwd

The checker resolved each link against `[src.parent/path, draft/path, Path(path)]`.
`Path(path)` is **process-CWD-relative** — never a meaningful base for a link inside a
document.

**Failure (demonstrated):** same document, same wiki, same broken link; only the caller's
cwd differs:

```console
$ cd /tmp/elsewhere && okf-fix-links.sh --file …/architecture.md --wiki …/wiki
BROKEN=1
okf-fix-links: FAILED (1 broken)                      # exit 1

$ touch /tmp/elsewhere/totally-not-here.md            # unrelated file, same name
$ cd /tmp/elsewhere && okf-fix-links.sh --file …/architecture.md --wiki …/wiki
BROKEN=0
okf-fix-links: clean                                  # exit 0
```

**Fix:** drop the CWD candidate. **Regression test:** both cwd states asserted to exit 1.

### 5. `[silent-failure]` `scripts/tools/parse-git-log.sh:132` — a failing `git log` is indistinguishable from an empty range

The commit stream ran as `done < <(git "${GIT_ARGS[@]}")`. A process substitution
discards the child's exit status, so the tool emitted zero JSONL records and **exit 0**.

**Failure (demonstrated):**

```console
$ parse-git-log.sh --branch does-not-exist-xyz
fatal: ambiguous argument 'does-not-exist-xyz': unknown revision …
exit=0                                # ← consumer reads "no commits"

$ parse-git-log.sh --limit abc
exit=0                                # ← silent, no diagnostic at all
```

The `--limit` case is worse: `git log -n abc` parses the count as 0 and exits **0**, so
no amount of status checking helps — it needs input validation.

**Fix:** stage git's output through a temp file and fail on non-zero status; reject a
non-numeric `--limit` up front. Both asserted.

### 6. `[bug]` `scripts/tools/verify-doc-anchors.sh` — a documented check was disabled, leaving dead code behind

The file header advertised check #1:

> `- §X.Y or §X numbered-section references → target document must contain a heading
> whose text starts with that number.`

The implementation was a bare `:` no-op under 13 lines of comment explaining why it had
been turned off, and `md_numbered_headers()` — its only consumer — had **zero call sites**
repo-wide (verified by grep). The tool's `--help` printed the disabled check as active.

**Fix:** removed the dead function and the no-op; the header now states plainly that
prose `§X.Y` is deliberately not validated and why.

### 7. `[bug]` `scripts/tools/mermaid-from-graph.sh:95`, `scripts/tools/hotspot-rank.sh:68` — engine payloads built by string concatenation

Both interpolated `$PROJECT` straight into a JSON literal:

```bash
memory_cli get_architecture "{\"project\":\"$PROJECT\",\"aspects\":[\"hotspots\"]}"
```

Every other call site of the **same tool** builds the payload with `jq -n --arg`
(`graph-arch.sh:60`, `graph-snapshot.sh:101,112`), and `memory_index_bounded` carries an
explicit comment that payloads are built with jq "so a repo path containing a `"` or `\`
can never corrupt the JSON sent to the engine". These two were the only exceptions in the
tree (mechanically verified).

**Fix:** `jq -n --arg p "$PROJECT" '{project:$p, aspects:[…]}'` at both sites.

---

## Suggestions (10) — all applied

- `[bug]` `okf-validate-quality.sh:117` — `grep -qE '[A-Za-z0-9_]\s*&\s*[A-Za-z0-9_]'`.
  `\s` is a GNU extension, not POSIX ERE; on BSD/macOS grep it means a literal `s`, so
  the mermaid `&`-chaining check silently stopped matching `A & B` (confirmed with the
  BSD-equivalent pattern). macOS is a supported target — `_lib.sh` carries a `stat -f`
  fallback and a bash-3.2 portability note. → `[[:space:]]`. Same in
  `okf-plan-concepts.sh:178`.
- `[bug]` `_lib.sh:grounded_paths_count` — printed **nothing** (not `0`) for a page with
  no `x-grounded-paths`, so `okf-validate-quality.sh` rendered `x-grounded-paths  < 2`.
  Now always prints an integer; asserted.
- `[bug]` `graph-init.sh` — `root-link.json` and both `--json` shapes interpolated repo
  paths with raw `printf` while its sibling `graph-preflight.sh` `json_escape`s every
  string. → escaped.
- `[bug]` `graph-preflight.sh:172` — `auto_index_limit` was emitted bare into the JSON
  report straight from `awk '{print $3}'`; the numeric guard existed only for the
  comparison at :174. A format change in the engine's `config list` would emit invalid
  JSON. → numeric-or-null.
- `[simplify]` `okf-render-views.sh:253` — the inline `desc=` awk in `build_concept_map`
  duplicated `page_desc()` verbatim six lines below it. → calls the function.
- `[simplify]` `okf-plan-concepts.sh:~380` — two adjacent `if [[ ${#E_ID[@]} -eq 0 ]]`
  blocks both invoked `plan_from_heuristic`; the second can never add what the first
  didn't. → one call site.
- `[comment]` `check-template-noop.sh:54` — "Skip changes to the templates themselves
  living under scripts" described a filter that does not exist in the `case`. → removed.
- `[comment]` `verify-graph-binary.sh` — the documented resolution order omitted
  `DRAFT_MEMORY_DISABLE`, which short-circuits everything, so a user who set it was told
  "Install it (scripts/fetch-memory-engine.sh) or put it on PATH" — the wrong remedy.
  → documented, and the diagnostic now names the variable.
- `[comment]` `okf-render-views.sh:4` — "the **two** derived views" above three numbered
  items; and the `strip_frontmatter` doc comment sat above `rewrite_body_links` instead
  of its own function (same class as the previous audit's S7). → both corrected.
- `[comment]` `classify-files.sh:37` — `--help` claimed generated-file detection matches
  "Code generated" or "DO NOT EDIT"; the code also matches `@generated` and
  `autogenerated`. → text matches code.
- `[simplify]` dead variables removed: `md_line` (`verify-citations.sh:194`), `stream`
  and `rel` (`check-skill-line-caps.sh`), `ups=2` (`graph-init.sh`, overwritten on the
  next line), `status` and two positional `ftype` reads (`okf-coverage-check.sh`),
  `STABLE_KEYS` (`migrate-track-frontmatter.sh` — an allow-list the drop-list-driven
  rewrite never consulted; kept as a comment), and `head_sha`
  (`benchmark/bench-grade.sh`). `finish_test`'s `suite_name` was accepted and discarded
  by all 11 callers that pass one — it is now printed.

---

## Investigated and deliberately left alone

**`scripts/lint.sh:20` blanket-disables `SC2034`** (shellcheck's unused-variable check).
The obvious recommendation is to remove `-e SC2034`, since that suppression is why unused
variables keep surfacing by hand across audits — `DO_CHECK` in the previous pass, five more
in this one. Running shellcheck 0.11.0 over the tree settles it: **20 SC2034 hits without
the suppression, of which only 5 were real.** Those 5 are now gone (`rel`, `status`,
`ftype` ×2, `STABLE_KEYS`, `head_sha` — see the suggestions list). The remaining 14 are
variables shellcheck **structurally cannot resolve**:

| Site | Count | Why it is not a defect |
|---|---|---|
| `scripts/lib.sh` — `SKILL_ORDER`, `CORE_FILES`, `TOOLS`, `SKILLS_DIR`, `CORE_DIR` | 5 | The file is a definitions module; its only consumer is the script that `source`s it. Shellcheck does not follow `source`. |
| `tests/*` — `OUT`, `OUT3`, `VOUT`, `pm_out`, `HLD_REQUIRED_KEYS`, `LLD_REQUIRED_KEYS` | 9 | Set by a shared `run()` helper that captures output for the assertions that want it; some suites assert only on the exit code. |

Enabling the rule would therefore add ~14 `# shellcheck disable=SC2034` annotations to
correct code and catch nothing. **The suppression stays** — it is the right call for a
codebase whose shared definitions live behind `source`. Hand review remains the way these
get caught, which is what happened here.

Confirmed after the change: `shellcheck --severity=warning -e SC1091,SC1090,SC2034,SC2164,SC2143`
over `scripts/` + `tests/` exits **0**.

---

## Strengths

- **The previous audit's fixes hold.** `reject_write_verbs` covers both `--cypher` and
  `--tool` payloads carrying a `query`; `apply_dest_mode` is applied at every `mktemp`→`mv`
  site including the three new ones in the OKF cluster; `resolve-tools.sh` no longer trusts
  cwd. Nothing regressed.
- **`build-integrations.sh` traps its own temp files** (`trap 'rm -f "$copilot_tmp"' EXIT`,
  cleared before the successful `mv`) — the stale `copilot-instructions.md.*` files sitting
  in the working tree predate that trap and are gitignored plus covered by `make clean`.
- **Fail-loud is the default in the graph wrappers.** `graph_bootstrap` returns 1 and each
  wrapper routes it to its own documented unavailable-JSON shape rather than emitting an
  empty success.
- **`okf-validate-all.sh` documents its own layer ordering with the bug that motivated it**
  ("Historical bug: structure-before-coverage let init promote a bundle whose coverage.md
  still had broken relative links"). Rare and load-bearing.
- **The OKF gate is genuinely three-layered** — structure, per-type semantic depth, and
  plan-vs-reality coverage — with the promotion `mv` conditioned on the aggregate. The
  design is sound; every finding above is an implementation slip inside it, not a hole in it.
- **`graph-preflight.sh` `json_escape`s every string in its report** and defaults every
  field so `--json` is well-formed even on the failure paths. It is the model the two
  outliers above were fixed toward.

---

## Coverage

**Reviewed in full this pass (risk-ranked) — the previous audit's blind spots:**

| Unit | Files | Depth |
|---|---|---|
| OKF cluster | `okf-plan-concepts.sh`, `okf-render-views.sh`, `okf-validate.sh`, `okf-validate-quality.sh`, `okf-validate-all.sh`, `okf-coverage-check.sh`, `okf-emit-catalog.sh`, `okf-fix-links.sh` (≈2,200 lines) | line-by-line + executed |
| `check-*` family | `check-track-hygiene.sh`, `check-scope-conflicts.sh`, `check-skill-line-caps.sh`, `check-graph-usage-report.sh`, `check-template-noop.sh` | line-by-line |
| `verify-*` family | `verify-citations.sh`, `verify-doc-anchors.sh`, `verify-graph-binary.sh` | line-by-line + executed |
| Data/report tools | `classify-files.sh`, `parse-git-log.sh`, `parse-reports.sh`, `adr-index.sh`, `render-track.sh`, `run-coverage.sh`, `detect-test-framework.sh`, `scan-markers.sh`, `validate-frontmatter.sh` | line-by-line |
| Graph orchestration | `graph-preflight.sh`, `graph-init.sh`, `mermaid-from-graph.sh`, `hotspot-rank.sh` | line-by-line |
| `tests/` | `test-helpers.sh` line-by-line; all 80 suites surveyed for exit-code convention, assertion density, and orphan wiring | structural |
| Build/lint | `Makefile`, `scripts/lint.sh`, `scripts/package.sh` (args) | line-by-line |
| Whole tree | 148 `*.sh` | mechanical sweep: non-POSIX regex escapes, string-concatenated engine payloads, `set -e` behavior on trailing AND-lists (verified empirically — no false findings filed), plus a full shellcheck pass with `SC2034` re-enabled |

**Verified negatives** — checked and found sound, no finding filed:

- Every test file in `tests/` is wired into `Makefile:TEST_SCRIPTS`; the only unwired file
  is `test-helpers.sh`, which is the shared library, not a suite.
- `graph-init.sh:root_link_relpath` computes `len(segments) + 2` `../` hops — correct for
  `<root>/<sub>/draft/graph` → `<root>/draft/graph` at every nesting depth.
- Trailing `[[ … ]] && cmd` lines do **not** trip `errexit` (verified by execution), so the
  ~20 such lines across the OKF tools are not the latent aborts they look like.
- `_graph_queries.sh:gq_escape` and the `graph-*.sh` wrappers — re-confirmed clean, matching
  the previous audit.

**Still not reviewed line-by-line — where remaining risk sits:**

- `scripts/build-book.sh` (684 lines of HTML generation) and `scripts/benchmark/*` (459
  lines). Neither ships in the plugin; both were left for budget.
- The 80 test suites were surveyed structurally, not read for assertion correctness. A
  suite that asserts the wrong thing still looks green from outside — this pass narrowed
  that gap (`test-helpers.sh` read, wiring and exit conventions verified) but did not close it.
- `skills/**/SKILL.md`, `core/**` (≈150 markdown files) — covered by the build contract and
  `make test`, not read as prose. Unchanged from the previous audit.
- `cli/`, `web/`, CI workflows, `fetch-memory-engine.sh`, `build-integrations.sh`,
  `resolve-tools.sh`, `graph-query.sh` — read in full by the **previous** audit; only
  spot-checked here to confirm its fixes held.

**xsecurity:** not requested (`--xsecurity` not passed); the lightweight `security`
dimension ran instead.

---

## Resolution (2026-08-18)

All 7 Important findings and all 10 suggestions applied on branch `xreview-audit`.
`make test` green (80 suites, 1,023 assertions); `make build` byte-identical.

| # | Finding | Fix | Regression test |
|---|---------|-----|-----------------|
| 1 | viewer script injection | whole data block filtered, not just `md` | `test-tools-okf-render-views.sh` — hostile title, no raw `</script>` survives |
| 2 | `${VAR}` blocks promotion | `template_scan_text`/`template_scan_body` strip fences + mask `${VAR}` | `test-tools-okf-validate.sh`, `test-tools-okf-validate-quality.sh` — `${HOME}` passes, `{SECTION_TITLE}` still fails |
| 3 | underscore slugs | `gsub(/[^a-z0-9_-]/…)` | `test-tools-verify-doc-anchors.sh` — `#draft_init-modes` resolves; absent anchor still fails |
| 4 | CWD-dependent link check | dropped the `Path(path)` candidate | `test-tools-okf-fix-links.sh` — both cwd states exit 1 |
| 5 | silent `git log` failure | temp-file staging + `--limit` validation | `test-tools-parse-git-log.sh` — bad ref and bad limit both non-zero |
| 6 | disabled check + dead code | removed; header corrected | — (removal) |
| 7 | concatenated engine payloads | `jq -n --arg` at both sites | existing `test-tools-hotspot-rank.sh` / `test-tools-mermaid-from-graph.sh` |

**Lint verified locally** (via `npx`, neither tool is installed on this host):
`shellcheck` 0.11.0 over `scripts/` + `tests/` with the repo's flags — exit 0;
`markdownlint-cli` 0.45.0 over the repo's glob — exit 0. Both gates are blocking in CI.
