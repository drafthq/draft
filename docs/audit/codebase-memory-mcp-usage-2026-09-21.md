# Audit: codebase-memory-mcp usage in Draft

**Date:** 2026-09-21 · **Engine:** codebase-memory-mcp 0.9.0 (pinned `v0.9.0`) · **HEAD:** `dab1904`
**Method:** read the integration layer (`_lib.sh`, `_graph_queries.sh`, the `graph-*.sh` wrappers, `fetch-memory-engine.sh`, `cli/src/lib/graph.js`) and the skill/shared markdown that uses it. Each behavioral finding was reproduced against the real engine, either on this repo or on scratch repos with an isolated `CBM_CACHE_DIR`. Where a finding rests on reading code alone, it says so.

## Bottom line

The integration's structure is sound: one Cypher module, payloads built with jq, fail-loud status handling, a guard against write verbs, and an opt-out. It has two correctness gaps that directly affect Draft's pitch:

1. **Live queries answer from a stale index and still report `status: ok`.**
2. **`graph-impact.sh --file` doesn't measure blast radius.** It returns only the symbols inside the file, never the code that depends on it.

Two other problems make regressions likely. The calling convention Draft uses everywhere is **deprecated upstream**. And **no test ever runs against the real engine**, while the local test suite writes into the user's real engine cache.

## Findings

### High

**H1. Stale index answers as if fresh.**
- **Where:** `scripts/tools/_lib.sh:345-357`, `core/shared/graph-query.md:378`.
- **What:** `memory_ensure_index` indexes only when the project is missing and never refreshes it. Only `graph-snapshot.sh` re-indexes. Meanwhile `review`, `implement` (post-edit blast radius, `skills/implement/SKILL.md:664-674`) and `debug` query after edits without refreshing. `graph-query.md:378` claims the engine "self-freshens on each query", which is false.
- **Repro:**
  1. Index a repo.
  2. Add `newfn()` that calls `helper()`.
  3. `graph-callers.sh --symbol helper` still returns only `core`, with `status:"ok"`.
  4. `newfn` appears only after `graph-snapshot.sh`.
- **Cost of fixing:** an incremental re-index of this repo (432 files) takes **0.6 s**. `index_status` already returns `git.head_sha`, so staleness is cheap to detect.
- **Fix:**
  - In `graph_bootstrap`, compare `index_status.git.head_sha` plus a hash of `git status --porcelain` against a stamp. Re-index on mismatch.
  - Delete the false "self-freshens" row.

**H2. `graph-impact.sh --file` reports symbols inside the file instead of blast radius.**
- **Where:** `scripts/tools/graph-impact.sh:86-97`.
- **What:** it filters `detect_changes.impacted_symbols` to the target file.
  - Every symbol comes back **twice**, and the file node itself is included.
  - Callers in other files are never included.
  - An unchanged file returns `impacted: []` with `source: "memory-graph"`. That is a success-shaped true negative, the failure mode Guardrail 4 exists to prevent.
  - `endswith($t)` has no path boundary, so `--file lib.sh` also matches `_lib.sh`.
- **Blast:** skills call it about 8 times with `--file <path>` to compute blast radius.
- **Repro:**
  - `graph-impact.sh --file scripts/tools/_lib.sh` returns **0**.
  - `MATCH (a)-[:CALLS*1..3]->(b) WHERE b.file_path = 'scripts/tools/_lib.sh' RETURN DISTINCT a.file_path` returns **23** dependent files. That query form works on 0.9.0.
- **Fix:**
  - Compute dependents with the variable-length inbound query above, plus inbound `IMPORTS`, and deduplicate.
  - When the file has no changes, return an explicit status instead of an empty success.

**H3. Every engine call uses a calling convention that is deprecated upstream.**
- **Where:** `_lib.sh:256,258,333,336`, plus the raw-CLI instructions in `graph-query.md`.
- **What:** on 0.9.0, every call prints: *"passing raw JSON to 'cli \<tool\>' is deprecated and will be removed in a future release; use flags, --args-file, or piped stdin."* `memory_cli` sends stderr to `/dev/null`, so the warning is never seen.
- **Risk:**
  - The next pin bump breaks all wrappers at once.
  - `find_memory_bin` prefers a codebase-memory-mcp binary on `$PATH` over the managed copy, so a user with a newer global install breaks first.
- **Fix:** pipe the JSON on stdin instead, e.g. `printf '%s' "$args" | "$MEMORY_BIN" cli "$tool"`. Verified to work with no warning. The change is confined to `memory_cli` and the two `systemd-run` call sites.

**H4. No real-engine test coverage, and the tests pollute the user's engine cache.**
- **Where:** `tests/test-helpers.sh:35-71`, `tests/test-tools-graph-query.sh:34-40`, `.github/workflows/ci.yml`.
- **What:**
  - All 21 wrapper tests use a mock engine.
  - The mock's `list_projects` always returns `[]`, so the "already indexed" branch never runs.
  - CI never fetches the engine.
  - As a result, no `gq_q_*` Cypher builder, JSON shape, or project-resolution path is ever run against the real engine. That is how the dialect list went stale (M7) and how the cycle bugs (M5) got in.
- **Pollution:**
  - The write-verb guard loop in `test-tools-graph-query.sh` sets no `DRAFT_MEMORY_BIN`. On any machine with the engine installed, it indexes `mktemp` fixtures into `~/.cache/codebase-memory-mcp` and never deletes them.
  - The cache holds **141** `tmp-*` project DBs (78 MB of 716 MB). This audit's test run added 6 of them.
  - No test sets `CBM_CACHE_DIR`.
- **Fix:**
  - Have `test-helpers.sh` export `DRAFT_MEMORY_DISABLE=1` and `CBM_CACHE_DIR=$(mktemp -d)` by default.
  - Add a CI job that fetches the pinned engine and runs a smoke test on a small fixture repo (callers, impact, cycles, hotspots) with the real engine.

### Medium

**M1. Checksum verification only catches download corruption, not a compromised release.**
- **Where:** `scripts/fetch-memory-engine.sh:101-119`.
- **What:** `checksums.txt` comes from the same release as the archive. A replaced release asset, or a re-pointed tag, passes verification.
- **Also:** strict mode is off by default. `bin/README.md` states this honestly, but the fix is cheap.
- **Fix:** pin four per-platform SHA-256 values next to `DEFAULT_VERSION`. Treat a mismatch with the pinned values as fatal regardless of `DRAFT_STRICT_VERIFY`.

**M2. The pinned engine version is never enforced.**
- **Where:** `fetch-memory-engine.sh:47-50`, `_lib.sh:193-196`, `verify-graph-binary.sh:127-130`.
- **What:**
  - The fetch script exits 0 if any binary exists at the destination, whatever its version. Bumping the pin never upgrades an existing install, and that path is untested because every test passes `--force`.
  - Binaries on `$PATH` win over the managed copy.
  - `verify-graph-binary.sh` checks only that the binary responds to `--version`.
- **Fix:**
  - Reinstall when `--version` differs from `DEFAULT_VERSION`.
  - Warn in `verify-graph-binary.sh` and `graph-preflight.sh` when the resolved version is off-pin.

**M3. A repo reached through a symlink is re-indexed on every wrapper call.**
- **Where:** `_lib.sh:238`, `graph-snapshot.sh:64`, `graph-init.sh`.
- **What:** `REPO_ABS` comes from `pwd`, which keeps the symlink path. The engine stores the resolved real path. So the `list_projects` lookup misses and `index_repository` runs on every query. Confirmed with `DRAFT_MEMORY_DEBUG`.
- **Hits:**
  - macOS `/tmp` and `/var/folders`, which resolve under `/private`.
  - Any symlinked workspace.
- **Fix:** use `pwd -P`.

**M4. Two different repo paths can share one engine project.**
- **What:** the engine derives project names by replacing `/` with `-`. `/x/a-b/c` and `/x/a/b-c` map to the same DB, and each call from one repo re-indexes over the other. Verified: after both were indexed, the DB held only whichever repo was indexed last.
- **Fix:** pass `--name` (the engine supports it) using a hash of the path. Or check the returned project's `root_path` and fail loud on mismatch.

**M5. `cycle-detect.sh` reports each 3-cycle three times and reports self-loops as 3-cycles.**
- **Where:** `scripts/tools/cycle-detect.sh:74-83`.
- **What:**
  - A single `fa→fb→fc→fa` cycle comes back as 3 rows, one per rotation.
  - The self-loop filter is applied only to 2-cycles. The one "cycle" this tool reports for Draft itself is `getHost, getHost, getHost`, which is a false positive.
- **Fix:** in jq, drop 3-rows that repeat a node, rotate each row to start at its smallest element, then `unique`.

**M6. The docs contradict the code and each other.**
- `bin/README.md:101` says "Skills never call the engine directly". But `core/shared/graph-query.md:118,196-202` tells agents to run raw `codebase-memory-mcp cli` for `search_graph`, `search_code` and `trace_path`.
  - `graph-query.sh --tool` already allow-lists all three.
  - Pointing the docs there removes the contradiction and the deprecated calling form, with no new code.
- `graph-query.md:378` makes the false "self-freshens" claim (see H1).

**M7. The documented Cypher restrictions are out of date.**
- **Where:** `_graph_queries.sh:10-19`, `graph-query.sh:15-19`, `graph-query.md:140-159`, `graph-traces.sh:7,42`.
- **What:** all of these say "v0.8.x" and forbid constructs that 0.9.0 handles correctly:
  - `<>` (filters correctly)
  - `coalesce()`
  - variable-length paths such as `[:CALLS*1..3]`
  - `WITH` aggregation

  Property-to-property comparison still fails.
- **Cost:** the stale list pushed designs into weaker forms: `trace_path` without file paths (L1), and self-loop and duplicate filtering done in jq (M5).
- **Fix:** re-verify each construct on 0.9.0, update the list, and add a real-engine dialect test (H4).

### Low

- **L1.** `graph-impact.sh --symbol` always emits `file: ""`, because `trace_path` returns no `file_path`. As a result, skills can't turn callers into files.
  - The code comment says the `"callers"` direction returns nothing. `direction:"inbound"` works; `"both"` also computes callees that are then thrown away.
  - Fix: switch to the variable-length Cypher query, which returns `a.file_path`.
- **L2.** `hotspot-rank.sh` enriches hotspots with `MATCH (f) … LIMIT 10000` over all nodes. On repos with more than 10k nodes, hotspots outside that window get complexity 0 while the output still says `enrichment:"ok"`.
  - Fix: fetch properties for the hotspot qualified names only.
- **L3.** On a repo not yet indexed, `graph-snapshot.sh:73-82` indexes twice: once in `memory_ensure_index`, then again in `memory_index_bounded`.
  - Fix: drop the first call.
- **L4.** The engine honors `CBM_MEM_BUDGET_MB` (the log shows `source=CBM_MEM_BUDGET_MB`).
  - Setting it gives macOS a real memory bound. The `_lib.sh:307-341` comment currently says the worker cap is "the only bound" there.
- **L5.** The committed `draft/graph/schema.yaml` carries fields that change on every run or only make sense on one machine:
  - `project:`, a name derived from the local path.
  - `generated_at`, which churns on every init.
  - `changed_files`.

  `graph-init.sh` also copies `project:` into `root-link.json`.
  - Fix: commit only fields that hold on any machine. Keep the per-machine fields in the engine cache.
- **L6.** `bin/README.md`'s "no outbound calls" claim holds for CLI mode: strace of `list_projects` and `index_repository` showed zero `connect()` calls and no `curl` exec.
  - The binary does embed an update checker (`api.github.com/.../releases/latest`) and an `update` subcommand.
  - Fix: scope the claim to "as Draft invokes it (CLI mode)".

## What is working well (keep)

- **Fail-loud results:** `gq_run` rejects JSON without rows. `gq_symbol_status` separates `no-match`, `no-edges` and `probe-failed`. `cycle-detect` and `hotspot-rank` refuse to present a failed query as a clean result.
- **Injection-safe payloads:** every payload is built with `jq --arg`, and `gq_escape` doubles backslashes before escaping quotes.
- **Write-verb guard:** it strips quoted spans before scanning, fails closed on unterminated quotes, and also scans the `query` field of `--tool` payloads.
- **Safe install and deletes:** the fetch accepts HTTPS only (including redirects), and the snapshot's `rm -rf` runs only on a directory Draft owns.
- **Memory-bounded indexing:** a transient cgroup plus `CBM_WORKERS`, and it never falls back to an unbounded run.
- **No writes into the user's source tree:** there is no `.codebase-memory/` directory, and `--persistence` is not used.
- **Opt-out:** `DRAFT_MEMORY_DISABLE`, with documented reduced-context behavior.

## Recommended order

| # | Item | Size | Why first |
|---|---|---|---|
| 1 | H3: pass JSON on stdin | ~4 lines | Unblocks every future engine upgrade |
| 2 | H4: test isolation (`DRAFT_MEMORY_DISABLE`, `CBM_CACHE_DIR`) | ~3 lines | Stops ongoing pollution of the user's cache |
| 3 | H4: real-engine CI smoke job | small | Would have caught M5, M7 and L1 |
| 4 | H1: freshness stamp in `graph_bootstrap` | small | Stops stale answers to post-edit queries |
| 5 | H2 + L1: real blast radius via variable-length Cypher | medium | Makes the blast-radius numbers honest |
| 6 | M5, M3, M2, M1 | small each | Correctness and supply-chain hygiene |
| 7 | M6, M7, L2-L6 | small | Docs and cleanup |

## Side effect of this audit

The test-coverage pass ran the graph test suite, which added 6 `tmp-*` project DBs to `~/.cache/codebase-memory-mcp` through the leak in H4. The cache now holds 141 of them. Scratch experiments used an isolated `CBM_CACHE_DIR` under the session scratchpad.
