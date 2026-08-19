# Cross-Skill Dispatch Convention

Standard convention for how Draft skills invoke, offer, or suggest other skills. All Tier 1 orchestrators and cross-referencing skills follow this pattern.

Convention spec implemented by: All Tier 1 orchestrators (`init`, `new-track`, `implement`, `review`, `upload`), and Tier 2 skills that cross-reference others. Skills implement this dispatch convention independently; see `skills/GRAPH.md` for the full dependency graph.

## Dispatch Tiers

### Tier 1: Auto-Invoke (Silent)

Execute without user confirmation. Used for passive context enrichment and established patterns.

- Load `testing-strategy.md` if it exists (context enrichment)
- Feed quality results to `/draft:learn` (established pattern)
- Sync artifacts to Jira via `core/shared/jira-sync.md` when ticket is linked
- Load `rca.md` into bug track implementation context

**Convention:** No announcement needed. Log in track metadata if applicable.

### Tier 2: Offer (Ask with Default)

Present a choice with a recommended default. Used when the skill adds significant value but the user may want to skip.

Format:

```text
"Run /draft:<skill> to <benefit>? [Y/n]"
```

Examples:

- "Run `/draft:debug` to investigate before writing the spec? [Y/n]" — bug tracks in new-track
- "Run full three-stage review or `/draft:quick-review` for lightweight check? [full]" — phase boundaries in implement
- "Run `/draft:tech-debt` to scope this refactor? [Y/n]" — refactor tracks in new-track

**Convention:** Default answer in brackets. Enter accepts default.

### Tier 3: Suggest (Announce, Don't Block)

Announce availability at completion without blocking. Used for optional follow-up actions.

Format:

```text
"Consider running `/draft:<skill>` to <benefit>."
```

Examples:

- "Consider running `/draft:tech-debt` to catalog debt found during review."
- "Consider running `/draft:documentation api` to document new endpoints."
- "Consider running `/draft:adr` to record this design decision."

**Convention:** Grouped in a "What's Next" or "Suggestions" section at skill completion.

### Tier 4: Detect + Auto-Feed (Smart Context Injection)

Automatically detect when output from one skill is useful to another and inject it as context. No user interaction.

| Source Skill | Output | Target Skill | How Injected |
|---|---|---|---|
| `/draft:debug` | Debug Report | `/draft:new-track` | Fed into spec.md "Reproduction" and "Root Cause Hypothesis" sections |
| `/draft:incident-response` | Postmortem | `/draft:new-track` | Fed into bug track spec context |
| `/draft:tech-debt` | Debt Report | `/draft:new-track` | Fed into refactor track spec scope |
| `/draft:testing-strategy` | Strategy Doc | `/draft:implement` | Loaded into TDD context (coverage targets, test boundaries) |
| `/draft:debug` + RCA agent | `rca.md` | `/draft:implement` | Loaded as investigation context for bug fix implementation |

**Convention:** Check for artifact existence before injection. If not found, skip silently.

## Dispatch Registry

Complete registry of all cross-skill dispatch points:

| Orchestrator | When | Dispatches | Tier |
|---|---|---|---|
| `init` | Brownfield + debt signals detected | `tech-debt` | Suggest |
| `init` | After generating tech-stack.md | `testing-strategy` | Suggest |
| `init` | At completion | `documentation readme` | Suggest |
| `new-track` | Bug track detected | `debug` | Offer |
| `new-track` | Incident/outage keywords | `incident-response postmortem` | Detect + Suggest |
| `new-track` | Refactor track | `tech-debt` | Offer |
| `new-track` | New technology / arch shift | `adr` | Detect + Suggest |
| `new-track` | Plan generation (feature) | `testing-strategy` task, `deploy-checklist` task, `documentation` task | Auto-embed |
| `implement` | Blocked task | `debug` | Offer (replaces inline debugger) |
| `implement` | Before TDD (first task) | `testing-strategy` load | Auto-Invoke |
| `implement` | Bug track before tests | Ask developer | Offer (test guardrail) |
| `implement` | Phase boundary | `quick-review` | Offer |
| `implement` | Track completion | `deploy-checklist`, `documentation`, `tech-debt`, `adr` | Suggest |
| `review` | After Stage 3 | `coverage` | Auto-Invoke |
| `review` | At completion (quality findings) | `tech-debt`, `documentation` | Suggest |
| `upload` | Pre-upload | `deploy-checklist` | Auto-Invoke |
| `upload` | New APIs detected | `documentation api` | Detect + Suggest |
| `upload` | Post-upload success | Jira comment | Auto-Invoke |
| `decompose` | After module decomposition | `testing-strategy`, `documentation api` | Suggest |
| `decompose` | Dependency cycles detected | `tech-debt` | Detect + Suggest |
| `decompose` | Module boundary decisions | `adr` | Auto-Invoke |
| `bughunt` | Critical bugs found | `debug` | Suggest |
| `deep-review` | Architecture debt found | `tech-debt`, `adr` | Suggest |

## Implementation Pattern

Skills implementing dispatch should follow this pattern:

```markdown
## Cross-Skill Dispatch

At this point, check for dispatch opportunities:

### Auto-Invoke
- [list auto-invoke actions relevant to this skill]

### Offer
- [list offer actions relevant to this skill]

### Suggest (at completion)
- [list suggest actions relevant to this skill]
```

## Test Writing Guardrail

**In bug/debug/RCA workflows:** Never auto-write unit tests. Always ask the developer first.

Applies to: `/draft:debug`, `/draft:implement` (bug tracks), auto-triage pipeline, `/draft:bughunt`
Does NOT apply to: Feature tracks with TDD enabled, `/draft:coverage`

```text
If track type is "bugfix" OR current context is debug/RCA:
  BEFORE writing any test file:
    ASK: "Want me to write [regression/unit] tests for [description]? [Y/n]"
    If declined: skip test writing, note in plan.md: "Tests: developer-handled"
```
