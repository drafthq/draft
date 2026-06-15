---
name: deploy-checklist
description: Pre-deployment verification checklist. Generates customized checklists based on tech-stack with rollback triggers. Auto-invoked by /draft:upload.
---

# Deploy Checklist

You are generating a pre-deployment verification checklist customized to this project's technology stack.

## MANDATORY GRAPH LOOKUP (read before Phase 1)

When `draft/graph/schema.yaml` exists, this skill **must** follow the graph-first lookup contract in [core/shared/graph-query.md](../../core/shared/graph-query.md) §Mandatory Lookup Contract. Use the graph to validate module boundaries before the deploy:

1. For each file in the deploy diff, run `scripts/tools/graph-impact.sh --repo . --file <path>` to enumerate the modules affected — flag any module **not** declared in `hld.md` §Detailed Design as a deployment-scope miss.
2. Run `scripts/tools/cycle-detect.sh --repo .` (and query `scripts/tools/graph-arch.sh --repo .` for the module overview) to ensure no fresh cycles were introduced after HLD sign-off.
3. Run `scripts/tools/hotspot-rank.sh --repo .` — any hotspot in the diff escalates the Resiliency row of Phase 0.

Filesystem `grep` is reserved for source-text scans (migration file names, flag-key strings). Module/impact discovery goes through the graph.

## Red Flags — STOP if you're:

See [shared red flags](../../core/shared/red-flags.md) — applies to all code-touching skills.

Skill-specific:
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
git branch --show-current # Current branch name
git rev-parse --short HEAD # Current commit hash
```

Store this for the checklist header. The checklist is scoped to this specific branch/commit.

### 1. Verify Draft Context

```bash
ls draft/ 2>/dev/null
```

If `draft/` doesn't exist, this skill can still run standalone — generate a generic checklist.

### 2. Load Draft Context (if available)

Read and follow the base procedure in `core/shared/draft-context-loading.md`.

### 3. Run validator gate chain (WS-9)

Canonical chain documented in
[core/shared/verification-gates.md](../../core/shared/verification-gates.md).
A single non-zero exit aborts the checklist and the output groups defects
by validator.

```bash
TRACK_DIR="$1" # absolute path to track-under-deploy, or .

DRAFT_TOOLS="${DRAFT_PLUGIN_ROOT:-$HOME/.claude/plugins/draft}/scripts/tools"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$HOME/.cursor/plugins/local/draft/scripts/tools"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$PWD/scripts/tools"

"$DRAFT_TOOLS/check-track-hygiene.sh" "$TRACK_DIR" || rc=$?
"$DRAFT_TOOLS/verify-citations.sh" "$TRACK_DIR" || rc=$?
"$DRAFT_TOOLS/verify-doc-anchors.sh" "$TRACK_DIR" || rc=$?
"$DRAFT_TOOLS/check-graph-usage-report.sh" "$TRACK_DIR" || rc=$?
"$DRAFT_TOOLS/check-scope-conflicts.sh" "$TRACK_DIR/.." || rc=$?
"$DRAFT_TOOLS/diff-templates-vs-tracks.sh" "$TRACK_DIR" || rc=$?
```

After the chain runs, write the result into `metadata.json:pre_deploy_status`
(`passing` / `failing` / `bypassed`). The downstream checklist sections must
not be considered "ready to deploy" if `pre_deploy_status != passing`.

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
2. Read `draft/workflow.md` — Deployment conventions, toolchain (git)
3. Read `draft/.ai-context.md` — Service topology, dependencies
4. **If track-scoped:** Read `draft/tracks/<id>/hld.md` and `lld.md` if present — these are the source of truth for HLD §Checklist (Performance, Scale, Security, Resiliency, Multi-tenancy, Upgrade, Cost, Flags), §Deployment, §Observability, and LLD §Alerting Thresholds. The deploy checklist validates they are populated.

## Step 3: Generate Checklist

Generate a four-phase checklist customized to the project's tech stack. Adapt items based on what the project actually uses — omit irrelevant items (e.g., skip database items if there is no database) and add project-specific items discovered in context.

### Phase 0: HLD/LLD Gate (track-scoped only, when hld.md exists)

> ** blocker:** the HLD's §Checklist sections were the design-time commitment. If they are still empty at deploy time, the design was never validated against operational reality. This phase enforces that.

For `criticality ∈ {high, mission-critical}` (read from `hld.md` frontmatter `classification.criticality`), every row below MUST be checked before Phase 1 begins. For `standard` criticality, missing rows produce warnings but do not block. For `low`, this phase is informational.

- [ ] **HLD §Performance** populated — QPS and p95 latency stated
- [ ] **HLD §Scale** populated — horizontal scaling story documented; bottlenecks named
- [ ] **HLD §Security** populated — credentials, RBAC, encryption answered
- [ ] **HLD §Resiliency** populated — failure modes and graceful degradation described
- [ ] **HLD §Multi-tenancy** populated — isolation, predictable performance, migration covered
- [ ] **HLD §Upgrade** populated — backward compat, dependent service order, blast radius
- [ ] **HLD §Flags and Controlled Rollout** populated — flag names, kill switches
- [ ] **HLD §Cost Implications** populated — Cloud cost calculation included for SaaS deployments

- [ ] **HLD §Deployment** populated — DP/CP platform call answered (on-prem / SaaS / Cloud Console / IBM cloud)
- [ ] **HLD §Observability** populated — key metrics named with thresholds
- [ ] **HLD §Approvals table** signed by Technical Leads and Architecture Review Board (and Cloud Operations if SaaS, QA if on-prem) — Date column populated
- [ ] **LLD §Alerting Thresholds** table populated (when `lld.md` exists) — every metric has Threshold, Severity, Action

If any blocker row is empty for high/mission-critical: STOP. Do not generate Phases 1–3, **do not run Step 5 (Save Output)**, and do not create the `deploy-checklist.md` file. Tell the developer: "HLD/LLD §[section] is empty for a [criticality] track. Fill it in `hld.md` / `lld.md` before deploy. Run `/draft:decompose` to refresh structural sections; author-driven sections must be filled manually."

If a partial file is needed for tracking, write it with `status: BLOCKED` in the frontmatter and `_latest` symlinks must NOT be updated — `/draft:upload` Step 2.5 detects `status: BLOCKED` and refuses to treat the file as a passing checklist.

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

## Mandatory Self-Check (before saving the checklist)

Before saving the checklist file, internally verify and report:

1. **Graph files queried** — JSONL files loaded plus any live graph query-tool invocations (`impact`, `cycles`, `modules`).
2. **Layer 1 files deliberately skipped** — list any context sections skipped.
3. **Filesystem grep fallback justification** — for every `grep`/`find` run, name the concept it searched for.

If `draft/graph/schema.yaml` does not exist, set `Graph files queried: NONE` and use justification `graph data unavailable`.

## Graph Usage Report (append to checklist)

Emit the canonical footer from [core/shared/graph-usage-report.md](../../core/shared/graph-usage-report.md). The lint hook `scripts/tools/check-graph-usage-report.sh` validates the section on save.
## Cross-Skill Dispatch

- **Auto-invoked by:** `/draft:upload` (pre-upload verification)
- **References:** `core/agents/ops.md` for production-safety mindset
- **Jira sync:** If ticket linked, attach checklist and post comment via `core/shared/jira-sync.md`
- **MCP:** GitHub MCP for change details, Jira MCP for ticket context

## Error Handling

**If no tech-stack.md:** Generate generic checklist with all items, note: "Customize after running `/draft:init`"
**If no active track:** Generate standalone checklist, ask which service/release
**If no workflow.md:** Use sensible defaults, recommend documenting deployment conventions
