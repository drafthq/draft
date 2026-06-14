# Draft Context Loading

Standard procedure for loading Draft project context. All Draft commands that read project context follow this procedure before analysis or execution.

Referenced by: All skills that load Draft project context — including `/draft:bughunt`, `/draft:review`, `/draft:deep-review`, `/draft:quick-review`, `/draft:learn`, `/draft:tech-debt`, `/draft:deploy-checklist`, `/draft:incident-response`, `/draft:documentation`, `/draft:adr`, `/draft:testing-strategy`, `/draft:standup`, `/draft:debug`

## Context Loading Layers

Draft uses a layered context system inspired by memory tiering — compact, always-available context at the top, with progressively deeper context loaded on demand.

### Layer 0: Project Profile (Always Loaded)

If `draft/.ai-profile.md` exists, **always** read it first. This ultra-compact file (20-50 lines) provides the minimum context every command needs: language, framework, database, auth, API style, critical invariants, safety rules, active tracks, and recent changes.

- **Always loaded** regardless of task complexity
- **Purpose**: Enables simple tasks (quick edits, config changes, small fixes) without loading full context
- **Fallback**: If `.ai-profile.md` does not exist, proceed to Layer 1

### Layer 0.5: Plugin Guardrails (Selective Loading)

Layer 0.5 files live in the Draft plugin (`core/guardrails/`) and provide numbered, versioned baseline rules. **Project-level `draft/guardrails.md` always takes precedence** — if a project rule conflicts with a plugin rule, the project rule wins. See `core/guardrails/README.md` for vocabulary and full precedence order. (Portable improvement merged per manifest §2.1.)

| File | Rules | Scope |
|------|-------|-------|
| `core/guardrails/README.md` | (index) | Vocabulary, ID prefixes, precedence rules |
| `core/guardrails/code-quality.md` | CQ-001…CQ-012 | Code authoring, naming, error messages, structure |
| `core/guardrails/design-norms.md` | DN-001…DN-010 | HLD/LLD depth split, diagrams, traceability, secrets |
| `core/guardrails/review-checks.md` | RC-001…RC-015 | Cross-cutting review baseline (security, tests, observability) |
| `core/guardrails/security.md` | SEC-01…SEC-10 | Hard security red lines + reasoning chain |
| `core/guardrails/secure-patterns.md` | (cross-cites SEC) | Per-language enforcement of SEC rules |
| `core/guardrails/dependency-triage.md` | RC-014 | Third-party dependency vulnerability handling |
| `core/guardrails/language-standards.md` | Per-stack sections | Language-specific style, safety, test standards |
| `core/guardrails.md` *(existing)* | G1…G8 | C++ systems guardrails — always enforced for C++ code (conditioned on language signals for public language-agnostic use) |

#### Selective Loading Matrix (binding)

This matrix is the **single source of truth** for which Layer 0.5 files load per command. Skills MUST honor it — over-loading is a Red Flag (see red-flags.md) and costs tokens per invocation.

| Command type | Commands | Guardrails loaded |
|---|---|---|
| **Read-only** | `/draft:status`, `/draft:standup`, `/draft:tour`, `/draft:coverage` | **none** |
| **Spec / Plan** | `/draft:new-track`, `/draft:decompose`, `/draft:adr`, `/draft:testing-strategy`, `/draft:documentation` | `design-norms.md` only (architecture-shaped rules) |
| **Code-touching (generation)** | `/draft:implement`, `/draft:debug`, `/draft:change`, `/draft:revert` | `code-quality.md` + `security.md` + `secure-patterns.md` + `language-standards.md` (detected stack) |
| **Review** | `/draft:review`, `/draft:quick-review`, `/draft:deep-review`, `/draft:assist-review`, `/draft:bughunt`, `/draft:tech-debt` | `review-checks.md` + `security.md` + `language-standards.md` (detected stack); deep-review also loads `code-quality.md` + `design-norms.md` |
| **Deploy** | `/draft:deploy-checklist`, `/draft:incident-response` | `security.md` + `dependency-triage.md` |
| **Pattern / Meta** | `/draft:learn`, `/draft:init` | `code-quality.md` + `security.md` (baseline only — pattern discovery uses project-level guardrails as primary signal) |

**Sensitive-task escalation:** Even when the matrix says "none" or a narrow set, code-touching tasks whose title/spec mentions authentication, authorization, login, token, session, password, SQL, database query, subprocess, exec, crypto, encryption, hash, file upload, or external API input MUST additionally load `security.md` + `secure-patterns.md` and treat `[SEC-*]` violations as Critical.

**Citation requirement:** When a rule is enforced or violated, cite the ID inline — `[SEC-03]`, `[CQ-007]`, `[RC-012]`, `[DN-004]`.

**Fallback**: If `core/guardrails/` files are not present (older plugin installation), skip gracefully — no degradation.

### Layer 1: Base Context Files

If `draft/` directory exists, read and internalize these files in order:

| Priority | File | Purpose | Fallback |
|----------|------|---------|----------|
| 1 | `draft/.ai-context.md` | Module boundaries, dependencies, critical invariants, concurrency model, error handling, data flows | `draft/architecture.md` (legacy projects) |
| 2 | `draft/tech-stack.md` | Frameworks, libraries, constraints, **Accepted Patterns** | — |
| 3 | `draft/product.md` | Product vision, user flows, requirements, **Guidelines** | — |
| 4 | `draft/workflow.md` | Team conventions, testing preferences | — |
| 5 | `draft/guardrails.md` | Hard guardrails, **Learned Conventions**, **Learned Anti-Patterns** | `draft/workflow.md` `## Guardrails` (legacy) |

### Layer 1.5: Graph Context (When Available)

If `draft/graph/schema.yaml` exists, the project has automated graph analysis data. This provides precise, deterministic structural context that complements the AI-generated `.ai-context.md`.

**Always-load files** (compact, read alongside Layer 1):

| File | Purpose | Content |
|------|---------|---------|
| `draft/graph/schema.yaml` | Snapshot metadata (engine, project, node/edge counts) | YAML, ~15 lines |
| `draft/graph/architecture.json` | Node labels, edge types, languages, packages (fan-in/out), entry points, routes, hotspots | JSON |
| `draft/graph/hotspots.jsonl` | Fan-in-ranked symbols, one object per line: `{id, name, fanIn}` | JSONL |

The snapshot also includes `draft/graph/okf/` — an Open Knowledge Format v0.1 bundle (`index.md` + `modules/*.md`) emitted by default. It is a portable mirror of the graph, not an always-load target.

Note: `.ai-context.md` embeds a condensed graph summary (`GRAPH:MODULES`, `GRAPH:HOTSPOTS`, `GRAPH:CYCLES`) for first-pass structural ground truth. `architecture.json` is authoritative for deep structure.

Note: The canonical embedded mermaid diagrams are in architecture.md injection slots (`<!-- GRAPH:module-deps:START/END -->`, `<!-- GRAPH:proto-map:START/END -->`), refreshed by `draft:init`. For current data, regenerate via `scripts/tools/mermaid-from-graph.sh`.

**Live structural queries** (run on demand — no per-language index files; the engine's model is unified):

| Tool | Use When... |
|------|-------------|
| `scripts/tools/graph-callers.sh --symbol <name>` | Enumerating callers of a function |
| `scripts/tools/graph-impact.sh --file <path>` / `--symbol <name>` | Sizing blast radius before a change |
| `scripts/tools/cycle-detect.sh` | Checking for call cycles |
| `scripts/tools/hotspot-rank.sh` | Fan-in ranking (live) |

See `core/shared/graph-query.md` for the full query contract.

**Fallback**: If `draft/graph/` does not exist, skip — no degradation.

### Layer 2: Fact Registry (When Available)

If `draft/.state/facts.json` exists, it provides granular fact-level context:

- **For refresh operations**: Load facts sourced from changed files to enable contradiction detection
- **For quality commands**: Load facts by category relevant to the current analysis dimension
- **For implementation**: Load facts related to files being modified (match via `source_files`)

Facts are NOT loaded in full for every command — use relevance filtering (see below).

Additional state files used by refresh operations (not loaded during normal context loading):
- `draft/.state/freshness.json` — SHA-256 hashes for file-level staleness detection
- `draft/.state/signals.json` — signal classification for structural drift detection

## Relevance-Scored Context Loading

Not all context is equally relevant to every task. When a specific track or task is active, apply relevance scoring to prioritize which context sections are most useful.

### When to Apply

Apply relevance scoring when ALL of these conditions are true:
1. A specific track or task is active (has `spec.md` and/or `plan.md`)
2. `draft/.ai-context.md` exists and is above tier-1 minimum (100 lines)
3. The command benefits from focused context (`/draft:implement`, `/draft:bughunt`, `/draft:review`)

Do NOT apply relevance scoring for commands that need full context (`/draft:init`, `/draft:deep-review`, `/draft:decompose`).

### Scoring Procedure

1. **Extract key concepts** from the active task:
   - Read `spec.md` acceptance criteria and extract domain terms
   - Read `plan.md` current task description and extract file paths, module names, technology terms
   - Identify the primary concern: data flow, UI, API, security, performance, configuration, etc.

2. **Score `.ai-context.md` sections** against the task concepts:

| Section | Load When Task Involves... |
|---------|--------------------------|
| `## META` | Always (baseline) |
| `## GRAPH:COMPONENTS` | Module boundary changes, new components |
| `## GRAPH:MODULES`    | Module boundary changes, new components, cross-module work |
| `## GRAPH:HOTSPOTS`   | Performance work, refactoring, changes to high-complexity files |
| `## GRAPH:CYCLES`     | Dependency restructuring, module boundary decisions |
| `## GRAPH:DEPENDENCIES` | Integration work, new external dependencies |
| `## GRAPH:DATAFLOW` | Data pipeline changes, new flows |
| `## INVARIANTS` | Always (safety critical) |
| `## INTERFACES` | API changes, new implementations |
| `## CATALOG:*` | Implementation work matching the category |
| `## THREADS` | Concurrency-related tasks |
| `## CONFIG` | Configuration changes |
| `## ERRORS` | Error handling tasks |
| `## CONCURRENCY` | Any async/parallel work |
| `## EXTEND:*` | Adding new implementations of existing patterns |
| `## TEST` | Always (need test commands) |
| `## FILES` | Always (need file locations) |
| `## VOCAB` | Domain-specific tasks |

3. **Score graph files** (if `draft/graph/` exists) against the task concepts:

| Graph source | Use When Task Involves... |
|------------|--------------------------|
| `architecture.json` | Module boundary changes, cross-module work, architecture analysis, API/route surface |
| `hotspots.jsonl` | Performance work, refactoring, changes to high-fanIn symbols |
| `scripts/tools/graph-callers.sh --symbol <name>` | Enumerating callers before a change |
| `scripts/tools/graph-impact.sh --file <path>` / `--symbol <name>` | Tracing call paths, root cause analysis, function-level impact |
| `scripts/tools/cycle-detect.sh` | Checking for call cycles |

4. **Always include**: `META`, `INVARIANTS`, `TEST`, `FILES` (minimum context floor)
5. **Include if relevant**: All other sections scored against task concepts
6. **Result**: A focused subset of `.ai-context.md` that maximizes signal-to-noise for the current task

### Fact Registry Relevance

When `draft/.state/facts.json` exists, also load relevant facts:

1. **By file overlap**: Facts whose `source_files` overlap with files the current task will modify
2. **By category**: Facts in categories matching the task's primary concern
3. **By recency**: Prefer facts with recent `last_active_at` timestamps (active code areas)
4. **Limit**: Load at most 20 relevant facts per task to stay within token budget

## Special Sections to Honor

### Accepted Patterns (`tech-stack.md` → `## Accepted Patterns`)

Patterns listed here are **intentional design decisions**. Do NOT flag these as bugs, issues, or violations. They represent deliberate trade-offs documented by the team.

### Guardrails (`draft/guardrails.md`)

Project-level `draft/guardrails.md` has three sections with different enforcement behavior:

| Section | Behavior |
|---------|----------|
| **Hard Guardrails** (checked `[x]`) | Always flag violations as issues |
| **Learned Conventions** | Skip these patterns during analysis — they are verified intentional patterns |
| **Learned Anti-Patterns** | Always flag these patterns — they are verified problematic patterns |
| **Hard Guardrails** (unchecked `[ ]`) | Ignore (not enforced) |

**Legacy fallback:** If `draft/guardrails.md` does not exist, check `draft/workflow.md` for a `## Guardrails` section and enforce checked items there. Suggest running `/draft:learn migrate` to move to the new format.

### Critical Invariants (`.ai-context.md` → `## Critical Invariants`)

Invariants covering data safety, security, concurrency, ordering, and idempotency. Check for violations across all relevant code paths.

## Track Context (when scoped to a track)

If analyzing a specific track, also load:

| File | Purpose |
|------|---------|
| `draft/tracks/<id>/spec.md` | Requirements, acceptance criteria, edge cases |
| `draft/tracks/<id>/plan.md` | Implementation tasks, phases, dependencies |

Use track context to:
- Verify implemented features match spec requirements
- Check edge cases listed in spec are handled
- Focus analysis on files modified/created by the track

## Toolchain & MCP Auto-Connect

After loading Layer 1 context, check `draft/workflow.md` → `## Toolchain` section. Draft uses standard `git` for VCS — see `core/shared/vcs-commands.md` for the command conventions.

### MCP Auto-Connect (optional)

If MCP integrations are checked in `draft/workflow.md`, verify availability at context-load time:

| Server | Verification Call | On Success | On Failure |
|--------|-------------------|------------|------------|
| Jira MCP | `get_issue(key="TEST-1", prune_mode="minimal")` — expect error, confirms server responds | Record: `jira_mcp=available` | Record: `jira_mcp=unavailable`, degrade gracefully |
| Confluence MCP | Check for Confluence tools in environment (e.g., `search_confluence`, `get_page`) | Record: `confluence_mcp=available` | Record: `confluence_mcp=unavailable`, degrade gracefully |
| GitHub MCP | Check for GitHub tools in environment (e.g., `gh_pr_create`, `gh_issue_get`) | Record: `github_mcp=available` | Record: `github_mcp=unavailable`, fall back to `gh` CLI |

MCP availability status is passed to downstream skills. Skills that can leverage MCPs will automatically use them when available, falling back to local-only analysis when unavailable.

### Confluence Integration Points

When Confluence MCP is available, skills can leverage it for documentation lookup:

| Skill | Confluence Use |
|-------|---------------|
| `/draft:init` | Search for existing design documents, architecture docs related to the project |
| `/draft:new-track` | Search for relevant RFCs, design docs, or prior art before starting a track |

## Degradation Behavior

| Scenario | Behavior |
|----------|----------|
| No `draft/` directory | Proceed with code-only analysis (no context enrichment) |
| `.ai-profile.md` missing | Skip Layer 0; proceed directly to Layer 1 context loading |
| `.ai-context.md` missing | Fall back to `draft/architecture.md` if it exists |
| `tech-stack.md` missing | Skip framework-specific checks |
| `product.md` missing | Skip product requirement verification |
| `workflow.md` missing | Skip workflow preferences |
| `guardrails.md` missing | Fall back to `workflow.md ## Guardrails`; if neither exists, skip guardrail enforcement |
| `draft/graph/` missing | Skip Layer 1.5; no structural graph data available |
| `facts.json` missing | Skip Layer 2; no fact-level context available |
| Track files missing | Warn and proceed with project-level scope |

## Context-Enriched Analysis

Once loaded, Draft context enables analysis that pure code reading cannot:

- **Architecture violations** — Coupling or boundary violations against intended module structure
- **Framework-specific checks** — Anti-patterns for the specific frameworks in tech-stack.md
- **Product requirement bugs** — Behavior that contradicts product.md user flows
- **Invariant violations** — Data safety, security, concurrency, ordering, idempotency violations
- **Concurrency analysis** — Race conditions and deadlocks informed by the documented concurrency model
- **Error handling gaps** — Missing failure modes against documented failure recovery matrix
- **State machine violations** — Invalid transitions, missing guards, states with no exit
- **Consistency boundary bugs** — Stale reads, lost events at eventual-consistency seams
- **Guardrail violations** — Checked hard guardrails and learned anti-patterns from guardrails.md
- **False positive suppression** — Learned conventions and accepted patterns are skipped during analysis
- **Precise dependency analysis** — Module boundaries, weighted edges, and cycle detection from graph data (Layer 1.5)
- **Impact assessment** — Blast radius of file changes using graph callers/impact queries
- **Hotspot awareness** — High-complexity, high-fanIn files flagged before modification

## Future MCP Extensions

The following MCP integrations are planned but not yet available. Skills referencing these should use graceful fallback (manual input or skip).

| MCP Server | Purpose | Used By | Status |
|---|---|---|---|
| Monitoring MCP | Metrics dashboards, alert history, SLO status | `incident-response`, `deploy-checklist` | Planned |
| CI/CD MCP | Build status, pipeline triggers, deployment history | `deploy-checklist` | Planned |
| Chat MCP | Slack/Teams notifications, war room creation | `incident-response` | Planned |
| Incident Management MCP | PagerDuty/OpsGenie integration, on-call schedules | `incident-response` | Planned |
| APM MCP | Distributed traces, error tracking, performance profiles | `debug`, `incident-response` | Planned |

When these MCPs become available, update the corresponding skills to auto-connect using the standard MCP auto-connect pattern defined above.
