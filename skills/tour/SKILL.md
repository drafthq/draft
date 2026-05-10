---
name: tour
description: "Engaging, interactive onboarding tour of the repository to train new engineers on system architecture and patterns without passive reading. Use when the user asks for a 'code tour', 'walk me through the codebase', 'onboard me', 'show me the architecture', or says 'I am new here, where do I start'."
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
5. **Traceability:** Highlight `draft/.state/facts.json` showing how module constraints have evolved.
6. **Completion:** Guide the developer to create their first test track using `/draft:new-track` so they understand the artifact loop.

---
