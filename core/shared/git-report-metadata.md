# Git Report Metadata

Shared procedure for gathering git metadata and generating YAML frontmatter in Draft reports.

Referenced by: All skills that generate Draft reports — including `/draft:bughunt`, `/draft:deep-review`, `/draft:review`, `/draft:quick-review`, `/draft:tech-debt`, `/draft:deploy-checklist`, `/draft:incident-response`, `/draft:debug`, `/draft:standup`, `/draft:testing-strategy`

> **Two-tier metadata pattern:**
> - **Project-level artifacts** (`draft/architecture.md`, `.ai-context.md`, `.ai-profile.md`, `product.md`, `workflow.md`, etc.): git state lives in `draft/metadata.json` only. Per-file frontmatter carries only `project`, `module`, `generated_by`, `generated_at`. Skills read `synced_to_commit` from `draft/metadata.json`.
> - **Session/report artifacts** (`draft/bughunt-report-*.md`, `draft/review-*.md`, etc.): embed full git frontmatter using the template below — these are point-in-time snapshots, not refreshable docs.
> - **Track artifacts** (`tracks/<id>/spec.md`, `hld.md`, etc.): git state lives in `tracks/<id>/metadata.json`. Per-file frontmatter carries only stable fields.
>
> This doc covers session/report artifacts. For project-level artifacts see `core/templates/draft-metadata.json`.

## Preferred: Deterministic Script

Use `git-metadata.sh` from the plugin install, resolved via the canonical tool resolver (see [tool-resolver.md](tool-resolver.md)):

```bash
DRAFT_TOOLS="$(cat ~/.cache/draft/plugin-root 2>/dev/null)/scripts/tools"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$(ls -d ~/.claude/plugins/cache/*/draft/*/scripts/tools 2>/dev/null | sort -V | tail -1)"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$(ls -d ~/.claude/plugins/marketplaces/*draft*/scripts/tools 2>/dev/null | tail -1)"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$PWD/scripts/tools"
bash "$DRAFT_TOOLS/git-metadata.sh" --yaml \
    --project "$PROJECT" --module "$MODULE" \
    --track-id "$TRACK_ID" --generated-by "draft:bughunt"
```

The script emits the full YAML frontmatter block shown below, including `commits_ahead_base` / `commits_behind_base` vs. `--base main`. Use `--json` for a machine-readable object with the same fields. Exits nonzero outside a git work tree.

The manual commands below remain the specification and a fallback for environments where the script is not present.

## Git Metadata Commands

Gather git info before writing the report:

```bash
git branch --show-current # LOCAL_BRANCH
git rev-parse --abbrev-ref @{upstream} 2>/dev/null || echo "none" # REMOTE/BRANCH
git rev-parse HEAD # FULL_SHA
git rev-parse --short HEAD # SHORT_SHA
git log -1 --format=%ci HEAD # COMMIT_DATE
git log -1 --format=%s HEAD # COMMIT_MESSAGE
[ -n "$(git status --porcelain)" ] && echo "true" || echo "false" # dirty check
```

## YAML Frontmatter Template

Every Draft report MUST include this frontmatter block at the top of the file. Replace placeholders with values from the commands above.

```yaml
---
project: "{PROJECT_NAME}"
module: "{MODULE_NAME or 'root'}"
track_id: "{TRACK_ID or null}"
generated_by: "{COMMAND_NAME}"
generated_at: "{ISO_TIMESTAMP}"
git:
  branch: "{LOCAL_BRANCH}"
  remote: "{REMOTE/BRANCH}"
  commit: "{FULL_SHA}"
  commit_short: "{SHORT_SHA}"
  commit_date: "{COMMIT_DATE}"
  commit_message: "{COMMIT_MESSAGE}"
  dirty: {true|false}
synced_to_commit: "{FULL_SHA}"
---
```

### Field Notes

- `project` — Derive from the repository name or `draft/product.md` title
- `module` — Use `"root"` for project-level reports; use the module name/path for module-level reports
- `track_id` — Set to the track ID if scoped to a track; `null` otherwise
- `generated_by` — The Draft command that produced this report (e.g., `"draft:bughunt"`, `"draft:deep-review"`, `"draft:review"`)
- `synced_to_commit` — Use the full SHA of HEAD at report time; or read from `draft/metadata.json:synced_to_commit` if available

## Report Header Table

Include this summary table immediately after the frontmatter for human readability:

```markdown
| Field | Value |
|-------|-------|
| **Branch** | `{LOCAL_BRANCH}` → `{REMOTE/BRANCH}` |
| **Commit** | `{SHORT_SHA}` — {COMMIT_MESSAGE} |
| **Generated** | {ISO_TIMESTAMP} |
| **Synced To** | `{FULL_SHA}` |
```

## Timestamped File Naming

Reports use timestamped filenames with a `-latest.md` symlink:

```bash
# Generate timestamp
TIMESTAMP=$(date +%Y-%m-%dT%H%M)

# Write report to timestamped file
# Example: draft/bughunt-report-2026-03-15T1430.md

# Refresh the "-latest.md" symlink deterministically (resolver as above):
[ -x "$DRAFT_TOOLS/manage-symlinks.sh" ] && bash "$DRAFT_TOOLS/manage-symlinks.sh" draft/ bughunt
# (Fallback when the script is unavailable:)
# ln -sf <report-filename> <report-dir>/<report-type>-latest.md
```

Previous timestamped reports are preserved. The `-latest.md` symlink always points to the most recent report.
