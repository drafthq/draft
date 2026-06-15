# Chapter 22: Appendix A: Command Reference

Appendix

Quick-reference for all 33 Draft commands. Syntax shown is for Claude Code (`/draft:*`); Copilot uses `draft command` (no slash); Cursor uses `/draft:*` syntax.

## Intent Mapping

Draft recognizes natural language equivalents for all commands. You do not need to memorize slash syntax — describe what you want and Draft maps it to the right command.

Run `/draft` (the overview command) to see the complete intent mapping table with all 33 commands and their natural language triggers.

## Primary Commands (4)

The four commands that cover the end-to-end workflow. Use these as your main entry points.

| Command | Purpose |
|---------|---------|
| `/draft:init` | Analyze the codebase, generate architecture documentation, and create the full context file set (`draft/`). Scope-aware: run at repo root for whole-repo graph; run inside a sub-module to build module context and write `draft/graph/root-link.json`. Supports `--graph-only` and `--module-only` flags. |
| `/draft:new-track` | Start a new feature or bug track. Runs collaborative intake, asks probing questions, and generates `spec.md` + `plan.md` before any implementation begins. |
| `/draft:implement` | Execute the active track task-by-task following TDD cycles and verification gates. Reads status markers from `plan.md` to find the next pending task. |
| `/draft:review` | Three-stage review: automated validation, spec compliance, code quality. Produces a structured findings report. |

## Routers (5)

Routers accept natural language and dispatch to the right specialist with full context already loaded. Prefer routers over calling specialists directly.

| Command | Purpose |
|---------|---------|
| `/draft:plan` | Planning router — dispatches to `new-track`, `decompose`, `adr`, or `change` based on intent. |
| `/draft:ops` | Operations router — dispatches to `standup`, `status`, `incident-response`, `deploy-checklist`, or `revert`. |
| `/draft:docs` | Documentation router — dispatches to `documentation`, `learn`, `tour`, `tech-debt`, or `adr`. |
| `/draft:discover` | Discovery router — dispatches to `graph`, `impact`, `integrations`, `bughunt`, or `debug`. |
| `/draft:jira` | Jira router — supports `preview`, `create`, and advanced `review <JIRA-ID>` qualification pipeline (deep-review + bughunt + coverage + test-gap analysis). |

## Specialist Commands (24)

Specialists are dispatched by routers or can be called directly for targeted work.

| Command | Purpose |
|---------|---------|
| `/draft:draft` | Overview and intent map — shows all 33 commands with natural language triggers. |
| `/draft:graph` | Query the live knowledge graph (codebase-memory-mcp). Supports hotspot analysis, impact tracing, and module dependency queries. |
| `/draft:decompose` | Break down a large feature or system into independently deliverable tracks with dependencies mapped. |
| `/draft:coverage` | Measure test coverage gaps against the active track's plan and acceptance criteria. |
| `/draft:deploy-checklist` | Generate an environment-aware pre-deployment checklist for the active track. |
| `/draft:bughunt` | 14-dimension exhaustive bug hunt across the codebase. Produces severity-ranked findings with code evidence and suggested fixes. |
| `/draft:upload` | Upload context files or track artifacts for sharing or backup. |
| `/draft:integrations` | Audit and document external integrations: APIs, SDKs, webhooks, and service dependencies. |
| `/draft:quick-review` | Lightweight review for small changes and hotfixes — faster than full three-stage review. |
| `/draft:deep-review` | Exhaustive multi-dimension code review with architecture conformance, security analysis, and invariant checking. |
| `/draft:testing-strategy` | Generate or audit a testing strategy for the active track or a specified module. |
| `/draft:learn` | Auto-discover conventions and anti-patterns from the existing codebase. Populates `guardrails.md`. Runs automatically during `init` for brownfield projects. |
| `/draft:adr` | Author an Architecture Decision Record for a decision made during planning or implementation. |
| `/draft:debug` | Systematic debugging with the RCA agent: reproduce → trace → hypothesize → fix with blast radius scoping. |
| `/draft:standup` | Generate a standup summary from recent track activity, git log, and plan progress. |
| `/draft:tech-debt` | Identify, categorize, and prioritize technical debt in the codebase or a specified module. |
| `/draft:incident-response` | Structured incident response workflow: triage → root cause → mitigation → postmortem. |
| `/draft:documentation` | Generate or refresh user-facing documentation from source code and context files. |
| `/draft:status` | Display current progress of all tracks — phases, completion percentages, and blocked items. |
| `/draft:revert` | Safely revert an active track to a previous state or checkpoint. |
| `/draft:change` | Document and assess the impact of an architectural or dependency change. |
| `/draft:tour` | Generate a guided codebase tour for onboarding new engineers or AI agents. |
| `/draft:impact` | Trace the downstream impact of a proposed change across module and service boundaries. |
| `/draft:assist-review` | Assist a human reviewer by pre-populating review comments from spec compliance and quality checks. |

## Syntax by Platform

| Platform | Syntax | Install |
|----------|--------|---------|
| Claude Code | `/draft:init` | `npx @drafthq/draft install claude-code` |
| Cursor | `/draft:init` | `npx @drafthq/draft install cursor` |
| Codex | `/draft:init` | `npx @drafthq/draft install codex` |
| OpenCode | `/draft:init` | `npx @drafthq/draft install opencode` |
| GitHub Copilot | `draft init` | `npx @drafthq/draft install copilot` (copies `.github/copilot-instructions.md`) |
| Gemini | `draft init` | `npx @drafthq/draft install gemini` (creates `.gemini.md`) |
