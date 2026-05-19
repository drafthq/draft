<<<<<<< HEAD
---
shared: graph-usage-report
applies_to: quality + init + graph skills
---

# graph-usage-report (Foundations Stub)

Portable generalized stub per manifest §2.1. Full content will be expanded in later agent tranche or manual follow-up.

See verification-gates.md and template-hygiene.md for usage contracts.
=======
# Graph Usage Report Footer

Every code-touching skill that consults `draft/graph/` MUST emit this footer
as the closing section of its output. The lint hook
`scripts/tools/check-graph-usage-report.sh` validates the footer's presence
and column shape on save.

The footer documents what the skill **looked at** in the graph before
acting — making after-the-fact review of graph-vs-grep discipline possible.

## Canonical footer (markdown to emit)

```md
## Graph Usage Report

- Graph files queried: <list, or `NONE` with justification>
- Modules identified via graph: <list>
- Files identified via graph: <count>
- Filesystem grep fallbacks: <list with justification, or `none`>
- Justification (only when Graph files queried = NONE): <required>
```

## Where each skill appends

Skills append the footer to their primary output artifact. Convention:

- `/draft:new-track` — completion announcement
- `/draft:decompose` — terminal output
- `/draft:implement` — session summary
- `/draft:review`, `quick-review`, `deep-review` — review report (before Verdict)
- `/draft:bughunt` — bug report
- `/draft:debug` — debug report
- `/draft:learn` — completion summary
- `/draft:tech-debt` — debt report
- `/draft:deploy-checklist` — checklist
- `/draft:discover` — discovery.md trailer

When the skill's output is a long-form artifact, the footer goes at the
bottom of the artifact (after the Verdict line is rendered for reviews;
before the closing for sessions). When the skill's output is the terminal
announcement only, the footer goes at the end of the announcement.

## Rule on `NONE`

If `draft/graph/schema.yaml` does not exist OR the skill genuinely consulted
no graph files, set `Graph files queried: NONE` and provide a one-line
justification (e.g. "graph data unavailable", "non-code-touching command").
The lint hook fails when `NONE` appears without an adjacent justification.

## See also

- [graph-query.md](graph-query.md) — §Mandatory Lookup Contract
- [red-flags.md](red-flags.md) — universal red flags including the GUR-omission rule
>>>>>>> a79c14023e16774c77463870ac3510b728e8a91c
