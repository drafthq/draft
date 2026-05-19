---
project: "{PROJECT_NAME}"
module: "{MODULE_NAME or 'root'}"
generated_by: "draft:new-track"
generated_at: "{ISO_TIMESTAMP}"
---

# Intake Questions

Structured questions for track creation. **Ask ONE question at a time.** Wait for user response before proceeding. Update drafts progressively.

---

## Flow Instructions

**CRITICAL:** This is a conversation, not a form. Follow this pattern for EACH question:

1. **Ask** — One question only. Wait for response.
2. **Listen** — Process the user's answer.
3. **Contribute** — Add your expertise (patterns, risks, alternatives, citations).
4. **Update** — Modify spec-draft.md with what's been established.
5. **Bridge** — Summarize briefly, then ask the next question.

**DO NOT** dump multiple questions at once. The value is in the dialogue.

---

## Phase 1: Initial Context

### Question 1.1: Existing Documentation
> Start here. Gather any existing context before diving in.

**Ask:**
> "Do you have existing documentation for this work? (PRD, RFC, design doc, Jira ticket, or any notes)"

**If yes:**
- Request the document or key excerpts
- Ingest and extract: goals, requirements, constraints, open questions
- Summarize: "I've extracted [X, Y, Z]. I notice [gap] isn't covered yet."

**If no:**
- Acknowledge: "No problem. Let's build this from scratch together."
- Proceed to Phase 2

**Update spec-draft.md:** Add any extracted context to relevant sections.

---

## Phase 2: Problem Space

### Question 2.1: Problem Definition
**Ask:**
> "What problem are we solving?"

**After response, contribute:**
- Pattern recognition: "This sounds similar to [industry pattern]..."
- Domain concepts: Reference Jobs-to-be-Done, DDD problem space if relevant
- Clarifying probe: "When you say [X], do you mean [A] or [B]?"

**Update spec-draft.md:** Problem Statement section.

---

### Question 2.2: Urgency & Impact
**Ask:**
> "Why does this problem matter now? What happens if we don't solve it?"

**After response, contribute:**
- Validate urgency: Is this symptom or root cause?
- Impact analysis: Who's affected? How severely?
- Reference: 5 Whys technique if they're describing symptoms

**Update spec-draft.md:** Background & Why Now section.

---

### Question 2.3: Users & Workarounds
**Ask:**
> "Who experiences this pain? How do they currently cope?"

**After response, contribute:**
- User segmentation: Are there different user types with different needs?
- Workaround analysis: Current workarounds often reveal requirements
- Prior art: "Similar products handle this by [X]..."

**Update spec-draft.md:** Add user context to Background.

---

### Question 2.4: Scope Boundary
**Ask:**
> "What's the scope boundary? Where does this problem end and adjacent problems begin?"

**After response, contribute:**
- Identify adjacent problems that should NOT be solved here
- Reference: Bounded Context (DDD)
- Flag scope creep risks: "I'd suggest explicitly excluding [X]..."

**Update spec-draft.md:** Non-Goals section.

---

### Checkpoint: Problem Space Complete

**Summarize:**
> "Here's what we've established about the problem:
> - Problem: [summary]
> - Why now: [summary]
> - Users: [summary]
> - Scope: [in] / [out]
>
> Does this capture it accurately, or should we refine anything before moving to solutions?"

**Wait for confirmation before proceeding.**

---

## Phase 3: Solution Space

### Question 3.1: Simplest Solution
**Ask:**
> "What's the simplest version that solves this problem?"

**After response, contribute:**
- MVP identification: What's truly essential vs nice-to-have?
- Gold-plating risks: "We could simplify by [X]..."
- Reference: YAGNI, Walking Skeleton, Tracer Bullet (Pragmatic Programmer)

**Update spec-draft.md:** Requirements > Functional section.

---

### Question 3.2: Approach Rationale
**Ask:**
> "Why this approach over alternatives?"

**After response, contribute:**
- Present 2-3 alternative approaches with trade-offs
- Reference: Architecture Decision Records pattern
- Probe: "Have you considered [alternative]? Trade-off would be [X]..."

**Update spec-draft.md:** Technical Approach section.

---

### Question 3.3: Explicit Non-Goals
**Ask:**
> "What are we explicitly NOT doing? What should be out of scope?"

**After response, contribute:**
- Suggest common scope creep items to exclude
- Reference: Anti-goals pattern, MoSCoW prioritization
- "I'd recommend also excluding [X] to keep scope tight..."

**Update spec-draft.md:** Non-Goals section (append to existing).

---

### Question 3.4: Architecture Fit
**Ask:**
> "How does this fit with the current architecture?"

**After response, contribute:**
- Cross-reference `draft/.ai-context.md` (or `draft/architecture.md`) for integration points
- Identify affected modules/components
- Reference: Clean Architecture boundaries, module coupling
- Flag: "This will touch [modules]. Consider [integration pattern]..."

**Update spec-draft.md:** Context References and Technical Approach.

---

### Question 3.5: Reusable Patterns
**Ask:**
> "What existing patterns or components can we leverage?"

**After response, contribute:**
- Search codebase context for reusable patterns
- Suggest tech-stack.md conventions to follow
- Reference: DRY, existing abstractions
- "I see [existing component] could be extended for this..."

**Update spec-draft.md:** Technical Approach section.

---

### Checkpoint: Solution Space Complete

**Summarize:**
> "Here's the proposed solution:
> - Approach: [summary]
> - Why this approach: [rationale]
> - Not doing: [non-goals]
> - Architecture fit: [affected modules]
> - Reusing: [existing patterns]
>
> Ready to discuss risks, or want to refine the approach?"

**Wait for confirmation before proceeding.**

---

## Phase 4: Risk & Constraints

### Question 4.1: What Could Go Wrong
**Ask:**
> "What could go wrong with this approach?"

**After response, contribute:**
- Surface risks user may not have considered
- Security: Reference OWASP Top 10 if relevant
- Performance: Identify potential bottlenecks
- Edge cases: "What happens when [edge case]?"
- Reference: Failure mode analysis, distributed systems fallacies

**Update spec-draft.md:** Open Questions section.

---

### Question 4.2: Dependencies & Blockers
**Ask:**
> "What dependencies or blockers exist? (External APIs, other teams, data, infrastructure)"

**After response, contribute:**
- Identify external dependencies and their reliability
- Team dependencies: Who else needs to be involved?
- Data dependencies: What data do we need? Where does it come from?
- Reference: Critical path analysis

**Update spec-draft.md:** Open Questions and Technical Approach.

---

### Question 4.3: Assumptions
**Ask:**
> "What assumptions are we making? Why might this fail?"

**After response, contribute:**
- List implicit assumptions explicitly
- Fact-check against `draft/tech-stack.md` and `draft/.ai-context.md`
- Reference: Pre-mortem technique
- "I'm assuming [X]. If that's wrong, [consequence]..."

**Update spec-draft.md:** Open Questions section.

---

### Question 4.4: Constraints
**Ask:**
> "What constraints must we operate within? (Timeline, tech limitations, compliance, performance requirements)"

**After response, contribute:**
- Identify tech constraints from tech-stack.md
- Performance requirements: Latency, throughput, scale
- Compliance: GDPR, SOC2, industry-specific
- Reference: 12-Factor App constraints, NFR frameworks

**Update spec-draft.md:** Requirements > Non-Functional section.

---

### Question 4.5: Security & Compliance
**Ask:**
> "Are there security or compliance considerations?"

**After response, contribute:**
- Flag relevant OWASP concerns
- Data privacy: PII handling, encryption, access control
- Authentication/authorization patterns
- Reference: OWASP ASVS, security by design principles

**Update spec-draft.md:** Requirements > Non-Functional section.

---

### Checkpoint: Risks Complete

**Summarize:**
> "Key risks and constraints identified:
> - Risks: [list]
> - Dependencies: [list]
> - Assumptions: [list]
> - Constraints: [list]
> - Security: [considerations]
>
> Anything else that could derail this, or ready to define success criteria?"

**Wait for confirmation before proceeding.**

---

## Phase 5: Success Criteria

### Question 5.1: Definition of Done
**Ask:**
> "How do we know this is complete? What must be true when we're done?"

**After response, contribute:**
- Suggest measurable acceptance criteria
- Convert vague criteria to testable outcomes
- Reference: SMART criteria, Given-When-Then format
- "I'd phrase that as: 'Given [X], when [Y], then [Z]'..."

**Update spec-draft.md:** Acceptance Criteria section.

---

### Question 5.2: Verification Strategy
**Ask:**
> "How will we verify it works correctly?"

**After response, contribute:**
- Suggest testing strategies appropriate to feature type
- Reference: Test pyramid, TDD practices
- Integration testing: What integration points need testing?
- "I'd recommend [unit/integration/e2e] tests for [component]..."

**Update spec-draft.md:** Acceptance Criteria section.

---

### Question 5.3: Stakeholder Acceptance
**Ask:**
> "What would make stakeholders accept this? What does success look like to them?"

**After response, contribute:**
- Align with product.md goals
- Suggest demo scenarios
- Reference: Stakeholder analysis, acceptance criteria patterns
- "For [stakeholder], I'd demonstrate [specific scenario]..."

**Update spec-draft.md:** Acceptance Criteria section.

---

### Checkpoint: Success Criteria Complete

**Summarize:**
> "Success criteria defined:
> - Done when: [criteria list]
> - Verified by: [testing approach]
> - Stakeholders accept when: [demo scenarios]
>
> Ready to finalize the spec?"

**Wait for confirmation before proceeding.**

---

## Phase 6: Finalization

### Spec Review

**Present complete spec-draft.md:**
> "Here's the complete specification:
> [Display spec-draft.md content]
>
> Open questions remaining: [list any]
>
> Ready to finalize this spec, or any changes needed?"

**If changes needed:**
- Discuss specific sections
- Update spec-draft.md
- Return to this review step

**If confirmed:**
- Promote spec-draft.md → spec.md
- Announce: "Spec finalized. Now let's create the implementation plan."

---

### Plan Creation

**After spec is finalized, propose plan structure:**
> "Based on the spec, I propose these phases:
> - Phase 1: [name] — [goal]
> - Phase 2: [name] — [goal]
> - Phase 3: [name] — [goal]
>
> Each phase will have specific tasks with file references and tests.
> Does this phasing make sense, or should we adjust?"

**After confirmation:**
- Build out detailed plan-draft.md with tasks
- Present for review
- On confirmation: promote plan-draft.md → plan.md

---

## Anti-Patterns

**STOP if you're doing any of these:**

- Asking multiple questions at once
- Moving to next question before user responds
- Accepting answers without contributing expertise
- Not citing sources when giving advice
- Skipping checkpoints between phases
- Not updating drafts after each answer
- Rushing to finalization without thorough exploration

**The goal is collaborative understanding, not speed.**
