---
shared: red-flags
applies_to: all code-touching skills
---

# Shared Red Flags

Cross-skill red flags that any code-touching skill must enforce. Skills include their own skill-specific red flags **in addition to** the universal block below. The graph-first red flags are non-negotiable — they protect correctness against premature `grep`/`find` fallbacks that miss structural truth.

Referenced by: `/draft:decompose`, `/draft:implement`, `/draft:review`, `/draft:deep-review`, `/draft:quick-review`, `/draft:bughunt`, `/draft:debug`, `/draft:learn`, `/draft:tech-debt`, `/draft:deploy-checklist`, `/draft:new-track`.

## Universal Red Flags (STOP if any apply)

- **Ran `grep`/`find`/`rg` for symbol or file discovery before consulting the graph** (when `draft/graph/schema.yaml` exists).
- **Read more than 50 lines of source before querying hotspot rank** (`scripts/tools/hotspot-rank.sh --repo .`) to know whether the file is a hotspot.
- **Omitted the Graph Usage Report footer** from the final output (see [graph-query.md](graph-query.md) §Mandatory Lookup Contract).
- **Used a `grep` fallback without an explicit graph-miss statement** in the form: `Graph returned no match for <X>; falling back to grep.`
- **Loaded full Layer 0.5 guardrails when the command type does not require them** (see selective-loading matrix in [draft-context-loading.md](draft-context-loading.md) §Layer 0.5).
- **Marked a task complete without verification evidence** (test run, build output, lint output — pasted, not summarized).
- **Made up file paths or line numbers** instead of reading the file (`file_path:line_number` references must resolve).

## Ground-Truth Red Flags (STOP if any apply)

These enforce [graph-query.md](graph-query.md) §Ground-Truth Discipline. Graph identifies candidates; Read confirms them. Shipping unread claims is the dominant correctness failure mode observed in Draft output.

- **Wrote a `path:line` / `func()` / `symbol` reference into a deliverable without opening the file in this run.** Graph hit ≠ Read. (G1)
- **Declared something in-scope or out-of-scope without Reading at least one file in that path.** Module names from the live engine (`get_architecture`) are a candidate set, not proof that the candidate contains the named cost. (G2)
- **Shipped `Citation: TBD` / `Path: TBD` / `Symbol: TBD` on a row whose Status is `Modified` or `Existing`.** TBD is reserved for `Status: New` rows with a planned path filled in. (G3)
- **Claimed code behavior (writes / blocks / loops / fails / is the only path) from graph metadata alone.** Fan-in / fan-out / complexity scores are necessary signal, not sufficient evidence. (G4)
- **Promoted a spec / generated an HLD or LLD / closed a review without checking that the in-scope file set covers every cost term in the problem statement.** Silent scope narrowing that excludes the named cost is the highest-impact failure class. (G5)
- **Treated a graph query result as the terminal answer.** Graph is the index; the source files are the territory. Every claim that survives to a deliverable needs at least one Read behind it.

When in doubt, prefer "not yet validated against source" over an unbacked assertion. A flagged uncertainty is reviewable; a confident wrong claim is not.

## Graph-First Lookup Order (non-negotiable)

1. **Graph first** — wrapper scripts (`scripts/tools/graph-arch.sh`, `graph-callers.sh`, `graph-impact.sh`, `cycle-detect.sh`, `hotspot-rank.sh`) and direct engine queries (`search_graph`, `search_code`). The gate marker `draft/graph/schema.yaml` (present = engine available) is the only committed graph file.
2. **Generated context second** — `draft/.ai-context.md`, relevant `draft/architecture.md` slices, track-level `hld.md`/`lld.md`.
3. **Source file reads third** — only narrowed targets identified via graph or generated context.
4. **Filesystem `grep`/`find` last** — only after a graph miss, with the explicit fallback sentence above.

Using a lower tier before a higher tier is a **Red Flag** and must be reported in the skill's Graph Usage Report (justification required).

## How to Extend

Skill-specific red flags live in the skill's `SKILL.md` under `## Red Flags - STOP if you're:`. Skills should not duplicate the universal block above — instead they reference this file:

```markdown
## Red Flags - STOP if you're:

See [shared red flags](../../core/shared/red-flags.md) — applies to all code-touching skills.

Skill-specific:
- <skill-specific red flag>
- <skill-specific red flag>
```

This keeps boilerplate centralized while leaving room for skill-specific guardrails.
