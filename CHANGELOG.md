# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Adoption-audit remediation. The audit's finding was that the funnel, not the product, was the constraint:
the wedge command required the expensive command first, the install path had no
regression test, releases were invisible, and the central efficacy claim was
unfalsifiable.

### Added

- **`/draft:review` runs with zero setup.** A missing `draft/` directory is now
  a supported mode, not an error. The review resolves scope from git, runs
  Stage 1 and Stage 3 against plugin guardrails, renders the report inline
  (writing nothing into your repo), and closes by naming the specific
  structural checks `/draft:init` would have added. Contract:
  `skills/review/references/zero-setup-mode.md`.
- **CI.** `.github/workflows/ci.yml` runs the test suites, lint, an
  integrations-freshness check, and — new — the install path itself.
- **`scripts/tools/check-repo-size.sh`** fails the build when the tree at HEAD
  exceeds a cap (default 10 MB). This is the test that would have caught the
  v2.8.3 install hang.
- **`scripts/tools/install-smoke-test.sh`** reproduces a new user's first
  install on a throwaway shallow clone: manifest discovery, skill frontmatter,
  and a `--dry-run` writer pass per host against an empty HOME.
- **GitHub Releases per tag.** `.github/workflows/release.yml` publishes a
  Release for every `vX.Y.Z` tag, with notes extracted from CHANGELOG.md by
  `scripts/release-notes.sh`.
- **`DRAFT_STRICT_VERIFY=1`** makes an unverifiable graph-engine download fatal
  instead of a warning. `bin/README.md` gains a Trust story section stating what
  is and is not guaranteed (checksum yes, signing and provenance no) and the
  contingency if the upstream engine stalls.
- **Efficacy benchmark harness.** `docs/benchmark/README.md` (protocol)
  plus `scripts/benchmark/` — `bench-checkout.sh` prepares pre-merge worktrees
  and refuses any corpus row whose fix is reachable from the reviewed tree;
  `bench-grade.sh` records grades review-before-fix; `bench-report.sh` computes
  catch rate, precision, and the graph delta. Corpus not yet collected.
- **`docs/COMMANDS.md`** — the full 33-skill reference, moved off the README.
- **Issue and pull-request templates.** `CONTRIBUTING.md` linked to a bug report
  template, a feature request template, and a PR checklist that did not exist;
  all three now do.

### Fixed

- **`/draft:graph` refreshed nothing after the first index.** `graph-snapshot.sh`
  obtained its index solely through `memory_ensure_index`, which calls
  `index_repository` only when the project is *absent* — correct for the
  `graph-*.sh` query wrappers, which must stay cheap, but wrong for the one tool
  whose job is the refresh. Every subsequent run was a no-op that still printed
  `Indexed <project>` and rewrote the gate marker with a fresh `generated_at`, so
  a symbol deleted from the tree stayed resolvable, a newly added one never
  appeared, and nothing surfaced the staleness. This repo's own marker claimed
  currency while sitting on a June index from an older engine build. The refresh
  now issues an explicit re-index; the query wrappers are unchanged.
- **The offline wiki viewer executed content from the repository it documented.**
  `okf-render-views.sh --web` inlines every page into a `<script>` block. Only the
  markdown body was passed through the `</` → `<\/` filter; the page title, type,
  and path were not. JSON escaping does not stop a literal `</script>` from closing
  the script element, so a concept page titled
  `Pwn</script><script>alert(1)</script>` ran that script when the viewer was
  opened. The whole emitted data block is now filtered, so no field can escape.
- **A wiki page that documented `${HOME}` could not be promoted.** The
  unreplaced-template-token scan in `okf-validate.sh` (and the Q-TEMPLATE check in
  `okf-validate-quality.sh`) matched the `{HOME}` inside `${HOME}`, so any page
  quoting a shell or CI variable — in prose or in a fenced code block — failed
  structure validation and blocked the atomic `draft.tmp/ → draft/` promotion.
  Fenced blocks and `${VAR}` expansions are now excluded from the scan; a genuine
  `{SECTION_TITLE}` placeholder in prose still fails.
- **`verify-doc-anchors.sh` reported every anchor to an underscored heading as
  missing.** Its slug builder stripped `_`, while GitHub — and this repo's own
  `_lib.sh:gfm_slug` — keep it. A correct link to `## draft_init modes` failed the
  validator.
- **`okf-fix-links.sh` could be fooled into passing a dangling link.** The checker
  resolved each link against the process CWD in addition to the document's own
  directory, so an unrelated same-named file in the caller's cwd flipped the exit
  code from 1 to 0. CWD is no longer a resolution base.
- **`parse-git-log.sh` reported a failed `git log` as an empty history.** The
  stream ran inside a process substitution, which discards the child's exit status,
  so an unknown `--branch` produced zero records and exit 0. A non-numeric `--limit`
  was worse: `git log -n abc` counts as 0 and exits 0, so it now fails validation up
  front.
- **`verify-doc-anchors.sh` advertised a check it did not run.** Its header
  documented §X.Y numbered-section validation; the implementation was a no-op and
  `md_numbered_headers()` had no call sites. Removed, and the header now states
  what is actually validated.
- **Two engine payloads were still built by string concatenation.**
  `mermaid-from-graph.sh` and `hotspot-rank.sh` interpolated the project name into
  a JSON literal while every other call site of the same tool used `jq -n --arg`.
- **A repo path containing `"` or `\` silently disabled every graph tool.**
  `memory_index_bounded` built the engine payload by string concatenation, so
  such a path produced malformed JSON, the index call failed, and every graph
  tool reported `{"source":"unavailable"}` — indistinguishable from a missing
  engine, and a direct violation of Guardrail 4 (an engine failure must never
  read as absence). Payloads are now built with `jq`, matching the idiom already
  used in `graph-impact.sh`. Same fix applied to the two other hand-built
  payloads in `graph-snapshot.sh` and `graph-arch.sh`.
- **`graph-query.sh` rejected legitimate read-only queries** about symbols named
  `set`, `create`, `delete`, `merge`, `remove`, `drop`, or `detach` — among the
  most common method names in real codebases. The write-verb guard grepped the
  raw query text and could not tell a Cypher clause from a quoted span. Quoted
  spans are now blanked before the scan, for all three forms the engine accepts
  (`'…'`, `"…"`, and backtick identifiers). The guard is unchanged for real
  write verbs, and an unterminated span still fails closed.
- **`cli/src/installer.js` pre-flight rejected `writeFile` actions.** Those
  actions carry no `src`, so `fsx.exists(undefined)` threw and the install
  aborted with `Bundled asset missing: undefined`. Latent — no shipped host plan
  emits one — but `fsAction` supports the kind.
- **`resolve-tools.sh` aborted at step 5 instead of falling through.** `newest()`
  ran `ls -d <glob> | sort -V | tail -1`; on a glob miss `ls` exits non-zero,
  `pipefail` propagated it, and `errexit` killed the resolver mid-chain. Steps
  6-8 were unreachable and the exit code was 2, not the documented 1 — so a
  Cursor-only install (step 7) resolved to nothing and every helper failed to
  load. The fallback chain now runs to completion.
- **Atomic rewrites reset files to 0600.** `mktemp` creates at 0600 and `mv`
  swaps the inode, so every helper using that pattern silently stripped the
  destination's permissions: `fix-whitespace.sh` handed back a 0600 file
  whatever it was given, and each `make build` left the generated integrations
  owner-only. New shared helper `apply_dest_mode` (in `scripts/tools/_lib.sh`,
  re-exported through `scripts/lib.sh`) carries the destination's mode across,
  applied in `build-integrations.sh`, `build-book.sh`, `fix-whitespace.sh`,
  `git-metadata.sh`, `migrate-track-frontmatter.sh`, `okf-fix-links.sh`,
  `okf-render-views.sh`, and `okf-coverage-check.sh`.
- **`okf-fix-links.sh` and `okf-render-views.sh` required `python3` without
  saying so.** Both shell out to it under `set -e`, so on a host without Python
  the OKF path — the default output mode for tier 3-5 projects — died at exit
  127 partway through, after `--fix` had already rewritten files. Both now check
  up front and fail with a clear message, and `python3` is listed in CLAUDE.md's
  prerequisites.
- **`graph-callers.sh --transitive` and `graph-impact.sh` put a qualified name
  in the field documented as `file`.** The `trace_path` expander returns no
  `file_path`, so the qualified name was emitted as if it were a path while the
  single-hop branch of the same tool emitted a real one. `file` is now always a
  path (empty when the engine has none) and `qualified` is its own field.
- **`build-integrations.sh` reported "Agent refs: preserved (not stripped)" for
  both builds.** The Copilot transform rewrites `@architect` and friends to
  `@workspace`, so the status line stated the opposite of what it did for one of
  the two outputs. `verify_output` now takes the description per build.
- **`graph-snapshot.sh` ran `rm -rf "$OUT/okf"` against an unvalidated `--out`.**
  Combined with the `mkdir -p` above it, a typo'd flag created a directory and
  then recursively deleted a subtree inside it. The prune now requires positive
  evidence that Draft owns the directory (default location, an existing
  `schema.yaml`, or a prior fat snapshot).
- **`install-smoke-test.sh --json` emitted invalid JSON** when a captured stderr
  line contained a backslash or control character — it escaped only `"`. It now
  uses `json_escape` from `_lib.sh`.
- `check-repo-size.sh`-class SIGPIPE bug: `sort | head` under `pipefail` failed
  non-deterministically depending on pipe-buffer occupancy. Both new tools
  materialize before slicing.
- `bench-report.sh` computes the graph delta from raw counts; differencing two
  independently-rounded percentages shifted it by up to 0.1pp.

### Security

- **`graph-query.sh --tool query_graph` bypassed the read-only guard entirely.**
  The write-verb scan ran only on `--cypher`; `query_graph` is on the tool
  allowlist and takes raw Cypher in its payload, so
  `--tool query_graph --json '{"query":"MATCH (n) DETACH DELETE n"}'` reached the
  engine unchecked and could wipe the graph index. The scan is now a shared
  `reject_write_verbs` applied to both entry points, and to any tool payload
  carrying a `query` field — not just `query_graph` — so a future query-bearing
  tool is covered by construction.
- **Tool resolution no longer trusts the working directory ahead of the
  installed plugin.** `resolve-tools.sh` returned `$PWD/scripts/tools` as soon as
  it saw a `resolve-tools.sh` there, before the install marker and the plugin
  registry. Since skills execute whatever it prints, and Draft is routinely
  pointed at repositories nobody trusts, any repo shipping that path captured
  execution. The cwd is now the last resort, gated on Draft's own plugin
  manifest; the bare `$PWD/scripts/tools` fallback (which matched any project
  using that very common layout) is gone. Work on Draft itself with
  `DRAFT_PLUGIN_ROOT="$PWD"`, which is step 1 and always wins.
- **Atomic rewrites no longer widen file permissions.** `writeJsonAtomic` in
  `cli/src/lib/cursor-registry.js` wrote a fresh temp file and renamed it over
  `~/.claude/settings.json`, discarding the destination's mode — a deliberately
  0600 settings file holding env secrets came back 0644. It now carries the
  destination's mode across.
- **`.github/workflows/pages.yml` pins `actions/deploy-pages` by SHA**
  (`cd2ce8f`, v5.0.0). It was the one action still on a mutable tag, in a job
  holding `pages: write` and `id-token: write`.
- **`release.yml` no longer interpolates `${{ }}` expressions into `run:`
  blocks.** A `workflow_dispatch` input was expanded textually before bash
  parsed the line, so a crafted tag could execute commands in a job holding
  `contents: write`. Values now pass through `env:` and are referenced as shell
  variables, and a tag containing a newline is rejected before it reaches
  `GITHUB_OUTPUT`. Exploitation required repo write access, so this is
  hardening rather than a remote hole.

### Changed

- **CI installs a pinned, checksum-verified shellcheck** (v0.11.0, static
  binary from the upstream release) instead of `apt-get install shellcheck`. The
  apt step stalled on the runner's package mirror twice in three pushes — once
  for 12 minutes, once until the job was cancelled — and because both lint
  checks are blocking, that took them down as `skipped` rather than failing
  honestly. The repo is clean under v0.11.0.
- **`markdownlint` now runs with `--ignore-path .gitignore`** in CI and in
  `scripts/lint.sh`. Its glob does not consult git, so a local `make lint` was
  linting gitignored artifacts a fresh CI checkout never has — a generated 1 MB
  `AGENTS.md` and everything under `docs/internal/` — and failing on files CI
  cannot see. Local and CI runs now cover exactly the same set.
- **Markdownlint is a blocking CI gate.** It ran `continue-on-error` against a
  backlog too large to enforce against; that backlog is cleared — 1691
  violations to 0 across the tree — so anything it reports now was introduced by
  the change under review, the same standard shellcheck is held to. Most of the
  cleanup was mechanical (`--fix`: blank lines around headings, lists and
  fences; list style; trailing whitespace), plus 232 fenced blocks that gained a
  language tag. Four rules are switched off, each with its reason recorded in
  `.markdownlint.json`, because they misread this corpus rather than finding
  defects in it: MD007 and MD029 (the numbered procedures nest bullets at the
  3-column ordered-list alignment and carry step numbers across interleaved code
  blocks — `--fix` lifts those bullets out of their parent item and restarts the
  numbering), MD025 (a SKILL.md body is a fragment inlined into a larger
  document, not a document), and MD036 (fires on template placeholder
  instructions like `**Describe the class level design**`).
- **`skills/review/SKILL.md` had a malformed `2.5.` list marker.** Markdown has
  no half-steps, so the item and everything indented under it fell out of the
  list. Renumbered; no cross-reference cited those numbers.
- **`install-smoke-test.sh` now asserts the project directory is untouched by a
  dry run,** not just `HOME`. `codex` and `opencode` default to project scope and
  write `AGENTS.md` into the cwd, which is the likelier leak and was unchecked.
- **`scripts/lib.sh` no longer runs `set -euo pipefail` at source time.** Its own
  header promised no side effects while it silently changed the shell options of
  all 16 files that source it. Every one of them sets its own strict mode.
- **Dead code removed from `okf-fix-links.sh`** (326 → 247 lines): `resolve_ok()`
  had no callers, which left `build_slugs()`/`SLUGS` feeding nothing;
  `pick_target()` and its `BASENAME_MAP_MULTI` builder were a bash twin of logic
  the Python pass already does itself; a `while read … done < /dev/null` loop had
  an empty body and could never execute; and `--check` was parsed into a variable
  nothing read. Checking is unconditional and the flag is now documented as such.
- **Graph engine pin bumped to `codebase-memory-mcp` v0.9.0** (from v0.8.1) in
  `scripts/fetch-memory-engine.sh`. Upstream ships ~61% faster indexing with a
  crash supervisor that quarantines a bad file instead of aborting the run,
  memory-safety fixes on large repositories, and CALLS/IMPORTS extraction
  correctness fixes across C/C++, Python, Go, PHP, Kotlin, Java, TS/JS, and
  Rust. Also relevant to Draft's wrappers: label-filtered cypher traversal no
  longer truncates at 10 results, and per-file indexing failures now surface in
  `skipped[]` instead of failing silently. Verified against the published
  checksum with `DRAFT_STRICT_VERIFY=1`.
- **README leads with five commands**, not 33, and orders the funnel
  `review → init → review` so the cheap step comes first.
- **Marketing copy replaced with output.** The "Maturity Level 4/5 / on par with
  Staff Engineer practices at FAANG" claim is gone from getdraft.dev, replaced
  by three real defects `/draft:review` found in Draft's own codebase and the
  graph query that scopes them.
- `core/shared/context-verify.md` lists `/draft:review` as context-optional.
- **Website and book follow the new funnel.** The install panel, primary command
  grid, terminal demo, and FAQ on getdraft.dev lead with `/draft:review`; the
  Getting Started and Review Pipeline chapters document zero-setup mode and what
  it cannot check; `llms.txt` and `llms-full.txt` describe it for agents.
- **The site changelog is current again.** It showed v3.3.0 as the latest release
  while the repo was on v3.6.0; v3.3.1 through v3.6.0 are now published there.
- **`CONTRIBUTING.md` corrected.** Skill registration pointed at case statements
  that had moved to `SKILL_META` in `scripts/lib.sh`; Node and `jq` were missing
  from the prerequisites. Adds what CI runs, how to reproduce the install-path
  jobs locally, and the release procedure.

## [3.6.0] - 2026-07-15

Full-codebase review release: 10-angle review with per-finding adversarial
verification produced 37 confirmed findings — all fixed (see
`docs/WORK_TRACKER.md` for the finding-by-finding record).

### Fixed

- **Validators no longer crash on clean input.** `check-track-hygiene.sh`
  (zero TBD markers) and `verify-doc-anchors.sh` (`(planned)` line with no
  path token) aborted under `set -euo pipefail` with no output; both now pass
  clean tracks.
- **Validators no longer silently pass bad input.** `okf-validate.sh` skipped
  pretty-printed path-index arrays; `verify-citations.sh` truncated
  `file:LO-HI` ranges to `LO`, so drifted range ends were never checked.
- **Graph tooling hardening.** `gq_escape` escapes backslashes (Cypher
  string-literal breakout); `graph-impact.sh` builds payloads with
  `jq -n --arg` and reports engine failures as `source:"unavailable"` instead
  of fabricating empty results; `graph-arch.sh` emits the universal `source`
  field; `graph-preflight.sh` survives non-numeric `auto_index_limit`;
  `hotspot-rank.sh` survives null `qualified_name`; `graph-snapshot.sh`
  escapes YAML scalars; symbol-status probes distinguish engine failure
  (`probe-failed`) from a true no-match.
- **CLI installer.** Upgrades mirror bundled directories instead of
  merge-copying (files deleted upstream no longer persist); the plugin-root
  marker records the actual install root (`CURSOR_HOME`/`--project` aware);
  `spawnSync` resolves npm `.cmd` shims on Windows.
- **Site.** `build-book.sh` derives sitemap blog URLs from `web/blog/*/`
  (three live posts were missing from the hardcoded list); the homepage
  terminal releases its pin on `focusout` for keyboard users.
- **Tool ergonomics.** Dangling flags exit with `--flag requires a value`
  instead of a raw `unbound variable` error (89 sites); `--help` output and
  usage headers corrected; `emit-skill-metrics.sh` can no longer corrupt the
  metrics NDJSON on payloads with trailing whitespace;
  `migrate-track-frontmatter.sh` preserves the EOF newline.

### Changed

- **DRAFT_TOOLS canonical preamble** now honors the `DRAFT_PLUGIN_ROOT`
  override first (matching `resolve-tools.sh` precedence); all 24 files
  carrying the inline resolver migrated, and `core/shared/graph-query.md`
  examples invoke tools via `"$DRAFT_TOOLS/..."`. Enforced by
  `tests/test-skill-script-invocation.sh` in `make test`.
- `check-track-hygiene.sh` honors `metadata.json:hygiene_budget`
  (`draft_tbd_cap`, `ready_for_review_tbd_cap`) instead of hardcoded caps.
- Skill display headers and Copilot triggers live in one `SKILL_META` table
  in `scripts/lib.sh`; the graph wrappers share one `graph_bootstrap()`
  helper instead of 15 copies of the engine-bootstrap sequence.

### Removed

- Retired `core/templates/track-architecture.md` (replaced by
  `hld.md`/`lld.md`; the decompose skill had already declared it retired).

### Added

- Six previously-missing test suites wired into `make test` (72 total):
  cross-references, HLD/LLD contract, skill-script invocation discipline, and
  tool suites for `check-graph-usage-report`, `check-template-noop`,
  `emit-skill-metrics` — plus regression cases for every fixed defect.
- `CHANGELOG.md` entries backfilled for 3.5.0–3.5.3.

## [3.5.3] - 2026-06-25

### Fixed

- **OKF bundle now conforms to the OKF v0.1 spec.** The emitted `draft/wiki/`
  bundle carries the spec-required index frontmatter and generates
  `coverage.md`, so downstream OKF consumers can validate the bundle shape.

## [3.5.2] - 2026-06-24

### Fixed

- **Wiki completeness is enforced.** `/draft:init` (okf mode) now requires a
  concept page for every module, rejects empty/shallow pages, and fails on
  broken index links (PR #47).

### Changed

- User-facing prose says "wiki" instead of "OKF" throughout the docs.

## [3.5.1] - 2026-06-22

### Fixed

- **`/draft:init` engine indexing is memory-bounded.** The
  `codebase-memory-mcp` index run is wrapped in a cgroup scope capped at 25%
  of system RAM, so indexing a large repo can no longer exhaust the machine.

## [3.5.0] - 2026-06-20

### Added

- **Deterministic wiki completeness gates.** New `okf-plan-concepts.sh` plan
  and `okf-coverage-check.sh` coverage gates enforce that the okf-mode wiki
  covers the full module surface before an init/refresh is accepted.

## [3.4.0] - 2026-06-20

### Added

- **Tree-search retrieval over the OKF bundle (PageIndex-style).** New
  `core/shared/okf-retrieval.md` adds a vectorless, reasoning-based retrieval
  loop for projects emitted in `okf` mode (`draft/wiki/` present). Agents now
  locate context by navigating the Concept Map tree — reading each node's
  `description` routing key and descending only matching subtrees to concept
  leaves — instead of loading sections by a static heuristic. No embeddings, no
  chunking: relevance is decided by reasoning over the tree (budget ≤5 pages,
  ~2 hops; broad tasks terminate at the Synopsis). `draft-context-loading.md`
  routes okf-mode to tree-search while monolith keeps static section-scoring,
  and the module is registered in `CORE_FILES` (`scripts/lib.sh`). Regenerated
  Copilot and Agents integrations.

### Changed

- Website, book, and blog refresh: new "Drafting Table" hero identity, refreshed
  social/meta copy and social-preview card, professionalized footer, and two new
  blog posts on relevance-based / reasoning-based vectorless retrieval.

## [3.3.1] - 2026-06-19

### Fixed

- **`/draft:init refresh` never regenerated the OKF `wiki/` bundle.** The init
  skill's Refresh Mode described only the `monolith` path (refresh
  `architecture.md` → regenerate `.ai-context.md`/`.ai-profile.md`), with no
  branch for `okf` mode — so an agent running `refresh` on an OKF-initialized
  repo would treat the *generated* `architecture.md` as the source of truth and
  never re-narrate the `draft/wiki/` concept taxonomy. `skills/init/SKILL.md`
  now detects `okf` mode (presence of `draft/wiki/`) and dispatches to
  `references/okf-emitter.md` §"Incremental refresh at concept granularity (M5)":
  regenerate only the concepts grounded in changed files, carry the rest forward
  from cache, always re-render `architecture.md`/`.ai-context.md` via
  `okf-render-views.sh`, and re-run `okf-validate.sh`. Mirrors the
  initial-generation branch. Cross-host integrations regenerated.

### Changed

- **Documentation, website, and book synced to v3.3.0.** OKF taxonomy mode is
  now documented across README, `web/index.html`, `web/what-is-draft`,
  `llms.txt`/`llms-full.txt`, and the book (getting-started, context-tiering);
  the website changelog gains its v3.3.0 entry; Cursor's registration +
  `--force` upgrade path is documented. Stale counts corrected
  (`templates 30→29`, `helpers 32→45`, `All Commands 34→33`, added the missing
  `/draft:upload`). No runtime behavior change in this item.

## [3.3.0] - 2026-06-19

### Added

- **`/draft:init` OKF taxonomy emitter (tier-gated default).**
  An init output mode that replaces the monolithic `architecture.md`
  with an OKF v0.1 concept bundle under `draft/wiki/` (one concept per file,
  cross-links form the graph), repurposes `.ai-context.md` as the index root
  (Synopsis + Concept Map), and demotes `architecture.md` to a generated rendered
  view. `DRAFT_INIT_MODE` defaults to tier-gated `auto` (tier 1–2 → `monolith`,
  tier 3–5 → `okf`); an explicit `monolith`/`okf` overrides. `monolith` is
  retained as the small-repo default, the A/B baseline, and the over-fetch
  fallback (`docs/audit/okf-benchmark.md`). Implements HLD
  `hld-draft-init-okf-taxonomy.md` milestones M1–M6 plus the tier-gated default
  and the render-views/offline-viewer layer.
  - `scripts/tools/okf-validate.sh` — the one new deterministic helper: fails the
    build on dangling cross-links, missing/invalid frontmatter, out-of-vocab
    concept `type`, or an incomplete `path-to-concept.json` index. Verified
    against the call graph (ground truth), not heuristics.
  - `core/templates/okf/{index,concept,section-index,ai-context-index}.md` —
    frozen `type` vocabulary, frontmatter contract, and bundle layout.
  - `skills/init/references/okf-emitter.md` — generation pipeline, render views,
    concept-granularity rules, and incremental refresh at concept granularity.
  - `scripts/tools/okf-render-views.sh` — deterministic renderer for the demoted
    views: `architecture.md` becomes a generated linear concat of the bundle
    (frontmatter stripped, canonical section order, banner + TOC), and the
    Concept Map routing table is injected between markers in index roots. Keeps
    the human "read one doc" onboarding view at zero extra maintenance —
    architecture.md is **demoted, not deleted**. `--web` additionally emits a
    self-contained offline HTML viewer (single file, all pages inlined, built-in
    markdown renderer, sidebar + search; double-click to open, no server/CDN).
    All views write into `draft/` — the OKF emitter never creates a separate dir.
- **`.cursor-plugin/plugin.json`** — Cursor-native plugin manifest (source of
  truth for Cursor discovery), version-synced alongside the Claude manifests.
- **`cli/src/lib/cursor-registry.js`** — non-destructive merge/write helper for
  Cursor's plugin registry, with a pure `registerCursorPlugin` and a
  disk-writing `applyCursorRegistration`.
- **`cli/src/lib/plugin-manifest.js`** — reads name/version from a plugin
  manifest, failing loud on a missing required field.

### Fixed

- **Cursor install never surfaced `/draft:*` commands.** `draft install cursor`
  copied the plugin tree to `~/.cursor/plugins/local/draft/` but never registered
  or enabled it, so skills and slash commands never appeared in Cursor chat. The
  installer now ships a Cursor-native `.cursor-plugin/plugin.json` manifest and
  registers + enables `draft@draft-plugins` in the shared Claude plugin registry
  (`known_marketplaces.json`, `installed_plugins.json`, and `settings.json`) that
  current Cursor builds read. Registry writes are atomic and non-destructive —
  other plugins, hooks, and unknown keys are preserved. Existing installs can
  upgrade with `draft install cursor --force`.

## [3.2.1] - 2026-06-15

### Fixed

- **Graph tooling unreachable on Claude Code marketplace/npm installs.** Skills
  invoked the bundled `scripts/tools/*.sh` helpers by bare, cwd-relative paths
  (e.g. `scripts/tools/graph-arch.sh`). Because a skill's shell runs with the
  cwd set to the *user's project* — not the plugin — and `${CLAUDE_PLUGIN_ROOT}`
  is not exported into skill-driven Bash, every graph wrapper silently failed and
  the knowledge-graph engine appeared unavailable. The pre-existing inline resolver
  also pointed at a nonexistent path (`$HOME/.claude/plugins/draft`). Skills now
  resolve a `DRAFT_TOOLS` directory (install marker → plugin cache glob →
  marketplace clone → cwd) and invoke helpers as `"$DRAFT_TOOLS/<tool>.sh"`.

### Added

- **`scripts/tools/resolve-tools.sh`** — canonical resolver that locates the
  bundled `scripts/tools/` dir regardless of install layout (Claude Code cache,
  marketplace clone, Cursor, or in-repo dev). Documented in
  `core/shared/tool-resolver.md`.
- **`draft install` writes `~/.cache/draft/plugin-root`** — an authoritative
  install-path marker so skills resolve the helper directory on the fast path
  (best-effort; resolution falls back to globbing the plugin cache if absent).

## [3.2.0] - 2026-06-14

### Added

- **Full codebase-memory-mcp capability adoption (graph tooling v2).** Draft now
  uses the whole graph engine instead of a thin ~3-edge slice. All Cypher is
  centralized in a new sourced module `scripts/tools/_graph_queries.sh` (single
  source of query truth, with verified dialect-safe builders), so a label/dialect
  fix is a one-line edit. New wrappers: `graph-query.sh` (generic read-only
  passthrough — Cypher or any read-only tool, write verbs rejected), `graph-snippet.sh`
  (verified source + caller/callee counts), `graph-search.sh` (semantic/ranked
  search), `graph-tests.sh` (TESTS coverage / `--untested`), `graph-deps.sh` (real
  `IMPORTS` graph), `graph-hierarchy.sh` (`INHERITS`), `graph-errors.sh`
  (`RAISES`/`THROWS`), `graph-risk.sh` (engine-precomputed risk flags), and
  `graph-traces.sh` (experimental `ingest_traces`). `graph-callers.sh` gains
  `--transitive[=N]`, `--prod-only`, and `--qualified`. Symbol-scoped wrappers emit
  a fail-loud `status` (`ok`/`no-edges`/`no-match`/`unavailable`) so an empty result
  is never mistaken for a confirmed true negative. Every wrapper degrades to
  `source:"unavailable"` (exit 2) without the engine and ships a `tests/test-tools-*.sh`.
- **Richer architecture/refresh data.** `hotspot-rank.sh` now ranks by
  `fanIn + complexity + cognitive` (de-skewing name-collision generics) and
  annotates entry points; `mermaid-from-graph.sh --diagram module-deps` derives the
  dependency diagram from real `IMPORTS` edges (closing the `architecture.md §9`
  synthesized-edges gap), with the prior co-change proxy preserved as
  `--diagram co-change`; `graph-snapshot.sh` records the `detect_changes` delta
  (`changed_files`/`impacted_symbols`) in the gate marker. The graph-query contract
  (`core/shared/graph-query.md`) documents every new wrapper, verified engine param
  shapes, the Cypher dialect limits, and the `--prod-only`/`--transitive` caveats.
  A regression test locks the Phase 0 `:Function`→label-agnostic fix and enforces
  that no Cypher literal lives outside `_graph_queries.sh`.
- **Single-source-of-truth version sync.** `package.json` is now the canonical
  version; `scripts/sync-version.sh` propagates it into `.claude-plugin/plugin.json`,
  `.claude-plugin/marketplace.json`, and the `web/index.html` release labels. It
  runs automatically via the npm `version` lifecycle hook (so `npm version <x>`
  updates everything in one commit), and `tests/test-version-sync.sh` fails CI if
  any file drifts from `package.json`.

## [3.1.5] - 2026-06-14

### Changed

- **The knowledge graph is now engine-only.** Draft no longer commits a
  machine-readable mirror of the graph. `scripts/tools/graph-snapshot.sh` indexes
  the repo into the local `codebase-memory-mcp` engine and writes a single committed
  file — `draft/graph/schema.yaml`, a gate marker carrying no graph data
  (`access: engine-live`). All structural data is queried live via the
  `scripts/tools/graph-*.sh` wrappers or `codebase-memory-mcp cli <tool>`. A
  re-index prunes any stale fat-snapshot artifacts left by 3.0.0. The graph-query
  contract (`core/shared/graph-query.md`) and every consuming skill now query the
  engine live instead of reading committed files.
- **`draft/index.md` is a plain docs index.** It lists the prose context files and
  tracks with one-line descriptions — no OKF framing or `okf_version` frontmatter.

### Removed

- **Open Knowledge Format (OKF) emission** added in 3.0.0. Deleted
  `scripts/tools/okf-emit.sh`, `okf-bundle.sh`, `okf-check.sh` (and their tests).
  No more `draft/graph/okf/` bundle.
- **Committed graph snapshot files**: `architecture.json`, `hotspots.jsonl`,
  `module-deps.mermaid`, `proto-map.mermaid` are no longer generated. They were
  lossy, went stale on the next commit, and duplicated what the engine serves live.

## [3.0.0] - 2026-06-14

### Added

- **Open Knowledge Format (OKF) emission by default.** The knowledge-graph
  snapshot now also writes an [OKF v0.1](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)
  bundle to `draft/graph/okf/` (`index.md` + cross-linked `modules/<name>.md`
  concept pages) via the new `scripts/tools/okf-emit.sh`, on every `/draft:graph`
  and `/draft:init` run. A portable, vendor-neutral markdown
  mirror of the graph.
- **The whole `draft/` directory is an OKF bundle.** `scripts/tools/okf-bundle.sh`
  writes `draft/index.md` (the bundle-root index) cross-linking every concept —
  context docs, tracks, and the graph sub-bundle. Project-doc templates
  (`architecture.md`, `.ai-context.md`, `.ai-profile.md`, `product.md`,
  `tech-stack.md`, `workflow.md`, `guardrails.md`) and track templates
  (`spec/plan/hld/lld/discovery/rca`, `tracks.md`) now carry an OKF `type:`
  frontmatter field.
- **OKF v0.1 conformance checker.** `scripts/tools/okf-check.sh` validates §9 of
  the spec — parseable frontmatter with a non-empty `type` on every concept, and
  the reserved-file rules for `index.md`/`log.md`. Wired (advisory) into
  `/draft:init`.
- **Scope-aware, root-first code-graph memory.** `/draft:init` is now the single,
  scope-aware entry point and builds the whole-repo "code-graph knowledge memory"
  first, wherever it is run. New `scripts/tools/graph-init.sh` resolves the repo
  ROOT (nearest ancestor with `draft/` → git toplevel → cwd), ensures the
  knowledge-graph engine is present (fetching it as a fallback), builds the
  committed root snapshot (`draft/graph/`), and — when run inside a sub-module —
  builds the module snapshot and writes `draft/graph/root-link.json` pointing up
  to the root graph, so any module has full cross-module understanding.
- **`/draft:init --graph-only` and `--module-only` flags.** `--graph-only`
  (re)builds just the code-graph memory with no markdown; `--module-only` skips
  touching the root (the module→root link is marked `pending`).

### Changed

- **`/draft:init` markdown is scope-asymmetric.** A root init now generates a
  sparse, high-level system map that links down to each module's context (no deep
  per-module prose); a module init generates the full detailed reference. The
  graph layer stays symmetric (root spine + per-module snapshots, linked).

### Removed

- **`/draft:index` is removed — folded into the scope-aware `/draft:init`.**
  Monorepo context now comes from running `/draft:init` at the repo root (sparse
  root map + whole-repo graph spine) and in each sub-module (detailed context +
  `root-link.json`). The multi-directory bug-hunt sweep moved to
  `/draft:bughunt` (explicit dir list or auto-discovery). Total surface: 33 skills.
  (Web/book references to `/draft:index` will be updated in a follow-up docs pass.)

## [2.8.3] - 2026-06-14

### Fixed

- **`draft install claude-code` no longer hangs.** `claude plugin marketplace
  add drafthq/draft` does a `git clone` of the repo, and the repo carried ~670 MB
  of audiobook `.m4a` files in HEAD (`web/book/audio/audio-files/`). Even claude's
  shallow clone downloaded all of it, so the install stalled on the very first
  step. The audio is now hosted as the `book-audio` GitHub Release and removed
  from the repo, shrinking the marketplace clone to a few MB. The book audio
  player and `podcast.xml` enclosures now point at the release assets.
- **Installer fails loudly instead of hanging forever.** Each `claude plugin`
  step now runs under a timeout (default 300s, override with
  `DRAFT_INSTALL_TIMEOUT_MS`); on timeout the installer prints the manual
  slash-command fallback rather than blocking indefinitely.
- **Marketplace manifest version synced.** `.claude-plugin/marketplace.json`
  advertised `2.8.0` while the plugin was newer, so `claude plugin update` saw a
  stale version; it now tracks the plugin version.

## [2.8.2] - 2026-06-14

### Documentation

- **README now documents the full router surface.** The command reference
  previously listed only the specialist leaf commands; it now also documents the
  4 top-tier routers (`/draft:plan`, `/draft:ops`, `/draft:docs`,
  `/draft:discover`), the `/draft:upload` handoff gate, and the
  `/draft:integrations` parent command — the recommended public entry points.
- **Corrected stale skill/command counts site-wide.** The total surface is
  **34 skills** (4 primary + 5 routers + 25 specialists). CLAUDE.md said
  "31 skills / 22 specialists" and the website said "33 commands / 22
  specialists"; both are now aligned to the actual count.

## [2.8.1] - 2026-06-14

### Fixed

- **Knowledge-graph engine fetch no longer 404s.** `scripts/fetch-memory-engine.sh`
  pinned `DEFAULT_VERSION="v0.7.0"`, but the upstream `codebase-memory-mcp` `0.7.0`
  release publishes no binary assets, so every fetch failed with a 404 and graph
  features stayed unavailable ("graph engine unavailable — no snapshot written").
  Bumped the pin to `v0.8.1` (the current release with published darwin/linux
  assets and a verified `checksums.txt`). Fixes both the manual fetch and the
  `draft install` graph download, which delegate to the same script.

## [2.8.0] - 2026-06-13

### Changed

- **`draft install claude-code` now upgrades an existing install** instead of
  no-op'ing on "already installed". The plan runs four idempotent `claude plugin`
  steps — `marketplace add`, `marketplace update`, `install`, `update` — so a
  re-run re-fetches the marketplace manifest from GitHub and bumps the plugin to
  the latest version. Previously `add`/`install` short-circuited when present, so
  existing users stayed pinned to their old version until they manually ran
  `marketplace update` + `plugin update`. The extra steps exit 0 when there's
  nothing to do, so fresh installs are unaffected.
- **`draft install` now fetches the knowledge-graph engine for every host**, not
  just cursor. Previously `claude-code`, `codex`, and `opencode` deferred the
  `codebase-memory-mcp` download to first use of `/draft:init`, so a fresh
  install left graph-backed steps stubbed until something happened to trigger the
  fetch. All host plans now set `graph: true`; the download remains best-effort
  and network-gated (skipped cleanly when offline) and is still opt-out via
  `--no-graph`.

## [2.7.1] - 2026-06-13

### Fixed

- **`draft install claude-code` now actually registers the plugin.** The 2.7.0
  installer copied the plugin into the project folder, but Claude Code only
  loads plugins from its own registry — so `/draft:*` commands never appeared
  ("Unknown command: /draft:init"). The installer now runs `claude plugin
  marketplace add drafthq/draft` + `claude plugin install draft@draft-plugins`
  (user scope by default; `--project` for project scope). If the Claude Code
  CLI isn't on PATH, it prints the two `/plugin` commands to run instead.
  The other hosts (cursor, codex, opencode) already installed to their
  auto-loaded locations and are unchanged.

## [2.7.0] - 2026-06-13

### Changed

- **Installation rewritten as an npm CLI (`@drafthq/draft`)** — `draft install <host>` replaces the previous `curl | bash scripts/install.sh` flow. Run `npx @drafthq/draft install <host>` (or install globally with `npm install -g @drafthq/draft`), where `<host>` is `claude-code`, `cursor`, `codex`, or `opencode`. `draft list` shows every host and its target; flags: `--global`/`--project`, `--dry-run`, `--force`, `--no-graph`. The CLI bundles all assets, so installs are self-contained (no runtime `git clone`).

### Added

- **Cross-host `AGENTS.md` integration** — `scripts/build-integrations.sh` now also generates `integrations/agents/AGENTS.md` (the full inlined methodology with native agent names preserved), consumed by the `codex` and `opencode` installers.

### Removed

- **`scripts/install.sh`** — the `curl | bash` universal installer is removed in favor of the npm CLI. GitHub Copilot and Gemini are no longer installable "hosts"; copy their committed instructions file directly (see README).

## [2.6.0] - 2026-06-11

### Changed

- **Graph engine replaced with [codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp)** — Draft's knowledge graph is now powered by codebase-memory-mcp (tree-sitter + LSP across 159 languages, 100% local, no API key). The previous in-house Node.js + tree-sitter-WASM engine is retired. The engine is fetched on install (`scripts/fetch-memory-engine.sh`, checksum-verified) into `~/.cache/draft/bin` rather than vendored, and resolved via `scripts/tools/_lib.sh:find_memory_bin` (`DRAFT_MEMORY_BIN` > PATH > managed > vendored). Set `DRAFT_MEMORY_DISABLE=1` to opt out.
- **Graph artifacts** — `draft/graph/` now holds a lightweight committed snapshot (`schema.yaml`, `architecture.json`, `hotspots.jsonl`, `*.mermaid`) instead of the per-language JSONL indexes. Live structural queries run on demand against the engine.
- **Public website & book completely synchronized** — Exhaustive pass across `web/index.html`, `web/llms-full.txt`, `web/llms.txt`, all notebook sources, and rendered `web/book/chapters/*.html`. Removed every stale reference to removed flat Jira commands and outdated "28 commands" language. The live site now accurately presents the 5-router architecture.
- **Build & registration** — `SKILL_ORDER`, `CORE_FILES`, and `TOOLS` updated in `scripts/lib.sh`. Static "Available Commands" and "Intent Mapping" tables in `build-integrations.sh` now lead with the 5 routers.
- **`skills/GRAPH.md`** — Full rewrite of topology description, Mermaid diagrams, execution chains, and dependency matrix to reflect the routed two-tier model.
- All cross-references, skill bodies, core docs, and high-level documentation updated for the new surface.

### Added

- **`/draft:graph` command** — Initialize or refresh the `draft/graph/` snapshot for a repo (optional `<path>` argument). Ensures the engine is present (fetching if needed), then builds and reports counts/hotspots/cycles.
- **New graph tools** — `graph-snapshot.sh` (committed snapshot), `graph-impact.sh` (file/symbol blast radius), `graph-callers.sh` (caller enumeration), plus `fetch-memory-engine.sh` (pinned, checksum-verified engine install).
- **Two-tier command architecture** — 4 primary workflow commands (`init`, `new-track`, `implement`, `review`) + 5 routers (`plan`, `ops`, `docs`, `discover`, `jira`) as the recommended public interface. 22 specialist commands are dispatched underneath the routers.
- **Unified `/draft:jira` router** — Single entry point replacing the previous flat `/draft:jira-preview` and `/draft:jira-create`. Supports `preview [track]`, `create [track] [--epic]`, and the advanced `review <JIRA-ID>` qualification subcommand.
- **Full Jira qualification pipeline** — 7-phase deep engine (context loading → collection → synthesis → code changes → deep-review + bughunt + coverage + test-gap analysis) now public. Produces `qualification-report.md` + `remediation-plan.md` with QUALIFIED / PARTIALLY QUALIFIED / NOT QUALIFIED verdict. Pipeline lives in `skills/jira/references/review.md` for correct inlining into integrations.
- **Guardrails subsystem** — New `core/guardrails/` (baseline + language standards) plus 9 shared quality modules (`red-flags.md`, `verification-gates.md`, `template-hygiene.md`, `context-verify.md`, `template-contract.md`, etc.).
- **13 new deterministic hygiene/verification tools** (`check-track-hygiene.sh`, `check-scope-conflicts.sh`, `check-template-noop.sh`, `verify-citations.sh`, `render-track.sh`, etc.).
- **New router skills** — `skills/plan/`, `skills/ops/`, `skills/docs/`, `skills/discover/`, `skills/jira/`.
- **`docs/MIGRATION.md`** — Actionable guidance for transitioning from the old flat command surface to the router model.

### Removed

- `skills/jira-preview/` and `skills/jira-create/` directories and all associated flat command references.

### Fixed

- Critical packaging defect: advanced review pipeline was invisible to Copilot/Gemini users because `review.md` lived outside `references/`.
- Numerous stale command strings, count mismatches ("28 commands"), and public documentation drift across the book and website.

All 25+ test suites pass, `make build` + `make lint` clean, zero branding leaks or internal references in public tree. Public surfaces at <https://getdraft.dev> are now authoritative.

## [2.4.0] - 2026-04-26

### Added

- **Knowledge graph engine** (`graph/`) — Pure Node.js + tree-sitter WASM. Indexes Go, Python, TypeScript/JS, C/C++, proto. ctags fallback for Java/Rust/Ruby/Swift/Kotlin/PHP/etc. CLI exposes 6 query modes:
  - `--mode callers` — file-level (include graph) and function-level (call index) callers.
  - `--mode impact` — transitive blast radius with depth grouping and **file-class dimension** (code/test/doc/config).
  - `--mode hotspots` — complexity × fan-in ranking.
  - `--mode modules` — inter-module dependency graph with hub detection.
  - `--mode cycles` — circular dependency detection (iterative DFS, cycle-stable).
  - `--mode mermaid` — module-deps and proto-map diagrams as fenced code blocks ready for embedding.
- **Confidence markers on call edges** — every `*-call` JSONL record carries `confidence: direct | inferred`. Direct = bare-identifier callee (`foo()`, `Foo::bar()`); inferred = member/attribute/field call where the receiver collapses (`obj.foo()`). Skills weight findings accordingly.
- **Atomic incremental graph builds** — per-module SHA-256 hashing in `hashes.json`. Output writes to a temp directory then renames into place; readers never see partial state.
- **14 deterministic shell helpers** under `scripts/tools/`:
  - `git-metadata.sh`, `parse-git-log.sh` — git introspection emitting JSON.
  - `classify-files.sh` — language + category classification with broad ignore set (`.terraform`, `_build`, `.svelte-kit`, `.dart_tool`, `Pods`, `cdk.out`, `.turbo`, `.parcel-cache`, `.nuxt`, `.vercel`, `.pnpm-store`, plus the standard set).
  - `hotspot-rank.sh`, `cycle-detect.sh`, `mermaid-from-graph.sh` — graph wrappers with graceful degradation.
  - `freshness-check.sh`, `manage-symlinks.sh`, `parse-reports.sh`, `adr-index.sh`, `validate-frontmatter.sh`, `scan-markers.sh`, `detect-test-framework.sh`, `run-coverage.sh`.
  - All emit JSON, follow uniform exit-code contract (0 = success, 1 = invocation error, 2 = upstream-data missing), degrade gracefully.
- **Track-level impact memory** — `metadata.json` schema gains an `impact` block (`files_touched`, `modules_touched`, `downstream_files`, `downstream_modules`, `max_depth`, `by_category`, `computed_at`). Written by `/draft:implement` on phase complete; read by `/draft:new-track` to surface overlap warnings when a new track touches modules recently changed by a completed track.
- **Shared procedures** — `core/shared/graph-query.md` (canonical graph CLI reference), `core/shared/parallel-analysis.md` (Map/Reduce IR-based parallel codebase analysis for large repos — ~60% wall-clock cut at XL tier).
- **16 new tool tests** under `tests/test-tools-*.sh` plus a registry test (`tests/test-tools-registered.sh`) and a conventions test (`tests/test-tools-conventions.sh`).
- **`make build` and `make lint` Makefile targets** — `make build` is an explicit alias for `make build-integrations`; `make lint` runs `scripts/lint.sh`.

### Changed

- **Methodology and skills refreshed** with deeper guidance and "Red Flags — STOP if you're..." preambles; `architecture.md` template expanded from 25 sections to 28 sections + 5 appendices.
- **Build script** (`scripts/build-integrations.sh`) refactored to source shared definitions from `scripts/lib.sh` (`SKILL_ORDER`, `CORE_FILES`, `TOOLS`).
- **Copilot syntax transform** hardened — kebab-case skill names only (no over-match for `<>`), email-shaped tokens (`foo@draft.com`) preserved, alternation delimiters fixed.
- **TS module-edge resolution** in graph writer now resolves multi-segment relative imports (`../../shared/foo`) against the source file's directory rather than stripping a single `../`.
- **JSON escape helper** in `scripts/tools/_lib.sh` now strips ASCII control characters so adversarial filenames can't produce invalid JSON.
- **Glob exclude patterns** in graph engine now anchor to full-string match (`*.pem` no longer matches `foo.pem.txt`).
- **`#draftXXX` TOC anchors** in `core/methodology.md` corrected (16 entries) to match actual `### /draft:X` heading slugs.

### Fixed

- **CI's `make build` invocation** — added the missing target so re-enabling auto-triggers won't fail with "No rule to make target 'build'".
- **Duplicate `workflow_dispatch:` keys** in `.github/workflows/pages.yml` — would have failed `check-yaml`.
- **`.h` C++ detection by substring** in graph engine — was triggering on any header containing `class` followed by a space (comments, identifiers, strings); now requires a real `class Name {`/`class Name :` pattern.
- **Mermaid loader CRLF handling** — graph mermaid generator now tolerates Windows-edited JSONL.
