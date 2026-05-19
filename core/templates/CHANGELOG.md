# Template Schema Changelog

Semver-style change log for the schema defined by files under `core/templates/`.
Tracks are generated from these templates by `skills/new-track`, `skills/decompose`,
and downstream skills. Any change here is a contract change consumed by every
downstream repo. Major bumps require a `scripts/tools/migrate-track-frontmatter.sh`
migration path.

## How template versions are referenced

- `metadata.json` carries the optional field `template_version` (semver string).
- Validators in `scripts/tools/` (hygiene, citations, anchors, scope-conflicts,
  graph-usage-report) read this field and refuse to lint tracks whose
  `template_version` major-bumps past the validator's known schema.

## Shared blocks each template depends on

| Template | Depends on (under `core/shared/`) |
|---|---|
| `spec.md` | `template-contract.md`, `template-hygiene.md`, `discovery-schema.md` (back-link), `verification-gates.md` |
| `hld.md` | `template-contract.md`, `template-hygiene.md`, `graph-query.md`, `verification-gates.md` |
| `lld.md` | `template-contract.md`, `template-hygiene.md`, `graph-query.md`, `verification-gates.md` |
| `plan.md` | `template-contract.md`, `template-hygiene.md`, `verification-gates.md` |
| `metadata.json` | `template-contract.md` (canonical schema for ephemeral fields) |
| `discovery.md` | `discovery-schema.md` |

Templates are markdown-only (and JSON for `metadata.json`). Viewer artifacts
(HTML/PDF) are rendered on demand by `scripts/tools/render-track.sh` and are
git-ignored at the track level. No HTML or PDF templates ship here.

## Versions

### 2.0.0 — Templates-as-contract baseline

- **Breaking:** Introduces parseable sentinel placeholders (`_TBD_<field>_`,
  `_PLACEHOLDER_<kind>_`). Silent placeholders such as `Author1`,
  `xxx@example.com`, pre-checked `Status: [x] Complete` are forbidden.
- **Breaking:** Introduces `<!-- REQUIRED -->` and `<!-- OPTIONAL -->` markers
  next to authorable fields. Hygiene validator gates `ready-for-review` on the
  required set being populated; optional fields may carry sentinels indefinitely.
- **New:** `core/templates/discovery.md` becomes a first-class artifact.
- **New:** `core/templates/CHANGELOG.md` (this file) and
  `core/shared/template-contract.md` (narrative + field index).
- **New:** Scope frontmatter — `scope_includes: []`, `scope_excludes: []`.
  Lives on `spec.md` and mirrored into `metadata.json`.
- **New:** Table columns required by WS-7 — `concurrency_model`,
  `aggregate_resource_cap`, `derived_from`, `mitigation_test_id`, `test_id`,
  `entry_gate_command`, `exit_gate_command`, `owner`, `flag_name`,
  `cluster_feature_gate`, `kill_switch_test_id`, `runbook_link`,
  `sunset_criteria`, `promote_to_adr`, `lock_acquired`, `reentrant`,
  `fault_injection_site`.
- **New:** `<!-- DECOMPOSE:REGENERATE START -->` / `<!-- ... END -->` markers
  in `plan.md` so `draft:decompose` can rewrite phase tables without clobbering
  manual notes outside the markers.
- **New:** `<!-- META:<key> -->` directives in `spec.md`, `hld.md`, `lld.md`,
  `plan.md` that pull ephemeral fields from `metadata.json` at render time.
- **Breaking:** Ephemeral fields stripped from per-file YAML frontmatter —
  `git.*`, `synced_to_commit`, `classification.*`, `status`. They live solely
  in `metadata.json` from this version forward.
- **Migration:** `scripts/tools/migrate-track-frontmatter.sh` rewrites pre-2.0
  tracks in place (idempotent; emits `.bak`).
- **Validators:** any commit touching `skills/**` or `scripts/tools/**` that
  affects artifact schema must also touch `core/templates/**`, or carry
  `[template-noop]` in the commit message.

### 1.x.y — pre-baseline (historical)

- See `git log -- core/templates/` for changes before 2.0.0. No formal version
  tagging; downstream consumers relied on `generated_by` and `generated_at`
  frontmatter only.
