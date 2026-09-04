# xreview — whole-codebase audit

**Date:** 2026-09-03 · **Mode:** audit (no diff) · **Scope:** repo root · **Base:** `6d29e85`

**Remediation:** all Important findings and Suggestions in this report were
fixed on `audit-fixes` (see CHANGELOG Unreleased).

Draft is a plugin: 33 markdown skills, 53 bash helpers, a Node installer, and a
local graph engine fetched on install. Trust boundaries are (a) shell tools an
agent invokes with arguments from repo content, (b) the installer writing
`~/.claude` / `~/.cursor` / `~/.cache`, (c) `fetch-memory-engine.sh` downloading
a binary, (d) OKF renderers emitting HTML from wiki markdown.

Findings below survived independent re-validation against the code. Candidates
that did not re-derive (e.g. `check-track-hygiene.sh` unbound `hld_ts` — `local`
initializes empty under `set -u`) were dropped.

xsecurity was not launched (audit mode, no change set).

Profile: skipped (401 source-ish files; not large enough to justify
`.xreview/profile.md`).

---

## Critical (0)

None on the default install/query path. The remaining fail-open graph hole is
the same *class* as the 3.7.1/3.7.2 fixes but does not crash or delete data.

---

## Important (11)

### 1. `[silent-failure]` `scripts/tools/_graph_queries.sh:78-88` — `gq_run` treats any JSON as success, including `{}`

`gq_run` requires a binary, non-empty stdout, and `jq -e .` (parseable JSON). It
does **not** require `.rows` (or any tool-shaped object). `{}` therefore returns
exit 0.

Callers that were patched in 3.7.x to fail-loud on non-JSON still treat `{}` as
an empty true-negative with `source:"memory-graph"`:

| Wrapper | What `{}` becomes |
|---|---|
| `cycle-detect.sh:69-83` | `{cycles:[], source:"memory-graph"}` exit 0 — clean bill of health |
| `hotspot-rank.sh:68-112` | `{hotspots:[], enrichment:"ok", source:"memory-graph"}` |
| `graph-impact.sh:79-84` | `{impacted:[], source:"memory-graph"}` (via `jq -e .` on `trace_path`) |
| `graph-callers.sh:112-120` | `{callers:[], status:"no-match", source:"memory-graph"}` |
| `mermaid-from-graph.sh` | empty-graph stub, not "unavailable" |

`cycle-detect.sh:67-68` comments that `gq_run` "only ever echoes validated JSON,
so nothing downstream needs a second shape guard." That comment is false for
shape: `{}` is JSON and has no `.rows`.

**Failure:** engine (or a stub) emits `{}` → skills report "no cycles / no
hotspots / no callers" as a measured result.

**Fix:** `gq_run` should require a `.rows` array (or a documented per-tool
shape) and return 3 otherwise. Then drop the duplicate `jq -e .` guards in
wrappers that already call `gq_run`. (confidence 95)

### 2. `[silent-failure]` `scripts/tools/hotspot-rank.sh:82-87` — `{}` from the props query sets `enrichment:"ok"` and emits zeros

The 3.7.2 fix records `enrichment:"unavailable"` when `gq_run` fails. Because
`gq_run` succeeds on `{}` (finding 1), this path still sets `ENRICHMENT="ok"`,
then the jq merge fills `complexity`/`cognitive` from missing props as `0` and
folds them into `score`.

**Failure:** unmeasured ranking presented as fully measured — the lie that fix
was written to stop. (confidence 95)

**Fix:** after `gq_run`, require `.rows` is an array; otherwise `ENRICHMENT=unavailable`.

### 3. `[silent-failure]` `scripts/tools/graph-snapshot.sh:82-83` — failed refresh still writes a fresh `schema.yaml`

```bash
REFRESHED="$(memory_index_bounded "$REPO_ABS" 2>/dev/null | jq -r '.project // empty' 2>/dev/null || true)"
[[ -n "$REFRESHED" ]] && PROJECT="$REFRESHED"
```

If the refresh call fails, `REFRESHED` is empty, `PROJECT` stays at the
`memory_ensure_index` value, and the script continues to write
`draft/graph/schema.yaml` with a new `generated_at`. The block comment at
76-81 describes this as the exact stale-index failure the refresh exists to
prevent.

**Failure:** gate marker claims a fresh index over a frozen one. (confidence 92)

**Fix:** if `REFRESHED` is empty after an existing project was found, exit 2
and write nothing.

### 4. `[security]` `scripts/fetch-memory-engine.sh:77,83,101` — HTTPS prefix check does not bind `curl -L` redirects

`case "$BASE" in https://*)` rejects a non-HTTPS *starting* URL. Both `curl`
invocations use `-L` without `--proto '=https' --proto-redir '=https'`. A
server at an accepted `https://` BASE (including `CMM_DOWNLOAD_URL`) can 302
to `http://...` and the archive/checksums are still written and installed.

Default GitHub release URLs stay on HTTPS; the hole is the redirector and any
custom BASE. Tests only cover a non-`https://` BASE string. (confidence 92)

**Fix:** add `--proto '=https' --proto-redir '=https'` to both `curl` calls.

### 5. `[security]` `scripts/tools/okf-render-views.sh:417,441` — wiki HTML viewer XSS

The offline viewer escapes headings/lists via `inline(esc(...))`. Two sinks do
not:

- **Tables (`:441`):** `inline(c.trim(), base)` with no `esc()`. A cell
  `| <img src=x onerror=alert(1)> |` is emitted raw into `#content`.
- **Autolinks (`:417`):** any `scheme://` becomes `<a href="'+u+'">` with no
  scheme allowlist and no attribute escaping. `javascript://…` and
  `https://a.com/"onmouseover="…` both fire. Link text `t` is also unescaped.

`</script>` neutralization of the data blob does not cover these sinks. Attack
path: a wiki concept page (user- or agent-authored markdown) → open
`draft/wiki/web/index.html` → script runs in that origin. (confidence 92)

**Fix:** `esc()` table cells before `inline`; allowlist `https:`/`http:`/`mailto:`;
attribute-escape `u` and `esc(t)`.

### 6. `[security]` `scripts/tools/okf-emit-catalog.sh:85-86` — `concept_id` is joined onto `$BUNDLE` unsanitized

`out="$BUNDLE/$cid"` then `mkdir -p "$(dirname "$out")"` and write. A plan
row `concept_id: "../outside.md"` writes outside the bundle (re-derived from
the join; no sanitization in `write_page`). (confidence 88)

**Fix:** reject `cid` containing `..` or starting with `/`; resolve and require
the result stays under `$BUNDLE`.

### 7. `[contract]` `cli/src/cli.js:51` vs `cli/src/hosts/claude-code.js:24` — help lies about the default scope

Help: `--project` is "default for claude-code, codex, opencode".
`claude-code.js` sets `defaultScope: 'global'` (comment: "Default scope is
`user` (global)"). `cmdInstall` uses `flags.scope || host.defaultScope`.

**Failure:** `draft install claude-code` with no flags installs user-scope;
`--help` says project. README agrees with the code, not with `--help`.
(confidence 95)

**Fix:** change the help line to match `defaultScope` (global/user for
claude-code and cursor; project for codex/opencode).

### 8. `[bug]` `cli/src/installer.js:17-20` — `hasBinary` treats Windows missing-CLI as present

`spawnSync(name, ['--version'], { shell: USE_SHELL })` with `USE_SHELL` true
on win32. A missing `.cmd` shim returns `status: 127` and no `error`. The
predicate is `!(r.error && r.error.code === 'ENOENT')`, so 127 counts as
present. The requires-check is skipped; the later exec fails as a generic
step error instead of "not on PATH". (confidence 92)

**Fix:** treat non-zero `status` (and `error`) as missing.

### 9. `[bug]` `cli/src/lib/graph.js:17` — graph fetch has no timeout

Install exec steps use `STEP_TIMEOUT_MS` (default 300s). `fetchGraph` calls
`spawnSync('bash', [script], { stdio: 'inherit' })` with no `timeout`. A
stalled `curl` hangs the installer after files/registry are already written.
(confidence 90)

**Fix:** pass `timeout: STEP_TIMEOUT_MS` (or the same env override).

### 10. `[silent-failure]` `scripts/tools/resolve-tools.sh:56-58,68-69` — probe failures abort instead of falling through

`set -euo pipefail`. Two probes are not fall-through-safe:

- Marker present but unreadable: `d="$(cat "$marker" 2>/dev/null)/scripts/tools"`
  — `cat` non-zero exits the script; steps 3–8 never run.
- `installed_plugins.json` present and `jq` on PATH, JSON malformed:
  `ip="$(jq … | head -1)"` fails the pipeline; same abort.

A valid cache/marketplace install at a later step is then invisible. Same
abort-on-probe class the step-5 `ls || true` fix addressed. (confidence 88)

**Fix:** `cat … || true`; `jq … || true`; keep the `[ -d "$d" ]` / `[ -n "$ip" ]`
gates.

### 11. `[bug]` `scripts/build-integrations.sh:47` — Copilot transform rewrites emails whose local-part is an agent name

```sed
s#@(architect|debugger|planner|rca|reviewer|ops|writer)([^[:alnum:]_-])#@workspace\2#
```

`user@ops.example` → `user@workspace.example` because `.` matches the
separator class. Copilot-only. (confidence 92)

**Fix:** require a non-email left boundary (start, whitespace, or opening
backtick), not just `[^[:alnum:]_-]` on the right.

---

## Suggestions (8)

- `[silent-failure]` `cli/src/lib/cursor-registry.js:81,96` — `typeof x === 'object'` accepts arrays; named keys added onto `plugins: []` / `enabledPlugins: []` are dropped by `JSON.stringify`. Install prints Done, Cursor never sees the plugin. Guard with `!Array.isArray`.
- `[bug]` `cli/src/cli.js` / `tests/test-cli.sh` — no dry-run coverage for `opencode` (`AGENTS.md` + `~/.agents/skills/draft`).
- `[security]` `scripts/tools/okf-validate.sh:255` — `--path-index` values like `../external.md` satisfy `-f "$BUNDLE/$ref"` if that file exists beside the bundle; the claimed check is "in the bundle".
- `[silent-failure]` `scripts/tools/okf-render-views.sh:229` — `okf-fix-links.sh … || true` hides dangling-link failures; render exits 0.
- `[bug]` `scripts/build-book.sh:269` — chapter pages `cat > index.html` in place (landing/sitemap use mktemp+mv). Kill mid-write leaves truncated HTML as the live page.
- `[silent-failure]` `.github/workflows/release.yml:64-71` — `release-notes.sh` exit 2 (missing file / bad VERSION) takes the same `else` as exit 1 (missing section), publishes a stub Release.
- `[bug]` `scripts/tools/scan-markers.sh:81` — `path:line:text` split breaks if the path contains `:`.
- `[bug]` `scripts/tools/check-repo-size.sh:112` — over-cap listing prints only the first field of a spaced blob path; the gate still fails.

`scripts/package.sh --out /` with `rsync --delete` / `rm -rf` is a maintainer
footgun (not a user-facing CLI). Not promoted: operator-only, not on the
install path.

---

## Strengths

- 3.7.1/3.7.2 fail-loud work on `cycle-detect` / `hotspot-rank` / `mermaid-from-graph` is real for **non-JSON** engine failures; the remaining hole is specifically shapeless JSON.
- `graph-query.sh` now scans `--tool … --json '{"query":…}'` for write verbs (the 2026-08-18 Critical).
- CI workflows: no `pull_request_target`, no secrets on fork PRs, Pages not driven by untrusted PRs.
- Skill-name path traversal is blocked (`is_valid_skill_name` + `SKILL_ORDER`).
- `gq_escape` + `jq --arg` payloads: no Cypher injection proven in the graph wrappers.

---

## Coverage

- **Reviewed (8 units):** `cli/`; `scripts/fetch-memory-engine.sh`; `scripts/tools/_lib.sh` + `resolve-tools.sh` + `verify-graph-binary.sh`; graph wrappers (`_graph_queries.sh`, `hotspot-rank`, `cycle-detect`, `mermaid-from-graph`, `graph-impact`, `graph-callers`, `graph-snapshot`, `graph-query`); OKF tools (`okf-fix-links`, `okf-render-views`, `okf-plan-concepts`, `okf-validate`, `okf-emit-catalog`, `okf-validate-all`, `okf-validate-quality`); `scripts/build-integrations.sh` + `lib.sh` + `sync-version.sh` + `build-book.sh` + `package.sh`; `.github/workflows/`; `install-smoke-test.sh` + `check-repo-size.sh` + `check-track-hygiene.sh` + `manage-symlinks.sh` + `scan-markers.sh`.
- **Not reviewed (out of budget):** `skills/**` (markdown instructions), `core/**` (templates/methodology), `tests/**` except as cited, `web/**` (static site), `book/**`, generated `integrations/**` / root `AGENTS.md`, remaining `scripts/tools/*` (classify-files, git-metadata, coverage runners, etc.).
