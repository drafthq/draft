# Chapter 8: Decomposition

Part II: Track Lifecycle· Chapter 8

4 min read

A feature starts as a paragraph in a spec. Implementation starts as a list of tasks in a plan. But between the two lies a structural question that determines whether the code will be maintainable or not: how do you divide the work into modules?/draft:decomposeanswers this question systematically — mapping responsibilities to modules, dependencies between them, and the order in which they should be built.

## The Problem With Ad-Hoc Boundaries

Without explicit decomposition, module boundaries emerge accidentally. A developer creates a file, another developer creates a related file in a different directory, a third adds a utility that both use. Six months later, nobody can explain why the authentication logic spans three directories and imports from the billing module.

Decomposition is the act of making module boundaries intentional. Draft's/draft:decomposecommand forces this intentionality by requiring explicit definitions for every module — what it owns, what it exposes, what it depends on, and how complex it is.

## Two Scopes of Decomposition

/draft:decomposeoperates at two levels, depending on context:

Project-wide decomposition defines the system's module structure. Track-scoped decomposition defines the module structure for a specific feature or fix, which may introduce new modules or refine existing ones.

## SRP Enforcement

The Architect Agent enforces a strict single responsibility principle during decomposition. Each module must have exactly one responsibility, expressed in one sentence. If the sentence contains "and" — if a module "handles authenticationandmanages user sessions" — it gets split.

This is not a style preference. It is a structural constraint. The one-sentence responsibility becomes the module's contract: everything inside the module serves that sentence, and nothing outside the module does that job.

## The 1-3 File Constraint

Draft enforces a hard size constraint: each module contains 1 to 3 source files (excluding test files). This constraint is deliberately tight. If a module needs 4 files, it is doing too much and must be split further. If a module needs only a single function, it is too granular and should be absorbed into an adjacent module.

The constraint forces real decomposition. Teams that define modules as "the auth directory" with 15 files in it have not decomposed anything — they have named a directory. Draft's constraint means a module namedauthmight actually becomeauth-token,auth-session, andauth-middleware, each with 1-3 files and a clear boundary.

## Module Definition

For each module, decomposition produces six fields:

* Name— Short, descriptive identifier (auth-token,scheduler,parser)
* Responsibility— One sentence describing what this module owns
* Files— Expected source files (existing or to be created)
* API Surface— Public functions, classes, or interfaces using the project's language conventions
* Dependencies— Which other modules it imports from
* Complexity— Low, Medium, or High
The API surface is especially important. It defines the only way other modules may interact with this one. Anything not in the API surface is internal and may change without affecting dependents.

## Dependency Analysis

After modules are defined and approved, Draft maps dependencies between them. The process has three outputs:

A dependency diagram— ASCII art showing which modules depend on which:

A dependency table— showing both directions of every relationship:

An implementation order— a topological sort that determines which modules to build first. Leaf modules (no dependencies) come first. Modules that depend on them come next. This ensures that when you start coding a module, everything it imports already exists.

## Breaking Circular Dependencies

Cycles in the dependency graph are structural defects. If module A depends on module B and module B depends on module A, their boundaries are wrong. Draft's Architect Agent applies a cycle-breaking framework with three strategies:

The first strategy is most common. Whenuser-serviceimports fromnotification-serviceand vice versa, the shared concern — user preferences — gets extracted into a newuser-preferencesmodule that both can depend on without creating a cycle.

## The Architect Agent's Role

Decomposition is guided by Draft's Architect Agent, a specialized behavioral protocol defined incore/agents/architect.md. The agent brings four capabilities to decomposition:

* Module identification— Scans existing code for directory-per-feature patterns, barrel exports, package files, and import graphs to propose initial boundaries
* Story writing— Each module gets a placeholder story field during decomposition, filled in during/draft:implementwith a natural-language algorithm description
* Execution state design— Defines intermediate state variables between input and output for each module
* Function skeleton generation— Creates function stubs with complete signatures before TDD begins
The agent is not autonomous. Decomposition includes mandatory checkpoints where the developer reviews and approves the module breakdown, the dependency analysis, and any plan restructuring before changes are written.

## Plan Restructuring

For track-scoped decomposition, Draft can restructure an existingplan.mdto align phases with module boundaries. Each module becomes a phase (or maps to an existing phase), and the implementation order from the dependency graph determines the phase sequence.

Existing task statuses are preserved during restructuring: completed tasks stay completed, in-progress tasks get flagged if they span multiple modules, pending tasks are remapped freely. Tasks that don't map cleanly to any module are collected in an "Unmapped Tasks" section for developer decision — nothing is silently dropped.

draft/architecture.mdis the source of truth for project-wide decomposition.draft/.ai-context.mdis derived from it via the Condensation Subroutine. Always updatearchitecture.mdfirst, then regenerate.ai-context.md. Completed modules are never removed or modified during re-decomposition.
