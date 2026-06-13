---
shared: graph-usage-report
applies_to: quality + init + graph skills
---

# Graph Usage Report (Canonical Footer)

Every code-touching skill output that performs graph or filesystem discovery MUST end with this footer block. The lint hook `scripts/tools/check-graph-usage-report.sh` validates the section on save.

See [graph-query.md](graph-query.md) §Graph Usage Report (Mandatory Footer) for the full lookup contract. Emit this block verbatim:

```md
## Graph Usage Report

- Graph files queried: <comma-separated list, e.g. `architecture.json, hotspots.jsonl` and/or query tools like `graph-callers.sh` — or `NONE` with justification below>
- Modules identified via graph: <comma-separated module names, or `none`>
- Files identified via graph: <integer count>
- Filesystem grep fallbacks: <list of `<pattern>` searches with one-line justification each, or `none`>
- Justification (only when `Graph files queried: NONE`): <required — `graph data unavailable` | `non-code task` | `<explicit reason>`>
```

**Gate:** `Graph files queried: NONE` without a populated justification line is a hard failure.