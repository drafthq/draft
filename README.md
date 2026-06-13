<h1 align="center">Draft</h1>

<p align="center">
  <strong>Stop shipping AI-generated bugs.</strong><br>
  One command runs a three-stage review on your branch — validation, spec compliance, code quality — and writes the missing tests. Free. Open-source. MIT.
</p>

<p align="center">
  <a href="https://github.com/drafthq/draft/releases"><img src="https://img.shields.io/github/v/release/drafthq/draft?include_prereleases&style=for-the-badge" alt="GitHub release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge" alt="MIT License"></a>
  <a href="https://github.com/drafthq/draft/stargazers"><img src="https://img.shields.io/github/stars/drafthq/draft?style=for-the-badge" alt="Stars"></a>
  <a href="https://github.com/DeusData/codebase-memory-mcp" target="_blank" rel="noopener noreferrer"><img src="https://img.shields.io/badge/graph_engine-codebase--memory--mcp-8A2BE2?style=for-the-badge" alt="Graph engine: codebase-memory-mcp"></a>
</p>

<p align="center">
  Powered by <a href="https://github.com/DeusData/codebase-memory-mcp" target="_blank" rel="noopener noreferrer">codebase-memory-mcp</a> by <a href="https://github.com/DeusData" target="_blank" rel="noopener noreferrer">DeusData</a> — a 159-language, 100% local knowledge-graph engine.
</p>

<p align="center">
  <a href="https://getdraft.dev">Website</a> ·
  <a href="https://getdraft.dev#commands">Docs</a> ·
  <a href="core/methodology.md">Methodology</a> ·
  <a href="https://www.youtube.com/watch?v=gBSwFEFVd7Y">Watch (8 min)</a> ·
  <a href="https://www.youtube.com/playlist?list=PLoN73NRJ_HQPdnR5Su4WkWK-O_7IOrOg_">All Videos</a>
</p>

---

## The 60-second pitch

Your AI assistant just wrote 200 lines. Some of them are bugs. Some don't match your patterns. Some skip tests.

```bash
/draft:review
```

Three stages, one command:

1. **Validation** — runs your tests, lints, type-checks, and surfaces real failures
2. **Spec compliance** — checks the diff against the agreed spec, not vibes
3. **Code quality** — flags hotspots, blast radius, and missing test coverage using a tree-sitter knowledge graph of your repo

Free. No API keys. No paid tier. No vendor lock-in. Catches the 3 bugs you missed before they hit your reviewer.

> *Demo coming soon — for now, [watch the 8-minute walkthrough](https://www.youtube.com/watch?v=gBSwFEFVd7Y).*

---

## Install (30 seconds)

One command installs Draft into your agent. No clone, no config.

```bash
npx @drafthq/draft install <host>      # claude-code | cursor | codex | opencode
```

…or install the CLI once and reuse it:

```bash
npm install -g @drafthq/draft
draft install <host>
draft list                             # show every host + where it installs
```

| Host | `draft install …` | Lands in |
|------|-------------------|----------|
| **Claude Code** | `claude-code` | `./.claude-plugin/` + `skills/` `core/` (project) |
| **Cursor** | `cursor` | `~/.cursor/plugins/local/draft/` (global) |
| **Codex** | `codex` | `./AGENTS.md` (project) |
| **opencode** | `opencode` | `./AGENTS.md` + `~/.agents/skills/draft/` |

Flags: `--global` / `--project` to pick scope, `--dry-run` to preview writes, `--force` to overwrite, `--no-graph` to skip the graph-engine fetch.

Then, in Claude Code:

```bash
/draft:init       # 5-phase codebase analysis (one-time)
/draft:review     # ← run this on every branch before you push
```

Run `/draft` for the full command map.

<details>
<summary><strong>Other ways to install →</strong></summary>

### Claude Code — native marketplace
```bash
/plugin marketplace add drafthq/draft
/plugin install draft
```

### Cursor — from GitHub
Cursor natively supports the `.claude-plugin/` structure. Add via *Settings > Rules, Skills, Subagents > Rules > New > Add from Github*:
```
https://github.com/drafthq/draft.git
```

### GitHub Copilot
Copilot reads a committed instructions file — copy it directly (not a `draft install` host):
```bash
mkdir -p .github && curl -o .github/copilot-instructions.md \
  https://raw.githubusercontent.com/drafthq/draft/main/integrations/copilot/.github/copilot-instructions.md
```

### Gemini
```bash
curl -o .gemini.md https://raw.githubusercontent.com/drafthq/draft/main/integrations/gemini/.gemini.md
```

</details>

---

## Beyond `/draft:review` — 27 more commands

`/draft:review` is the wedge. Once Draft has indexed your repo, you also get spec-driven planning, TDD-enforced implementation, exhaustive bug hunting, deep architectural audits, and 23 more commands covering the full development lifecycle.

---

## What You Get

| Command | What It Does |
|---------|--------------|
| **`/draft`** | Overview, intent mapping, and command reference |
| **`/draft:init`** | Analyze codebase, create context files + state tracking |
| **`/draft:index`** | Aggregate monorepo service contexts |
| **`/draft:new-track`** | Collaborative spec + plan with AI |
| **`/draft:decompose`** | Module decomposition with dependency mapping |
| **`/draft:implement`** | TDD workflow with checkpoints |
| **`/draft:coverage`** | Code coverage report (target 95%+) |
| **`/draft:review`** | 3-stage review (validation + spec compliance + code quality) |
| **`/draft:deep-review`** | Enterprise-grade module lifecycle and ACID audit |
| **`/draft:bughunt`** | Exhaustive 14-dimension defect discovery with taint tracking |
| **`/draft:learn`** | Discover coding patterns, update guardrails |
| **`/draft:adr`** | Architecture Decision Records |
| **`/draft:status`** | Show progress overview |
| **`/draft:revert`** | Git-aware rollback |
| **`/draft:change`** | Handle mid-track requirement changes |
| **`/draft:debug`** | Structured debugging: reproduce, isolate, diagnose, fix |
| **`/draft:quick-review`** | Lightweight 4-dimension code review |
| **`/draft:deploy-checklist`** | Pre-deployment verification with rollback triggers |
| **`/draft:testing-strategy`** | Test plan design with coverage targets |
| **`/draft:tech-debt`** | Technical debt analysis across 6 dimensions |
| **`/draft:standup`** | Git activity standup summary (read-only) |
| **`/draft:incident-response`** | Incident lifecycle: triage, communicate, mitigate, postmortem |
| **`/draft:documentation`** | Technical docs: readme, runbook, api, onboarding |
| **`/draft:jira`** | Unified Jira workflows (preview / create / review) |
| **`/draft:tour`** | Interactive architecture mentorship and codebase walk-through |
| **`/draft:impact`** | ROI analytics tracking friction and timeline metrics |
| **`/draft:assist-review`** | Summarize intent and highlight structural PR risks for reviewers |

[See full command reference →](core/methodology.md#command-workflows)

> **Recommended next step after install:** run `/draft:init` to index your repo, then `/draft:review` on any branch with AI-generated changes. Once you've seen what it catches, explore the rest.

---

## Built-in Code Intelligence

Draft is powered by a **local knowledge graph engine** ([codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp)) that gives every command precise structural context — module boundaries, call graphs, dependencies, hotspots. It's 100% local (no API key, no SaaS), installed on first use.

```bash
/draft:graph                                  # build / refresh the snapshot
scripts/tools/graph-impact.sh --file src/auth/login.go
# → blast radius: which files, which symbols, which tests/docs/configs
```

| Capability | What it provides |
|---|---|
| **Multi-language extraction** | Tree-sitter + LSP-grade resolution across 159 languages, 100% local |
| **Call graph** | Callers/callees with confidence signals so review/bughunt can weight findings |
| **Impact analysis** | Blast-radius with file-class dimension (code/test/doc/config) — answers *"what breaks if I change this?"* |
| **Cycle detection** | Flags circular call dependencies before they bite |
| **Hotspot ranking** | Fan-in score so high-risk symbols get extra scrutiny |
| **Incremental indexing** | git-aware, content-based; only changed code re-indexes |
| **Track impact memory** | `metadata.json.impact` snapshots each completed track's blast radius — `/draft:new-track` flags overlap with recent work |

The graph powers `/draft:graph` and `/draft:impact`, enriches `/draft:bughunt` and `/draft:review`, and is consumed by skills via `core/shared/graph-query.md`. The engine is installed via [`scripts/fetch-memory-engine.sh`](scripts/fetch-memory-engine.sh); the deterministic shell helpers live under [`scripts/tools/`](scripts/tools/).

### Deterministic helper tools

Skills also call into **14 shell helpers** under `scripts/tools/` for mechanical work — git metadata, file classification, test-framework detection, hotspot ranking, freshness checks, ADR indexing. All emit JSON, follow a uniform exit-code contract, and degrade gracefully when their input source is unavailable.

---

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                        /draft:init                          │
│    5-phase codebase analysis + signal detection + state     │
│  architecture.md + .ai-context.md + .state/ (freshness,    │
│                   signals, run memory)                      │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                      /draft:new-track                       │
│            AI-guided spec.md + phased plan.md               │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                     /draft:implement                        │
│              RED → GREEN → REFACTOR (repeat)                │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                      /draft:review                          │
│        Three-stage review (validation + spec + quality)     │
└─────────────────────────────────────────────────────────────┘

         /draft:init refresh  ←── incremental: only re-analyze
                                   files with changed hashes
```

[Full workflow →](core/methodology.md#core-workflow)

---

## Why Draft?

AI tools are fast but unstructured. Draft applies Context-Driven Development to impose clear boundaries: explicit context, phased execution, and built-in verification, ensuring outputs remain aligned, predictable, and production-ready.

```
product.md       →  "Build a task manager"
tech-stack.md    →  "React, TypeScript, Tailwind"
architecture.md  →  Comprehensive: 28 sections + 5 appendices, Mermaid diagrams (source of truth). Mature brownfield projects with strong existing agent docs (CLAUDE.md, INVARIANTS.md, etc.) receive early Context Quality Audit, graph fidelity dashboard, and explicit Relationship + Gaps sections (no blind duplication).
.ai-context.md   →  200-400 lines: condensed from architecture.md (token-optimized AI context)
.state/          →  freshness hashes, signal classification, run memory (incremental refresh)
spec.md          →  "Add drag-and-drop reordering"
plan.md          →  "Phase 1: sortable, Phase 2: persist"
```

Each layer narrows the solution space. By the time AI writes code, decisions are made.

**Incremental refresh**: After initial setup, `/draft:init refresh` uses stored file hashes and signal classification to only re-analyze what changed — no full re-scan needed.

[Read methodology →](core/methodology.md#philosophy)

---

## Contributing

### Source of Truth
1. `core/methodology.md` — Master methodology
2. `skills/<name>/SKILL.md` — Command implementations
3. `integrations/` — Auto-generated (don't edit)

### Update Workflow
```bash
# 1. Edit core/methodology.md or skills/*/SKILL.md
# 2. Rebuild integrations
./scripts/build-integrations.sh
```

[Full architecture →](CLAUDE.md)

---

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=drafthq/draft&type=Date)](https://star-history.com/#drafthq/draft&Date)

---

<p align="center">MIT License &middot; Graph engine: <a href="https://github.com/DeusData/codebase-memory-mcp" target="_blank" rel="noopener noreferrer">codebase-memory-mcp</a> by <a href="https://github.com/DeusData" target="_blank" rel="noopener noreferrer">DeusData</a></p>

<p align="center">
  <strong>Credits:</strong> Inspired by <a href="https://github.com/gemini-cli-extensions/conductor">gemini-cli-extensions/conductor</a>
</p>
