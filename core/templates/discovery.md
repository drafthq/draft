---
type: Discovery
project: "{PROJECT_NAME}"
module: "root"
track_id: "{TRACK_ID}"
generated_by: "draft:discover"
generated_at: "{ISO_TIMESTAMP}"
links:
  spec: "./spec.md"
  plan: "./plan.md"
  hld: "./hld.md"
  lld: "./lld.md"
---

# {TRACK_TITLE} — Discovery

> Phase 0 (code spike). Captures the current-state code reading the AI
> performed before the spec was written, anchored to
> `metadata.json:synced_to_commit`. See
> [core/shared/discovery-schema.md](../../core/shared/discovery-schema.md)
> for the schema. Hygiene validator forbids empty hotspots without an
> adjacent `_NONE_FOUND_` justification.

**Status:** <!-- META:status --> <!-- REQUIRED -->

---

## Hotspots <!-- REQUIRED -->

Code locations the spec must address. Each row cites `path:line` that
verify-citations.sh resolves against the pinned commit.

| Step | Location | Behavior |
|------|----------|----------|
| _TBD_hotspot_1_step_ | _TBD_hotspot_1_location_ | _TBD_hotspot_1_behavior_ |
| _TBD_hotspot_2_step_ | _TBD_hotspot_2_location_ | _TBD_hotspot_2_behavior_ |
| _TBD_hotspot_3_step_ | _TBD_hotspot_3_location_ | _TBD_hotspot_3_behavior_ |

> If the spike found nothing: keep this table empty and add a
> `_NONE_FOUND_ — <justification>` line below before saving.

---

## Mode Selection <!-- REQUIRED -->

Flags, feature gates, environment switches that govern the current code
path. Receivers of the spec use this to scope rollout planning.

| Switch | Location | Notes |
|--------|----------|-------|
| _TBD_switch_1_name_ | _TBD_switch_1_location_ | _TBD_switch_1_notes_ |

---

## Open Questions <!-- REQUIRED -->

Load-bearing unknowns that must close before spec freeze. Each question
must resolve into a decision in `spec.md`, a deferral with a follow-up
track ID, or `_NONE_FOUND_` with justification.

- Q1: _TBD_question_1_
- Q2: _TBD_question_2_

---

## References <!-- REQUIRED -->

Flat list of files and functions touched in the spike. Files cited here
without line numbers are exempt from drift checks (they document
*familiarity*, not pinned facts).

- _TBD_reference_1_path_ — _TBD_reference_1_symbol_ — _TBD_reference_1_role_
- _TBD_reference_2_path_ — _TBD_reference_2_symbol_ — _TBD_reference_2_role_

---

## Conversation Log <!-- OPTIONAL -->

> Free-form notes captured during the spike. Reviewers can skim this for
> context the structured sections above don't carry. Not validator-checked.
