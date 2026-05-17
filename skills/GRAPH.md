# Skill Dependency Graph

> Reference artifact mapping relationships between all 31 Draft skills. Not a skill itself.
> Regenerate after adding/removing skills or changing cross-skill references.

---

## Two-Tier Architecture

### Primary Workflow (5 commands)
```
init → new-track → implement → review → upload
                       ↑ |
                       └───────────┘ (auto-invoked at phase boundaries)
```

### Specialist Commands (26 commands)
Grouped into subsystems that primary commands auto-invoke or that users invoke directly.

---

## System Topology

```mermaid
graph TD
    subgraph "Foundation"
        init["/draft:init"]
    end

    subgraph "Track Lifecycle"
        new-track["/draft:new-track"]
        implement["/draft:implement"]
        upload["/draft:upload"]
        regression["/draft:regression"]
        change["/draft:change"]
        revert["/draft:revert"]
        status["/draft:status"]
    end

    subgraph "Code Quality"
        quick-review["/draft:quick-review"]
        review["/draft:review"]
        deep-review["/draft:deep-review"]
        bughunt["/draft:bughunt"]
        coverage["/draft:coverage"]
        testing-strategy["/draft:testing-strategy"]
        learn["/draft:learn"]
    end

    subgraph "Debugging"
        debug["/draft:debug"]
    end

    subgraph "Architecture"
        decompose["/draft:decompose"]
        adr["/draft:adr"]
        index["/draft:index"]
        tech-debt["/draft:tech-debt"]
    end

    subgraph "Operations"
        deploy-checklist["/draft:deploy-checklist"]
        incident-response["/draft:incident-response"]
        standup["/draft:standup"]
    end

    subgraph "Authoring"
        documentation["/draft:documentation"]
    end

    subgraph "Integration"
        jira-preview["/draft:jira-preview"]
        jira-create["/draft:jira-create"]
        epic-status["/draft:epic-status"]
    end

    subgraph "Navigation"
        draft["/draft"]
    end

    %% Foundation dependencies
    init --> new-track
    init --> learn
    init --> adr
    init --> bughunt
    init --> index
    init --> status
    init --> deep-review
    init --> debug
    init --> tech-debt
    init --> incident-response
    init --> documentation
    init --> standup

    %% Track lifecycle
    new-track --> implement
    new-track --> change
    new-track --> revert
    new-track --> review
    new-track --> coverage
    new-track --> decompose
    new-track --> jira-preview
    new-track --> status
    new-track --> debug
    new-track --> regression

    %% Implementation flow
    implement --> upload
    implement -.->|auto-invokes at phase boundary| review
    implement --> debug
    implement -.->|calls Condensation Subroutine| init

    %% Upload flow
    upload -.->|auto-invokes pre-flight| deploy-checklist

    %% Debugging flow
    debug -.->|RCA feeds| regression
    debug -.->|fix feeds| implement

    %% Regression flow
    regression --> implement

    %% Quality chain
    review -.->|with-bughunt flag| bughunt
    review -.->|fast alternative| quick-review
    coverage -.->|calls Condensation Subroutine| init
    testing-strategy -.->|informs| coverage
    testing-strategy -.->|informs| bughunt

    %% Cross-skill dispatch (quality → specialists)
    bughunt -.->|suggests| debug
    bughunt -.->|suggests| regression
    deep-review -.->|suggests| tech-debt
    deep-review -.->|suggests| adr
    deep-review -.->|suggests| documentation

    %% Integration chain
    jira-preview --> jira-create
    bughunt -.->|report feeds| jira-preview
    review -.->|report feeds| jira-preview

    %% Epic status chain
    init --> epic-status
    deep-review -.->|Phase 5| epic-status
    bughunt -.->|Phase 5| epic-status

    %% Operations chain
    incident-response -.->|post-incident| debug
    incident-response -.->|timeline feeds| documentation
    standup -.->|reads| status
    deploy-checklist -.->|reads| testing-strategy

    %% Authoring chain
    documentation -.->|reads| deep-review

    %% Architecture chain
    tech-debt -.->|prioritized items feed| new-track

    %% Monorepo chain
    init -.->|per-service| index
```

## Dependency Matrix

| Skill | Requires | Required By | Shared Artifacts |
|-------|----------|-------------|-----------------|
| `init` | -- | all others | architecture.md, .ai-context.md, .ai-profile.md, product.md, tech-stack.md, guardrails.md, .state/* |
| `new-track` | init | implement, review, change, revert, coverage, decompose, jira-preview, status, debug | spec.md, plan.md, metadata.json |
| `implement` | init, new-track | review (triggers at phase boundaries) | Modifies source code; regenerates .ai-context.md |
| `review` | init, new-track | implement (called at phase boundaries) | review-report-latest.md |
| `quick-review` | init | review (fast alternative) | quick-review-report.md |
| `upload` | implement | -- | Squashed commits, GitHub/git push; auto-invokes deploy-checklist |
| `bughunt` | init | review (optional), index (optional), jira-preview (optional) | bughunt-report-latest.md |
| `deep-review` | init | -- | deep-review audit report |
| `coverage` | init, new-track | -- | Regenerates .ai-context.md |
| `testing-strategy` | init | coverage (informs), bughunt (informs) | testing-strategy.md |
| `debug` | init, new-track | implement (fix feeds back), regression (RCA feeds) | debug-report.md |
| `regression` | new-track | implement (RCA phase) | Bisect results, regression source identification |
| `decompose` | init, new-track | implement (optional) | Updates architecture.md; regenerates .ai-context.md |
| `change` | init, new-track | -- | Modifies spec.md, plan.md |
| `revert` | init, new-track | -- | Updates tracks.md, git state |
| `status` | init | standup (reads) | Read-only (tracks.md, plan.md, metadata.json) |
| `learn` | init | -- | Updates guardrails.md (conventions, anti-patterns) |
| `adr` | init | deep-review (suggests) | Creates ADR files in draft/adrs/ |
| `tech-debt` | init | deep-review (suggests), new-track (feeds prioritized items) | draft/tech-debt-report-latest.md |
| `deploy-checklist` | init | upload (auto-invoked pre-flight) | deploy-checklist.md |
| `incident-response` | init | -- | incident-<timestamp>.md, postmortem-<timestamp>.md |
| `standup` | init | -- | standup summary (reads status, git log) |
| `documentation` | init | deep-review (suggests), incident-response (feeds) | Generated docs, runbooks |
| `index` | init (per-service) | -- | service-index.md, dependency-graph.md, tech-matrix.md |
| `jira-preview` | new-track | jira-create | jira-export-latest.md |
| `jira-create` | jira-preview | -- | Creates Jira issues via API |
| `epic-status` | init, deep-review, bughunt, coverage | -- | draft/epic-status/*.md |
| `draft` | -- | -- | Navigation only -- references all skills |

## Execution Chains

### Standard Development Flow
```
init → new-track → implement → review → upload
                       ↑ | |
                       └───────────┘ └→ deploy-checklist (auto)
                    (iterate at phase boundaries)
```

### Bug Fix Flow
```
new-track (bug) → debug → regression → implement → review → upload
                    ↑ |
                    └──────────────────────┘ (iterate if fix incomplete)
```

### Incident Response Flow
```
incident-response → debug → regression → implement → review → upload
        | |
        └→ documentation (post-incident report) └→ deploy-checklist (auto)
```

### Operations Flow
```
standup ←── status (reads tracks + git log)
upload ──→ deploy-checklist (auto pre-flight)
deep-review ──→ tech-debt ──→ new-track (prioritized items)
```

### Monorepo Flow
```
init (per-service) → index (at root) → aggregated context
```

### Quality Audit Flow
```
init → quick-review (fast sanity check)
init → review (full three-stage)
init → bughunt (14-dimension sweep)
init → deep-review (module audit)
init → testing-strategy → coverage
init → decompose (optional pre-step for large modules)
```

### Jira Integration Flow
```
new-track → jira-preview → jira-create
                ↑
         bughunt + review reports (optional enrichment)
```

### Development Flow
```
init → new-track → implement → upload → (GitHub PR review)
```

### Regression Investigation Flow
```
new-track (bug) → regression → implement (RCA + fix)
```

### Learning Flow
```
init → learn → (updates guardrails.md)
                    ↓
         All quality skills read guardrails.md
         (bughunt, review, deep-review, coverage, quick-review)
```

## Shared Subroutines

| Subroutine | Defined In | Called By |
|------------|-----------|----------|
| Condensation Subroutine (.ai-context.md regeneration) | `core/shared/condensation.md` | implement, decompose, coverage, index |
| Standard File Metadata (YAML frontmatter) | `init` | All skills that generate draft/ files |
| Three-Stage Review | `review` | implement (at phase boundaries) |
| Signal Classification | `init` | init refresh, index (future) |
| Pattern Learning | `core/shared/pattern-learning.md` | learn, bughunt, review, deep-review (updates guardrails.md) |
| Context Loading | `core/shared/draft-context-loading.md` | All skills requiring draft/ context |
| Cross-Skill Dispatch | `core/shared/cross-skill-dispatch.md` | bughunt, deep-review, implement, review, upload |
| Jira Sync | `core/shared/jira-sync.md` | bughunt, review, implement (when ticket linked) |
| Graph Query | `core/shared/graph-query.md` | init, implement, bughunt, review, debug, decompose, index |
| Graph Mermaid | `graph/src/mermaid.js` | init (injects module-deps + proto-map into architecture.md) |

## Artifact Flow

```
                    ┌─────────────────────────────────────────────┐
                    │ draft/.state/ │
                    │ freshness.json signals.json run-memory │
                    └──────────────────┬──────────────────────────┘
                                       │ read by refresh
                    ┌──────────────────▼──────────────────────────┐
                    │ draft/ │
  init ──────────► │ architecture.md ──► .ai-context.md │
                    │ product.md tech-stack.md guardrails.md │
                    │ workflow.md tracks.md tech-debt.md │
                    │ graph/ (module-graph, hotspots, proto, │
                    │ module-deps.mermaid, proto-map..) │
                    └──────────────────┬──────────────────────────┘
                                       │ read by all skills
           ┌───────────────────────────┼───────────────────────┐
           ▼ ▼ ▼
    new-track bughunt learn
    ┌──────────┐ ┌────────────┐ ┌──────────┐
    │ spec.md │ │ report.md │ │guardrails│
    │ plan.md │ └─────┬──────┘ │ update │
    │metadata │ │ └──────────┘
    └────┬─────┘ │
         │ ┌────┴─────┐
         ▼ ▼ ▼
    implement jira-preview debug
    ┌──────────┐ ┌──────────┐ ┌──────────┐
    │ code │ │export.md │ │report.md │
    │ changes │ └────┬─────┘ └────┬─────┘
    └────┬─────┘ │ │
         │ ▼ ▼
         ▼ jira-create regression
      review ┌──────────┐ ┌──────────┐
    ┌──────────┐ │Jira API │ │bisect │
    │report.md │ └──────────┘ └──────────┘
    └────┬─────┘
         │
         ▼
      upload ──► deploy-checklist
    ┌──────────┐ ┌──────────────┐
    │squash + │ │pre-flight │
    │push │ │verification │
    └──────────┘ └──────────────┘
```
