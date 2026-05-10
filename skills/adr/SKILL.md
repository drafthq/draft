---
name: adr
description: "Create and manage Architecture Decision Records. Documents significant technical decisions with context, alternatives, and consequences. Also supports evaluate (assess proposals) and design (system design) modes. Use when the user asks to 'document a decision', 'create an ADR', 'evaluate a proposal', 'design a system', or says 'why did we choose X', 'record this decision'."
---

# Architecture Decision Records

Create or manage Architecture Decision Records (ADRs) for this project.

## Red Flags - STOP if you're:

- Creating an ADR without understanding the decision context
- Documenting trivial decisions that don't warrant an ADR (e.g., variable naming)
- Writing an ADR after the fact without capturing the original reasoning
- Listing alternatives without genuine pros/cons analysis
- Skipping the "Consequences" section (the most valuable part)
- Not checking existing ADRs for conflicts or superseded decisions

**ADRs capture WHY, not just WHAT. Every decision needs alternatives considered.**

---

## Pre-Check

1. Verify Draft is initialized:
```bash
ls draft/ 2>/dev/null
```

If `draft/` doesn't exist:
- Tell user: "Project not initialized. Run `/draft:init` first."
- Stop here.

2. Check for existing ADR directory:
```bash
ls draft/adrs/ 2>/dev/null
```

If `draft/adrs/` doesn't exist, create it:
```bash
mkdir -p draft/adrs
```

## Step 1: Parse Arguments

Check for arguments:
- `/draft:adr` — Interactive mode: ask about the decision
- `/draft:adr "decision title"` — Create ADR with given title
- `/draft:adr list` — List all existing ADRs
- `/draft:adr supersede <number>` — Mark an ADR as superseded

### List Mode

If argument is `list`:
1. Read all files in `draft/adrs/`
2. Display summary table:

```
Architecture Decision Records

| # | Title | Status | Date |
|---|-------|--------|------|
| 001 | Use PostgreSQL for primary storage | Accepted | 2026-01-15 |
| 002 | Adopt event-driven architecture | Proposed | 2026-02-01 |
| 003 | Replace REST with GraphQL | Superseded by #005 | 2026-02-03 |
```

Stop here after listing.

### Supersede Mode

If argument is `supersede <number>`:
1. Read the ADR file `draft/adrs/<number>-*.md`
2. Change status from `Accepted` to `Superseded by ADR-<new_number>`
3. In the OLD ADR's References section, add: "Superseded by ADR-<new_number>"
4. Ask what new ADR supersedes it, or create the new one
5. In the NEW ADR's References section, add: "Supersedes ADR-<old_number>"
6. Stop here after updating.

### Evaluate Mode

If argument starts with `evaluate`:
- `/draft:adr evaluate <proposal or description>` — Evaluate a design proposal

1. Read the proposal (from arguments, pasted text, file path, or ask user to describe)
2. Load project context: `draft/tech-stack.md`, `draft/.ai-context.md`, `draft/architecture.md`
3. Check existing ADRs in `draft/adrs/` for related decisions
4. Evaluate against six dimensions:
   - **Architecture alignment:** Does it fit current patterns?
   - **Tech stack consistency:** Does it introduce technology not in tech-stack.md?
   - **Invariant impact:** Does it affect critical invariants from .ai-context.md?
   - **Scalability:** How does it scale with data/users/team growth?
   - **Operational complexity:** What new operational burden does it add?
   - **Team familiarity:** Does the team have experience with this approach?

5. Output evaluation report (do not save to file — display directly):

```
# Design Evaluation: <Title>

## Summary
[1-2 sentence assessment]

## Alignment Analysis
| Dimension | Assessment | Notes |
|-----------|------------|-------|
| Architecture alignment | ✅ Aligned / ⚠️ Partial / ❌ Conflict | [detail] |
| Tech stack consistency | ✅/⚠️/❌ | [detail] |
| Invariant impact | ✅/⚠️/❌ | [detail] |
| Scalability | ✅/⚠️/❌ | [detail] |
| Operational complexity | ✅/⚠️/❌ | [detail] |
| Team familiarity | ✅/⚠️/❌ | [detail] |

## Risks
- [Risk and mitigation strategy]

## Recommendation
[Accept as-is / Accept with modifications / Reconsider approach / Reject — with reasoning]

## Next Steps
If this leads to a decision: `/draft:adr "<decision title>"` to document it
If this needs a full design: `/draft:adr design "<system>"` to design it
```

Stop here after evaluation.

### Design Mode

If argument starts with `design`:
- `/draft:adr design <system or component>` — Full system/component design

1. Gather requirements:
   - Ask user or extract from arguments: What does it need to do?
   - **Functional requirements** — Features and behaviors
   - **Non-functional requirements** — Scale, latency, availability, cost targets
   - **Constraints** — Team size, timeline, existing tech stack (from `draft/tech-stack.md`)

2. Load project context: same as ADR creation (Step 3 of main flow)

3. Design using 5-section framework:

   **Section 1: Requirements**
   - Functional requirements (bulleted list)
   - Non-functional requirements (table: dimension, target, rationale)
   - Constraints and assumptions

   **Section 2: High-Level Design**
   - Component diagram (ASCII)
   - Data flow description
   - API contracts (key endpoints/interfaces)
   - Storage choices with rationale

   **Section 3: Deep Dive**
   - Data model design (key entities and relationships)
   - API endpoint design (REST/GraphQL/gRPC with examples)
   - Caching strategy (what, where, TTL, invalidation)
   - Queue/event design (if applicable)
   - Error handling and retry logic

   **Section 4: Scale & Reliability**
   - Load estimation (requests/sec, data growth)
   - Scaling strategy (horizontal vs vertical)
   - Failover and redundancy
   - Monitoring and alerting requirements

   **Section 5: Trade-off Analysis**
   - Key trade-offs made (table: decision, alternative, why this choice)
   - What to revisit as the system grows
   - Risks and mitigations

4. Determine design document number using same ADR numbering (Step 4 of main flow)
5. Save to `draft/adrs/<number>-design-<kebab-case-title>.md` with YAML frontmatter and git metadata (same format as ADR creation, Step 5)
6. Present for review (same as Step 6 of main flow)

Stop here after design.

## Step 2: Gather Decision Context

If in interactive mode (no title provided), ask:

1. "What technical decision needs to be documented?"
2. "What's the context? What forces are driving this decision?"
3. "What alternatives did you consider?"

If title provided, proceed directly with the title.

## Step 3: Load Project Context

Follow the base procedure in `core/shared/draft-context-loading.md`.

Read relevant Draft context:
- `draft/.ai-context.md` — Current architecture patterns, invariants, data paths, and constraints. Falls back to `draft/architecture.md` for legacy projects.
- `draft/tech-stack.md` — Current technology choices
- `draft/product.md` — Product requirements that influence the decision

Cross-reference the decision against existing context:
- Does it align with documented architecture patterns?
- Does it introduce a new technology not in tech-stack.md?
- Does it affect product requirements?

## Step 4: Determine ADR Number

```bash
# Extract the highest existing ADR number from filenames
ls draft/adrs/*.md 2>/dev/null | sed 's/.*\/\([0-9]*\)-.*/\1/' | sort -n | tail -1
```

Next number = highest existing ADR number + 1, zero-padded to 3 digits (001, 002, ...). If no ADRs exist, start at 001.

Verify the target filename `draft/adrs/<number>-<kebab-case-title>.md` does not already exist. If collision, increment the number until a free slot is found.

## Step 5: Create ADR File

**MANDATORY: Include YAML frontmatter with git metadata.** Gather git info first:

```bash
git branch --show-current                    # LOCAL_BRANCH
git rev-parse --abbrev-ref @{upstream} 2>/dev/null || echo "none"  # REMOTE/BRANCH
git rev-parse HEAD                           # FULL_SHA
git rev-parse --short HEAD                   # SHORT_SHA
git log -1 --format=%ci HEAD                 # COMMIT_DATE
git log -1 --format=%s HEAD                  # COMMIT_MESSAGE
git status --porcelain | head -1 | wc -l     # 0 = clean, >0 = dirty
```

Create `draft/adrs/<number>-<kebab-case-title>.md`:

```markdown
---
project: "{PROJECT_NAME}"
module: "root"
adr_number: <number>
generated_by: "draft:adr"
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

# ADR-<number>: <Title>

| Field | Value |
|-------|-------|
| **Branch** | `{LOCAL_BRANCH}` → `{REMOTE/BRANCH}` |
| **Commit** | `{SHORT_SHA}` — {COMMIT_MESSAGE} |
| **Generated** | {ISO_TIMESTAMP} |
| **Synced To** | `{FULL_SHA}` |

**Status:** Proposed
**Deciders:** [names or roles]

## Context

[What is the issue that we're seeing that is motivating this decision or change?]
[What forces are at play (technical, business, organizational)?]

## Decision

[What is the change that we're proposing and/or doing?]
[State the decision in active voice: "We will..."]

## Alternatives Considered

### Alternative 1: <name>
- **Pros:** [advantages]
- **Cons:** [disadvantages]
- **Why rejected:** [specific reason]

### Alternative 2: <name>
- **Pros:** [advantages]
- **Cons:** [disadvantages]
- **Why rejected:** [specific reason]

## Consequences

### Positive
- [Benefit 1]
- [Benefit 2]

### Negative
- [Trade-off 1]
- [Trade-off 2]

### Risks
- [Risk and mitigation]

## References

- [Link to relevant discussion, RFC, or documentation]
- [Related ADRs: ADR-xxx]
```

## Step 6: Present for Review

Present the ADR to the user for review:

```
ADR-<number> created: <title>
File: draft/adrs/<number>-<kebab-case-title>.md
Status: Proposed

Review the ADR and update status to "Accepted" when approved.
```

## Step 7: Update References (if applicable)

If the decision affects existing Draft context:

1. **tech-stack.md** — If introducing or removing technology, note: "Consider updating draft/tech-stack.md to reflect this decision."
2. **architecture.md** — If changing architectural patterns, note: "Consider updating `draft/architecture.md` to reflect this decision (`.ai-context.md` will be auto-refreshed via Condensation Subroutine)."
3. **Superseded ADRs** — If this decision replaces a previous one, update the old ADR's status.

## ADR Status Lifecycle

```
Proposed → Accepted → [Deprecated | Superseded by ADR-xxx]
```

- **Proposed** — Decision documented, awaiting review
- **Accepted** — Decision approved and in effect
- **Deprecated** — Decision no longer relevant (context changed)
- **Superseded** — Replaced by a newer decision (link to replacement)

## Error Handling

**If no draft/ directory:**
- Tell user to run `/draft:init` first

**If ADR number conflict:**
- Increment to next available number
- Warn: "ADR-<number> already exists. Using ADR-<next>."

**If superseding non-existent ADR:**
- Warn: "ADR-<number> not found. Check `draft/adrs/` for valid ADR numbers."
