---
name: upload
description: Pre-upload gate for track handoff. Verifies review status, HLD approvals, deploy checklist, and validator chain before git upload or PR submission.
---

# Upload for Review

Gate track completion before `git upload`, `git push`, or opening a PR for human review.

## Red Flags — STOP if you're:

See [shared red flags](../../core/shared/red-flags.md).

Skill-specific:
- Uploading without a passing `/draft:review` on the track
- Skipping HLD §Approvals for `criticality ∈ {high, mission-critical}` tracks
- Treating a deploy checklist with `status: BLOCKED` as passing
- Pushing when validator tools report hygiene or citation drift

**Upload is a gate, not a shortcut around review.**

---

## Step 1: Resolve Track

1. Parse `track <id|name>` from arguments, or auto-detect the active `[~]` track from `draft/tracks.md`.
2. Load `draft/tracks/<id>/spec.md`, `plan.md`, `metadata.json`, and `hld.md` when present.
3. If no track resolves, error: "No track to upload. Specify `track <id>` or activate a track."

---

## Step 2: Pre-Upload Verification

### 2.1 Review gate

- Require `review-report-latest.md` on the track with verdict `PASS` or `PASS WITH NOTES`.
- If missing or `FAIL`, stop and instruct: run `/draft:review track <id>` first.

### 2.2 Deploy checklist (auto-invoke)

Run `/draft:deploy-checklist track <id>` when no fresh passing checklist exists.

### 2.5 Checklist status

- Read `draft/tracks/<id>/deploy-checklist-latest.md` (or timestamped sibling).
- If frontmatter contains `status: BLOCKED`, **stop** — checklist is not a passing gate.
- Critical unchecked items block upload.

### 2.3 Validator chain

Run the WS-9 chain from [verification-gates.md](../../core/shared/verification-gates.md) against the track directory. Any non-zero exit aborts upload.

```bash
TRACK_DIR="draft/tracks/<id>"
DRAFT_TOOLS="${DRAFT_PLUGIN_ROOT:-$HOME/.claude/plugins/draft}/scripts/tools"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$HOME/.cursor/plugins/local/draft/scripts/tools"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$PWD/scripts/tools"

"$DRAFT_TOOLS/check-track-hygiene.sh" "$TRACK_DIR"
"$DRAFT_TOOLS/verify-citations.sh" "$TRACK_DIR"
"$DRAFT_TOOLS/verify-doc-anchors.sh" "$TRACK_DIR"
"$DRAFT_TOOLS/diff-templates-vs-tracks.sh" "$TRACK_DIR"
```

---

## Step 3: HLD / LLD Approval Gate

### 3.1 HLD §Approvals (high-criticality)

When `spec.md` frontmatter `classification.criticality` is `high` or `mission-critical`:

- Every required row in `hld.md` §Approvals must have a populated **Date** column.
- If HLD was edited after the latest signed Date, stop — re-circulate for sign-off.
- For `low` / unset criticality, warn if approvers are placeholders but do not block.

### 3.2 LLD presence

When LLD was generated for the track, ensure Team Lead / QA approval rows are populated before upload (same Date rule as HLD).

---

## Step 4: Upload Execution

After all gates pass:

1. Confirm branch and commit range with the user.
2. Run the project's upload command (`git upload`, `git push`, or `gh pr create` per `draft/workflow.md`).
3. Capture the review URL or change ID.

Update `draft/tracks/<id>/metadata.json`:

```json
{
  "lastUploaded": "<ISO-8601>",
  "uploadCount": <N+1>
}
```

---

## Step 5: Post-Upload

- If Jira is linked, sync via [jira-sync.md](../../core/shared/jira-sync.md): comment "Code uploaded for review. {URL}".
- If new public APIs lack docs, suggest `/draft:documentation api`.

---

## Cross-Skill Dispatch

- **Auto-invokes:** `/draft:deploy-checklist`
- **Requires:** `/draft:review` PASS (or PASS WITH NOTES)
- **Suggested by:** `/draft:implement` (track completion), `/draft:documentation` (pre-upload API docs)

## Graph Usage Report

Emit the canonical footer from [graph-usage-report.md](../../core/shared/graph-usage-report.md) when graph queries were used during validation.