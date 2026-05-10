---
name: deploy-checklist
description: "Pre-deployment verification checklist. Generates customized checklists based on tech-stack with rollback triggers. Use when the user asks to 'generate a deploy checklist', 'pre-deploy verification', 'rollback plan', or says 'we're shipping', 'about to deploy'."
---

# Deploy Checklist

Generate a pre-deployment verification checklist customized to this project's technology stack.

## Red Flags — STOP if you're:

- Deploying without a rollback plan
- Skipping database migration verification
- Deploying on Friday without explicit team approval
- Pushing to production without monitoring in place
- Ignoring failed checklist items marked as critical

**Every deployment needs a rollback plan. No exceptions.**

---

## Pre-Check

### 0. Capture Git Context

Before starting, capture the current git state:

```bash
git branch --show-current    # Current branch name
git rev-parse --short HEAD   # Current commit hash
```

Store this for the checklist header. The checklist is scoped to this specific branch/commit.

### 1. Verify Draft Context

```bash
ls draft/ 2>/dev/null
```

If `draft/` doesn't exist, this skill can still run standalone — generate a generic checklist.

### 2. Load Draft Context (if available)

Read and follow the base procedure in `core/shared/draft-context-loading.md`.

## Step 1: Parse Arguments

Check for arguments:
- `/draft:deploy-checklist` — Interactive: detect active track or ask for service name
- `/draft:deploy-checklist <service>` — Generate checklist for named service
- `/draft:deploy-checklist track <id>` — Generate from track's change scope

If a track is active: read `draft/tracks/<id>/spec.md` and `plan.md` for change scope.

## Step 2: Load Context

1. Read `draft/tech-stack.md` — Identify deployment-relevant tech:
   - Database type (migrations needed?)
   - Container orchestration (K8s, Docker Compose?)
   - CI/CD pipeline details
   - Feature flag system
   - Monitoring/alerting stack
2. Read `draft/workflow.md` — Deployment conventions and verification gates
3. Read `draft/.ai-context.md` — Service topology, dependencies

## Step 3: Generate Checklist

Generate a three-phase checklist customized to the project's tech stack. Adapt items based on what the project actually uses — omit irrelevant items (e.g., skip database items if there is no database) and add project-specific items discovered in context.

### Phase 1: Pre-Deploy

- [ ] **Tests:** All tests passing in CI
- [ ] **Review:** Code reviewed and approved
- [ ] **Migrations:** Database migrations tested on staging (if applicable)
- [ ] **Migration Rollback:** Down-migration verified (if applicable)
- [ ] **Feature Flags:** New features behind flags (if applicable)
- [ ] **Config:** Environment variables and secrets verified for target environment
- [ ] **Dependencies:** No known vulnerable dependencies (`npm audit` / `pip audit` / equivalent)
- [ ] **Monitoring:** Alerting rules configured for new endpoints/services
- [ ] **Rollback Plan:** Documented and tested (see Rollback Triggers below)
- [ ] **Communication:** Team notified of deployment window
- [ ] **Backup:** Database backup taken (if schema changes)
- [ ] **Changelog:** Release notes or changelog updated
- [ ] **API Compatibility:** Breaking changes documented and consumers notified

### Phase 2: Deploy

- [ ] **Method:** [Canary / Blue-Green / Rolling / Direct] — specify strategy
- [ ] **Sequence:** Deploy order for multi-service changes documented
- [ ] **Monitoring Dashboard:** [URL] open during deployment
- [ ] **Smoke Tests:** Ready to run post-deploy
- [ ] **Rollback Command:** `[specific rollback command]` ready to execute
- [ ] **Health Checks:** Endpoints responding before traffic shift
- [ ] **Traffic Shift:** Gradual rollout percentage plan (if canary/blue-green)
- [ ] **Deployment Log:** Recording start time and each step completion

### Phase 3: Post-Deploy

- [ ] **Smoke Tests:** All passing
- [ ] **Error Rate:** Below threshold ([X]% — from baseline)
- [ ] **Latency:** Below threshold ([X]ms — p95 from baseline)
- [ ] **Logs:** No unexpected errors in first 15 minutes
- [ ] **Feature Verification:** New features working as expected
- [ ] **Data Integrity:** No data corruption indicators
- [ ] **Dependency Health:** Downstream services unaffected
- [ ] **Cleanup:** Feature flags toggled, old code paths removed (if applicable)
- [ ] **Documentation:** Runbook updated if operational procedures changed
- [ ] **Notification:** Team notified of successful deployment

### Rollback Triggers

Initiate rollback if ANY of these occur:
- Error rate exceeds 2x baseline
- p95 latency exceeds 3x baseline
- Data corruption detected
- Critical user-facing functionality broken
- Deployment stuck in partial state for >10 minutes
- Health check failures on >10% of instances
- Memory or CPU exceeding safe thresholds on deployed instances

### Rollback Procedure

1. Execute rollback command (documented in Phase 2)
2. Verify previous version is serving traffic
3. Confirm error rates return to baseline
4. Investigate root cause before re-attempting deployment
5. Post-mortem if rollback was triggered by data corruption or user impact

## Step 4: Present and Track

Present the checklist interactively. For each critical item (marked **bold**):
- If unchecked and user wants to proceed: warn "Critical item unchecked: [item]. Are you sure? [y/N]"
- Default: stop and address critical items

Allow the user to:
- Check off items as they complete them
- Add custom items specific to this deployment
- Mark items as N/A with justification

## Step 5: Save Output

**MANDATORY: Include YAML frontmatter with git metadata.** Follow `core/shared/git-report-metadata.md`.

Include the report header table immediately after frontmatter:

```markdown
| Field | Value |
|-------|-------|
| **Branch** | `{LOCAL_BRANCH}` → `{REMOTE/BRANCH}` |
| **Commit** | `{SHORT_SHA}` — {COMMIT_MESSAGE} |
| **Generated** | {ISO_TIMESTAMP} |
| **Synced To** | `{FULL_SHA}` |
```

Save to:
- Track-scoped: `draft/tracks/<id>/deploy-checklist.md`
- Standalone: `draft/deploy-checklist-<timestamp>.md` with symlink `deploy-checklist-latest.md`

```bash
TIMESTAMP=$(date +%Y-%m-%dT%H%M)
# Example: draft/deploy-checklist-2026-03-15T1430.md
ln -sf deploy-checklist-${TIMESTAMP}.md draft/deploy-checklist-latest.md
```

## Cross-Skill Dispatch

- **Invoked manually before deployment.**
- **References:** `core/agents/ops.md` for production-safety mindset
- **Jira sync:** If ticket linked, attach checklist and post comment via `core/shared/jira-sync.md`
- **MCP:** GitHub MCP / `gh` CLI for PR details, Jira MCP for ticket context

## Error Handling

**If no tech-stack.md:** Generate generic checklist with all items, note: "Customize after running `/draft:init`"
**If no active track:** Generate standalone checklist, ask which service/release
**If no workflow.md:** Use sensible defaults, recommend documenting deployment conventions
