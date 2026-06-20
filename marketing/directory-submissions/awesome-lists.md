# Awesome List Submissions

Most awesome lists require either (a) a PR that edits `README.md`, or (b) a
GitHub Issue using a "resource submission" form. Each target below says which.

## The canonical entry (use everywhere, trim per list style)

**Long form:**

```markdown
- [Draft](https://github.com/drafthq/draft) - Context-Driven Development plugin for Claude Code, Cursor, Codex & opencode. One command runs a 3-stage review — validation, spec compliance, and code quality — backed by a 100% local, 159-language knowledge-graph engine. 33 commands. Free, MIT, no API key.
```

**Short form (terse lists like sindresorhus/awesome style):**

```markdown
- [Draft](https://github.com/drafthq/draft) - One-command 3-stage review for AI-generated code, backed by a local knowledge graph. MIT.
```

Notes for entry hygiene (most awesome lists lint for this):
- No trailing period rule varies — match the surrounding entries exactly.
- Use the bare repo URL, not a tracking/UTM link.
- Place alphabetically within the chosen section unless the list is curated by recency.

---

## 1. hesreallyhim/awesome-claude-code  ⭐ highest-relevance target

The de-facto list for Claude Code plugins/skills/commands. Submission is via a
**GitHub Issue form**, not a direct README PR (the README/table of contents is
auto-generated from validated submissions).

**Steps:**
1. Go to https://github.com/hesreallyhim/awesome-claude-code/issues/new/choose
2. Pick the **Resource Submission** template (titles look like `[Resource]: ...`).
3. Fill in:
   - **Display name:** Draft
   - **Category:** Plugins (it's a full plugin / command suite, not a single command)
   - **Primary link:** https://github.com/drafthq/draft
   - **Author:** mayurpise (drafthq)
   - **License:** MIT
   - **Description:** `Context-Driven Development plugin: /draft:review runs a 3-stage review (validation + spec compliance + code quality) over your branch, backed by a 100% local 159-language knowledge-graph engine. 33 commands, free, MIT.`
4. Submit. A validation bot labels it `validation-passed`/`validation-failed`;
   fix any flagged issues (usually link reachability or description length).

If a `secondary` link is requested, use https://getdraft.dev.

---

## 2. ai-for-developers/awesome-ai-coding-tools  (PR)

A curated README of AI coding tools grouped by category (editors, agents,
code-review assistants, testing…). Draft fits **Code Review** and/or **Agents**.

**Steps:**
1. Fork https://github.com/ai-for-developers/awesome-ai-coding-tools
2. Open `README.md`, find the most fitting section (e.g. "Code Review" /
   "AI Agents"). Add the long-form entry alphabetically.
3. Commit on a branch `add-draft`, open a PR titled
   **`Add Draft (Context-Driven Development review plugin)`**.
4. PR body — use the template at the bottom of this file.

---

## 3. furudo-erika/awesome-ai-coding-tools  (PR)

Same mechanism as #2 (separate maintainer, same niche). Reuse the fork/PR flow
and the long-form entry. Place under the closest category to "code review /
quality".

---

## 4. eudk/awesome-ai-tools  (PR)

Very large general AI-tools list (broad audience, high traffic). Put Draft in a
**Developer / Coding** section.

**Steps:** fork → edit `README.md` → add long-form entry → PR
**`Add Draft — open-source AI code-review plugin`**.

---

## 5. sourcegraph/awesome-code-ai  ⚠ archived

This well-known list is **archived/read-only**, so PRs can't be merged. Leave on
the tracker as "skip/monitor"; if it's ever un-archived, submit the short-form
entry under the "Code review" section.

---

## "Awesome-OpenSource" — disambiguation needed

There is no single canonical repo literally named `Awesome-OpenSource` that
accepts tool listings the way the above do. The likely intents:

- **A general "awesome" list** (e.g. `sindresorhus/awesome`) — that list only
  accepts *other awesome lists*, not individual tools, so Draft itself is not
  eligible there. We'd instead need a standalone `awesome-context-driven-development`
  list to qualify (out of scope here).
- **An open-source-projects directory site** (e.g. opensourcealternative.to,
  libhunt, Awesome Open Source aggregators) — these are handled as roundups; see
  `ai-tool-roundups.md`.

➡ **Recommended substitute targets** that match the original intent (open-source +
discovery) and *do* accept tool entries:
  - `hesreallyhim/awesome-claude-code` (covered above)
  - `e2b-dev/awesome-ai-agents` (PR; "agents/dev-tools" section)
  - `Hannibal046/Awesome-LLM` → "Tools" (only if it grows a dev-tooling section)

Confirm with the requester which "Awesome-OpenSource" was meant before spending
effort; the substitutes above deliver the same discovery value.

---

## Reusable PR body template

```markdown
### Adding: Draft

**Repo:** https://github.com/drafthq/draft
**Website:** https://getdraft.dev
**License:** MIT (free, open-source, no API key)

Draft is a Context-Driven Development plugin for AI coding agents (Claude Code,
Cursor, Codex, opencode). Its wedge command, `/draft:review`, runs a 3-stage
review over your branch — test/lint/type validation, spec-compliance, and code
quality — using a 100% local, 159-language knowledge-graph engine for blast-radius
and hotspot analysis. 33 commands total.

- [x] Entry added alphabetically in the most relevant section
- [x] Link is the bare canonical repo URL (no tracking params)
- [x] Description matches the list's length/style conventions
- [x] Project is open-source (MIT) and actively maintained
```
