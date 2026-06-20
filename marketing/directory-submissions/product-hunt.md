# Product Hunt — Launch / Relaunch Kit

## ⚠ Relaunch eligibility (check this first)

Product Hunt allows a new launch for the **same product only if**:
- It has been **≥ 6 months** since the previous launch, **and**
- There is a **significant update** (major new functionality / redesign — not a
  pricing tweak or minor UI change), serving a substantially different use case.

If both are true → launch normally. If it's been < 6 months but you shipped a
major change (e.g. the OKF taxonomy mode, multi-host install across
Cursor/Codex/opencode, the local knowledge-graph engine), you can **request an
early relaunch**: message Product Hunt support explaining the significant changes
and get approval before posting.

If Draft has **never** launched → this is a first launch; skip the relaunch gate.

---

## Listing fields

- **Name:** Draft
- **Tagline (≤ 60 chars):** `Stop shipping AI-generated bugs`
  - Alts: `One-command code review for your AI coding agent` · `Catch the 3 bugs your AI just wrote`
- **Topics/Categories:** Developer Tools, Artificial Intelligence, GitHub, Open Source, Code Review
- **Links:**
  - Website: https://getdraft.dev
  - GitHub: https://github.com/drafthq/draft
  - Install: `npx @drafthq/draft install claude-code`
- **Pricing:** Free / Open Source

## Description (the "what is it" field)

```
Your AI assistant just wrote 200 lines. Some are bugs. Some don't match your
patterns. Some skip tests.

Draft is a Context-Driven Development plugin for AI coding agents — Claude Code,
Cursor, Codex, and opencode. One command, /draft:review, runs a three-stage
review over your branch:

1. Validation — runs your tests, lints, and type-checks, surfacing real failures
2. Spec compliance — checks the diff against the agreed spec, not vibes
3. Code quality — flags hotspots, blast radius, and missing coverage using a
   tree-sitter knowledge graph of your repo

It's 100% local (159 languages, no API key, no SaaS) and ships 32 more commands
for spec-driven planning, TDD implementation, bug hunting, and architectural
audits. Free. MIT. No paid tier.
```

## Maker's first comment (post immediately after launch)

```
Hey hunters 👋

I built Draft because AI coding agents are fast but unstructured — they write
code that *looks* right and quietly ships bugs, pattern violations, and missing
tests. Reviewing that by hand defeats the speed you came for.

Draft adds a review layer your agent runs itself. `/draft:review` does three
passes — validation, spec-compliance, and code quality — and the quality pass is
backed by a knowledge graph of your repo, so it knows blast radius and hotspots,
not just the diff. Everything runs locally: no API key, no data leaves your
machine, MIT licensed.

Install is one line and it works across Claude Code, Cursor, Codex, and opencode:
`npx @drafthq/draft install claude-code`

I'd love feedback on: (1) what your AI agent ships that you wish got caught
earlier, and (2) which host you'd want supported next. I'm here all day —
ask me anything!
```

## Gallery / media checklist

- [ ] **Thumbnail (240×240):** Draft logo on brand background
- [ ] **Gallery image 1 (1270×760):** the `/draft:review` 3-stage output (the money shot)
- [ ] **Gallery image 2:** blast-radius / hotspot graph view (`graph-impact` output)
- [ ] **Gallery image 3:** one-line multi-host install matrix
- [ ] **Gallery image 4:** command map (`/draft` overview, 33 commands)
- [ ] **Demo video / GIF:** trim the 8-min walkthrough (https://www.youtube.com/watch?v=gBSwFEFVd7Y) to a 30–60s loop of `review` catching a real bug
- [ ] Reuse `web/social-preview.png` as a fallback social card

## Launch logistics

- **Day:** Tue–Thu, post at **12:01 AM PT** (resets the 24-hour leaderboard in your favor).
- **Hunter:** self-hunt is fine; an established hunter helps reach but isn't required.
- **First hour:** notify your network (don't ask for "upvotes" — PH penalizes that;
  ask people to "check it out and leave feedback").
- **Engage:** reply to every comment within minutes for the first few hours.
- **Cross-post** the launch to the relevant subreddits / Discords / X on the same day.
```
