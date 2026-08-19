# Chapter 17: Pattern Learning

Part IV: Quality· Chapter 15

5 min read

A new developer joins the team and notices that every database call in the codebase is wrapped in a transaction, even single reads. "Is this intentional?" she asks. Nobody remembers who started the pattern or why, but it has been that way for two years and nothing has broken. Three months later, an AI coding agent generates a database module without transaction wrappers. The code review catches it, but only because a human happened to know the convention./draft:learncatches it automatically — because it already discovered that pattern, recorded it, and taught the AI to enforce it.

## How Pattern Learning Works

/draft:learnscans the codebase for recurring patterns — code structures that appear three or more times consistently. It distinguishes betweenconventions(patterns the team intentionally follows) andanti-patterns(patterns that cause bugs, security issues, or performance problems). Both are recorded indraft/guardrails.md, where they feed into every subsequent quality command.

## The Evidence Threshold

Pattern learning is conservative by design. A single occurrence is an example. Two occurrences might be coincidence. Three or more consistent occurrences are a pattern worth recording.

The last row is critical. If a pattern appears in eight files but two of them do it differently, that is not a convention — it is a conflict that needs human attention./draft:learndoes not paper over inconsistencies; it surfaces them.

Pattern learning never infers from fewer than three occurrences, never auto-promotes to hard guardrails without human approval, never overwrites human-curated entries, and never learns framework defaults as project conventions. The rule is simple: quantity over anecdote.

## Two Categories

Every learned pattern falls into one of two categories, and the distinction determines how quality commands treat it.

### Conventions (Skip in Future)

A convention is a pattern that is consistently applied and does not cause bugs. When a convention is recorded, future runs of/draft:reviewand/draft:bughuntwill not flag it as unusual or suspicious. This eliminates false positives.

### Anti-Patterns (Always Flag)

An anti-pattern is a pattern that is consistently applied but causes or risks bugs, security issues, or performance problems. When an anti-pattern is recorded, every future quality command will flag it.

## Temporal Metadata

Every learned pattern carries four timestamps that enable temporal reasoning about the codebase's evolution:

These timestamps answer questions that occurrence counts alone cannot. A pattern discovered recently but established two years ago is a well-entrenched convention. A pattern established last month and actively spreading is an emerging convention. A pattern wherelast_activeis six months old and all occurrences live in legacy code is a declining pattern that the team is phasing out.

## Temporal Analysis: Declining vs. Emerging Patterns

/draft:learnusesgit blameto detect the trajectory of each pattern. If a pattern appears heavily in files last modified over a year ago but rarely in files modified within the past six months, it is flagged as declining. The occurrence ratio old:new greater than 3:1 triggers the declining classification.

This matters because a declining pattern should not be enforced. If the team is migrating from manual error logging to structured error middleware, learning the old pattern as a convention would create friction — flagging every new file that correctly uses the new approach as inconsistent. Instead, declining patterns are annotated but not propagated to quality commands.

A pattern emerges when a developer introduces a new approach. It becomes a convention when others adopt it. It plateaus as the standard way. It declines when a better approach arrives./draft:learntracks where each pattern sits in this lifecycle, so it enforces living conventions and leaves dying patterns alone.

## The Seven Dimensions Scanned

/draft:learnanalyzes the codebase across seven dimensions, looking for recurring structures in each:

* Error handling— How errors are caught, logged, propagated. Custom error classes, retry strategies, error boundaries
* Naming— Variable, function, file naming conventions beyond language defaults. Module organization patterns
* Architecture— Import patterns, state management approaches, API call patterns, component composition
* Concurrency— Async/await conventions, locking approaches, queue patterns, cancellation handling
* Data flow— Validation placement, serialization conventions, caching strategies, transformation pipelines
* Testing— Test file placement, structure (arrange/act/assert vs. given/when/then), mock conventions, fixture patterns
* Configuration— Environment variable access patterns, feature flag patterns, config file conventions
Before recording any candidate,/draft:learncross-references it againsttech-stack.md(already documented patterns), existingguardrails.mdentries (already learned), and.ai-context.md(architecture-level documentation). No duplication occurs.

## How Patterns Feed Into Guardrails

draft/guardrails.mdhas three sections, each treated differently by quality commands:

Hard guardrails are human-written rules that override everything. Learned entries complement them but never replace them. If a learned pattern conflicts with a hard guardrail, the hard guardrail wins.

## Auto-Eviction

Each section inguardrails.mdis capped at 50 learned entries. When capacity is reached, the oldest medium-confidence entry that has not been re-verified in 90+ days is evicted to make room. This prevents guardrails from growing unboundedly and ensures that the entries reflect the current state of the codebase, not its history.

Before saving any new pattern,/draft:learnchecks for conflicts with existing entries. If a new candidate contradicts a learned convention, an existing anti-pattern, or a hard guardrail, it presents both patterns side by side and asks the developer to resolve the conflict. Options: keep both (the new pattern is a scoped exception), replace (the pattern has evolved), or discard (the existing entry is correct). No silent overwrites.

## The Promotion Workflow

Learned patterns start as provisional entries. When a pattern reaches high confidence (5+ consistent occurrences, cross-verified), it becomes a promotion candidate. Running/draft:learn promotepresents these candidates for human review:

Promoted conventions move totech-stack.mdunder Accepted Patterns. Promoted anti-patterns become hard guardrails — permanently enforced rules. In both cases, human approval is required./draft:learnnever auto-promotes.

## The Learning Loop

Pattern learning creates a continuous improvement cycle that makes each successive interaction with Draft more precise:

* /draft:initestablishes the project context and createsguardrails.md
* /draft:implementgenerates code following existing guardrails
* /draft:learnscans the codebase, discovers new patterns, updates guardrails
* Next/draft:implementis constrained by the updated guardrails — fewer convention violations, fewer false positives in review
* /draft:reviewand/draft:bughuntread the updated guardrails — skip known conventions, always flag known anti-patterns
* /draft:learn promotegraduates stable patterns to permanent status
Pattern learning also runs as the final phase of/draft:deep-review,/draft:review, and/draft:bughunt. Every quality analysis that discovers patterns feeds them back into guardrails, so the system gets smarter with each run without requiring explicit/draft:learninvocations.

Pattern learning solves a fundamental problem with AI coding assistants: they do not know your conventions. They generate code that works but does not match how your team does things./draft:learnobserves your codebase, extracts the implicit rules your team follows, and makes them explicit in a file the AI reads on every interaction. The AI stops guessing your conventions and starts enforcing them.
