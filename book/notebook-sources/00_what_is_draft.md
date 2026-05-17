# Chapter 0: What is Draft?

Chapter 0

2 min read

You installed an AI coding assistant. It writes code fast. But it also picks the wrong framework, ignores your project conventions, invents requirements you never asked for, and produces code that no one on your team would have approved. Draft exists because speed without direction is just expensive chaos.

## What Draft Is

Draft is a free, open-source plugin that adds structured development methodology to AI coding agents. It provides 28 slash commands and 7 specialized agents that turn your AI assistant from an autonomous guessing machine into a disciplined executor of pre-approved work.

The core idea: before AI writes a single line of code, it analyzes your codebase, generates a specification, builds a phased plan, and waits for your approval. Only then does implementation begin — constrained by your architecture, your conventions, and your acceptance criteria.

Draft calls thisContext-Driven Development. Every decision is grounded in explicit, versioned, reviewable documents rather than implicit assumptions buried in a chat window.

## What Draft Is Not

* Not a code generator— Draft does not write code itself. It structures and constrains the AI that does.
* Not an IDE— Draft is a plugin that works inside your existing tools.
* Not a replacement for thinking— Draft makes the thinking explicit and reviewable. You still make the decisions; Draft ensures they happen before code exists.
* Not another AI wrapper— There is no API key, no hosted service, no vendor lock-in. Draft is markdown files and bash scripts.
## Who It's For

Draft is for developers and teams who use AI coding assistants and have experienced the gap between "it generated code" and "it generated the right code." If you've ever had an AI assistant introduce a dependency your team doesn't use, violate your project's naming conventions, or build a feature that doesn't match what was actually needed — Draft addresses that gap structurally.

## What You Get

29 commands covering the full development lifecycle:

* Context — `/draft:init`, `/draft:tour` (exploratory walkthroughs), architecture documentation, AI context files, and state tracking
* Planning — `/draft:new-track` creates specifications and phased plans through collaborative dialogue
* Execution — `/draft:implement` builds features task-by-task with TDD cycles and architecture checkpoints
* Debugging — `/draft:debug` provides structured debugging: reproduce, isolate, diagnose, fix
* Quality — `/draft:review`, `/draft:deep-review`, `/draft:bughunt`, `/draft:quick-review`, `/draft:impact` (risk analysis), `/draft:assist-review` (intent summaries), `/draft:coverage`, and `/draft:testing-strategy`
* Operations — `/draft:deploy-checklist`, `/draft:incident-response`, `/draft:standup`, `/draft:status`, `/draft:revert`, `/draft:change`
* Strategy — `/draft:tech-debt` for technical debt analysis with prioritization
* Authoring — `/draft:documentation` generates technical docs: readme, runbook, api, onboarding
* Knowledge & Governance — `/draft:adr`, `/draft:learn`, `/draft:decompose`, `/draft:index`, `/draft:discover`
* Integration — `/draft:jira-preview`, `/draft:jira-create`

7 specialized agents — Architect, Debugger, Planner, RCA, Reviewer, Ops, and Writer — each with behavioral protocols tuned for their domain.


## Platform Support

Draft works with the AI coding tools you already use:

* Claude Code— Native plugin installation via/plugin install
* Cursor— Native support for the.claude/plugin structure
* GitHub Copilot— Via.github/copilot-instructions.md
* Gemini— Via.gemini.mdbootstrap file
* Antigravity IDE— Via global skill installation
Chapter 1 explains the problem Draft solves — and why better prompting isn't the answer. Chapter 2 introduces the methodology. Chapter 3 gets you running in five minutes.

