---
type: ContextMap
project: "{PROJECT_NAME}"
module: "root"
generated_by: "draft:init"
generated_at: "{ISO_TIMESTAMP}"
---

# {PROJECT_NAME} Context Map

> Self-contained AI context. Budget: {TIER_MIN}–{TIER_MAX} lines (tier {N}: {LABEL}).
> Graph metrics: M={modules} F={functions} P={proto_rpcs} E={include_edges}
> Primary value: faithful structural graph + **core operational models** (workflows, lifecycles, state machines) derived from architecture.md §3 (Primary Control & Data Flows).
> This file must stand alone — no references to architecture.md or source files needed.

| Field | Value |
|-------|-------|
| **Branch** | `{LOCAL_BRANCH}` → `{REMOTE/BRANCH}` |
| **Commit** | `{SHORT_SHA}` — {COMMIT_MESSAGE} |
| **Generated** | {ISO_TIMESTAMP} |
| **Synced To** | `{FULL_SHA}` |

---

## Architecture

- **Type**: {type} <!-- e.g., gRPC Microservice, CLI tool, library, REST API -->
- **Language**: {language} <!-- e.g., TypeScript 5.3, Python 3.12, Go 1.21 -->
- **Pattern**: {pattern} <!-- e.g., Hexagonal, MVC, Pipeline, Event-driven -->
- **Build**: `{build_command}`
- **Test**: `{test_command}`
- **Entry**: `{entry_file}` → `{entry_function}`
- **Config**: {config_mechanism} <!-- e.g., .env + config.ts, gflags, Viper -->
- **Generational**: {generational} <!-- V1/V2 split or "single generation" -->

## Component Graph

```
{project_root}/
├── {module1}/ ← {5-10 word description}
│ ├── {submod1}/ ← {description} ({Ncc} cc, {Nh} h)
│ │ └── ops/ ← {description} ({N} operations)
│ ├── {submod2}/ ← {description}
│ └── {shared}/ ← {description}
├── {module2}/ ← {description}
│ ├── {submod}/ ← {description}
│ └── {submod}/ ← {description}
└── {module3}/ ← {description}
```

> Include immediate sub-directories for all major modules (not just top-level).
> Use live engine queries (`get_architecture .packages[]` or `graph-callers.sh`) for exhaustive sub-module enumeration.
> Show file counts per sub-module to indicate relative size/importance.

## GRAPH:MODULES

{module}|{sizeKB}KB|go:{N},proto:{N} → {dep1},{dep2}
...

> One row per module ordered by sizeKB descending. Omit for tier-1 codebases (≤5 modules) where Component Graph is sufficient.

## GRAPH:HOTSPOTS

{file_path}|{lines}L|fanIn:{N}
...

> Top 10 files by score (lines + fanIn×50). Always include all tiers.

## GRAPH:CYCLES

None ✓

> Or: list cycle paths e.g. "auth → storage → auth". Always include — absence is signal.

## GRAPH:MODULE-HOTSPOTS

{module}: {file}|{lines}L|fanIn:{N}
           {file}|{lines}L|fanIn:{N}
           {file}|{lines}L|fanIn:{N}

> Top 3 hotspot files per module by score (lines + fanIn×50). Tier ≥ 3 only. Omit for tier 1–2.
> Tells agents which files in a specific module carry the most change risk.

## GRAPH:FAN-IN

{module}|fanIn:{N}|callers:{caller1},{caller2}

> Modules ordered by incoming dependency count descending. Tier ≥ 3 only.
> High fanIn = high change risk — modifications propagate to many callers.

## GRAPH:PROTO-MAP

{ServiceName}: {rpc}({RequestType}) → {ResponseType} @{file}

> One line per RPC, grouped by service. Present only when proto_rpcs > 0. Omit entirely for non-proto codebases.

## GRAPH:OPERATIONAL (Core Behavioral Models)

**Primary Operational Models** (from architecture.md §3 — highest fidelity requirement):

- **{Flow/Lifecycle Name 1}** (e.g. Request Lifecycle, Init Pipeline, Job Pipeline):
  State1 --(event/func)--> State2 --(error path)--> ErrorState --> Recovery
  (include key decision points, alt paths, and error recovery)

- **{Flow/Lifecycle Name 2}**:
  ...

> For typical apps: main request flow + background processing + startup.
> For plugin / meta-tooling platforms: init with graph gate, skill/agent dispatch + frontmatter enforcement, condensation, parallel analysis, etc.
> Represent complex sequence/state diagrams in compact structured text. Preserve error paths and critical transitions.

## Dependency Injection / Wiring

{One paragraph or bullets explaining how components find each other.}

Key injection points:
- `{token1}`: {what it provides}
- `{token2}`: {what it provides}
- `{token3}`: {what it provides}

## Critical Invariants (DO NOT BREAK)

- [Data] **{name}**: {one-sentence rule} — enforced at `{file}:{line}`
- [Security] **{name}**: {rule} — enforced at `{file}:{line}`
- [Concurrency] **{name}**: {rule} — enforced at `{file}:{line}`
- [Ordering] **{name}**: {rule} — enforced at `{file}:{line}`
- [Idempotency] **{name}**: {rule} — enforced at `{file}:{line}`
- [Compatibility] **{name}**: {rule} — enforced at `{file}:{line}`

## Interface Contracts (TypeScript-like IDL)

```typescript
// Primary extension interface
interface {InterfaceName} {
  {method}({param}: {Type}): {ReturnType}; // {brief description}
  {optionalMethod}?({param}: {Type}): {ReturnType};
}

// Service contract
interface {ServiceName} {
  {rpcMethod}(req: {RequestType}): Promise<{ResponseType}>;
}
```

## Dependency Graph

```
[{Component}] -> (HTTP) -> [{ExternalService}]
[{Component}] -> (SQL) -> [{Database}]
[{Component}] -> (gRPC) -> [{PeerService}]
[{Component}] -> (queue) -> [{MessageBroker}]
```

## Key Data Sources

| Source | Type | Readers |
|--------|------|---------|
| `{table/topic/endpoint}` | {DB/Queue/API} | `{component1}`, `{component2}` |

## Data Flow Summary (tied to Operational Models above)

**{FlowName}** (from GRAPH:OPERATIONAL): {concise description of one primary model, including main error/recovery path}.

**{FlowName2}**: ...

> This section should be a lightweight textual summary of the key models already detailed in GRAPH:OPERATIONAL. Do not duplicate — complement it.

## Error Handling & Failure Recovery

- **{Scenario}**: {Recovery mechanism} — {where handled}
- **{Scenario}**: {Recovery mechanism} — {where handled}
- **Retries**: {policy description}
- **Circuit breaker**: {if applicable}
- **Graceful degradation**: {behavior when dependencies unavailable}

## Concurrency Safety Rules

- **{ComponentName}**: {rule} — violating causes {consequence}
- **{ComponentName}**: {rule} — violating causes {consequence}
- **Lock ordering**: {if applicable}
- **Thread affinity**: {which components are single-threaded}

## Implementation Catalog

### {Category1}

| Name | Type | Description |
|------|------|-------------|
| `{impl1}` | `{Class}` | {brief description} |
| `{impl2}` | `{Class}` | {brief description} |

### {Category2}

| Name | Type | Description |
|------|------|-------------|
| `{impl3}` | `{Class}` | {brief description} |

## V1 ↔ V2 Migration Status

> Skip if no generational split.

| V1 | V2 | Status |
|----|----|----|
| `{v1_impl}` | `{v2_impl}` | {Migrated/Pending/Deprecated} |

**Rule**: When adding new {X}, prefer {V1/V2} because {reason}.

## Thread Pools / Execution Model

| Pool | Count | Purpose |
|------|-------|---------|
| `{pool_name}` | {N} | {what runs on it} |

> For single-threaded: "Single-threaded event loop — N/A"

## Key Configuration

| Flag/Param | Default | Critical? | Purpose |
|------------|---------|-----------|---------|
| `{FLAG_NAME}` | `{value}` | Yes | {description} |
| `{flag_name}` | `{value}` | No | {description} |

## Extension Points — Step-by-Step Cookbooks

### Adding a New {ExtensionType}

1. Create `{path/to/new_file.ext}` (naming: `{convention}`)
2. Implement interface:
   - Required: `{method1}()`, `{method2}()`
   - Optional: `{method3}?()`
3. Register at `{registry_file}:{line}` via `{mechanism}`
4. Add to build: `{build_dep_instruction}`
5. Test: create `{test_path}` covering {scenarios}

### Adding a New {ExtensionType2}

1. {step}
2. {step}
3. {step}

## Testing Strategy

- **Unit**: `{exact_test_command}`
- **Integration**: `{framework}` in `{location}`
- **E2E**: `{command}` (if applicable)
- **Key hooks**: `{injection_point}`, `{mock_pattern}`, `{test_utility}`

## File Layout Quick Reference

- Entry: `{path}`
- Config: `{path}`
- Routes/Handlers: `{path}`
- Services: `{path}`
- Repositories: `{path}`
- Models: `{path}`
- Tests: `{path}`
- Build: `{path}`

## Glossary (Critical Terms Only)

| Term | Definition |
|------|------------|
| {term} | {one-sentence definition} |
| {term} | {one-sentence definition} |

## Draft Integration

- See `draft/tech-stack.md` for accepted patterns and technology decisions
- See `draft/workflow.md` for TDD preferences and commit conventions
- See `draft/guardrails.md` for hard guardrails, learned conventions, and learned anti-patterns
- See `draft/product.md` for product context and guidelines
