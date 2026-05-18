---
name: discover
description: Draft Phase 0 — produce a discovery.md code-spike report before spec freeze. Run by draft:new-track as the first step on any new track. Reads current code, enumerates hotspots, names mode-selection flags, surfaces load-bearing open questions, and records references. Output is a first-class artifact verifiable by the citation verifier against metadata.json:synced_to_commit.
---

# /draft:discover — Phase 0 Code Spike

> Mandatory first step for any new Draft track. Builds the `discovery.md`
> artifact that subsequent `spec.md` / `hld.md` / `lld.md` cite as their
> grounding source. Without it, downstream artifacts are not eligible for
> `ready-for-review` promotion.

## Contract

- Schema: [core/shared/discovery-schema.md](../../core/shared/discovery-schema.md)
- Template: [core/templates/discovery.md](../../core/templates/discovery.md)
- Hygiene rules: [core/shared/template-hygiene.md](../../core/shared/template-hygiene.md)
- Citation verifier: `scripts/tools/verify-citations.sh tracks/<track-id>` (exit 0 = clean, 1 = drift detected; add `--tolerance N` to widen the line-window match)

## Inputs

1. The track ID (from `metadata.json:id`).
2. The pinned commit (`metadata.json:synced_to_commit` — set by
   `draft:new-track` Step 0a).
3. The problem statement the user provided.

## When `draft/graph/schema.yaml` exists

Follow the graph-first lookup contract in
[core/shared/graph-query.md](../../core/shared/graph-query.md)
§Mandatory Lookup Contract. The discovery hotspots **must** start from the
graph; filesystem `grep` is permitted only after a documented graph miss.

## Procedure

1. **Read the problem statement.** Extract candidate nouns (component
   names, file extensions, flag names, behaviors).
2. **Query the graph** with each candidate. Capture modules and entry
   symbols. If the graph has no schema, fall back to `grep` and document
   the miss per `graph-query.md` rules.
3. **Read 3–10 files** at the entry points found. Quote the exact
   `path:line-range` you read.
4. **Fill the Hotspots table** with at least N rows (default 3; configurable
   via `metadata.json:hygiene_budget.discovery_min_hotspots`).
5. **Fill the Mode selection table** with every flag, env var, build
   option, or cluster-feature gate the reading surfaced.
6. **Write Open Questions**: each is a load-bearing unknown. Examples:
   "Does dependency X expose a public API for behavior Y?", "Is constraint
   Z still active given upstream change W?". Surface, do not hide.
7. **Write References**: flat list of files and named functions.
8. **Save** `discovery.md` under the track directory; emit the `generated_at`
   timestamp; do NOT touch `metadata.json:status` (still `draft`).

## Output gate

The skill output is rejected if any of:

- `discovery.md` has zero Hotspot rows AND no `_NONE_FOUND_` justification.
- Any `path:line` citation in Hotspots fails `verify-citations.sh`.
- Open Questions list is empty AND no `_NONE_FOUND_ — <reason>` line.
- Any forbidden sentinel from `template-hygiene.md` appears in the output.

## Re-spiking

If a later phase reveals the original spike missed material facts:

1. Rename the existing file to `discovery-<isodate>.md`.
2. Run `draft:discover` again to produce a fresh `discovery.md`.
3. Bump `metadata.json:synced_to_commit` if the re-spike was driven by an
   upstream change.

## Red Flags — STOP if you're:

See [shared red flags](../../core/shared/red-flags.md).

Skill-specific:

- Writing hotspot rows without `path:line` citations.
- Inventing function names not present in the code at `synced_to_commit`.
- Filling the Open Questions section with non-blocking commentary instead
  of load-bearing unknowns.
- Re-running discovery silently on top of an existing `discovery.md`
  without archiving the previous file.

## Graph Usage Report

End every invocation with the standard footer from
[core/shared/graph-query.md](../../core/shared/graph-query.md)
§Graph Usage Report:

```
## Graph Usage Report
- Graph files queried: <list>
- Modules / files identified via graph: <list>
- Grep fallbacks: <count, with justification per item>
- Justification when NONE: <if graph was not consulted>
```
