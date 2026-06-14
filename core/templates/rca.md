---
type: RCA
project: "{PROJECT_NAME}"
track_id: "{TRACK_ID}"
jira_ticket: "{JIRA_KEY}"
generated_by: "draft:new-track"
generated_at: "{ISO_TIMESTAMP}"
---

# Root Cause Analysis: {TITLE}

| Field | Value |
|-------|-------|
| **Branch** | `{LOCAL_BRANCH}` → `{REMOTE/BRANCH}` |
| **Commit** | `{SHORT_SHA}` — {COMMIT_MESSAGE} |
| **Generated** | {ISO_TIMESTAMP} |
| **Synced To** | `{FULL_SHA}` |

## Summary

[1-2 sentence root cause statement with `file:line` references]

## Classification

- **Type:** [logic error | race condition | data corruption | config error | dependency issue | missing validation | state management | resource exhaustion]
- **Severity:** [SEV1 | SEV2 | SEV3 | SEV4]
- **Detection Lag:** [when introduced vs when detected]
- **SLO Impact:** [which SLOs affected, by how much]

## Evidence Gathered

| Source | URL/Path | Key Finding |
|--------|----------|-------------|
| Jira ticket | {JIRA_KEY} | [reproduction steps, reporter context] |
| Logs | [ssh path or URL] | [relevant log lines] |
| Dashboard | [URL] | [metric anomaly] |
| Code | [file:line] | [relevant code section] |

## Timeline

| When | What |
|------|------|
| [date] | Bug introduced (commit SHA if known) |
| [date] | Bug detected / reported |
| [date] | Investigation started |
| [date] | Root cause confirmed |
| [date] | Fix deployed |

## 5 Whys

1. Why did [symptom]? → Because [cause 1]
2. Why [cause 1]? → Because [cause 2]
3. Why [cause 2]? → Because [cause 3]
4. Why [cause 3]? → Because [cause 4]
5. Why [cause 4]? → Because [root cause]

## Blast Radius

- **Affected modules:** [from .ai-context.md service map]
- **Affected users/flows:** [from product.md user journeys]
- **Data impact:** [any data corruption or loss]
- **SLO budget consumed:** [percentage of error budget burned]

## Prevention Items

### Detection Improvement
- [ ] [monitoring/alerting improvement to catch this sooner]

### Process Improvement
- [ ] [review/testing improvement to prevent this class of bug]

### Code Improvement
- [ ] [guard/validation to add in code]

### Architecture Improvement
- [ ] [structural change if needed to make this class of bug impossible]

## Proposed Fix

[Brief description of the fix approach — developer reviews before implementation]

**Files to modify:**
- `file1:line` — [change description]
- `file2:line` — [change description]

**Regression test:**
- [Description of regression test to write — pending developer approval]
