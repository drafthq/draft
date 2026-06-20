# AI Tool Roundups & Directories

Two buckets: **self-serve directories** (you fill a form) and **curated
newsletters/roundups** (you pitch an editor). Copy below is sized for each.

## A. Self-serve directories (submit a form)

| Directory | Submit URL | Notes |
|-----------|-----------|-------|
| There's An AI For That | https://theresanaiforthat.com/submit/ | Largest AI directory; free + paid fast-track |
| Futurepedia | https://www.futurepedia.io/submit-tool | High traffic; "Code" category |
| Toolify.ai | https://www.toolify.ai/submit | Good SEO backlinks; "Developer Tools" |
| aitools.fyi | https://aitools.fyi/submit | Free listing |
| AI Tool Hunt / Insidr / SaaSAI | (various) | Batch-submit with the same copy |
| AlternativeTo | https://alternativeto.net | List Draft as an alternative to CodeRabbit / Copilot review |
| OpenSourceAlternative.to | https://www.opensourcealternative.to | Strong fit: OSS alternative to paid AI review |

**Directory copy (paste into the form fields):**

- **Name:** Draft
- **Category:** Developer Tools → Code Review / Coding Assistant
- **Short tagline:** Stop shipping AI-generated bugs.
- **Description (≤ 300 chars):**
  ```
  Draft is a free, open-source plugin for AI coding agents (Claude Code, Cursor,
  Codex, opencode). One command runs a 3-stage review — validation, spec
  compliance, code quality — backed by a 100% local 159-language knowledge graph.
  No API key, MIT.
  ```
- **Pricing:** Free / Open Source
- **Tags:** code-review, ai-agents, claude-code, cursor, open-source, developer-tools, tdd
- **Website:** https://getdraft.dev · **Repo:** https://github.com/drafthq/draft

## B. Newsletters / curated roundups (pitch an editor)

| Outlet | How to reach | Angle |
|--------|-------------|-------|
| TLDR AI | https://tldr.tech/ (sponsor/tip form) | "Open-source review layer for AI coding agents" |
| Ben's Bites | reply to newsletter / submit form | Indie OSS dev-tool |
| The Rundown AI | tips/submission form | Tool of the day |
| AI Tidbits / The Neuron | editor email | Dev-tooling segment |
| Console.dev | https://console.dev (submit a tool) | Curated dev tools — strong fit |
| Changelog News | news@changelog.com | OSS + dev-workflow audience |
| Hacker News | Show HN post (self) | See Show HN copy below |

**Pitch email (≤ 120 words):**

```
Subject: Draft — open-source 3-stage review for AI coding agents (MIT)

Hi <name>,

Quick one for <outlet>'s dev/AI readers: Draft is a free, MIT-licensed plugin
that adds a review layer to AI coding agents (Claude Code, Cursor, Codex,
opencode). One command, /draft:review, runs three passes over a branch —
test/lint/type validation, spec compliance, and code-quality — with the quality
pass backed by a 100% local, 159-language knowledge graph (blast radius +
hotspots, no API key, nothing leaves the machine). 33 commands total.

Install is one line: npx @drafthq/draft install claude-code

Repo: https://github.com/drafthq/draft · Site: https://getdraft.dev
Happy to send screenshots or a 60s demo. Thanks!
```

**Show HN copy:**

```
Title: Show HN: Draft – a local, open-source 3-stage review for AI coding agents

Body:
AI agents write code fast but ship bugs, pattern drift, and missing tests. Draft
is an MIT plugin (Claude Code, Cursor, Codex, opencode) where /draft:review runs
validation + spec-compliance + code-quality over your branch. The quality pass is
backed by a tree-sitter knowledge graph that runs 100% locally across 159
languages — so it reasons about blast radius and hotspots, not just the diff. No
API key, no SaaS. One-line install: npx @drafthq/draft install claude-code.
Repo: https://github.com/drafthq/draft — feedback welcome.
```

## Submission tips
- Use the **same name, tagline, and bare URL** everywhere (consistency aids SEO + dedup).
- Lead every form with "free / open-source / MIT / local" — it's the differentiator vs. paid review tools.
- Where a directory asks for a "best alternative to," name **CodeRabbit, Greptile, or Copilot review** — that maps Draft into an existing search intent.
- Track every live listing URL back in `README.md`'s tracker for backlink auditing.
