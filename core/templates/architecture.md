---
type: Architecture
project: "{PROJECT_NAME}"
module: "root"
generated_by: "draft:init"
generated_at: "{ISO_TIMESTAMP}"

# Ownership — enterprise accountability.
ownership:
  codeowners_file: "{path-to-CODEOWNERS or 'none'}"
  primary_owners: ["{team-or-person}"]
  security_contact: "{email-or-channel-or-'N/A'}"
  oncall: "{pagerduty/opsgenie URL or 'none'}"

# Verification — stamped by draft:init at render time.
verification:
  citations_verified: "{true | false | unchecked}"
  staleness_hash: "{sha256 of tracked source set at synced_to_commit}"
  graph_schema_version: "{semver or 'absent'}"

# Graph fidelity (mandatory, forward-looking)
graph:
  build_status: "{success | failed | absent}"
  overall_fidelity: "{high | mixed | low | stub}"
  language_fidelity:
    python: "{stub (directory-level only) | approximate | high}"
    typescript: "{stub | approximate | high}"
    rust: "{approximate | high}"
    cpp: "{high}"
    go: "{approximate | high}"
  stats:
    modules: "{N from schema.yaml}"
    edges: "{total_edges from engine: get_architecture .edges}"
    hotspots: "{N}"
  notes: "{explicit fidelity summary from engine: get_architecture .languages/.packages}"
generation_notes: "{High existing context detected via audit — see §10 Relationship for deference | Standard graph-primary generation}"
---

# Architecture: {PROJECT_NAME}

> Graph-primary, high-signal engineering reference for AI coding assistants and humans.
> For the token-optimized machine version, see `draft/.ai-context.md`.
> The knowledge graph is the deterministic structural spine. LLM synthesis exists only to interpret dynamic behavior, state machines, and rationale not visible in the static graph. Fidelity is declared explicitly. Provenance is mandatory on all claims.

**Graph Health & Fidelity Dashboard** (populated at generation time from the `graph:` block; future agents must read this first):

| Language/Area | Fidelity | Modules | Edges | Hotspots | Notes |
|---------------|----------|---------|-------|----------|-------|
| Python        | {stub}   | {N}     | {N}   | {N}      | {e.g. directory-level only} |
| Rust          | {high}   | {N}     | {N}   | {N}      | {graph-derived} |
| ...           | ...      | ...     | ...   | ...      | ... |

> Low-fidelity areas are explicitly called out in §9. This document never pretends richer graph data than actually exists.

## Generation Contract (read first — binding)

1. **Graph is structural truth.** Module boundaries, dependencies, public surfaces, hotspots, and call relationships come from `draft/graph/`. LLM never invents them.
2. **Fidelity declaration is non-negotiable.** Every major claim carries an explicit tag: `[Graph:High]`, `[Graph:Stub]`, `[Existing:CLAUDE.md §3]`, `[Human:Synthesis]`, or `[Test-backed:INV-042]`.
3. **Provenance on all claims.** Invariants, failure modes, lock ordering, and data truth sources must name their source and enforcement.
4. **Diagrams > prose.** One accurate Mermaid workflow/state/sequence diagram grounded in the graph is worth more than paragraphs of generic description.
5. **No duplication of excellent existing agent docs.** When the Context Audit detects CLAUDE.md / INVARIANTS.md / ADRs, this document defers and cross-references. It supplies the graph spine and synthesis, not a parallel prose copy.
6. **Honest gaps.** §9 is mandatory and high-value. Future agents must be able to read the fidelity table + gaps section and know exactly where to distrust the model.
7. **Accuracy over volume.** Short, precise, graph-anchored sections are correct. Historical line-count or diagram-count targets are retired.

Absence is signal. If a section does not apply, state the precise reason referencing graph data or classification.

---

## 1. Executive Summary + Graph Health Dashboard

One tight paragraph: what the system is, what it does, its role in the larger environment.

The Graph Health & Fidelity Dashboard (above) is the first artifact any reader or agent must internalize.

---

## 2. Critical Invariants & Safety Rules (Highest Priority)

The longest and most precise section.

Every invariant must include:
- Precise statement
- Why violation is dangerous
- Enforcement mechanism (test, runtime, type system, review, graph constraint, or none)
- Provenance / Fidelity tag + source (e.g. `docs/INVARIANTS.md:INV-003`, `Graph:High`, `Human Judgment`)

Example format:

```
### INV-003: Sentinel Lock Ordering
**Rule**: `_strategies_lock < _strategy_process_locks < _global_capacity_lock < entry_lock`
**Fidelity**: High (enforced in code + tests)
**Graph Evidence**: Not expressible in static graph (dynamic ordering)
**Source**: docs/INVARIANTS.md + src/.../sentinel/...
**Enforcement**: test + code review
```

---

## 3. Primary Control & Data Flows (Graph + Synthesis)

Focus on the highest-value dynamic behavior:

- Dominant request / data / control flows (end-to-end)
- State machines with financial or safety impact
- Lifecycle sequences (bootstrap, shutdown, reconciliation, failover)

Each backed by:
- Graph-derived paths where available
- High-quality Mermaid (stateDiagram-v2, sequenceDiagram, or detailed flowchart)
- Explicit note when the flow is only partially visible in the graph

---

## 4. Module & Dependency Map (Primarily Graph-Derived)

- Module dependency graph rendered from live engine query `scripts/tools/graph-arch.sh --repo . | jq '.packages'` + `scripts/tools/mermaid-from-graph.sh --repo . --diagram module-deps` (generated live, never committed)
- High fan-in / fan-out modules highlighted
- Cyclic dependencies called out
- Cross-language boundaries (FFI, RPC, shared memory) explicitly surfaced with coverage notes

Include a short "graph coverage for this view" paragraph.

---

## 5. Concurrency, Ownership & Isolation Model

- Single-writer patterns and ownership boundaries
- Lock ordering (explicitly tagged when not graph-expressible)
- Async / thread-pool / actor boundaries
- Failure isolation regions

---

## 6. Error Handling & Failure Mode Catalog

For every major component or flow:
- What can go wrong
- How it is detected
- The defined safe response
- Whether enforcement is graph, test, runtime, or process

---

## 7. State & Data Truth Sources + Reconciliation

For each major domain:
- Authoritative source
- Derived / cached views
- Reconciliation mechanisms and lag tolerance
- Staleness policy

---

## 8. Extension Points & Safe Mutation Patterns

How to add new behavior without violating invariants. Include registration sites, required vs optional contracts, and test patterns. Graph-derived where possible.

---

## 9. Graph Coverage Gaps & Known Limitations (MANDATORY)

Explicit, honest list of where the document and underlying graph are weak or absent.

- Per-language fidelity shortfalls (copy from Dashboard)
- Areas where synthesis or existing high-quality docs were the real ground truth
- Remaining hallucination risk for future agents
- "Future agents should re-verify X against source before acting here"

This section is one of the most valuable outputs for safety-critical or low-graph-fidelity systems.

---

## 10. Relationship to Other Authoritative Documentation (MANDATORY when Context Audit high/medium)

When the Pre-Check Context Audit detects strong agent-optimized sources (CLAUDE.md, INVARIANTS.md, ADRs, etc.):

- List the detected files with one-line characterization
- State exactly what this architecture.md supplies (graph spine, deterministic maps, visual synthesis, provenance on claims)
- State what it defers to, with concrete cross-references
- Explicit confirmation that no large-scale prose duplication of the existing authoritative material occurred

When no high context was detected: short note that this document is the primary self-contained reference.

---

## Fidelity & Provenance Rules (Strict — apply everywhere)

Every claim or section must be tagged with one of:

- `Graph-Derived (High)` — direct from rich graph data
- `Graph-Derived (Approximate)` — tree-sitter / static analysis
- `Graph-Derived (Stub)` — directory/file counts only
- `Human + Graph` — graph shows structure; synthesis added rationale or dynamic behavior
- `Human Judgment` — not (yet) expressible in the graph (lock ordering, certain safety rules) — always call out
- `Existing Authoritative Doc` — defers to CLAUDE.md / INVARIANTS.md etc.

AI agents are trained by the document itself to treat Stub and Human Judgment claims with calibrated caution.

---

**End of clean graph-primary architecture template.**

This is the single forward-looking source of truth. Legacy 28-section volume-oriented material has been retired.