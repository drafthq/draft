# xreview — whole-codebase audit

**Date:** 2026-08-18 · **Mode:** audit (no diff) · **Scope:** repo root · **Base:** `cc8fadf`

Draft is a Claude Code plugin: 33 markdown skills are the source of truth, a bash build
script inlines them into host integration files, 53 deterministic shell helpers do the
mechanical work, and a Node CLI installs the whole thing into a user's agent host. Trust
boundaries are (a) the shell tools, which an agent invokes with arguments derived from
repo content, (b) the installer, which writes into `~/.claude`, `~/.cursor`, and `~/.cache`,
and (c) `fetch-memory-engine.sh`, which downloads and executes a binary.

`make test` — **80/80 suites pass, exit 0** (run during this audit).

Findings below survived independent re-validation against the code; the five marked
**demonstrated** were reproduced by running the code.

---

## Critical (1)

### 1. `[security]` `scripts/tools/graph-query.sh:82` — read-only guard is fully bypassable

`--cypher` rejects write verbs via `strip_quoted_spans` + a `CREATE|MERGE|DELETE|SET|…`
scan. The `--tool` path applies **no such scan**, and `query_graph` — the tool that takes
raw Cypher — is in `TOOL_ALLOW`. Every "read-only passthrough" claim in the header, the
usage text, and `core/shared/graph-query.md:117` is therefore false on one of the two paths.

**Failure (demonstrated):**

```
$ graph-query.sh --repo R --cypher 'MATCH (n) DETACH DELETE n'
ERROR: write verbs are not allowed (read-only passthrough)   # exit 1

$ graph-query.sh --repo R --tool query_graph --json '{"query":"MATCH (n) DETACH DELETE n"}'
{"rows":[]}                                                  # exit 0

# what the engine received:
ENGINE-RECEIVED: tool=query_graph payload={"query":"MATCH (n) DETACH DELETE n","project":"p"}
```

The graph index is destroyed. `tests/test-tools-graph-query.sh` covers `--cypher CREATE`,
`--cypher DETACH DELETE`, and `--tool delete_project`, but never `--tool query_graph` with
a write verb — which is why this survived.

**Smallest fix:** run the existing `strip_quoted_spans` + verb scan over
`$(jq -r '.query // empty' <<< "$TOOL_JSON")` when `TOOL == query_graph`, before line 157.

---

## Important (4)

### 2. `[security]` `scripts/tools/resolve-tools.sh:37` — any repo can hijack tool resolution

Step 1b returns `$PWD/scripts/tools` whenever `$PWD/scripts/tools/resolve-tools.sh` exists,
**before** the authoritative install marker (step 2), `CLAUDE_PLUGIN_ROOT` (step 3), and the
Claude Code registry (step 4). The comment claims the file-presence check "can never misfire
in a user project" — that check is the whole guard, and it is trivially satisfiable by the
project being reviewed.

**Failure (demonstrated):** a directory containing a copied `scripts/tools/resolve-tools.sh`
resolves to itself even with a valid install elsewhere:

```
$ cd /tmp/victim && resolve-tools.sh
/tmp/victim/scripts/tools
```

Skills then execute `$DRAFT_TOOLS/git-metadata.sh`, `$DRAFT_TOOLS/classify-files.sh`, etc.
from the audited repo. Reviewing an unfamiliar repository is a primary Draft use case, so
"run Draft on a repo you don't control" is the normal path, not an exotic one. Step 8
(line 72) is the same trust-cwd issue without even the filename check.

**Smallest fix:** move step 1b below the marker/registry steps, or gate it on a
draft-repo-identity check (e.g. `.claude-plugin/marketplace.json` naming `draft-plugins`)
rather than the presence of a same-named file.

### 3. `[bug]` `scripts/tools/resolve-tools.sh:25,60` — the fallback chain aborts at step 5

`newest()` is `ls -d $1 2>/dev/null | sort -V | tail -1`. Under the file's own
`set -euo pipefail`, a glob miss makes `ls` exit non-zero, `pipefail` propagates it,
and the `d="$(newest …)"` assignment trips `errexit`.

**Failure (demonstrated):** with no `~/.claude/plugins/cache/*/draft/*`, execution stops
immediately after line 60 — steps 6 (marketplace clone), 7 (**Cursor local install**) and 8
are never reached, and the script exits **2**, not the documented 1:

```
++ ls -d '…/.claude/plugins/cache/*/draft/*/scripts/tools'
+ d=
$ echo $?   →  2      # steps 6-8 never ran
```

A user installed via `draft install cursor` (files land in `~/.cursor/plugins/local/draft`,
step 7) gets an empty `DRAFT_TOOLS` and every one of the 53 helpers fails to resolve.

**Smallest fix:** `ls -d $1 2>/dev/null | sort -V | tail -1 || true` — or drop `ls` for a
glob-array test.

### 4. `[bug]` Atomic-rewrite helpers reset the target file to mode 0600

`mktemp` creates at 0600; `mv` onto the destination replaces the inode, so the original
permissions are silently discarded. Sites: `build-integrations.sh:539,556`,
`fix-whitespace.sh:78`, `git-metadata.sh:129`, `migrate-track-frontmatter.sh:228`,
`okf-fix-links.sh:243`, and the JS equivalent `cli/src/lib/cursor-registry.js:27`
(`writeJsonAtomic` → new file + `renameSync`).

**Failure (demonstrated):**

```
$ ls -l a.md      →  -rw-r--r--
$ fix-whitespace.sh a.md
$ ls -l a.md      →  -rw-------
```

**Live evidence in this tree right now** — every `make build` does the same to its own output:

```
-rw------- integrations/copilot/.github/copilot-instructions.md
-rw------- integrations/agents/AGENTS.md
```

The JS case is the sharper one: `writeJsonAtomic` rewrites `~/.claude/settings.json`, which
can hold `env` secrets. A user who deliberately set it to 0600 gets it widened to 0644 by
`draft install cursor` (reproduced: 0600 → 0664 under umask 002).

**Smallest fix:** in the shell helpers, `chmod --reference="$file" "$_tmp"` (or `cp -p`)
before the `mv`; in `writeJsonAtomic`, `fs.writeFileSync(tmp, …, { mode: <stat of filePath> })`
when the destination already exists.

### 5. `[bug]` Undeclared, unguarded `python3` dependency breaks the OKF path

`okf-fix-links.sh:149,267` and `okf-render-views.sh:110` shell out to `python3` with no
`command -v` guard, under `set -euo pipefail`. `migrate-track-frontmatter.sh:126` guards it;
these three do not. CLAUDE.md lists the prerequisites as "Bash 4.0+, jq (graph tools),
Node 18+ (draft CLI), shellcheck, markdownlint-cli (lint only)" — Python is not among them.

**Failure:** on a host without `python3`, the OKF emitter aborts at exit 127 mid-run —
after `mkdir`/partial writes, before link fixing or view rendering. Per CLAUDE.md, `okf` is
the **default** output mode for tier 3–5 projects, so this is the default path for the
largest repos, not an opt-in corner.

**Smallest fix:** guard with `command -v python3` and fail with a clear message (or skip the
link-fix pass), and add `python3` to the documented prerequisites.

---

## Suggestions (10)

- `[simplify]` `scripts/tools/okf-fix-links.sh:106-144,257-261` — dead code block:
  `resolve_ok()` has **no call sites**, so `build_slugs()`/`SLUGS` (lines 106-123, called
  once at 258) feed nothing; `broken=0`/`total=0` are never read; and lines 257-261 are a
  `while IFS= read … done < /dev/null` loop with an empty body that cannot execute. The
  Python block at 267 does all the real checking. Separately, `DO_CHECK` is assigned at
  lines 23 and 51 and **never read** — the documented `--check` flag is inert.
- `[bug]` `scripts/tools/graph-callers.sh:95` and `scripts/tools/graph-impact.sh:81` — the
  `--transitive` branch emits `file: (.qualified_name // "")`, while the single-hop branch
  (`graph-callers.sh:116`) emits the real `c.file_path`. Same tool, same documented field
  (`callers:[{name,file[,hop]}]`), two different meanings; a consumer resolving `.file` to a
  path gets `pkg.mod.Class.method` under `--transitive`.
- `[test-gap]` `tests/test-tools-resolve-tools.sh` — every foreign-cwd case sets
  `DRAFT_PLUGIN_ROOT`, so steps 2-8 (marker, `CLAUDE_PLUGIN_ROOT`, registry, cache glob,
  marketplace, Cursor, dev) are entirely untested. That is why findings 2 and 3 both survived.
- `[test-gap]` `scripts/tools/install-smoke-test.sh:179-181` — asserts "dry run left HOME
  untouched", but `codex` and `opencode` default to project scope and write `AGENTS.md` into
  `ctx.cwd` (`$PROJECT`), which is never asserted clean. The likeliest dry-run leak is the
  one not checked.
- `[bug]` `scripts/tools/install-smoke-test.sh:198` — `--json` escapes only `"` in `detail`
  (`${detail//\"/\\\"}`); a backslash or control char from `clone.err`/`manifest.err` emits
  invalid JSON. `_lib.sh:json_escape` already handles `\`, `\n`, `\t`, `\r`.
- `[comment]` `scripts/build-integrations.sh:518` — `verify_output` prints
  `"Agent refs: preserved (not stripped)"` for **both** builds, but
  `transform_copilot_syntax:47-48` rewrites `@architect`/`@debugger`/… → `@workspace`. The
  Copilot build reports the opposite of what it did.
- `[comment]` `scripts/tools/_lib.sh:18` and `:112-115` — two doc comments are detached from
  their functions. Line 18 ("Extract a top-level YAML frontmatter field…") sits above
  `discover_track_dirs`; it describes `get_yaml_field` (line 93), which has no comment. The
  `find_memory_bin` docblock (112-115) is separated from the function (157) by `gfm_slug` and
  `grounded_paths_count`, and its stated order "PATH > Draft-managed > vendored" omits steps
  0 and 1 (`DRAFT_MEMORY_DISABLE`, `DRAFT_MEMORY_BIN`), which take priority.
- `[comment]` `scripts/lib.sh:5-6` vs `:12` — the header says "Defines constants and
  validation functions but does not execute anything when sourced", but line 12 runs
  `set -euo pipefail`, mutating every sourcing shell's options (8 test suites plus
  `build-integrations.sh` and `verify-graph-binary.sh`). Contrast `scripts/tools/_lib.sh:4`,
  which correctly states "No side effects at source time" and sets nothing.
- `[security]` `.github/workflows/pages.yml:45` — `actions/deploy-pages@v5` is tag-pinned
  while every other action across all three workflows is SHA-pinned with a version comment.
  A moved tag changes what runs in a job holding `pages: write` + `id-token: write`.
- `[bug]` `scripts/tools/graph-snapshot.sh:81-82` — `rm -f "$OUT/architecture.json" …` and
  `rm -rf "$OUT/okf"` run against a fully user-supplied `--out DIR` with no validation, and
  `mkdir -p "$OUT"` (line 79) creates it first, so a mistyped path silently gets a directory
  and a recursive delete of its `okf/` subtree.

---

## Strengths

- **Cypher escaping is correct.** `gq_escape` (`_graph_queries.sh:34`) doubles backslashes
  before escaping quotes; I tested `foo'bar`, `trail\`, and `a'} RETURN 1 //` — all produced
  well-formed literals. Every `gq_q_*` call site escapes its input; no wrapper inlines Cypher,
  so the "single source of query truth" guardrail holds.
- **JSON payloads are built with `jq -n --arg`,** never string concatenation
  (`gq_run`, `memory_index_bounded`, `graph-callers.sh:85`) — a repo path or symbol containing
  a quote cannot corrupt what reaches the engine.
- **Fail-loud beats fail-empty.** `gq_symbol_status` distinguishes `no-edges` / `no-match` /
  `probe-failed`, so an engine failure is never mistaken for "no results" — a discipline most
  codebases skip.
- **`release.yml` is injection-hardened:** every untrusted value goes through `env:` rather
  than `${{ }}` interpolation into a shell body, the tag is newline-checked, and the release
  is gated on `package.json` agreement.
- **The comments explain *why*, with receipts** — the 670 MB blob behind `check-repo-size.sh`,
  the SIGPIPE-under-`pipefail` note at `check-repo-size.sh:108-111`, the cgroup bound in
  `memory_index_bounded`. Rare and genuinely useful.
- `strip_quoted_spans` fails **closed** on an unterminated quote span, and handles `'`, `"`,
  and backtick spans plus backslash escapes — the `--cypher` guard itself is well built. It is
  only the `--tool` path that never calls it.
- **Every one of the 53 registered tools has a matching test suite**; `make test` is green.

---

## Coverage

**Reviewed in full (risk-ranked):**

| Unit | Files | Depth |
|---|---|---|
| Graph query surface | `_graph_queries.sh`, `_lib.sh`, `graph-query.sh`, `graph-callers.sh`, `graph-snapshot.sh` | line-by-line + executed |
| Tool resolution | `resolve-tools.sh` | line-by-line + executed |
| Build / release | `build-integrations.sh`, `lib.sh`, `sync-version.sh`, `release-notes.sh` | line-by-line |
| Supply chain | `fetch-memory-engine.sh` | line-by-line |
| Node CLI | all 15 files under `cli/` | line-by-line |
| CI | `ci.yml`, `pages.yml`, `release.yml` | line-by-line |
| File-mutating tools | `fix-whitespace.sh`, `okf-fix-links.sh`, `git-metadata.sh`, `freshness-check.sh`, `manage-symlinks.sh` | line-by-line + executed |
| Install gates | `check-repo-size.sh`, `install-smoke-test.sh` | line-by-line |
| Website JS | `web/js/*`, `web/book/js/*`, `web/blog/share.js` | sink scan (`innerHTML`, `eval`, URL/`localStorage` reads) — no attacker-controlled input reaches any HTML sink; no findings |
| Whole shell corpus | 148 `*.sh` | mechanical sweep: `set -e` coverage, `eval`, `rm -rf`, `printf` format strings, unguarded `python3`, `mktemp`→`mv`, network calls, checksum verification |

**Not reviewed line-by-line — where remaining risk sits:**

- ~40 of the 53 `scripts/tools/*.sh` (≈6,000 lines), notably the OKF cluster
  (`okf-plan-concepts.sh` 538, `okf-render-views.sh` 511, `okf-validate*.sh`,
  `okf-emit-catalog.sh`, `okf-coverage-check.sh`) and the `check-*`/`verify-*` family.
  They were covered only by the mechanical sweep above. **This is the largest blind spot.**
- `tests/` (81 files, ≈8,000 lines) — executed, not read. A test asserting the wrong thing
  looks identical to a passing one from the outside; finding 10 is the one case where I did
  read a suite and found exactly that.
- `scripts/build-book.sh` (≈650 lines of HTML generation), `package.sh`, `lint.sh`,
  `scripts/benchmark/*` — not part of the shipped plugin.
- `skills/**/SKILL.md`, `core/**` (≈150 markdown files) — reviewed structurally via the build
  contract and `make test`, not read as prose.
- `integrations/**` — generated; excluded by design.

**xsecurity:** not requested (`--xsecurity` not passed); the lightweight `security` dimension
ran instead.

---

## Resolution (2026-08-18)

All 5 findings and all 10 suggestions were fixed on branch `xreview-fixes`.
`make test` is green (80 suites, 1,176 assertions) and `make build` reproduces
byte-identical integrations.

| # | Finding | Fix | Regression test |
|---|---------|-----|-----------------|
| 1 | `graph-query.sh` read-only bypass | shared `reject_write_verbs`, applied to `--cypher` and to any `--tool` payload carrying a `query` | `test-tools-graph-query.sh` — write verb in a `query_graph` payload, plus a symbol literally named `DELETE` to pin the no-false-positive edge |
| 2 | `resolve-tools.sh` cwd hijack | cwd demoted to last resort and gated on Draft's plugin manifest; bare `$PWD/scripts/tools` fallback removed | `test-tools-resolve-tools.sh` — a repo impersonating Draft loses to an installed plugin; a plain `scripts/tools/` project resolves nothing |
| 3 | `resolve-tools.sh` step-5 abort | `\|\| true` on the `newest()` pipeline | same suite — steps 2-8 each asserted under a synthetic HOME; step 7 is reachable only if step 5's glob miss no longer aborts |
| 4 | 0600 permission stripping | new `apply_dest_mode` helper applied at all 8 shell rewrite sites; `writeJsonAtomic` stats the destination first | `test-tools-fix-whitespace.sh` — 0644 stays 0644, 0600 stays 0600 |
| 5 | undeclared `python3` | preflight `command -v` in both OKF tools; prerequisite documented in CLAUDE.md | — (environment-dependent) |
| S1 | dead code in `okf-fix-links.sh` | removed `resolve_ok`, `build_slugs`/`SLUGS`, the `< /dev/null` loop, `broken`/`total`, and the inert `DO_CHECK`; also `pick_target` + `BASENAME_MAP_MULTI`, found during the fix — a bash twin of what the Python pass already does. 326 → 247 lines | existing suite still passes, including the section-preference case the removed bash twin claimed to handle |
| S2 | `file` vs `qualified_name` | `file` is now always a path; `qualified` is its own field in both tools | — |
| S3 | resolve-tools test gap | steps 2-8 covered under synthetic HOMEs (16 assertions, was 5) | is the test |
| S4 | smoke test only checked HOME | project dir asserted untouched too | is the test |
| S5 | smoke-test JSON escaping | `json_escape` from `_lib.sh` | `--json` output parsed with `json.load` |
| S6 | false "Agent refs" status line | `verify_output` takes the description per build | visible in `make build` output |
| S7 | misplaced `_lib.sh` comments | moved to their functions; `find_memory_bin`'s precedence list corrected to include `DRAFT_MEMORY_DISABLE`/`DRAFT_MEMORY_BIN` | — |
| S8 | `lib.sh` side-effect at source | `set -euo pipefail` removed (all 16 consumers set their own); header corrected | full suite |
| S9 | unpinned Pages action | pinned to `cd2ce8f` (v5.0.0) | — |
| S10 | `rm -rf` under unvalidated `--out` | prune gated on positive evidence Draft owns the dir | `test-tools-graph-snapshot.sh` still proves migration pruning works; an unrelated `--out` dir's `okf/` was verified to survive |

**Not verified locally:** `shellcheck` is not installed on this machine, so the
blocking CI lint gate ran only in CI. The audit's stated blind spots (≈40 tools
not read line-by-line, `tests/` not read) are unchanged — this pass fixed what
was found, it did not widen coverage.
