# Chapter 3: Getting Started

Part I: Foundation· Chapter 3

8 min read

You have a codebase. Maybe it's a React app with 200 components. Maybe it's a Go microservice with 50 endpoints. Maybe it's a Python ML pipeline that three people understand and two of them left. In five minutes, Draft will analyze that codebase, generate comprehensive architecture documentation, and create the context files that turn your AI assistant into a developer who actually knows your project.

## Installation

Draft installs with a single command. No API keys, no accounts, no hosted services.

### Claude Code (Recommended)

That's it. You now have all 33 commands available as/draft:*slash commands.

### Cursor

Cursor natively supports the.claude/plugin structure:

Commands use@draft init,@draft new-track,@draft implementsyntax.

### GitHub Copilot

Copilot uses acopilot-instructions.mdfile in your project:

### Gemini

Gemini uses a.gemini.mdbootstrap file:

### Antigravity IDE

Clone Draft to a global skill location and configure your~/.gemini.mdto point to the skills directory.

Draft's methodology is the same regardless of which AI tool you use. The commands and syntax differ slightly, but the workflow — init, spec, plan, implement, review — is identical.

## Running /draft:init

Navigate to your project root and run:

Draft performs a five-phase analysis of your codebase. This is not a quick scan — it is an exhaustive, deep analysis designed to produce a permanent reference document that future AI sessions and human engineers will use instead of re-reading source code.

### Phase 1: Discovery (Broad Scan)

Draft maps your entire project structure. It reads the directory tree, identifies the file layout, and processes your build and dependency files —package.json,go.mod,Cargo.toml,requirements.txt,pom.xml, or whatever applies to your stack.

It then reads API definition files (protobuf, OpenAPI, GraphQL schemas, route decorators) and interface/type definition files to understand your public API and design intent.

The critical substep here issignal classification. Draft walks the file tree and tags every file that matches one of 11 signal categories:

* backend_routes— Routes, handlers, controllers, API directories
* frontend_routes— Pages, views, router files, Next.js app directory
* components— UI components, widgets
* services— Service classes, service directories
* data_models— Models, entities, schemas, migrations
* auth_files— Auth modules, middleware, guards, JWT/OAuth imports
* state_management— Stores, reducers, state directories
* background_jobs— Jobs, workers, task queues, cron
* persistence— Repositories, DAOs, database directories, ORM config
* test_infra— Test files, test utilities, test config
* config_files— Environment files, config directories, settings
Signal counts driveadaptive section depthin the generated architecture document. Categories with 3+ files get deep treatment. Categories with zero files get skipped. This means your architecture document reflects your actual codebase, not a generic template.

### Phase 2: Wiring (Trace the Graph)

Draft finds your application's entry point and traces the initialization sequence. From the top-level controller, app, or server, it follows how components are created, initialized, and wired together. It maps the registration code — where handlers, plugins, routes, and middleware are registered — and builds a dependency graph showing how the DI container, module system, or import graph connects everything.

### Phase 3: Depth (Trace the Flows)

For each major data flow, Draft starts at the entry point and follows the code through every processing stage to the output. It reads core module implementations to understand algorithms, error handling, retry logic, and state management. It identifies the concurrency model — thread pools, async executors, goroutines, worker processes — and maps safety checks including invariant assertions, validation logic, auth checks, and transaction boundaries.

### Phase 4: Periphery

Draft catalogs all external dependencies from build files and import statements. It examines test infrastructure to understand testing patterns and mock strategies. It scans for every configuration mechanism — flags, environment variables, config files, feature gates. And it reads any existing documentation for additional architectural context.

### Phase 5: Synthesis

The final phase cross-references everything. Every component mentioned in one section must appear in all relevant sections. Every endpoint, handler, schema, and dependency is validated for completeness. Draft identifies recurring design patterns, then generates Mermaid diagrams after understanding the full picture.

Draft's analysis mandate is explicit: read all relevant source files, enumerate all implementations, generate real diagrams with actual data. No sampling, no "and others," no placeholders. For codebases over 500 files, it focuses deep dives on the top 20 most-imported modules and summarizes others in tables.

## What Gets Created

After the five-phase analysis, Draft creates thedraft/directory with these files:

### architecture.md (Source of Truth)

A comprehensive 10-section engineering reference. This is the primary artifact — designed for both human engineers and AI agents. It includes:

* Executive summary and system identity
* Component map and module documentation
* Data flow diagrams (Mermaid)
* API definitions and interface contracts
* Concurrency model and safety checks
* Security architecture
* Testing infrastructure
* Configuration catalog
* Dependency graph
Every section uses real data from your codebase — actual code snippets, real module names, genuine dependency relationships. Not templates.

### .ai-context.md (Token-Optimized AI Context)

A 200-400 line document derived fromarchitecture.md. It contains 15+ mandatory sections condensed for AI consumption: architecture overview, invariants, interface contracts, data flows, concurrency rules, error handling patterns, implementation catalogs, extension cookbooks, testing strategy, and glossary. This is what Draft commands load when implementing features.

### .ai-profile.md (Always-On Profile)

A 20-50 line ultra-compact profile that is injected into every AI interaction. Contains: language, framework, database, auth mechanism, API style, critical invariants, safety rules, active tracks, and recent changes. Even a simple task like "fix this typo" gets basic project awareness.

### Configuration Files

* product.md— Product vision, target users, goals, success criteria, and guidelines. Created through dialogue — Draft asks probing questions about what you're building and for whom.
* tech-stack.md— Languages, frameworks, patterns, and accepted design decisions. Auto-detected for brownfield projects, cross-referenced with the architecture analysis.
* workflow.md— Team engineering workflow: TDD preference (strict/flexible/none), commit strategy and frequency, code review checklists, phase verification procedures, and session management rules. Every Draft agent reads this file to determine how work should be done — when to run tests, how to structure commits, what review gates to enforce.
* guardrails.md— Hard guardrails (human-defined constraints), learned conventions (auto-discovered patterns to skip in analysis), and learned anti-patterns (auto-discovered patterns to always flag). For brownfield projects,/draft:learnruns automatically during init to populate conventions and anti-patterns from your existing codebase. These are refined over time by quality commands like/draft:reviewand/draft:bughunt.
Every Draft agent readsproduct.md,tech-stack.md,workflow.md, andguardrails.mdon every command, across the entire SDLC, for every engineer who uses the repository. These are not configuration details to skim past — they areteam-level engineering policythat shapes every spec, plan, implementation, and review.

After/draft:initcompletes, have your subject matter experts thoroughly review and refine all four:

* product.md— Product managers should verify vision, user personas, and goals. Revisit after OKR cycles, product pivots, or when user segments change.
* tech-stack.md— Tech leads should verify languages, frameworks, and accepted patterns. Revisit after major dependency upgrades, new framework adoption, or ADR acceptance.
* workflow.md— Engineering leads should verify TDD settings, commit strategy, review checklists, and coverage targets. Revisit when your team's development process evolves.
* guardrails.md— Senior engineers should verify hard guardrails and review auto-discovered conventions and anti-patterns. Revisit after/draft:learn promoteor when team standards change.
Stale context files are worse than no context — they silently misalign every engineer's AI-assisted work. Treat these as living documents, not one-time setup.

### State Files

Draft creates adraft/.state/directory with four files that enable incremental refresh:

* freshness.json— SHA-256 hashes of all analyzed source files. On refresh, Draft compares current hashes against stored ones to identify exactly which files changed, which are new, and which were deleted — without re-reading unchanged files.
* signals.json— The signal classification from Phase 1, stored as a baseline. On refresh, Draft re-runs classification and diffs against the baseline to detect structural drift (e.g., auth files appearing for the first time).
* run-memory.json— Run metadata, unresolved questions, and resumable checkpoints. If an init or refresh is interrupted, Draft can resume from where it left off.
* facts.json— Atomic architectural facts with temporal metadata and relationship edges. Enables fact-level contradiction detection on refresh.
## Your First Track

With initialization complete, you're ready to create your first feature track:

Draft loads your full project context — product vision, tech stack, architecture, workflow preferences, guardrails — and begins a collaborative dialogue to understand exactly what you need. It asks probing questions about scope, requirements, and constraints before generating anything.

After the dialogue, Draft produces two files:

* spec.md— Requirements, acceptance criteria, non-goals, technical approach. Grounded in your architecture and tech stack.
* plan.md— Phased task breakdown. Foundation → Implementation → Integration → Polish. Each task specifies target files, test files, and verification criteria.
You review these documents. Edit them if needed. Commit them for peer review. Only when the spec and plan are approved does implementation begin:

Draft picks up the first pending task from the plan and begins the TDD cycle: write a failing test, write the code to pass it, refactor. One task at a time. One phase at a time. Each phase verified before proceeding to the next.

## The Quick Workflow

Not everything needs a full specification. For hotfixes, small changes, and well-understood tasks, Draft supports a streamlined workflow:

The--quickflag creates a lightweight track with a condensed spec and minimal plan. It still loads project context and creates trackable artifacts, but skips the extended dialogue and detailed phase breakdown. The fix is still constrained by your architecture and conventions — it's just faster to get started.

Use--quickfor one-line fixes, typo corrections, small refactors, and changes where the scope is obvious. Use the full workflow for anything that requires design decisions, will be reviewed by others, or involves complex multi-step implementation. Draft adds structure; use it when structure has value.

## Refreshing Context

Your codebase changes over time. New modules get added, dependencies change, architectural decisions evolve. Draft handles this with incremental refresh:

Refresh uses the stored file hashes infreshness.jsonto identify exactly what changed since the last analysis. It only re-analyzes changed, new, and deleted files — unchanged files are skipped entirely. Signal classification is re-run and diffed against the baseline to detect structural drift. The architecture document, AI context, and profile are updated with targeted changes rather than a full regeneration.

If nothing changed, Draft short-circuits: "Architecture context is current. Nothing to refresh." No wasted tokens, no unnecessary work.

## What Comes Next

You now have a project with full context, a track with a spec and plan, and an implementation workflow that keeps AI constrained to your architecture. The next chapters dive into each stage of the workflow in detail — how specifications are crafted, how plans are structured, how implementation works task by task, and how the review process catches what the AI missed.

