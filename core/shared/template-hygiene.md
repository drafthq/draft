<<<<<<< HEAD
---
shared: template-hygiene
applies_to: quality + init + graph skills
---

# template-hygiene (Foundations Stub)

Portable generalized stub per manifest §2.1. Full content will be expanded in later agent tranche or manual follow-up.

See verification-gates.md and template-hygiene.md for usage contracts.
=======
# Template Hygiene Rules

> Imported by every generator skill. Defines the hygiene contract enforced by
> `scripts/tools/check-track-hygiene.sh` and surfaced by `draft:deploy-checklist`.

## Forbidden patterns

These strings must never appear in a generated artifact:

| Pattern | Replace with |
|---|---|
| `Author1`, `Author2`, `Author3` | author from `git config user.name` |
| `xxx@example.com`, `xxx@example.com`, `xxx@example.org` | author email from `git config user.email` |
| `[name]` placeholder cell | `_TBD_<role>_` sentinel |
| Pre-checked `Status: [x] Complete` (when work is not done) | `Status: [ ] _TBD_status_` |
| Empty cell in an approval-bearing table | `_TBD_approver_<role>_` |

## Sentinel placeholders

- `_TBD_<field>_` — value missing, must be filled before `ready-for-review`.
- `_PLACEHOLDER_<kind>_` — illustrative example for authors; not blocking.
- `_NONE_FOUND_` — explicit "looked, nothing here"; requires adjacent justification.

## Required vs optional markers

Every authorable field in a template carries a marker the validator can read:

- `<!-- REQUIRED -->` — counts as blocking for `ready-for-review` if it
  contains a `_TBD_` sentinel.
- `<!-- OPTIONAL -->` — never blocking; may carry a sentinel indefinitely.

When neither marker is present, the validator defaults to OPTIONAL but logs
a warning. New fields should always carry an explicit marker.

## Status transitions

| Status (in `metadata.json`) | Allowed `_TBD_` count (per doc) |
|---|---|
| `draft` | unlimited |
| `ready-for-review` | ≤ 3 OPTIONAL, **0 REQUIRED** |
| `in_progress` | inherits from `ready-for-review` |
| `completed` | 0 of any |
| `archived` | not checked |

`metadata.json:status` is the single source of truth. Markdown `Status:` rows
must be rendered from it, never authored independently. The hygiene validator
fails on disagreement.

## Author resolution

The hygiene validator runs `git config user.name` and `git config user.email`
in the track's working tree. If either is unset, validation fails — the user
must configure git identity before generating tracks.

## Approver placeholders

Empty cells in any approval table render as `_TBD_approver_<role>_`. The role
slug is lower-snake-case from the column header (e.g. `Technical Leads` →
`tech_leads`). The validator forbids empty cells in any table whose first
header is `Role`.

## TBD budget gate

The validator counts every occurrence of `_TBD_` per document. The default
caps (configurable via `metadata.json:hygiene_budget`):

- `draft`: no cap
- `ready-for-review`: per-doc ≤ 3 OPTIONAL, **0 REQUIRED**

If the cap is exceeded, the validator emits one line per offending sentinel
with a file:line citation.
>>>>>>> a79c14023e16774c77463870ac3510b728e8a91c
