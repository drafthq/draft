# Chapter 10: Context Tiering

Part III: How Draft Thinks· Chapter 10

6 min read

Your AI assistant just rewrote a utility function. Harmless change, two lines of code. But it violated a concurrency invariant documented three months ago in a 400-line architecture file that the assistant never loaded because it was "just a quick fix." Draft prevents this by treating context like memory architecture: always-available registers at the top, deep storage on demand, and a scoring system that loads exactly what each task needs.

## The Memory Analogy

Every computer has a memory hierarchy: CPU registers are tiny and instant, RAM is larger and fast, disk is massive and slow. Draft applies the same principle to project context. Not every task needs the full engineering reference. A config change needs 20 lines of project identity. A feature implementation needs module boundaries and interface contracts. A deep architecture review needs everything.

Draft organizes your project context into three tiers, each optimized for a different level of task complexity:

Simple tasks only need Tier 0. Implementation tasks load Tier 0 plus relevant sections of Tier 1. Deep reviews and architecture refreshes access all tiers. This layered approach ensures the right context for each task without burning tokens on irrelevant information.

## Tier 0: The Project Profile

The filedraft/.ai-profile.mdis the smallest, most critical context artifact. At 20 to 50 lines, it contains the absolute minimum every Draft command needs: language, framework, database, auth method, API style, critical invariants, safety rules, active tracks, and recent changes. It isalways loaded, regardless of task complexity.

Think of it as the project's elevator pitch to the AI. When someone asks "fix this typo in the config file," the AI does not need to know your module dependency graph. It needs to know you use TypeScript, PostgreSQL, and that you never commit secrets to environment files.

The profile must be brutally concise. Every line competes for space in the AI's always-loaded context window. If a fact does not change how the AI writes code on a daily basis, it does not belong in Tier 0. Push it to Tier 1 or Tier 2.

When.ai-profile.mddoes not exist, Draft skips Tier 0 and proceeds directly to loading Tier 1 context. No crash, no error — graceful degradation.

## Tier 1: The AI Context

The filedraft/.ai-context.mdis the working memory of the system. At 200 to 400 lines, it is token-optimized and self-contained: module boundaries, dependencies, invariants, interface contracts, data flows, error handling patterns, concurrency rules, implementation catalogs, extension cookbooks, testing strategy, and a project glossary. It is loaded for most tasks — any command that modifies code or analyzes quality.

This file isderivedfromarchitecture.md, not written directly. Draft's condensation subroutine compresses the full engineering reference into a format designed for AI consumption: terse headings, structured sections, no prose where a table will do.

.ai-context.mduses structured section headers:META,GRAPH:COMPONENTS,GRAPH:DEPENDENCIES,GRAPH:DATAFLOW,INVARIANTS,INTERFACES,CATALOG:*,THREADS,CONFIG,ERRORS,CONCURRENCY,EXTEND:*,TEST,FILES,VOCAB. These headers enable relevance scoring — Draft loads only the sections that match your current task.

## Tier 2: The Full Architecture

The filedraft/architecture.mdis the source of truth. It is a comprehensive, human-readable 10-section engineering reference, complete with Mermaid diagrams, code snippets, interaction matrices, and state machine definitions. It exists for two audiences: AI agents performing deep analysis, and engineers who need to understand a module without reading source code.

Tier 2 is loaded only for deep analysis:/draft:initrefresh,/draft:deep-review,/draft:decompose, and full architecture refreshes. Most day-to-day development never touches it. When it is loaded, it provides exhaustive context that Tier 1 intentionally omits: per-module state machines, thread safety annotations, the full implementation catalog, concurrency model details, and configuration reference tables.

Alongsidearchitecture.md, Tier 2 includesdraft/.state/facts.json— an atomic fact registry that stores individual architectural facts with source file references, confidence scores, and relationship tracking. Facts are queried by relevance, not loaded in bulk. A task modifyingsrc/auth/middleware.tsloads facts sourced from that file and related auth module facts, not facts about the billing system.

## Relevance-Scored Context Loading

Loading all of Tier 1 for every task wastes tokens. Loading none of it is reckless. Draft solves this with relevance scoring: it extracts key concepts from the active task (domain terms fromspec.md, file paths and module names fromplan.md) and scores each section of.ai-context.mdagainst those concepts.

Four sections are always loaded regardless of task — thecontext floor:

* META— project identity and build commands
* INVARIANTS— safety-critical rules that apply everywhere
* TEST— how to run and verify tests
* FILES— where things live in the codebase
Everything else is loaded conditionally. Working on an API change? LoadINTERFACES. Adding a new module? LoadGRAPH:COMPONENTSandGRAPH:DEPENDENCIES. Fixing a race condition? LoadCONCURRENCYandTHREADS. The scoring is not magic — it is a lookup table matching task characteristics to section relevance:

Relevance scoring activates when three conditions hold: a specific track is active (hasspec.mdand/orplan.md),.ai-context.mdexists and exceeds 200 lines, and the command benefits from focused context (/draft:implement,/draft:bughunt,/draft:review). Commands that need the full picture —/draft:init,/draft:deep-review,/draft:decompose— bypass scoring and load everything.

## The Fact Registry

Beyond the three-tier document hierarchy, Draft maintains a fact registry atdraft/.state/facts.json. Each fact is an atomic, verifiable statement about the codebase with source file references, a confidence level, a category, and relationship links to other facts.

Facts are loaded through relevance filtering, not wholesale. When a task will modifysrc/billing/charge.ts, Draft loads facts whosesource_filesoverlap with that file. It also loads facts by category matching the task's primary concern, and prefers facts with recentlast_active_attimestamps. The limit is 20 relevant facts per task — enough for precision without flooding the context window.

During refresh, the fact registry supports contradiction detection. If a previously recorded fact ("Auth uses session cookies") is contradicted by new code analysis ("Auth uses JWT tokens"), Draft marks the old fact as superseded and records the evolution. This prevents stale facts from silently corrupting future analysis.

## Degradation Behavior

Draft never crashes because a file is missing. Every tier degrades gracefully:

This cascade means Draft works on projects at any stage of context maturity. A project with only.ai-profile.mdgets basic constraint enforcement. A project with the full stack — profile, context, architecture, facts, guardrails — gets deep architectural reasoning, invariant checking, and contradiction detection.

Morning: you fix a typo in an error message. Draft loadsTier 0 only— 30 lines. It knows your language, your test command, your safety rules. That is enough. Total context cost: minimal.

Afternoon: you implement a new API endpoint for user preferences. Draft loadsTier 0 + relevant Tier 1 sections: META, INVARIANTS, INTERFACES, GRAPH:COMPONENTS, ERRORS, TEST, FILES. It knows your module boundaries, your existing API contracts, your error handling patterns. It skips CONCURRENCY and CONFIG because this task does not touch them. Total context: roughly 120 lines out of the full 350.

Evening: you run/draft:deep-reviewon the auth module after a security concern. Draft loadsall three tiers: profile, full .ai-context.md, complete architecture.md, and relevant facts from the registry. It has the complete picture: state machines, thread safety annotations, the full interaction matrix, every invariant. This is the only scenario where the full cost is justified.

## Why Not Just Load Everything?

Token budgets are finite. A 400-line.ai-context.mdplus a comprehensive 10-sectionarchitecture.mdplus 150 facts consumes significant context window space — space that competes with the actual code being analyzed, the spec being checked, and the plan being followed. Tiering is not an optimization. It is a necessity. Without it, large projects would hit context limits before the AI could even begin working.

The three-tier system also reflects a truth about information relevance: most of your project's architectural knowledge is irrelevant to any single task. Loading it anyway does not make the AI smarter. It makes it noisier. Focused context produces focused output.

