<h1 align="center">Draft</h1>

<p align="center">
  <strong>Stop shipping AI-generated bugs.</strong><br>
  One command runs a three-stage review on your branch — validation, spec compliance, code quality — and writes the missing tests. Free. Open-source. MIT.
</p>

<p align="center">
  <a href="https://github.com/mayurpise/draft/releases"><img src="https://img.shields.io/github/v/release/mayurpise/draft?include_prereleases&style=for-the-badge" alt="GitHub release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge" alt="MIT License"></a>
  <a href="https://github.com/mayurpise/draft/stargazers"><img src="https://img.shields.io/github/stars/mayurpise/draft?style=for-the-badge" alt="Stars"></a>
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

## Install — Claude Code (30 seconds)

```bash
/plugin marketplace add mayurpise/draft
/plugin install draft
/draft:init       # Graph + 5-phase codebase analysis (one-time)
/draft:review     # ← run this on every branch before you push
```

That's it. Run `/draft` for the full command map.

<details>
<summary><strong>Also works with Cursor, GitHub Copilot, Antigravity, and Gemini →</strong></summary>

You can use the universal installation script to configure Draft for your environment:

### Claude Code (Local Installation)
If you prefer not to use the marketplace, you can install the plugin locally to your project:
```bash
curl -fsSL https://raw.githubusercontent.com/mayurpise/draft/main/scripts/install.sh | bash -s -- --claude
```

### Cursor
```bash
curl -fsSL https://raw.githubusercontent.com/mayurpise/draft/main/scripts/install.sh | bash -s -- --cursor
```

### GitHub Copilot
```bash
curl -fsSL https://raw.githubusercontent.com/mayurpise/draft/main/scripts/install.sh | bash -s -- --copilot
```

### Gemini
```bash
curl -fsSL https://raw.githubusercontent.com/mayurpise/draft/main/scripts/install.sh | bash -s -- --gemini
```

### Antigravity IDE
```bash
curl -fsSL https://raw.githubusercontent.com/mayurpise/draft/main/scripts/install.sh | bash -s -- --antigravity
```

</details>

---

## The 7 Core Workflows

Draft provides a complete system for spec-driven planning, TDD-enforced implementation, and operational workflows.

Specialist modes are built in. Advanced review, bug hunting, impact analysis, debugging, and documentation workflows are invoked intelligently through these parent commands.

---

## What You Get

| Command | What It Does |
|---------|--------------|
| **`/draft`** | Overview, intent mapping, and command reference |
| **`/draft:init`** | Analyze codebase, create context files, or route to `refresh`/`index`/`discover` |
| **`/draft:plan`** | Canonical planning entry point (routes to `new-track`, `decompose`, `change`, `adr`) |
| **`/draft:implement`** | TDD workflow, routes to `status`, `coverage`, `revert` |
| **`/draft:review`** | 3-stage review, routes to `quick`, `bughunt`, `deep`, `assist` |
| **`/draft:ops`** | Operations entry point (routes to `debug`, `deploy-checklist`, `incident-response`, `standup`) |
| **`/draft:docs`** | Documentation entry point (routes to `documentation`, `testing-strategy`, `tech-debt`, `tour`) |
| **`/draft:integrations`**| External systems entry point (routes to `jira-preview`, `jira-create`) |

*(Legacy specialist commands remain supported via their canonical parent commands.)*

[See full command reference →](core/methodology.md#command-workflows)

> **Recommended next step after install:** run `/draft:init` to index your repo, then `/draft:review` on any branch with AI-generated changes. Once you've seen what it catches, explore the rest.

---

## Built-in Code Intelligence

Draft ships with a **knowledge graph engine** that gives every command precise structural context — module boundaries, call graphs, dependencies, hotspots — without you having to install or configure anything.

```bash
graph --repo . --query --file src/auth/login.go --mode impact
# → blast radius: which files, which modules, which tests/docs/configs
```

| Capability | What it provides |
|---|---|
| **Multi-language extraction** | Tree-sitter parsers for Go, Python, TypeScript/JS, C/C++, proto + ctags fallback for Java/Rust/Ruby/Swift |
| **Call graph with confidence** | Every call edge tagged `direct` (bare identifier) or `inferred` (member call) so review/bughunt can weight findings |
| **Impact analysis** | Blast-radius BFS with file-class dimension (code/test/doc/config) — answers *"what breaks if I change this?"* |
| **Cycle detection** | Iterative DFS — flags circular module dependencies before they bite |
| **Hotspot ranking** | Complexity × fan-in score so high-risk files get extra scrutiny |
| **Atomic incremental builds** | Per-module SHA-256 hashing; only changed modules re-extract |
| **Track impact memory** | `metadata.json.impact` snapshots each completed track's blast radius — `/draft:new-track` flags overlap with recent work |

The graph powers `/draft:impact`, enriches `/draft:bughunt` and `/draft:review`, and is consumed by skills via `core/shared/graph-query.md`. See [graph/](graph/) for the engine source.

### Deterministic helper tools

Skills also call into **14 shell helpers** under `scripts/tools/` for mechanical work — git metadata, file classification, test-framework detection, hotspot ranking, freshness checks, ADR indexing. All emit JSON, follow a uniform exit-code contract, and degrade gracefully when their input source is unavailable.

---

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                        /draft:init                          │
│  Phase 0: Graph build (module boundaries, impact, cycles)   │
│  Phase 1-5: Codebase analysis + signal detection + state    │
│  architecture.md + .ai-context.md + graph/ + .state/        │
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
architecture.md  →  Comprehensive: 28 sections + 5 appendices, Mermaid diagrams (source of truth)
.ai-context.md   →  200-400 lines: condensed from architecture.md (token-optimized AI context)
graph/           →  knowledge graph artifacts (modules, proto APIs, hotspots)
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

[![Star History Chart](https://api.star-history.com/svg?repos=mayurpise/draft&type=Date)](https://star-history.com/#mayurpise/draft&Date)

---

<p align="center">MIT License</p>

<p align="center">
  <strong>Credits:</strong> Inspired by <a href="https://github.com/gemini-cli-extensions/conductor">gemini-cli-extensions/conductor</a>
</p>
