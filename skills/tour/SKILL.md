---
name: tour
description: Interactive onboarding walkthrough for a new engineer. Use for "give me a tour", "onboard me", "walk me through the codebase".
---

# Draft Tour: Interactive Onboarding

Provide an interactive codebase walk-through based on existing architecture and guardrail constraints.

## Red Flags - STOP if you're:
- Dumping the entire `architecture.md` into the chat window.
- Giving answers to foundational pattern questions before prompting the developer to guess.
- Explaining code the developer hasn't explicitly asked to view yet.

---

## Execution Constraints

1. **Load Context:** Read `draft/architecture.md`, `draft/tech-stack.md`, and `draft/guardrails.md`.
2. **Interactive Cadence:** Ask the developer if they are familiar with the tech stack constraints found in `draft/tech-stack.md`.
3. **Module Introduction:** Instead of listing all modules, introduce the "Entry Point" module first.
4. **Active Challenge:** After explaining a module's responsibility, challenge the developer: "Based on our *Context-Driven Development* rules, how do you think we handle data persistence here?" Wait for their answer before revealing the architecture strategy.
   - If the answer is correct, confirm briefly and cite the supporting line in `architecture.md` / `guardrails.md`.
   - If the answer is partially right, name what they got right, then ask a narrower follow-up (e.g., "Right that we cache reads — what's the invalidation trigger?") before revealing the rest.
   - If the answer is wrong, do not just hand them the answer. Quote the specific guardrail or HLD section that contradicts it, then re-prompt with a hint scoped to that section.
5. **Traceability:** Highlight `draft/.state/facts.json` showing how module constraints have evolved.
6. **Track Lifecycle Walk:** Show the full feature lifecycle and who owns each gate:
   - `/draft:new-track` → `spec.md` (requirements + classification + approvers) + `plan.md` (phases/tasks)
   - `/draft:decompose` → `hld.md` (always, with graph-derived diagrams) + `lld.md` (when --lld or High-complexity module)
   - **Approvers (HLD):** Technical Leads, Architecture Review Board, Cloud Operations (SaaS), QA Leads (on-prem), PM Leads
   - **Approvers (LLD):** Team Leads, Technical Leads, Quality Assurance
   - `/draft:implement` → TDD loop reading lld.md/hld.md for stub generation
   - `/draft:upload` → blocks `git upload` for high/mission-critical tracks until HLD §Approvals signed
   - `/draft:deploy-checklist` → blocks deploy until HLD §Checklist + LLD §Alerting Thresholds populated
   - Walk a real example track from `draft/tracks/` if any exist; otherwise sketch a hypothetical low-criticality flow.
7. **Completion:** Guide the developer to create their first test track using `/draft:new-track` so they understand the artifact loop end-to-end.

---
