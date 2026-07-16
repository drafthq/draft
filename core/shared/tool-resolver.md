---
shared: tool-resolver
applies_to: every skill that invokes scripts/tools/*
---

# tool-resolver

Canonical procedure for locating Draft's bundled shell helpers (`scripts/tools/*.sh`)
from inside a skill.

## Why this exists

When Claude runs a draft skill, the shell's **working directory is the user's
project**, not the plugin. The helpers live inside the plugin install directory,
which on a marketplace/npm install is `~/.claude/plugins/cache/<marketplace>/draft/<version>/`
— never the cwd. `${CLAUDE_PLUGIN_ROOT}` is **not** exported into skill-driven Bash
(it is only set for hooks, MCP/LSP servers, and monitor commands), so a bare
`scripts/tools/git-metadata.sh` or `${CLAUDE_PLUGIN_ROOT}/...` invocation silently fails.

Every skill MUST resolve `DRAFT_TOOLS` and invoke helpers as `"$DRAFT_TOOLS/<tool>.sh"`.

## Resolution order

`DRAFT_TOOLS` resolves to the first directory that exists, in this order:

1. `${DRAFT_PLUGIN_ROOT}/scripts/tools` — explicit override (testing / pinned installs)
2. `$PWD/scripts/tools` — dev / dogfooding when cwd IS the draft repo (guarded by
   `resolve-tools.sh`'s own presence, so it can never misfire in a user project;
   deliberately beats the install marker so a repo checkout always wins)
3. `$(cat ~/.cache/draft/plugin-root)/scripts/tools` — install marker written by `draft install` (authoritative for installs)
4. `${CLAUDE_PLUGIN_ROOT}/scripts/tools` — set in hook/MCP contexts; harmless to probe
5. `installed_plugins.json → installPath` for `draft@*` — Claude Code's own registry (needs `jq`)
6. `~/.claude/plugins/cache/*/draft/*/scripts/tools` — newest cache install (glob, `sort -V`)
7. `~/.claude/plugins/marketplaces/*draft*/scripts/tools` — marketplace clone
8. `~/.cursor/plugins/local/draft/scripts/tools` — Cursor local install
9. `$PWD/scripts/tools` — last-resort cwd fallback (unguarded)

The marker (step 3) is the fast, authoritative path for installs; steps 6–7 are the
glob fallback that keeps resolution working on installs predating the marker (no
reinstall required).

## Skill preamble (copy verbatim)

Establish `DRAFT_TOOLS` once, before the first helper call, in the **same Bash
session** that runs your tool calls — exactly as skills already define `REPO_ABS`
once and reuse it. Env vars do not persist across **separate** Bash tool
invocations (only the cwd does), so if you split helper calls into a later, separate
Bash block, re-establish `DRAFT_TOOLS` there too:

```bash
DRAFT_TOOLS="${DRAFT_PLUGIN_ROOT:-$(cat ~/.cache/draft/plugin-root 2>/dev/null)}/scripts/tools"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$(ls -d ~/.claude/plugins/cache/*/draft/*/scripts/tools 2>/dev/null | sort -V | tail -1)"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$(ls -d ~/.claude/plugins/marketplaces/*draft*/scripts/tools 2>/dev/null | tail -1)"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$PWD/scripts/tools"
```

Then invoke helpers through the variable:

```bash
"$DRAFT_TOOLS/hotspot-rank.sh" --repo . --top 5
"$DRAFT_TOOLS/graph-arch.sh"   --repo .
```

The four-line inline preamble is self-contained and is the recommended form for
skills — it needs no marker file and no prior `source`. The full resolver
(adding the `${DRAFT_PLUGIN_ROOT}` override, the guarded dogfood short-circuit,
`${CLAUDE_PLUGIN_ROOT}`, the jq-registry lookup, and the Cursor path) is shipped
as `scripts/tools/resolve-tools.sh` for tests
and for callers that prefer a single source of truth:

```bash
DRAFT_TOOLS="$("$PWD/scripts/tools/resolve-tools.sh" 2>/dev/null)"   # dev/dogfood
# installed: "$(cat ~/.cache/draft/plugin-root)/scripts/tools/resolve-tools.sh"
```

## The engine binary is separate

`DRAFT_TOOLS` locates the **wrapper scripts**. Each wrapper then resolves the
`codebase-memory-mcp` **engine binary** itself via `_lib.sh:find_memory_bin`
(`DRAFT_MEMORY_BIN` → `$PATH` → `~/.cache/draft/bin/` → vendored). Do not conflate
the two: a wrapper that runs but reports `source: unavailable` means the engine
binary is missing, not the wrapper.
