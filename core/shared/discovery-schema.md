# Discovery Artifact Schema

> Schema for the `discovery.md` artifact produced by discovery flows (as part of
> new-track). The artifact captures the AI's pre-spec code-spike
> findings as a first-class output.

## Why this is first-class

Pre-2.0, code-spike findings were buried in "Conversation Log" sections of
`spec.md` or scattered across context-references rows. Reviewers could not
tell whether the AI had actually read the code or had inferred structure
from titles. `discovery.md` makes the spike output auditable, machine-
verifiable (via citation verifiers), and load-bearing for downstream specs.

## Required sections (each carries `<!-- REQUIRED -->`)

1. **Hotspots** — code locations the spec must address.
2. **Mode selection** — flags / feature gates / env switches governing the
   current code path.
3. **Open Questions** — load-bearing unknowns that must close before spec
   freeze.
4. **References** — flat list of files and functions touched in the spike.

## Hotspots table — required columns

| Column | Notes |
|---|---|
| Step | Short label for the operation observed |
| Location | `path/to/file.ext:LINE` (verifier-resolvable) |
| Behavior | What the spec must explain or improve (1 line) |

Minimum row count: 3 (configurable via `metadata.json:hygiene_budget.discovery_min_hotspots`).
If the spike genuinely found nothing, the row count may be 0 but the
**Open Questions** section must contain a `_NONE_FOUND_ — <one-line
justification>` line. The validator rejects an empty discovery without
that justification.

## Mode selection table — required columns

| Column | Notes |
|---|---|
| Switch | flag, gate, env var, or build option |
| Location | `path/to/file.ext:LINE` |
| Notes | what behavior the switch toggles |

## Open Questions

Each question begins with `Q<N>:` and is a single line. Each MUST close
into one of:

- a decision merged into `spec.md` (preferred),
- an explicit deferral with a follow-up track ID, or
- a `_NONE_FOUND_` annotation explaining why the question is moot.

A `discovery.md` whose Open Questions list is left dangling fails the
hygiene validator.

## References

A flat bullet list of files and functions:

- `path/to/file.ext` — `Function` / `Class::Method` — one-line role
- `path/to/other.ext` — `Function2` — …

Functions named here are exempt from citation drift unless they also
appear with line numbers elsewhere.

## Renaming / archiving

Discovery is created once per track at spec time. Subsequent
decompose runs DO NOT regenerate `discovery.md` — its job is to
capture the moment in time when the spec was written, anchored to
`metadata.json:synced_to_commit`. Re-running discovery is a deliberate
re-spike; the previous file should be renamed `discovery-<isodate>.md`
and the new one inherits the slot.
