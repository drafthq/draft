---
name: documentation
description: Technical documentation writing and maintenance. Modes — readme, runbook, api, onboarding. Uses writer agent principles for audience-appropriate, maintainable docs.
---

# Documentation

Generate or update technical documentation for this project using structured writing principles.

## Red Flags — STOP if you're:

- Writing docs without reading the code first
- Duplicating information that exists elsewhere (link instead)
- Writing docs for internal implementation details (only public interfaces)
- Ignoring the target audience (developer vs operator vs new hire)
- Generating a wall of text without structure or examples

**Write for the reader. Link don't duplicate. Show don't tell.**

---

## Pre-Check

1. Check for Draft context:
```bash
ls draft/ 2>/dev/null
```

If `draft/` doesn't exist, this skill works standalone — generate docs from code analysis.

2. Follow the base procedure in `core/shared/draft-context-loading.md`.

## Step 1: Parse Arguments

- `/draft:documentation readme` — Generate or update project README
- `/draft:documentation runbook <service>` — Operations runbook for a service
- `/draft:documentation api <module>` — API documentation for a module
- `/draft:documentation onboarding` — New developer onboarding guide
- `/draft:documentation` (no args) — Interactive: ask what type of documentation

## Step 2: Gather Source Material

### README Mode
- Read existing `README.md` (if any)
- Read `draft/product.md` — Product vision, users, goals
- Read `draft/tech-stack.md` — Technologies, setup requirements
- Read `draft/workflow.md` — Development workflow, commands
- Scan for `Makefile`, `package.json`, `pyproject.toml` — Build/run commands

### Runbook Mode
- Read `draft/architecture.md` or `draft/.ai-context.md` — Service topology, dependencies
- Read `draft/workflow.md` — Deployment conventions
- Read `draft/tech-stack.md` — Infrastructure details
- If GitHub MCP / `gh` CLI available: check recent merged PRs touching deployment configs
- If Jira MCP available: check recent incident tickets for the service

### API Mode
- Read source code for public interfaces, exported functions, API routes
- Read existing API docs (Swagger, OpenAPI, JSDoc, docstrings)
- Read `draft/architecture.md` — API conventions, data models
- Read `draft/tech-stack.md` — API framework details

### Onboarding Mode
- Read ALL draft context files in order:
  1. `draft/product.md` — What is this project?
  2. `draft/tech-stack.md` — What technologies?
  3. `draft/architecture.md` or `draft/.ai-context.md` — How is it structured?
  4. `draft/workflow.md` — How do I develop?
  5. `draft/guardrails.md` — What to watch out for?
- Scan for setup scripts, Docker configs, environment templates

## Step 3: Apply Writing Principles

Follow these principles (from `core/agents/writer.md`):

1. **Write for the reader** — Identify the audience (developer, operator, new hire) and tailor language, depth, and examples accordingly
2. **Start with the most useful information** — Lead with what the reader needs most (setup for README, troubleshooting for runbook, endpoints for API)
3. **Show don't tell** — Use code examples, command snippets, and diagrams over prose descriptions
4. **Progressive disclosure** — Start simple, add detail progressively. Don't front-load every edge case
5. **Link don't duplicate** — Reference existing docs, don't copy them. Single source of truth
6. **Keep current** — Reference source of truth files. Note: "Generated from draft context on {date}"

## Step 4: Generate Document

### README Structure
```markdown
# {Project Name}

{One-line description from product.md}

## Quick Start
{Setup commands from Makefile/package.json}

## Architecture
{High-level diagram from .ai-context.md}

## Development
{Commands from workflow.md}

## Testing
{Test commands and conventions}

## Contributing
{Workflow conventions}
```

### Runbook Structure
```markdown
# Runbook: {Service Name}

## Overview
{Service purpose, dependencies, SLOs}

## Health Checks
{Endpoints, expected responses}

## Common Issues
{Symptoms → diagnosis → resolution}

## Deployment
{Steps, rollback procedure}

## Monitoring
{Dashboard URLs, alert descriptions}

## Escalation
{On-call contacts, escalation paths}
```

### API Documentation Structure
```markdown
# API: {Module Name}

## Overview
{Purpose, authentication, base URL}

## Endpoints

### {METHOD} {path}
{Description}
**Request:** {body/params with examples}
**Response:** {status codes with examples}
**Errors:** {error codes and meanings}
```

### Onboarding Structure
```markdown
# Welcome to {Project Name}

## What is this?
{From product.md — 2-3 sentences}

## Architecture at a Glance
{Simplified from .ai-context.md}

## Getting Started
{Setup steps, first 15 minutes}

## Key Concepts
{Domain terms, important patterns}

## Development Workflow
{From workflow.md}

## Where to Find Things
{File structure guide}

## Common Pitfalls
{From guardrails.md}
```

## Step 5: Output

Save to:
- README: `README.md` in project root
- Runbook: `draft/docs/runbook-<service>.md`
- API: `draft/docs/api-<module>.md`
- Onboarding: `draft/docs/onboarding.md`

Create `draft/docs/` directory if needed.

Present generated doc to user for review before final save.

## Cross-Skill Dispatch

- **Suggested by:** `/draft:init` (after context generation), `/draft:implement` (track completion with new APIs), `/draft:decompose` (module API docs)
- **Jira sync:** If ticket linked, attach doc and post comment via `core/shared/jira-sync.md`

## Error Handling

**If no draft context:** Generate from code analysis alone, note: "Run `/draft:init` for richer documentation"
**If existing doc found:** Show diff between existing and generated, ask: "Update existing doc or create new? [update/new]"
