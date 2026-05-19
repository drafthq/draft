<<<<<<< HEAD
---
shared: template-contract
applies_to: quality + init + graph skills
---

# template-contract (Foundations Stub)

Portable generalized stub per manifest §2.1. Full content will be expanded in later agent tranche or manual follow-up.

See verification-gates.md and template-hygiene.md for usage contracts.
=======
# Template Contract

> Narrative + field index for `core/templates/*`. Every generator skill imports
> this block so the schema lives in one place. Source of truth: this file and
> `core/templates/CHANGELOG.md`.

## Contract summary

1. **Templates are the schema.** Skills, validators, and renderers consume
   `core/templates/*` as the canonical shape of every artifact. Schema changes
   that land only in skill prompts or validators (without touching templates)
   are forbidden.

2. **Placeholders are parseable.** Every authorable field uses one of:
   - `_TBD_<field>_` — value missing, must be filled before status promotion.
   - `_PLACEHOLDER_<kind>_` — illustrative example for authors (e.g.
     `_PLACEHOLDER_module_name_`); not blocking.
   - `_NONE_FOUND_` — explicit "I looked and there's nothing here" (e.g. used
     in `discovery.md` open-questions when truly empty); requires a one-line
     justification adjacent to it.

   Silent placeholders such as `Author1`, `xxx@example.com`, `xxx@example.com`,
   `[name]`, pre-checked `Status: [x] Complete`, or empty cells in approval
   tables are **forbidden**. Hygiene validator (WS-1) fails on any match.

3. **Required vs optional is explicit.**
   - `<!-- REQUIRED -->` next to a field, header, or table column: the
     hygiene validator counts this as blocking for `ready-for-review`.
   - `<!-- OPTIONAL -->` next to a field: never blocking; may carry sentinels.
   - Fields with neither marker default to optional but may be tightened
     later — prefer explicit markers.

4. **Two-tier metadata pattern — git state never in per-file frontmatter.**

   **Project level** (`draft/metadata.json`):
   - Single file that owns `git.*`, `synced_to_commit`, and `schema_version`
     for all 15 project-level artifacts (`architecture.md`, `.ai-context.md`,
     `.ai-profile.md`, `product.md`, `workflow.md`, etc.).
   - Written once by `draft:init` / `draft:init refresh` / `draft:index`.
   - All skills that need the project sync anchor read it here — never from
     per-file frontmatter.
   - Template: `core/templates/draft-metadata.json`.

   **Track level** (`tracks/<id>/metadata.json`):
   - Per-track file that owns `git.*`, `synced_to_commit`, `classification.*`,
     `status`, `scope_includes`, `scope_excludes`, `template_version`, and
     track progress fields.
   - Markdown track docs reference ephemeral fields via `<!-- META:<key> -->`
     directives, resolved by `scripts/tools/render-track.sh` at view time.
   - This makes re-sync a single-file edit and prevents drift across
     `spec.md` / `hld.md` / `lld.md` / `plan.md`.
   - Template: `core/templates/metadata.json`.

5. **Stable frontmatter only.** Per-file YAML frontmatter carries `project`,
   `module`, `track_id`, `generated_by`, `generated_at`, `links`, and nothing
   else. Never emit `git.*` or `synced_to_commit` into per-file frontmatter.

6. **Phase regeneration is bracketed.** `plan.md` wraps phase tables in
   `<!-- DECOMPOSE:REGENERATE START -->` / `<!-- DECOMPOSE:REGENERATE END -->`.
   `draft:decompose` rewrites only between markers. Manual notes outside the
   markers survive every regenerate.

7. **Example citations in templates are lint-clean by construction.** Any
   illustrative `path:line` or `§X.Y` snippet shown in a template is wrapped
   in `<!-- VERIFIER:IGNORE START -->` / `<!-- VERIFIER:IGNORE END -->`.
   `scripts/tools/verify-citations.sh` and `verify-doc-anchors.sh` skip these
   regions.

## Field index (canonical names)

These names appear identically across every template and validator.

### Frontmatter (markdown, stable)

| Field | Type | Required | Notes |
|---|---|---|---|
| `project` | string | yes | Project / repo name |
| `module` | string | yes | Module slug or `root` |
| `track_id` | string | yes | Kebab-case track identifier |
| `generated_by` | string | yes | Skill that last wrote the file (`draft:new-track`, `draft:decompose`, …) |
| `generated_at` | ISO-8601 | yes | Timestamp of the last regenerate |
| `links` | map | yes (hld/lld) | Cross-doc relative paths |

### `metadata.json` (canonical, ephemeral)

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | string | yes | Same as `track_id` |
| `title` | string | yes | Human-readable |
| `type` | enum | yes | `feature` / `bugfix` / `refactor` |
| `status` | enum | yes | `draft` / `ready-for-review` / `in_progress` / `completed` / `archived` |
| `template_version` | semver | yes (2.0+) | Schema version this track conforms to |
| `git.branch` | string | yes | Source branch |
| `git.remote` | string | optional | Upstream tracking |
| `git.commit` | string | yes | Full SHA |
| `git.commit_short` | string | optional | Render convenience |
| `git.commit_date` | ISO-8601 | optional | |
| `git.commit_message` | string | optional | |
| `git.dirty` | bool | yes | Working tree dirty at sync |
| `synced_to_commit` | string | yes | Anchors citation verifiers |
| `classification.criticality` | enum | yes | `low` / `standard` / `high` / `mission-critical` |
| `classification.data_classification` | enum | yes | `public` / `internal` / `confidential` / `regulated` |
| `classification.deployment_surface` | enum | yes | `on-prem` / `SaaS` / `hybrid-cloud` / `IBM-cloud` / `mixed` |
| `scope_includes` | array<string> | yes | Canonical problem-area tags |
| `scope_excludes` | array<string> | optional | Tags explicitly out of scope |
| `pre_deploy_status` | enum | optional | `unrun` / `passing` / `failing` / `bypassed` — written by deploy-checklist |
| `phases.total`, `phases.completed` | int | yes | |
| `tasks.total`, `tasks.completed` | int | yes | |
| `impact.*` | various | optional | Written by `draft:implement` |

### `draft/metadata.json` (project-level, ephemeral)

| Field | Type | Required | Notes |
|---|---|---|---|
| `project` | string | yes | Repo / product name |
| `schema_version` | semver | yes | `draft-metadata.json` schema version |
| `generated_by` | string | yes | Skill that last wrote this file |
| `generated_at` | ISO-8601 | yes | Timestamp of last write |
| `git.branch` | string | yes | Branch at last sync |
| `git.remote` | string | optional | Upstream tracking ref |
| `git.commit` | string | yes | Full SHA at last sync |
| `git.commit_short` | string | optional | Render convenience |
| `git.commit_date` | ISO-8601 | optional | |
| `git.commit_message` | string | optional | |
| `git.dirty` | bool | yes | Working tree dirty at sync |
| `git.base_branch` | string | optional | Default: `main` |
| `git.commits_ahead_base` | int | optional | |
| `git.commits_behind_base` | int | optional | |
| `synced_to_commit` | string | yes | Anchor for all project-level citation verifiers and staleness checks |

**Backward compatibility:** If `draft/metadata.json` is absent (pre-migration installs), fall back to reading `synced_to_commit` from `draft/architecture.md` YAML frontmatter. Write `draft/metadata.json` on the next `init` or `init refresh` to complete migration.

### Per-table required columns (WS-7)

**HLD component table:** `concurrency_model`, `aggregate_resource_cap`,
`parallel_flag_interaction`.
**HLD alternatives table:** `promote_to_adr` (boolean).
**HLD flags/rollout:** `flag_name`, `cluster_feature_gate`, `kill_switch_test_id`,
`runbook_link`.
**LLD class table:** adds `lock_acquired`, `reentrant`.
**LLD error table:** adds `fault_injection_site`.
**LLD eligibility/cap table:** `derived_from`.
**Spec eligibility table:** `derived_from`.
**Spec risk table:** `mitigation_test_id`.
**Spec acceptance criteria:** `test_id`.
**Plan phase rows:** `entry_gate_command`, `exit_gate_command`, `owner`.

## When to extend the contract

- Adding a field: edit the relevant template, add an entry above, bump
  `template_version` MINOR, append to `core/templates/CHANGELOG.md`.
- Removing a field: bump MAJOR, ship a migration in
  `scripts/tools/migrate-track-frontmatter.sh`, document in CHANGELOG.
- Renaming a field: treat as remove+add; never silently rename.
>>>>>>> a79c14023e16774c77463870ac3510b728e8a91c
