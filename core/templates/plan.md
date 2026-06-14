---
type: Plan
project: "{PROJECT_NAME}"
module: "root"
track_id: "{TRACK_ID}"
generated_by: "draft:new-track"
generated_at: "{ISO_TIMESTAMP}"
# Stable frontmatter only (WS-8). Ephemeral fields live in metadata.json
# and render via <!-- META:<key> --> directives.
---

# Plan: {TITLE}

<!-- DECOMPOSE:REGENERATE START -->
<!-- Phase tables below are rewritten by draft:decompose. Manual notes outside
     these markers survive every regenerate. -->
<!-- DECOMPOSE:REGENERATE END -->

| Field | Value |
|-------|-------|
| **Branch** | <!-- META:git.branch --> → <!-- META:git.remote --> |
| **Commit** | <!-- META:git.commit_short --> — <!-- META:git.commit_message --> |
| **Generated** | {ISO_TIMESTAMP} |
| **Synced To** | <!-- META:synced_to_commit --> |

**Track ID:** {TRACK_ID}
**Spec:** ./spec.md
**Status:** <!-- META:status --> <!-- REQUIRED -->

## Scope <!-- OPTIONAL -->

- **Includes:** <!-- META:scope_includes -->
- **Excludes:** <!-- META:scope_excludes -->

---

## Overview

{One-paragraph summary of what this plan delivers, derived from spec.md}

---

<!-- DECOMPOSE:REGENERATE START -->

## Phase 0: Discovery (completed)

**Goal:** Spike — read current code, enumerate hotspots and open questions.
**Verification:** [`./discovery.md`](./discovery.md) exists, hotspots cited,
open questions resolved or deferred.

| Entry gate | Exit gate | Owner |
|---|---|---|
| `draft:new-track` initiated | `discovery.md` validator clean (`scripts/tools/verify-citations.sh`, hygiene) | _TBD_owner_phase_0_ |

---

## Phase 1: Foundation

**Goal:** {What this phase establishes}
**Verification:** {How to confirm phase is complete}

| Entry gate | Exit gate | Owner | <!-- REQUIRED -->
|---|---|---|
| _TBD_phase_1_entry_gate_command_ | _TBD_phase_1_exit_gate_command_ | _TBD_owner_phase_1_ |

### Tasks

- [ ] **Task 1.1:** {Description} — `{file_path}`
- [ ] **Task 1.2:** {Description} — `{file_path}`

---

## Phase 2: Core Implementation

**Goal:** {What this phase delivers}
**Verification:** {How to confirm phase is complete}

| Entry gate | Exit gate | Owner | <!-- REQUIRED -->
|---|---|---|
| _TBD_phase_2_entry_gate_command_ | _TBD_phase_2_exit_gate_command_ | _TBD_owner_phase_2_ |

### Tasks

- [ ] **Task 2.1:** {Description} — `{file_path}`
- [ ] **Task 2.2:** {Description} — `{file_path}`

---

## Phase 3: Integration & Polish

**Goal:** {What this phase delivers}
**Verification:** {How to confirm phase is complete — run full test suite, manual verification}

| Entry gate | Exit gate | Owner | <!-- REQUIRED -->
|---|---|---|
| _TBD_phase_3_entry_gate_command_ | _TBD_phase_3_exit_gate_command_ | _TBD_owner_phase_3_ |

### Tasks

- [ ] **Task 3.1:** {Description} — `{file_path}`
- [ ] **Task 3.2:** Verify — {Run tests, confirm all acceptance criteria met}

<!-- DECOMPOSE:REGENERATE END -->

---

## Pre-Deploy Validation <!-- REQUIRED -->

Before any phase advances past `[~]` in-progress to `[x]` complete, run the
validator chain via the canonical resolver pattern (see
[core/shared/verification-gates.md](../../core/shared/verification-gates.md)):

```bash
DRAFT_TOOLS="${DRAFT_PLUGIN_ROOT:-$HOME/.claude/plugins/draft}/scripts/tools"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$HOME/.cursor/plugins/local/draft/scripts/tools"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$PWD/scripts/tools"
"$DRAFT_TOOLS/check-track-hygiene.sh" .; "$DRAFT_TOOLS/verify-citations.sh" .
"$DRAFT_TOOLS/verify-doc-anchors.sh" .; "$DRAFT_TOOLS/check-graph-usage-report.sh" .
"$DRAFT_TOOLS/check-scope-conflicts.sh" ..;"$DRAFT_TOOLS/diff-templates-vs-tracks.sh" .
```

`metadata.json:pre_deploy_status` MUST be `passing` to deploy.

---

## Status Markers

- `[ ]` Pending
- `[~]` In Progress
- `[x]` Completed — append commit SHA: `(abc1234)`
- `[!]` Blocked — note reason
