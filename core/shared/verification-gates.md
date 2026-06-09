# Verification Gates

> Shared block defining the validator chain every track passes through
> before promoting status. Imported by quality and implementation flows
> that gate on artifact correctness.

## The chain

Run in this order. Single non-zero exit aborts the chain.

| Step | Tool | What it checks |
|------|------|----------------|
| 1 | `scripts/tools/check-track-hygiene.sh` | status parity, author resolution, approver placeholders, TBD budget vs `metadata.json:status`, plan staleness vs HLD/LLD |
| 2 | `scripts/tools/verify-citations.sh` | every `path:line` resolves against `metadata.json:synced_to_commit` (±tolerance) |
| 3 | `scripts/tools/verify-doc-anchors.sh` | `§X.Y` references and `<doc>.md#anchor` links resolve |
| 4 | `scripts/tools/check-graph-usage-report.sh` | Graph Usage Report footer present and well-formed |
| 5 | `scripts/tools/check-scope-conflicts.sh` | no overlap with adjacent tracks under same scope tags |
| 6 | `scripts/tools/diff-templates-vs-tracks.sh` | no drift between track and current template schema |

## Output convention

Each tool emits:

- exit code 0/1 (clean / violations)
- text mode by default; `--json` for machine-readable
- one line per violation: `[<kind>] <track>/<file>:<line> — <detail>`

## Result persistence

After the chain runs, persist the outcome to `metadata.json:pre_deploy_status`:

- `unrun` — chain has never executed against this track
- `passing` — last run exited 0
- `failing` — last run exited 1; details in CI log
- `bypassed` — explicit override; requires `bypass_reason` in metadata

`/draft:deploy-checklist` reads this field and refuses to deploy a track
whose `pre_deploy_status != passing`.

## When to invoke

- `/draft:deploy-checklist` — mandatory before any production deploy.
- `/draft:implement` — at the end of each phase before flipping
  `phases.completed`.
- `/draft:decompose` — after rewriting `plan.md`, to catch plan-staleness
  immediately.
- CI hook — gate every merge that touches `tracks/**`.
