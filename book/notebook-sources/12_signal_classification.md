# Chapter 12: Signal Classification

Part III: How Draft Thinks· Chapter 12

5 min read

You run/draft:initon a project. Draft needs to produce a comprehensive architecture document, but every project is different. A React single-page app has no backend routes. A Go microservice has no frontend components. A data pipeline has no authentication layer. Draft cannot treat every project the same way, so it reads the file tree first and classifies what it finds into signals — categories that tell it what your project actually contains, what sections deserve deep treatment, and what can be skipped entirely.

## What Signals Are

Signals are categories of source files that reveal architectural concerns. During Phase 1 of architecture discovery, Draft walks your file tree and tags every file against 11 signal categories. The signal counts determine which sections ofarchitecture.mdget deep treatment, which get brief mention, and which are skipped. A signal count of zero means the architectural concern does not exist in your project. A count of 3 or more means it warrants exhaustive analysis.

This is how Draft adapts to your codebase without being told what kind of project it is. It does not ask "is this a web app?" — it finds route files, controller files, and API middleware, and concludes that API definitions need deep treatment.

## The 11 Signal Categories

### 1. Backend Routes

Files inroutes/,handlers/,controllers/, or**/api/**. Route decorators <like@app.route>,@router,@RequestMapping. These drive deep treatment of API Definitions and Cross-Module Integration sections. A project with 12 route files gets exhaustive endpoint cataloging. A project with zero gets those sections skipped.

### 2. Frontend Routes

Files inpages/,views/, or route configuration files. React Router setup, Next.jsapp/directory, Vue Router. These trigger UI topology documentation in the Architecture Overview section — component hierarchy, page routing, navigation flows.

### 3. Components

Files incomponents/,widgets/, or component-typed files like*.component.tsand*.tsxin component directories. These add component hierarchy documentation to the Core Modules section.

### 4. Services

Files inservices/or files matching*Service.*and*_service.*patterns. Service layer files drive the Component Map and Core Modules sections, documenting business logic boundaries and inter-service communication.

### 5. Data Models

Files inmodels/,entities/,schemas/, or migration directories. Files matching*.model.*and*.entity.*. These drive the State Management and API Definitions sections — schema definitions, ORM models, migration systems, and data lifecycle documentation.

### 6. Authentication

Files inauth/directories, auth middleware, guards. JWT and OAuth imports. These trigger deep treatment of the Security Architecture section: auth flows, token lifecycle, permission models, session management.

### 7. State Management

Files instore/,reducers/, or state directories. Redux, Vuex, Zustand, Pinia imports. These add frontend state management documentation: store structure, action flows, selector patterns, state shape.

### 8. Background Jobs

Files injobs/,workers/,tasks/, orqueues/. Celery, Sidekiq, Bull imports. These drive the Concurrency and Configuration sections with job scheduling, queue architecture, worker pool documentation.

### 9. Persistence

Files inrepositories/,dao/, or database directories. ORM configuration files and migration directories. These drive the State Management section with connection pooling, query patterns, transaction boundaries.

### 10. Test Infrastructure

Files intest/,tests/, or__tests__/. Files matching*.test.*and*.spec.*. Test configuration files. These drive the Testing Infrastructure section: test frameworks, mock patterns, fixture strategies, coverage configuration.

### 11. Configuration

Files matching.env*, files inconfig/, files matching*.config.*,application.yml, and settings files. These drive the Configuration section: environment variable catalogs, config loading mechanisms, feature flags, runtime tunables.

## How Signals Drive Analysis Depth

Each signal category maps to specific sections ofarchitecture.md. The mapping is explicit:

The thresholds are simple: zero files means skip or simplify the section. One to two files means include the section but keep it brief. Three or more files means the section warrants deep, exhaustive treatment. This prevents Draft from generating empty boilerplate sections for concerns that do not exist in your project, while ensuring real concerns get thorough documentation.

Signal classification integrates with the Adaptive Sections system. If your codebase has no plugin, algorithm, or handler system, the Framework and Extension Points section is skipped entirely. If your project is a library with no running process, the Process Lifecycle section is adapted to "Usage Lifecycle." If your project is a frontend module, component hierarchy, route maps, state management, and styling system documentation are added. Signals drive what gets written — the architecture document is shaped by your actual code, not a generic template.

## Signal-to-Context Mapping

Signals do not just determine section depth inarchitecture.md. They flow through the entire context pipeline. When architecture is condensed into.ai-context.md, sections that received deep treatment produce more detailed entries. Sections that were skipped are absent from the condensed output. This means the 200-400 line AI context file is automatically tuned to your project's actual architectural concerns.

The signal state is also persisted todraft/.state/signals.jsonfor incremental refresh tracking. On subsequent runs of/draft:init refresh, Draft re-classifies signals and compares against the stored baseline:

New signal categories appearing (zero to non-zero) indicate structural drift: your project has gained an architectural concern that did not exist before. Draft flags these for section generation. Removed categories (non-zero to zero) indicate pruning opportunities.

Consider a full-stack TypeScript project: React frontend with Express backend, PostgreSQL database, JWT authentication, and Redis caching.

Draft walks the file tree and produces this signal classification:

Nearly every signal category is active. This is a feature-rich project with both frontend and backend concerns. The resultingarchitecture.mdwill be comprehensive: full API catalog, component hierarchy with React component tree, auth flow documentation with JWT lifecycle, frontend state management with Redux store structure, database schema with Prisma models, and testing infrastructure covering both Jest (frontend) and Supertest (backend).

The only section simplified is Concurrency — no background jobs means the concurrency model is straightforward Express request handling and React rendering. No need for worker pool documentation or queue architecture.

Now contrast this with a Go CLI tool that has zero frontend files, zero components, zero state management, and zero auth. That project's signal classification would trigger deep treatment for only a few sections (services, config, tests) and skip everything frontend-related. Same tool, same process, radically different output — shaped entirely by what the code actually contains.

## The Classification Procedure

Signal classification is not heuristic. It is a file-matching procedure that runs during Phase 1 of architecture discovery. Draft counts files matching each category's detection patterns, excluding standard ignore paths (node_modules/,.git/,vendor/,draft/). The procedure is language-aware — a Python project looks <for@app.routedecorators> while a Java project looks for@RequestMappingannotations — but the signal categories are universal across all languages.

The result is a signal summary held in memory for Phase 5 (Synthesis), where it drives section-by-section generation decisions. It is then persisted todraft/.state/signals.jsonas the baseline for future drift detection.

You do not configure signals. You do not tell Draft "this is a web app" or "skip the frontend sections." Draft discovers what your project contains by reading the file tree. If your project gains authentication files six months from now, the next/draft:init refreshwill detect the new signal category, flag it as structural drift, and generate the Security Architecture section for the first time. The architecture document evolves with your code.
