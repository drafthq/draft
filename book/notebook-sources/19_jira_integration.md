# Chapter 19: Jira Integration

Part VI: Enterprise · Chapter 19

3 min read

Draft produces specs and plans. Jira tracks issues and assigns work. The gap between them is manual and error-prone. The unified `/draft:jira` router closes this gap with three subcommands: `preview`, `create`, and `review <ID>`.

**Default behavior:** One Story per track. All phases and tasks live inside the Story description as compact markdown sections + checklists. No Jira Tasks or Sub-tasks are created.

**Opt-in rich hierarchy:** Use `--epic` (on preview or create) for 1 Epic + 1–3 Stories when the track has many phases.

## Subcommands

| Subcommand              | Purpose |
|-------------------------|---------|
| `jira` or `jira preview [track]` | Generate editable `jira-export-<ts>.md` (default: 1 Story) |
| `jira preview --epic`   | Generate rich export: 1 Epic + 1–3 Stories |
| `jira create [track]`   | Push the latest export to Jira via MCP (creates Story/Bug issues) |
| `jira create --epic`    | Create Epic + Stories hierarchy |
| `jira review <JIRA-ID>` | Full qualification pipeline (deep-review + bughunt + coverage + test-gap) on any Jira ticket; produces qualification report + remediation plan |

## Preview

`/draft:jira preview` produces a timestamped export file + `jira-export-latest.md` symlink.

The export is deliberately minimal and focused:
- Root issue (Story or Epic) summary + description
- Phases rendered as compact sections with Goal, Verification, and task checklists
- Quality findings (from prior review/bughunt) surfaced as Bug issues
- Story points calculated from task count (simple table)

Never dump verbose plans or internal reasoning into Jira.

## Create

`/draft:jira create` reads the export (auto-runs preview if missing) and creates real issues via configured MCP-Jira tools. It updates the export file and `plan.md` with the resulting keys incrementally.

Bugs from bughunt/review reports are always created as separate Bug issues linked to the root.

## Review (Advanced Qualification)

`/draft:jira review ENG-1234` runs the full 7-phase pipeline on any Jira issue (Epic/Story/Bug/Sub-task):
1. Prerequisites & context loading
2. Epic/Story collection + linked issues
3. Document & test-plan synthesis
4. Code change collection (git history)
5. Context synthesis
6. Quality analysis (deep-review + bughunt + coverage)
7. Test-gap analysis + remediation plan

Produces `qualification-report.md` and (when gaps exist) `remediation-plan.md` with verdict: QUALIFIED / PARTIALLY QUALIFIED / NOT QUALIFIED.

This is the same deep engine used by `/draft:review` and `/draft:bughunt`, now available directly against live Jira work.

## Configuration

Project Jira settings live in `draft/workflow.md` under a `## Jira` section (Project Key required for create; other fields optional). The router prompts once and persists.

## Content Hygiene (Strict)

All text written to Jira (descriptions, summaries, bug details) must be minimal, concise, and precise. Use short summaries and compact structured sections only. Never pollute Jira with full plans or internal reasoning. This rule is enforced by the skill.

The creation order matters:

* Epic— Created first, capturing the epic key (e.g., PROJ-123)
* Stories— Created with epic link, one per phase
* Sub-tasks— Created under their parent story
* Bugs— Created as Bug issues linked to the epic, with severity mapped to Jira priority (Critical = Highest, High = High, Medium = Medium, Low = Low)
Each issue is persisted incrementally: after creating each issue, its Jira key is written back to the export file immediately. If the process fails mid-way (network error, API limit), re-running/draft:jira createskips already-created items and picks up where it left off.

## Configuration

The Jira project key is stored indraft/workflow.mdunder a## Jirasection:

If the key is missing on first run, Draft prompts for it and persists the value for all future invocations. The project key is validated against the Jira API before any issues are created — an invalid key fails fast with a clear error.

## Plan Synchronization

After issue creation,/draft:jira createupdatesplan.mdwith Jira keys inline:

This creates bidirectional traceability: the plan references Jira issues, and Jira issues contain the phase goals and verification criteria from the plan.

## Quality Reports in Jira

When/draft:reviewor/draft:bughunthas been run on the track, their findings are included in the Jira export. Review findings become an informational table in the epic description. Bug hunt findings become individual Bug issues with all evidence preserved: the code snippet, the data flow trace, the verification steps completed, the reasoning for why the finding is not a false positive, and the recommended fix with regression test.

This means the team working in Jira has the same quality intelligence that Draft produced — not a summary, but the full detail needed to act on each finding.

## Bidirectional Sync Considerations

Draft's Jira integration is currently one-directional: Draft pushes to Jira. If Jira issues are updated externally (status changes, reassignment, added comments), those changes are not pulled back into Draft'splan.md.

This is a deliberate design choice. Draft'splan.mdis the source of truth for implementation order and task status during active development. Jira is the source of truth for project management, assignment, and organizational tracking. The two systems serve different audiences and update at different cadences. The Jira keys inplan.mdprovide the link between them when cross-referencing is needed.

/draft:jira createrequires a configured MCP-Jira server. If MCP is not available, Draft provides the export file as a complete, structured document that can be manually imported or used with other Jira integration tools. The preview command (/draft:jira preview) works without MCP.

