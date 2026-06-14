---
name: index
description: Build federated index from all child draft/ directories. Aggregates service-level context into root-level knowledge without deep code analysis. Use at monorepo root after services have been initialized with /draft:init.
---

# Draft Index

You are building a federated knowledge index for a monorepo with multiple services.

## Red Flags - STOP if you're:

- Running at a non-root directory in a monorepo
- Indexing services that haven't been initialized with `/draft:init`
- Overwriting root-level context without confirming with the user
- Aggregating without verifying each service's draft/ directory exists
- Skipping dependency mapping between services

**Aggregate from initialized services only. Verify before overwriting.**

---

## Standard File Metadata

**ALL generated files MUST include the standard YAML frontmatter.** This enables refresh tracking, sync verification, and traceability.

### Project Metadata File (single source of truth)

Before writing any file, update `draft/metadata.json` with current git state. This is the single source of truth for `synced_to_commit` and all `git.*` fields for every project-level artifact. Do NOT embed git fields in per-file frontmatter.

Use the `--project-metadata` flag (preferred):

```bash
DRAFT_TOOLS="${DRAFT_PLUGIN_ROOT:-$HOME/.claude/plugins/draft}/scripts/tools"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$HOME/.cursor/plugins/local/draft/scripts/tools"
[ -d "$DRAFT_TOOLS" ] || DRAFT_TOOLS="$PWD/scripts/tools"
bash "$DRAFT_TOOLS/git-metadata.sh" --project-metadata \
    --project "$PROJECT" --generated-by "draft:index"
```

### Per-File Metadata Template

Insert this **stable** YAML frontmatter at the top of every generated file (`service-index.md`, `dependency-graph.md`, `tech-matrix.md`, `draft-index-bughunt-summary.md`):

```yaml
---
project: "{PROJECT_NAME}"
module: "root"
generated_by: "draft:index"
generated_at: "{ISO_TIMESTAMP}"
---
```

> **Note**: `generated_by` uses `draft:command` format (not `/draft:command`) for cross-platform compatibility.

---

## Pre-Check

```bash
ls draft/ 2>/dev/null
```

**If `draft/` does NOT exist at root:**
- Announce: "Root draft/ directory not found. Run `/draft:init` at monorepo root first to create base context, then run `/draft:index` to aggregate service knowledge."
- Stop here.

**If `draft/` exists:** Continue to lockfile check.

## Lockfile Check

Before proceeding, check for a stale lock:

```bash
ls draft/.index-lock 2>/dev/null
```

- **If `draft/.index-lock` exists and is less than 10 minutes old:** Warn: "Previous indexing may be incomplete. Remove `draft/.index-lock` to proceed." Stop here.
- **If `draft/.index-lock` exists and is older than 10 minutes:** Remove it and continue.
- **If no lock exists:** Continue.

Create `draft/.index-lock` with the current timestamp before starting:

```bash
date -u +"%Y-%m-%dT%H:%M:%SZ" > draft/.index-lock
```

**On completion (Step 9) or fatal error, remove the lock:**

```bash
rm -f draft/.index-lock
```

## Step 1: Parse Arguments

Check for optional arguments:
- `--init-missing`: Also initialize services that don't have `draft/` directories
- `bughunt [dir1 dir2 ...]`: Run bug hunt across subdirectories with `draft/` folders
  - If no directories specified: auto-discover all subdirectories with `draft/`
  - If directories specified: run bughunt only in those subdirectories (skip if no `draft/`)
  - Generate summary report at: `draft/bughunt-summary.md`

**If `bughunt` argument detected:** Skip to Step 1A (Bughunt Mode) instead of continuing to Step 2.

## Step 1A: Bughunt Mode

This mode runs `/draft:bughunt` across multiple subdirectories and aggregates results.

### 1A.1: Determine Target Directories

**If directories explicitly specified** (e.g., `bughunt dir1 dir2 dir3`):
- Use provided directory list as targets
- Verify each directory exists
- Check each directory for `draft/` subdirectory
- Warn and skip any directory without `draft/`

**If no directories specified** (e.g., just `bughunt`):
- Auto-discover all immediate child directories (depth=1)
- Filter for directories containing `draft/` subdirectory
- Exclude patterns: `node_modules/`, `vendor/`, `.git/`, `draft/`, `.*`

```bash
# Example auto-discovery
for dir in */; do
  if [ -d "$dir/draft" ]; then
    echo "$dir"
  fi
done
```

**Output:**
```
Target directories for bughunt:
  - services/auth/
  - services/billing/
  - services/notifications/
```

### 1A.2: Execute Bughunt Per Directory

For each target directory:

1. **Set working directory** to `<target-dir>` for the bughunt scope. The AI agent should invoke `/draft:bughunt` with the target directory as the scope path, rather than using `cd`:
   ```
   /draft:bughunt
   → (scope prompt) → "Specific paths"
   → (paths prompt) → <target-dir>
   ```

2. **Announce:**
   ```
   Running bughunt in <target-dir>...
   ```

3. **Let `/draft:bughunt` run its full workflow:**
   - Report will be generated at `<target-dir>/draft/bughunt-report-<timestamp>.md`
   - Capture exit status (success/failure)

4. **Record results:**
   - Directory path
   - Total bugs found (by severity)
   - Report location
   - Any errors encountered

**Note:** Run bughunts sequentially, not in parallel, to avoid context conflicts.

### 1A.3: Parse Individual Reports

After all bughunts complete, read each generated report:

```bash
# For each target directory
cat <dir>/draft/bughunt-report-latest.md
```

Extract from each report:
- Branch and commit (from header)
- Summary table (bug counts by severity)
- Critical/High issue count
- Total issues count

### 1A.4: Generate Aggregate Summary Report

Create `draft/bughunt-summary.md`:

```markdown
# Draft Index: Bughunt Summary

**Date:** YYYY-MM-DD HH:MM
**Mode:** [Auto-discovery | Explicit directories]
**Directories Scanned:** N

## Overview

| Directory | Critical | High | Medium | Low | Total | Report |
|-----------|----------|------|--------|-----|-------|--------|
| services/auth/ | 0 | 2 | 5 | 3 | 10 | [→](services/auth/draft/bughunt-report.md) |
| services/billing/ | 1 | 1 | 2 | 1 | 5 | [→](services/billing/draft/bughunt-report.md) |
| services/notifications/ | 0 | 0 | 1 | 2 | 3 | [→](services/notifications/draft/bughunt-report.md) |

**Grand Total:** X Critical, Y High, Z Medium, W Low

## Directories With Critical Issues

| Directory | Count | Details |
|-----------|-------|---------|
| services/billing/ | 1 | [→](services/billing/draft/bughunt-report.md#critical-issues) |

## Directories With No Issues

- services/api-gateway/
- services/user-service/

## Skipped Directories

| Directory | Reason |
|-----------|--------|
| services/legacy-tools/ | No draft/ directory found |
| services/experiments/ | No draft/ directory found |

## Next Steps

1. **Prioritize Critical Issues:** Review directories with Critical bugs first
2. **Review Individual Reports:** Click links above to see detailed findings
3. **Track Fixes:** Use `/draft:new-track` to create implementation tracks for fixes
4. **Re-run After Fixes:** Run `/draft:index bughunt` again to verify

---

*Generated by `/draft:index bughunt` command*
```

### 1A.5: Completion Report

```
---
              DRAFT INDEX BUGHUNT COMPLETE
---
Scanned: N directories
Completed: X successful
Skipped: Y (no draft/)
Failed: Z errors

Grand Total Bugs:
  Critical: W
  High: X
  Medium: Y
  Low: Z

Summary Report: draft/bughunt-summary.md

Directories requiring immediate attention:
  - services/billing/ (1 CRITICAL)
  - services/auth/ (2 HIGH)

---
```

**STOP HERE** if bughunt mode. Do not continue to Step 2 (normal indexing flow).

## Step 2: Discover Services (Depth=1 Only)

Scan immediate child directories for service markers. Do NOT recurse beyond depth=1.

**Service detection markers (any of these):**
- `package.json` (Node.js)
- `go.mod` (Go)
- `Cargo.toml` (Rust)
- `pom.xml` or `build.gradle` (Java)
- `pyproject.toml` or `requirements.txt` (Python)
- `Dockerfile` (containerized service)
- `src/` directory with code files

**Exclude patterns:**
- `node_modules/`
- `vendor/`
- `.git/`
- `draft/` (the root draft directory itself)
- Any directory starting with `.`

```bash
# Example discovery (adapt to actual structure)
ls -d */ | head -50
```

**Output:** List of detected service directories.

## Step 3: Categorize Services

For each detected service directory, check for `draft/` subdirectory:

```bash
# For each service
ls <service>/draft/ 2>/dev/null
```

Categorize into:
- **Initialized:** Has `draft/` with context files
- **Uninitialized:** No `draft/` directory

Report:
```
Scanning immediate child directories...

Detected X service directories:
  ✓ Y initialized (draft/ found)
  ○ Z uninitialized

Initialized services:
  - services/auth/
  - services/billing/
  - ...

Uninitialized services:
  - services/legacy-reports/
  - services/admin-tools/
  - ...
```

## Step 4: Handle Uninitialized Services

**If `init-missing` argument is present:**
1. For each uninitialized service, prompt:
   ```
   Initialize <service-name>/? [y/n/all/skip-rest]
   ```
2. If user selects:
   - `y`: Run `/draft:init` in that directory
   - `n`: Skip this service
   - `all`: Initialize all remaining without prompting
   - `skip-rest`: Skip all remaining uninitialized services

**If `init-missing` argument is NOT present:**
- Just report uninitialized services and continue
- Suggest: "Run `/draft:index --init-missing` to initialize these services"

## Step 5: Aggregate Context from Initialized Services

For each initialized service, read and extract:

### 5.1 From `<service>/draft/product.md`:
- Service name
- First paragraph of Vision (summary)
- Target users (list)
- Core features (list)

### 5.2 From `<service>/draft/.ai-context.md` (or legacy `<service>/draft/architecture.md`):
- Key Takeaway paragraph (from `## System Overview`)
- External dependencies (from `## External Dependencies`)
- Exposed APIs or entry points (from `## Entry Points`)
- Dependencies on other services (look for references to sibling service names)
- Critical invariants summary (from `## Critical Invariants`, if available)

### 5.3 From `<service>/draft/tech-stack.md`:
- Primary language/framework
- Database
- Key dependencies

### 5.4 Create/Update `<service>/draft/manifest.json`:
```json
{
  "name": "<service-name>",
  "type": "service",
  "summary": "<first line of product vision>",
  "primaryTech": "<main language/framework>",
  "dependencies": ["<other-service-names>", "<external-deps>"],
  "dependents": [],
  "team": "<if found in docs>",
  "initialized": "<date>",
  "lastIndexed": "<current-date>"
}
```

## Step 6: Detect Inter-Service Dependencies

Analyze extracted data to build dependency graph:

1. Look for service name references in each service's architecture.md
2. Look for API client imports or service URLs in tech-stack.md
3. Look for mentions in product.md that reference other services
4. **Graph-enriched detection** (if individual services have `draft/graph/` directories):
   - Read each service's `draft/graph/architecture.json` `.routes` to map which service defines vs consumes which endpoints
   - Cross-reference proto consumers with proto producers to build precise inter-service dependency edges
   - Read `draft/graph/architecture.json` (`.packages`) per service for internal module structure
   - This provides deterministic, code-level dependency data that supplements the heuristic name-matching above

Build a dependency map:
```
auth-service: [] # no dependencies on other services
billing-service: [auth-service]
api-gateway: [auth-service, billing-service]
```

### Step 6.1b: Cycle Detection

**Cycle detection:** Walk the dependency graph depth-first from each service. If a cycle is detected (service A depends on B depends on ... depends on A), emit a `> WARNING: Circular dependency detected: A → B → ... → A` line in `dependency-graph.md`, mark the back-edge with `circular: true` in `manifest.json`'s dependency entry, and continue processing. Do not fail on cycles — report and proceed.

### Step 6.2: Resolve Dependents (Reverse Lookup)

For each service S, iterate all other services' `dependencies` arrays. If S appears in another service's dependencies, add that service to S's `dependents` array. Write the updated `manifest.json` for each service.

## Step 7: Generate Root Aggregated Files

### 7.1 Generate `draft/service-index.md`

Use the following inline template:

```markdown
# Service Index

> Auto-generated by `/draft:index` on <date>. Do not edit directly.
> Re-run `/draft:index` to update.

## Overview

| Metric | Count |
|--------|-------|
| Total Services Detected | X |
| Initialized | Y |
| Uninitialized | Z |

## Service Registry

| Service | Status | Tech Stack | Dependencies | Team | Details |
|---------|--------|------------|--------------|------|---------|
| auth | ✓ | Go, Postgres | - | @auth-team | [→](../services/auth/draft/.ai-context.md) |
| billing | ✓ | Node, Stripe | auth | @billing | [→](../services/billing/draft/.ai-context.md) |
| legacy-reports | ○ | - | - | - | Not initialized |

## Uninitialized Services

The following services have not been initialized with `/draft:init`:
- `services/legacy-reports/`
- `services/admin-tools/`

Run `/draft:index --init-missing` or initialize individually with:
```bash
cd services/legacy-reports && /draft:init
```
```

### 7.2 Generate `draft/dependency-graph.md`

```markdown
# Service Dependency Graph

> Auto-generated by `/draft:index` on <date>. Do not edit directly.

## System Topology

```mermaid
graph LR
    subgraph "Core Services"
        auth[auth-service]
        billing[billing-service]
        users[user-service]
    end

    subgraph "Edge"
        gateway[api-gateway]
    end

    subgraph "Background"
        notifications[notification-service]
        reports[report-service]
    end

    gateway --> auth
    gateway --> billing
    gateway --> users
    billing --> auth
    notifications --> users
    reports --> billing
```

## Dependency Matrix

| Service | Depends On | Depended By |
|---------|-----------|-------------|
| auth-service | - | billing, gateway, users |
| billing-service | auth | gateway, reports |
| user-service | auth | gateway, notifications |
| api-gateway | auth, billing, users | - |

## Dependency Order (Topological)

1. **auth-service** (foundational - no internal dependencies)
2. **user-service** (depends on: auth)
3. **billing-service** (depends on: auth)
4. **notification-service** (depends on: users)
5. **report-service** (depends on: billing)
6. **api-gateway** (depends on: auth, billing, users)

> This ordering helps when planning cross-service changes or understanding impact.
```

### 7.3 Generate `draft/tech-matrix.md`

```markdown
# Technology Matrix

> Auto-generated by `/draft:index` on <date>. Do not edit directly.

## Common Stack (Org Standards)

Technologies used by majority of services:

| Technology | Usage | Services |
|------------|-------|----------|
| PostgreSQL | Database | auth, billing, users (85%) |
| Redis | Caching | auth, gateway, notifications (60%) |
| Docker | Containerization | all (100%) |
| GitHub Actions | CI/CD | all (100%) |

## Technology Distribution

### Languages

| Language | Services | Percentage |
|----------|----------|------------|
| Go | auth, users, gateway | 45% |
| TypeScript | billing, notifications, reports | 45% |
| Python | ml-service, analytics | 10% |

### Databases

| Database | Services |
|----------|----------|
| PostgreSQL | auth, billing, users, reports |
| MongoDB | notifications, analytics |
| Redis | auth, gateway (cache only) |

## Variance Report

Services deviating from org standards:

| Service | Deviation | Reason |
|---------|-----------|--------|
| ml-service | Python instead of Go/TS | ML ecosystem |
| analytics | MongoDB instead of Postgres | Time-series workload |
```

### Placeholder Detection

A file is considered a placeholder if it contains the marker `<!-- AUTO-GENERATED -->` or is smaller than 100 bytes. Placeholders may be overwritten without confirmation. Non-placeholder files require user confirmation before overwriting.

### 7.4 Synthesize `draft/product.md` (if not exists or is placeholder)

Read all service product.md files and synthesize:

```markdown
# Product: [Org/Product Name]

> Synthesized from X service contexts by `/draft:index` on <date>.
> Edit this file to refine the overall product vision.

## Vision

[Synthesized from common themes across service visions - one paragraph describing what the overall product/platform does]

## Target Users

<!-- Aggregated from all services, deduplicated -->
- **End Users**: [common user types across services]
- **Developers**: [if developer-facing APIs exist]
- **Operators**: [if ops/admin services exist]

## Service Capabilities

| Capability | Provided By | Description |
|------------|-------------|-------------|
| Authentication | auth-service | User identity, JWT, OAuth |
| Payments | billing-service | Stripe integration, invoicing |
| API Access | api-gateway | Rate limiting, routing |

## Cross-Cutting Concerns

<!-- Extracted from common patterns across services -->
- **Authentication**: All services validate via auth-service
- **Observability**: [common logging/tracing approach]
- **Data Privacy**: [common compliance patterns]
```

### 7.5 Synthesize `draft/architecture.md` (if not exists or is placeholder)

```markdown
# Architecture: [Org/Product Name]

> Synthesized from X service contexts by `/draft:index` on <date>.
> This is a system-of-systems view. For service internals, see individual service contexts.

## System Overview

**Key Takeaway:** [One paragraph synthesizing overall system purpose from service summaries]

### System Topology

```mermaid
graph TD
    subgraph "External"
        Users[Users/Clients]
        ThirdParty[Third-Party Services]
    end

    subgraph "Edge Layer"
        Gateway[API Gateway]
        CDN[CDN/Static]
    end

    subgraph "Core Services"
        Auth[Auth Service]
        Billing[Billing Service]
        Users2[User Service]
    end

    subgraph "Background"
        Notifications[Notifications]
        Reports[Reports]
    end

    subgraph "Data Layer"
        Postgres[(PostgreSQL)]
        Redis[(Redis)]
        Queue[Message Queue]
    end

    Users --> Gateway
    Gateway --> Auth
    Gateway --> Billing
    Gateway --> Users2
    Billing --> ThirdParty
    Auth --> Postgres
    Billing --> Postgres
    Notifications --> Queue
    Reports --> Queue
```

## Service Directory

| Service | Responsibility | Tech | Status | Details |
|---------|---------------|------|--------|---------|
| auth-service | Identity & access management | Go, Postgres | ✓ Active | [→ context](../services/auth/draft/.ai-context.md) |
| billing-service | Payments & invoicing | Node, Stripe | ✓ Active | [→ context](../services/billing/draft/.ai-context.md) |

## Shared Infrastructure

<!-- Extracted from common external dependencies -->

| Component | Purpose | Used By |
|-----------|---------|---------|
| PostgreSQL | Primary datastore | auth, billing, users |
| Redis | Caching, sessions | auth, gateway |
| RabbitMQ | Async messaging | notifications, reports |
| Stripe | Payment processing | billing |

## Cross-Service Patterns

<!-- Extracted from common conventions -->

| Pattern | Description | Services |
|---------|-------------|----------|
| JWT Auth | All services validate JWT via auth-service | all |
| Event-Driven | Async events via message queue | notifications, reports |

## Notes

- For detailed service architecture, navigate to individual service contexts
- This file is regenerable via `/draft:index`
- Manual edits to non-synthesized sections will be preserved on re-index
```

### 7.6 Synthesize `draft/tech-stack.md` (if not exists or is placeholder)

```markdown
# Tech Stack: [Org/Product Name]

> Synthesized from X service contexts by `/draft:index` on <date>.
> This defines org-wide standards. Service-specific additions are in their local tech-stack.md.

## Org Standards

### Languages
- **Primary**: [most common language] — [X% of services]
- **Secondary**: [second most common] — [Y% of services]

### Frameworks
- **API**: [common API framework]
- **Testing**: [common test framework]

### Infrastructure
- **Database**: PostgreSQL (standard), MongoDB (approved for specific use cases)
- **Caching**: Redis
- **Messaging**: RabbitMQ / SQS
- **Container**: Docker
- **Orchestration**: Kubernetes

### CI/CD
- **Platform**: GitHub Actions
- **Registry**: [container registry]

## Approved Variances

| Service | Variance | Justification |
|---------|----------|---------------|
| ml-service | Python | ML ecosystem requirements |
| analytics | MongoDB | Time-series workload |

## Shared Libraries

| Library | Purpose | Version | Used By |
|---------|---------|---------|---------|
| @org/auth-client | Auth service client | 2.x | billing, gateway, notifications |
| @org/logging | Structured logging | 1.x | all services |
```

### 7.7 Synthesize `draft/.ai-context.md` (if not exists or is placeholder)

After generating `draft/architecture.md`, derive a condensed `draft/.ai-context.md` using the Condensation Subroutine (as defined in `core/shared/condensation.md`). This provides a token-optimized, self-contained AI context file at the root level aggregating all service knowledge.

- Read the synthesized `draft/architecture.md`
- Condense into 200-400 lines covering: system overview, service catalog, inter-service dependencies, shared infrastructure, cross-cutting patterns, critical invariants, and entry points
- If `draft/.ai-context.md` already exists and is not a placeholder, prompt before overwriting

## Step 8: Create Root Config

Create `draft/config.yaml` if not exists:

```yaml
# Draft Index Configuration

# Service detection patterns (immediate children only)
service_patterns:
  - "package.json"
  - "go.mod"
  - "Cargo.toml"
  - "pom.xml"
  - "build.gradle"
  - "pyproject.toml"
  - "requirements.txt"
  - "Dockerfile"

# Directories to exclude from scanning
exclude_patterns:
  - "node_modules"
  - "vendor"
  - ".git"
  - "draft"
  - ".*" # Hidden directories

# Re-index on these events (for CI integration)
reindex_triggers:
  - "service added"
  - "service removed"
  - "weekly"
```

## Step 8.5: Refresh Graph Injection Slots

For each initialized service with both `draft/architecture.md` AND `draft/graph/schema.yaml`:

**A. Read current `architecture.md` into memory.**

**B. Regenerate slot content from graph JSONL:**
- `GRAPH:module-deps` → run `scripts/tools/mermaid-from-graph.sh --repo . --diagram module-deps`
  Parse JSON response, extract `.mermaid` string + `filtered` flag + stats
- `GRAPH:proto-map` → run `scripts/tools/mermaid-from-graph.sh --repo . --diagram proto-map`
  Parse JSON response, extract `.mermaid` string + stats
- `GRAPH:hotspots` → read `draft/graph/hotspots.jsonl`, build top-10 markdown table:
  `| File | Lines | fanIn | Score |` with one row per hotspot, ordered by score descending

**C. For each slot, find `<!-- GRAPH:{id}:START -->` ... `<!-- GRAPH:{id}:END -->` markers.**
Replace entire block (inclusive of markers) with regenerated content.
If a marker pair is absent (legacy file): insert slot at the designated position and log:
`"Injected GRAPH:{id} slot into architecture.md (slot was absent — legacy file upgraded)"`

**D. Write updated `architecture.md` back to disk.**
Update frontmatter: `generated_by = "draft:index"`, `generated_at = now`. Also update `draft/metadata.json` via `git-metadata.sh --project-metadata --generated-by "draft:index"` to re-anchor `synced_to_commit`.

**E. Re-run Condensation Subroutine** (condensation.md) to propagate updated hotspot data into `.ai-context.md` GRAPH:HOTSPOTS and recompute tier budget. If `.ai-profile.md` exists, regenerate via Profile Generation Subroutine.

**F. Report per service:**
```
✓ <service>: refreshed 3 graph slots (module-deps, proto-map, hotspots)
✓ <service>: regenerated .ai-context.md (tier N, {lines} lines)
```

## Step 8.6: Refresh OKF Bundle Root

After the root aggregated files exist (`service-index.md`, `architecture.md`,
`product.md`, `tech-stack.md`, `.ai-context.md`, …), regenerate the Open Knowledge
Format root index so the root `draft/` tree is a portable OKF bundle. This is the
default; the index links `service-index.md` and every other concept present.

```bash
scripts/tools/okf-bundle.sh --dir draft   # writes the bundle-root draft/index.md
scripts/tools/okf-check.sh  --dir draft   # OKF v0.1 conformance (advisory, non-fatal)
```

## Step 9: Completion Report

Remove the lockfile:

```bash
rm -f draft/.index-lock
```

```
---
                    DRAFT INDEX COMPLETE
---
Scanned: X service directories (depth=1)
Indexed: Y services with draft/ context
Skipped: Z uninitialized services

Generated/Updated:
  ✓ draft/service-index.md (service registry)
  ✓ draft/dependency-graph.md (inter-service topology)
  ✓ draft/tech-matrix.md (technology distribution)
  ✓ draft/product.md (synthesized product vision)
  ✓ draft/architecture.md (system-of-systems view)
  ✓ draft/tech-stack.md (org standards)
  ✓ draft/config.yaml (index configuration)

Service manifests updated: Y services

Next steps:
1. Review synthesized files in draft/
2. Edit draft/product.md to refine overall vision
3. Edit draft/architecture.md to add cross-cutting context
4. Run /draft:index periodically to refresh

For uninitialized services, run:
  /draft:index init-missing
---
```

## Operational Notes

### What This Command Does NOT Do

- **No deep code analysis** — Reads only existing `draft/*.md` files
- **No source code scanning** — That's `/draft:init`'s job per service
- **No recursive scanning** — Depth=1 only, immediate children
- **No duplication** — Root files link to service files, not copy content

### When to Re-Run

- After running `/draft:init` on a new service
- After significant changes to service architectures
- Weekly/monthly as part of documentation hygiene
- Before major cross-service planning

### Preserving Manual Edits

When regenerating, the skill:
1. Reads existing root files
2. Identifies manually-added sections (not marked as auto-generated)
3. Preserves those sections while updating auto-generated parts
4. Sections between `<!-- MANUAL START -->` and `<!-- MANUAL END -->` are never overwritten

**Graph injection slots** (`<!-- GRAPH:...:START -->` / `<!-- GRAPH:...:END -->`) are ALWAYS overwritten during refresh — they are auto-managed. Never place manual content between these markers. Use `<!-- MANUAL START -->` / `<!-- MANUAL END -->` for content you want preserved near a slot.
