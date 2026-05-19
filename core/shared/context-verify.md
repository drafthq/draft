---
shared: context-verify
applies_to: all skills that load Draft project context
---

# Verify Draft Context (Shared Subroutine)

Single-source `Verify Draft Context` subroutine. Replaces the duplicated 3–4 line blocks that appeared in skills that load project context.

Referenced by: every skill that starts with a `Verify Draft Context` step.

## Procedure

1. **Probe the draft directory:**

   ```bash
   ls draft/ 2>/dev/null
   ```

2. **Branch on result:**

   | Result | Action |
   |---|---|
   | Directory exists | Proceed to step 3. |
   | Directory missing AND skill requires context (`/draft:learn`, `/draft:deep-review`, `/draft:tech-debt`, `/draft:implement`) | **STOP** — print `No Draft context found. Run /draft:init first.` and exit. |
   | Directory missing AND skill is context-optional (`/draft:debug`, `/draft:quick-review`, `/draft:bughunt`, `/draft:deploy-checklist`, `/draft:documentation`, `/draft:testing-strategy`) | Proceed with reduced-context mode; record `draft_context: absent` in the report header. |

3. **Load context** by following [draft-context-loading.md](draft-context-loading.md). Honor the **selective guardrail matrix** in that file's Layer 0.5 — do not load all guardrails just because they are available.

## Usage in SKILL.md

Replace the existing 3–4 line `Verify Draft Context` block with a single reference:

```md
### Verify Draft Context

See [core/shared/context-verify.md](../../core/shared/context-verify.md). This skill is <required | optional> with respect to `draft/`.
```

This keeps each skill explicit about whether draft context is required, while centralizing the probe-and-branch logic.

## Why This Exists

Duplicating the same `ls draft/ 2>/dev/null` snippet across skills costs tokens per duplicate after frontmatter and surrounding prose. Factoring removes the duplication without changing semantics.
