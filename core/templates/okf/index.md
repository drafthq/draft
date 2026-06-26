---
okf_version: "0.1"
---

<!-- OKF §6/§11: an index file carries NO concept frontmatter; the root index.md
     may declare ONLY `okf_version`. The frozen concept-`type` vocabulary version
     is tracked here in the body (not in frontmatter) so bumping it stays visible
     without violating the index-frontmatter rule.
     okf-types-version: 0.1 -->

# {PROJECT_NAME} — Wiki

> Project wiki. One concept per file; cross-links form the graph. The
> live call graph (`codebase-memory-mcp`) is the grounding source; this wiki
> is the navigable serialization. `../ai-context.md` is the consumption entry point.

## Sections

| Section | Holds | Index |
|---------|-------|-------|
| `overview/` | System map, getting-started, glossary | [overview/index.md](overview/index.md) |
| `systems/` | Subsystems & modules (graph clusters) | [systems/index.md](systems/index.md) |
| `features/` | User-facing capabilities spanning modules | [features/index.md](features/index.md) |
| `reference/` | APIs, data models, dependencies, ADRs, runbooks | [reference/index.md](reference/index.md) |
| `entrypoints/` | Binaries / mains / CLIs / handler roots | see pages below |

## Concept Map

<!-- Built from each concept's frontmatter `description` (the routing key).
     One line per concept. Regenerated on every init/refresh. -->
<!-- CONCEPT-MAP:START -->
<!-- CONCEPT-MAP:END -->

## Change log

See [log.md](log.md) for chronological regeneration history.
