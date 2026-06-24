---
project: "{PROJECT_NAME}"
module: "{MODULE_NAME or 'root'}"
generated_by: "draft:init"
generated_at: "{ISO_TIMESTAMP}"
draft_init_mode: okf
---

# {PROJECT_NAME} — AI Context Index

> Index root for the project wiki (`wiki/`). Read **Synopsis** for broad
> tasks (they usually terminate here). For focused tasks, route through the
> **Concept Map** to ≤N concept pages — each lists `x-grounded-paths`. This is
> both the cheap broad-context path AND the progressive-disclosure entry point.

## Synopsis

<!-- 150–250 lines: the cheap broad-context path (prior .ai-context.md value
     preserved). Architecture in brief, key invariants, where to start, top
     hotspots. A broad task should be answerable from this section alone. -->

- **Architecture in brief:** {2–4 sentences}
- **Key invariants:** {bullet list, provenance-tagged}
- **Where to start:** {entrypoints + core subsystems}
- **Top hotspots:** {from hotspot-rank.sh — symbol, fan-in}

## Concept Map

<!-- Routing table built from each concept's frontmatter `description`.
     Open a section index for the full per-concept list. -->

| Section | Routing |
|---------|---------|
| `wiki/systems/` | {one-line per subsystem — what it owns, when to open} |
| `wiki/features/` | {one-line per feature} |
| `wiki/reference/` | config, schemas, APIs, ADRs, runbooks |
| `wiki/entrypoints/` | binaries / CLIs / handler roots |

Full taxonomy: [wiki/index.md](wiki/index.md).

## How to navigate

1. **Broad task** (summarize, "what owns X", topology) → answer from **Synopsis**.
2. **Focused task** ("what breaks if I change Y", "add a field to Z") → open the
   matching concept via the **Concept Map**; follow its `x-grounded-paths` and
   `Used by` cross-links. Do not read the whole bundle.
3. Every concept page is verified against the live call graph; trust its
   `Blast radius` section over re-deriving by hand.
