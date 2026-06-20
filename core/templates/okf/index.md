---
type: Subsystem
title: "{PROJECT_NAME} — Knowledge Bundle"
description: >
  Root index of the OKF taxonomy bundle. Start here, then route into
  overview/, systems/, features/, reference/, or entrypoints/ via the
  Concept Map. Open a concept only when its description matches the task.
resource: .
tags: [index]
timestamp: "{ISO_TIMESTAMP}"
okf_version: "0.1"
okf_types_version: "0.1"
---

# {PROJECT_NAME} — Knowledge Bundle

> OKF v0.1 bundle. One concept per file; cross-links form the graph. The
> live call graph (`codebase-memory-mcp`) is the grounding source; this bundle
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
