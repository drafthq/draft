---
<<<<<<< HEAD
shared: tool-resolver
applies_to: quality + init + graph skills
---

# tool-resolver (Foundations Stub)

Portable generalized stub per manifest §2.1. Full content will be expanded in later agent tranche or manual follow-up.

See verification-gates.md and template-hygiene.md for usage contracts.
=======
title: Draft Tool Resolver Pattern
purpose: Canonical bash snippet for resolving scripts/tools/*.sh paths across install layouts (Cursor plugin, Claude plugin, dev repo).
audience: skill authors and core/shared/*.md docs
---

# Tool resolver pattern

Draft ships `scripts/tools/*.sh` inside the plugin archive. At runtime, skills run inside a target project — `scripts/tools/` is **not** on a relative path from `$PWD`. Use this resolver to find the tools deterministically.

## The snippet

Paste this verbatim before invoking any `scripts/tools/*.sh` script:

```bash
DRAFT_TOOLS="${DRAFT_PLUGIN_ROOT:-$HOME/.claude/plugins/draft}/scripts/tools"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$HOME/.cursor/plugins/local/draft/scripts/tools"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$PWD/scripts/tools"
```

Resolution order:

1. `$DRAFT_PLUGIN_ROOT/scripts/tools/` — explicit override (set by install.sh or CI).
2. `$HOME/.claude/plugins/draft/scripts/tools/` — Claude Code default install.
3. `$HOME/.cursor/plugins/local/draft/scripts/tools/` — Cursor default install.
4. `$PWD/scripts/tools/` — developer running from the draft repo itself.

## Invocation forms

**Required tool** (the skill cannot complete its work without it; fail loudly):

```bash
bash "$DRAFT_TOOLS/git-metadata.sh" --yaml --project "$PROJECT"
```

**Soft tool** (best-effort; skip silently if missing — telemetry, optional polish):

```bash
[ -x "$DRAFT_TOOLS/emit-skill-metrics.sh" ] && \
  bash "$DRAFT_TOOLS/emit-skill-metrics.sh" '<payload>'
```

**Soft tool with explicit fallback prose**:

```bash
if [ -x "$DRAFT_TOOLS/fix-whitespace.sh" ]; then
  bash "$DRAFT_TOOLS/fix-whitespace.sh" --draft
fi
# If absent, the model performs the same normalization manually.
```

## Why not a simpler form

- **A bare `scripts/tools/<name>` path** breaks the moment the skill runs inside a project other than the draft repo (the common case). 3k+ engineers hit this.
- **A wrapper script on PATH** would require an installer step we don't have on Cursor/Claude Code.
- **A single env var pointing at the tool file** would multiply env vars per tool.

The three-line resolver is the smallest correct form. Tested by `tests/test-skill-script-invocation.sh`.
>>>>>>> a79c14023e16774c77463870ac3510b728e8a91c
