---
type: Profile
project: "{PROJECT_NAME}"
module: "{MODULE_NAME or 'root'}"
generated_by: "draft:{COMMAND_NAME}"
generated_at: "{ISO_TIMESTAMP}"
---

# {PROJECT_NAME} Profile

## Project
- Name: {PROJECT_NAME}
- One-liner: {ONE_LINE_PRODUCT_DESCRIPTION}
- Primary users: {USER_TYPES}
- Repository layout: {monorepo|polyrepo|single-service}

## Stack
- Language: {LANGUAGE}
- Framework: {FRAMEWORK}
- Database: {DATABASE}
- Auth: {AUTH_METHOD}
- API: {API_STYLE}
- Testing: {TEST_FRAMEWORK}
- Deploy: {DEPLOY_TARGET}
- Build: {BUILD_COMMAND}
- Entry: {ENTRY_POINT}

## INVARIANTS
{Top 3-5 critical invariants from .ai-context.md, one per line, with file:line refs}

## NEVER
{2-3 safety rules — things that must never happen}

## Key Operational Models (from §6 / GRAPH:OPERATIONAL)
- {Most critical flow 1 — one line}
- {Most critical flow 2 (if space allows)}

## Active Tracks
{List of active track IDs and one-line descriptions, or "none"}

## Recent Changes
{Last 3-5 significant commits or changes, one per line}
