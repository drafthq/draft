---
shared: template-contract
applies_to: quality + init + graph skills
---

# Template Contract

Tracks under `draft/tracks/<id>/` must conform to the artifact set and section headers in `core/templates/`. Enforcement tools:

| Tool | Purpose |
|------|---------|
| `scripts/tools/diff-templates-vs-tracks.sh` | Missing files, section headers, removed 2.0 fields |
| `scripts/tools/check-track-hygiene.sh` | Status parity, author placeholders, TBD budget, plan staleness |
| `scripts/tools/check-scope-conflicts.sh` | Overlapping `scope_includes` without mutual exclusion |
| `scripts/tools/verify-citations.sh` | `path:line` citations vs `synced_to_commit` |
| `scripts/tools/verify-doc-anchors.sh` | Internal `§` / `#anchor` references |

See [verification-gates.md](verification-gates.md) for the canonical WS-9 gate chain and [template-hygiene.md](template-hygiene.md) for hygiene rules.

**Required track artifacts (2.0):** `spec.md`, `plan.md`, `hld.md`, `lld.md`, `metadata.json`, `discovery.md`.

**Scope fields:** `metadata.json:scope_includes` / `scope_excludes` (or spec frontmatter fallback) define track footprint; conflicts block parallel work without explicit exclusion.