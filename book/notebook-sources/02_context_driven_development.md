# Chapter 2: Context-Driven Development

Part I: Foundation· Chapter 2

10 min read

Consider a funnel. At the top, every possible implementation exists — every framework, every pattern, every architectural choice. With each layer of context you add, the funnel narrows. By the time AI writes code at the bottom, most decisions are already made. The code almost writes itself — because there's only one right way to write it given all the constraints above. That is Context-Driven Development.

## The Core Insight

Draft's methodology rests on a single observation:each layer of context narrows the solution space. When you tell an AI "build a task manager," it has infinite choices. When you tell it "build a task manager with React, TypeScript, and Tailwind," the choices shrink. When you add "using our existing Express API with Prisma ORM and PostgreSQL," they shrink further. When you provide a specification with acceptance criteria, a phased plan with verification steps, and architecture documentation showing every module boundary and data flow — the AI is no longer choosing. It is executing.

This is not about constraining AI's creativity. It is about giving it the same constraints that make experienced human developers productive: deep knowledge of the system, clear requirements, and explicit conventions.

## The Constraint Hierarchy

Draft organizes context into a layered hierarchy. Each layer builds on the previous one, progressively narrowing the set of valid implementations:

Each layer locks in a different class of decisions:

### product.md — What and Why

Defines the product vision, target users, goals, success criteria, and guidelines. This is the widest layer of the funnel. It answers "what are we building and for whom?" without specifying how.

What it locks in:scope boundaries, user personas, business constraints, UX standards. The AI cannot build features nobody asked for because the product definition makes "asked for" explicit.

### tech-stack.md — How (Tools)

Languages, frameworks, libraries, patterns, and accepted design decisions. For brownfield projects, this is auto-detected from your codebase and cross-referenced with your dependency files.

What it locks in:technology choices, dependency constraints, accepted patterns. The AI cannot introduce random dependencies because the allowed set is defined. It includes an "Accepted Patterns" section for intentional design decisions that analysis tools should honor rather than flag.

### architecture.md — How (Structure)

The source of truth. A comprehensive 10-section engineering reference generated from exhaustive codebase analysis. It includes module boundaries, dependency graphs, data flows, API definitions, concurrency models, security architecture, and testing infrastructure — all with real Mermaid diagrams and actual code snippets from your codebase.

What it locks in:module boundaries, interaction contracts, data flow patterns, invariants. The AI cannot violate your architecture because the architecture is explicitly documented with every component, every interface, and every constraint.

architecture.mdis the primary artifact — comprehensive, human-readable, designed for engineers. From it, Draft derives two token-optimized documents:.ai-context.md(200-400 lines for AI consumption) and.ai-profile.md(20-50 lines, always loaded). The source of truth is never the condensed version.

### spec.md — What (Specific)

The specification for a single unit of work. Acceptance criteria, non-goals, technical approach, and explicit scope boundaries. Created through collaborative dialogue — Draft asks probing questions about what you want before generating the spec, not after.

What it locks in:feature scope, acceptance criteria, what's explicitly out of scope. The AI cannot gold-plate or scope-creep because the boundaries are documented and reviewable.

### plan.md — When and Order

A phased task breakdown with dependencies and verification steps. Each task specifies target files and test files. Each phase has completion criteria.

What it locks in:implementation order, task granularity, verification gates. The AI cannot attempt everything at once because the plan enforces sequential, verifiable progress.

## Context Tiering

Not every task needs every document. Loading full architecture documentation to fix a typo wastes tokens and increases the chance of hallucination. Draft uses a three-tier context system inspired by computer memory architecture:

### Tier 0: The Always-On Profile

.ai-profile.mdis an ultra-compact 20-50 line file that contains the essential facts about your project: language, framework, database, auth mechanism, API style, critical invariants, safety rules, active tracks, and recent changes. It is injected into every AI interaction, ensuring that even the simplest task has basic project awareness.

Think of it as the AI equivalent of a developer's muscle memory — the things you know about a project without having to look them up.

### Tier 1: Working Memory

.ai-context.mdis a 200-400 line token-optimized document derived fromarchitecture.md. It contains 15+ mandatory sections: architecture overview, invariants, interface contracts, data flows, concurrency rules, error handling patterns, implementation catalogs, extension cookbooks, testing strategy, and a glossary. It is loaded for any task that involves writing or modifying code.

This is where the AI gets enough context to make correct decisions without the full weight of the architecture document.

### Tier 2: Long-Term Storage

architecture.mdis the full, comprehensive reference — 10 sections with Mermaid diagrams and code snippets. It is loaded for deep reviews, architecture refreshes, and complex analysis tasks. Most day-to-day development never touches this tier directly.

Smaller context windows produce better AI decisions. By loading only what's needed, Draft reduces token consumption, decreases hallucination risk, and keeps the AI focused on the relevant subset of your architecture. The right context for the task — not all the context, all the time.

## Tracks: The Unit of Work

Atrackis Draft's unit of work. It can be a feature, a bug fix, a refactor, or any cohesive piece of development. Each track gets its own directory with its own specification, plan, and implementation state:

Tracks are isolated. Working on one track does not affect another. Each track references the project context (product, tech stack, architecture) but has its own scope, its own plan, and its own progress markers.

### Track Types

Draft auto-detects the track type from the description:

* Feature / Refactor— Detected by keywords like "add," "implement," "refactor," "improve." Gets a standard spec template and flexible phased plan.
* Bug / RCA— Detected by "fix," "bug," "investigate," or references to production incidents. Gets a focused bug spec with Code Locality and Blast Radius sections, and a fixed three-phase plan: Investigate → Root Cause Analysis → Fix & Verify.
### Track Lifecycle

Every track follows the same lifecycle:

* Create—/draft:new-track "Add drag-and-drop reordering"initiates collaborative spec creation
* Plan— After spec approval, Draft generates a phased plan with task-level granularity
* Review— The developer reviews spec and plan, edits them, commits them for peer review
* Implement—/draft:implementexecutes tasks one at a time, following TDD cycles when enabled
* Verify— Three-stage review validates the implementation against the spec
* Complete— All acceptance criteria met, track marked complete
This is Draft's most important feature. The AI creates the spec and plan. The developer reviews and edits them. The team approves the approach via PR. Only then does implementation begin. Disagreements are resolved by editing a paragraph, not rewriting a module. This is cheaper, faster, and produces better outcomes than reviewing AI-generated code after the fact.

## Status Markers

Draft uses four status markers throughout specs and plans to track progress at the task level:

* [ ]Pending— Not yet started
* [~]In Progress— Currently being implemented
* [x]Completed— Done and verified
* [!]Blocked— Cannot proceed, requires attention
These markers are not cosmetic./draft:implementscans the plan for the first[ ]or[~]task and works on that./draft:statusreads these markers to generate progress reports. They are the control mechanism that keeps implementation sequential and verifiable.

## How This Differs from "Better Prompting"

The most common response to "AI generates wrong code" is "write better prompts." Draft takes a fundamentally different approach:

* Prompts are ephemeral; context files are persistent— Draft's documents live on the filesystem, tracked in git, surviving across sessions and team members. A prompt dies when the chat window closes.
* Prompts are verbal; specs are structural— Telling an AI "follow the repository pattern" is weaker than providing a document that defines every module, its boundaries, and its interaction contracts. Structure constrains behavior more reliably than instructions.
* Prompts are individual; context is shared— Ten developers write ten different prompts. One.ai-context.mdgives all of them — and all their AI assistants — the same ground truth.
* Prompts don't have verification; plans have gates— A prompt says "make sure it works." A plan says "Phase 1 is complete when these three tests pass and this acceptance criterion is met."
Prompt approach:"Add user authentication. Use JWT. Make sure to follow our existing patterns. Don't forget error handling. Use the same middleware pattern as the other routes."

Draft approach:spec.mddefines exactly what authentication means for this project..ai-context.mddocuments the existing middleware pattern, error handling strategy, and module boundaries.plan.mdbreaks the work into phases with verification steps. The AI doesn't need to be told to follow patterns — the patterns are in the context it loads before writing any code.

## The Key Principle

Explicit context beats implicit assumptions.

Every time an AI makes an assumption, it has a chance of being wrong. Every time that assumption is replaced with an explicit document — a product definition, a tech stack declaration, an architecture reference, a specification, a plan — that chance drops to zero. The AI is no longer guessing. It is reading.

Context-Driven Development is the practice of making every relevant decision explicit, versioned, and reviewable before AI writes code. It is the difference between "the AI did something" and "the AI did what we agreed it should do."

## Keeping AI Constrained

Without constraints, AI coding assistants exhibit four predictable failure modes:

* Over-engineer— Add abstractions, utilities, and "improvements" you didn't ask for
* Assume context— Guess at requirements instead of working from explicit specifications
* Lose focus— Drift across the codebase making tangential changes
* Skip verification— Claim completion without proving it works
Draft addresses each with a specific mechanism:

* Explicit spec— The AI can only implement what's documented in the specification
* Phased plans— The AI works on one phase at a time, not the entire feature
* Verification steps— Each phase requires proof of completion before proceeding
* Status markers— Progress is tracked in the plan file, not assumed
The result: the AI becomes an executor of pre-approved work, not an autonomous decision-maker. It has the full power of an AI coding assistant, channeled through a constraint system that ensures its output matches what the team actually needs.

The next chapter shows you how to set this up in your project in five minutes.

