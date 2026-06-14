# Skill Dependency Graph

> Reference artifact mapping relationships between all Draft skills. Not a skill itself.
> Regenerate after adding/removing skills or changing cross-skill references.

---

## Two-Tier Architecture

### Primary Workflow (4 commands)
```
init → new-track → implement → review
                       ↑           |
                       └───────────┘  (auto-invoked at phase boundaries)
```

### Routed Core Workflows (5 routers)
The 5 routers (`/draft:plan`, `/draft:ops`, `/draft:docs`, `/draft:discover`, `/draft:jira`) provide intent analysis and dispatch to the leaf specialist skills. Primary commands and routers are the public surface; leaves remain for compatibility and direct scripting.

### Specialist Leaf Commands
Grouped into subsystems dispatched by the routers (or primary commands).

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
        tech-debt["/draft:tech-debt"]
        impact["/draft:impact"]
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
        jira["/draft:jira"]
    end

    subgraph "DX"
        assist-review["/draft:assist-review"]
        tour["/draft:tour"]
    end

    subgraph "Navigation"
        draft["/draft"]
    end

    subgraph "Routed Core Workflows"
        plan["/draft:plan"]
        ops["/draft:ops"]
        docs["/draft:docs"]
        discover["/draft:discover"]
        jira["/draft:jira"]
    end

    %% Foundation dependencies
    init --> new-track
    init --> learn
    init --> adr
    init --> bughunt
    init --> status
    init --> deep-review
    init --> debug
    init --> tech-debt
    init --> incident-response
    init --> documentation
    init --> standup

    %% Router dispatch (primary entry for specialists)
    plan --> new-track
    plan --> decompose
    plan --> adr
    plan --> "tech-debt"
    plan --> change
    ops --> deploy-checklist
    ops --> incident-response
    ops --> standup
    ops --> status
    ops --> revert
    docs --> documentation
    discover --> debug
    discover --> bughunt
    discover --> quick-review
    discover --> deep-review
    discover --> coverage
    discover --> testing-strategy
    discover --> learn
    discover --> tour
    discover --> impact
    discover --> assist-review
    %% jira router handles preview/create/review internally

    %% Track lifecycle
    new-track --> implement
    new-track --> change
    new-track --> revert
    new-track --> review
    new-track --> coverage
    new-track --> decompose
    new-track --> jira  %% via router
    new-track --> status
    new-track --> debug

    %% Implementation flow
    implement -.->|auto-invokes at phase boundary| review
    implement --> debug
    implement -.->|calls Condensation Subroutine| init

    %% Quality chain
    review -.->|with-bughunt flag| bughunt
    review -.->|fast alternative| quick-review
    coverage -.->|calls Condensation Subroutine| init
    testing-strategy -.->|informs| coverage
    testing-strategy -.->|informs| bughunt

    %% Cross-skill dispatch (quality → specialists)
    bughunt -.->|suggests| debug
    deep-review -.->|suggests| tech-debt
    deep-review -.->|suggests| adr
    deep-review -.->|suggests| documentation

    %% Integration chain
    %% preview/create/review are now subcommands of the jira router
    bughunt -.->|report feeds| jira
    review -.->|report feeds| jira

    %% Operations chain
    incident-response -.->|post-incident| debug
    incident-response -.->|timeline feeds| documentation
    standup -.->|reads| status
    deploy-checklist -.->|reads| testing-strategy

    %% Authoring chain
    documentation -.->|reads| deep-review

    %% Architecture chain
    tech-debt -.->|prioritized items feed| new-track
    impact -.->|reads graph| new-track
    impact -.->|reads graph| implement

    %% Monorepo: init is scope-aware — root build + module→root graph link (no separate index command)
```

## Dependency Matrix

> Routers (`plan`, `ops`, `docs`, `discover`, `jira`) depend on their dispatched leaves and are the recommended public interface. Leaves list their direct deps.

| Skill | Requires | Required By | Shared Artifacts |
|-------|----------|-------------|-----------------|
| `init` | -- | all others | architecture.md, .ai-context.md, .ai-profile.md, product.md, tech-stack.md, guardrails.md, .state/* |
| `new-track` | init | implement, review, change, revert, coverage, decompose, jira, status, debug | spec.md, plan.md, metadata.json |
| `implement` | init, new-track | review (triggers at phase boundaries) | Modifies source code; regenerates .ai-context.md |
| `review` | init, new-track | implement (called at phase boundaries) | review-report-latest.md |
| `quick-review` | init | review (fast alternative) | quick-review-report.md |
| `bughunt` | init | review (optional), jira (optional) | bughunt-report-latest.md |
| `deep-review` | init | -- | deep-review audit report |
| `coverage` | init, new-track | -- | Regenerates .ai-context.md |
| `testing-strategy` | init | coverage (informs), bughunt (informs) | testing-strategy.md |
| `debug` | init, new-track | implement (fix feeds back) | debug-report.md |
| `decompose` | init, new-track | implement (optional) | Updates architecture.md; regenerates .ai-context.md |
| `change` | init, new-track | -- | Modifies spec.md, plan.md |
| `revert` | init, new-track | -- | Updates tracks.md, git state |
| `status` | init | standup (reads) | Read-only (tracks.md, plan.md, metadata.json) |
| `learn` | init | -- | Updates guardrails.md (conventions, anti-patterns) |
| `adr` | init | deep-review (suggests) | Creates ADR files in draft/adrs/ |
| `tech-debt` | init | deep-review (suggests), new-track (feeds prioritized items) | draft/tech-debt-report-latest.md |
| `impact` | init, graph | new-track, implement | Reads graph; emits blast-radius reports |
| `deploy-checklist` | init | -- | deploy-checklist.md |
| `incident-response` | init | -- | incident-<timestamp>.md, postmortem-<timestamp>.md |
| `standup` | init | -- | standup summary (reads status, git log) |
| `documentation` | init | deep-review (suggests), incident-response (feeds) | Generated docs, runbooks |
| `index` | init (per-service) | -- | service-index.md, dependency-graph.md, tech-matrix.md |
| `jira` | new-track | -- | jira-export-latest.md (internal) |
| `assist-review` | init | -- | Inline PR review assistance |
| `tour` | init | -- | Read-only architecture walk |
| `draft` | -- | -- | Navigation only -- references all skills |

## Execution Chains

### Standard Development Flow
```
init → new-track → implement → review → (git push + PR)
                       ↑           |
                       └───────────┘
                    (iterate at phase boundaries)
```

### Bug Fix Flow
```
new-track (bug) → debug → implement → review
                    ↑                      |
                    └──────────────────────┘ (iterate if fix incomplete)
```

### Incident Response Flow
```
incident-response → debug → implement → review
        |
        └→ documentation (post-incident report)
```

### Operations Flow
```
standup ←── status (reads tracks + git log)
deep-review ──→ tech-debt ──→ new-track (prioritized items)
```

### Monorepo Flow
```
init (root)       → whole-repo code-graph spine + sparse root map
init (sub-module) → module snapshot + root-link.json → cross-module context via the root spine
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
new-track → jira (preview / create / review subcommands)
                ↑
         bughunt + review reports (optional enrichment)
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
| Condensation Subroutine (.ai-context.md regeneration) | `core/shared/condensation.md` | implement, decompose, coverage |
| Standard File Metadata (YAML frontmatter) | `init` | All skills that generate draft/ files |
| Three-Stage Review | `review` | implement (at phase boundaries) |
| Signal Classification | `init` | init refresh |
| Pattern Learning | `core/shared/pattern-learning.md` | learn, bughunt, review, deep-review (updates guardrails.md) |
| Context Loading | `core/shared/draft-context-loading.md` | All skills requiring draft/ context |
| Cross-Skill Dispatch | `core/shared/cross-skill-dispatch.md` | bughunt, deep-review, implement, review |
| Jira Sync | `core/shared/jira-sync.md` | bughunt, review, implement (when ticket linked) |
| Graph Query | `core/shared/graph-query.md` | init, implement, bughunt, review, debug, decompose, impact |
| Graph Mermaid | `scripts/tools/mermaid-from-graph.sh` | init (injects module-deps + proto-map into architecture.md) |

## Artifact Flow

```
                    ┌─────────────────────────────────────────────┐
                    │              draft/.state/                   │
                    │  freshness.json  signals.json  run-memory   │
                    └──────────────────┬──────────────────────────┘
                                       │ read by refresh
                    ┌──────────────────▼──────────────────────────┐
                    │              draft/                          │
  init ──────────►  │  architecture.md ──► .ai-context.md         │
                    │  product.md  tech-stack.md  guardrails.md   │
                    │  workflow.md  tracks.md  tech-debt.md       │
                    │  graph/ (module-graph, hotspots, proto,      │
                    │         module-deps.mermaid, proto-map..)   │
                    └──────────────────┬──────────────────────────┘
                                       │ read by all skills
           ┌───────────────────────────┼───────────────────────┐
           ▼                           ▼                       ▼
    new-track                      bughunt               learn
    ┌──────────┐              ┌────────────┐        ┌──────────┐
    │ spec.md  │              │ report.md  │        │guardrails│
    │ plan.md  │              └─────┬──────┘        │  update  │
    │metadata  │                    │               └──────────┘
    └────┬─────┘                    │
         │                     ┌────┴─────┐
         ▼                     ▼          ▼
    implement             jira  debug
    ┌──────────┐          ┌──────────┐  ┌──────────┐
    │  code    │          │export.md │  │report.md │
    │ changes  │          └────┬─────┘  └──────────┘
    └────┬─────┘               │
         │                     ▼
         ▼                (preview/create/review)
      review              ┌──────────┐
    ┌──────────┐          │Jira API  │
    │report.md │          └──────────┘
    └──────────┘
```
