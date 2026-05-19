# Draft Intent Mapping Guide

Draft commands can be invoked using natural language. If you describe your goal or ask a question, Draft will map your intent to the correct canonical or specialist command.

## Natural Language Intent Mapping

| What you say or want to do... | Resolved Draft Command | Primary Purpose |
|:---|:---|:---|
| "set up the project", "initialize draft", "start setup" | `/draft:init` | Bootstrap Draft in a new project |
| "plan this feature", "scope this work", "start a track" | `/draft:plan` | Planning coordinator (routes to new-track/change) |
| "new feature", "add search", "create new task list" | `/draft:plan` | Parent intent routing to `/draft:new-track` |
| "decompose this", "break into modules", "split service" | `/draft:decompose` | Model decomposition with dependency mapping |
| "requirements changed", "scope drift", "update spec" | `/draft:change` | Safely update active plan and spec |
| "document decision", "create ADR", "architectural choice" | `/draft:adr` | Record permanent engineering decisions |
| "continue planning", "next planning step" | `/draft:plan` | Keep planning in an active session |
| "start implementing", "begin coding", "write some code" | `/draft:implement` | Canonical implementation workflow |
| "continue task", "implement next step", "keep coding" | `/draft:implement` | Continue work on the active task checklist |
| "what is the progress", "track status", "show task list" | `/draft:status` | View progress, active phases, and blocked items |
| "check coverage", "coverage report", "test coverage" | `/draft:coverage` | Measure code coverage (target 95%+) |
| "undo changes", "revert commit", "rollback implementation" | `/draft:revert` | Git-aware safety rollback for active tasks |
| "review my code", "check quality", "run review" | `/draft:review` | Canonical change-scoped review |
| "quick review", "fast check", "sanity check" | `/draft:quick-review` | Parent-routed lightweight review for files/diffs |
| "hunt bugs", "find defects", "check for crashes" | `/draft:bughunt` | Exhaustive codebase-wide bug sweep |
| "deep review", "production readiness audit", "acid audit" | `/draft:deep-review` | Module-scoped ACID compliance and resilience audit |
| "review handoff", "prepare for PR", "create review handoff" | `/draft:review assist` | Generate detailed review context for humans/agents |
| "learn patterns", "update guardrails", "discover conventions" | `/draft:learn` | Discover coding conventions and update guardrails |
| "debug this issue", "investigate test failure", "fix crash" | `/draft:debug` | Structured 4-stage debugging workflow |
| "deploy checklist", "release checks", "pre-flight checks" | `/draft:deploy-checklist` | Pre-deployment verification checklist |
| "test strategy", "design test suite", "testing targets" | `/draft:testing-strategy` | Design standard testing plan |
| "tech debt analysis", "catalog debt", "code debt" | `/draft:tech-debt` | Technical debt audit across 6 dimensions |
| "weekly standup", "what did I do today", "activity summary" | `/draft:standup` | Summarize recent Git and file contributions |
| "incident", "production outage", "mitigate bug" | `/draft:incident-response` | Triage, mitigation, and postmortem incident flow |
| "write docs", "create readme", "api documentation" | `/draft:documentation` | Generate professional, structured docs |
| "preview jira", "export jira issues", "jira draft" | `/draft:jira-preview` | Generate Jira markdown export from plan |
| "create jira", "push to jira board" | `/draft:jira-create` | Create actual Jira issues via MCP integrations |
| "index services", "aggregate context", "monorepo setup" | `/draft:index` | Aggregate multi-service context at the root |
