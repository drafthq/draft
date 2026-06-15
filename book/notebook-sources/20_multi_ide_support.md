# Chapter 20: Multi-IDE Support

Part VI: Enterprise· Chapter 20

4 min read

Draft is not locked to a single AI coding tool. The methodology — the skills, agents, templates, and procedures — exists as markdown and bash, independent of any platform. A build pipeline transforms these source files into platform-specific integration formats. The result: every supported IDE gets the same methodology, with minor syntax adaptations.

## Claude Code (Native)

Claude Code is Draft's native environment. Install with:

`npx @drafthq/draft install claude-code`

All 33 commands are available as/draft:*slash commands. Skills are loaded from the.claude-plugin/plugin.jsonmanifest, which points to theskills/directory. Each skill'sSKILL.mdfile is read at invocation time, giving Claude Code direct access to the full methodology without any transformation.

The 7 specialized agents (Architect, Debugger, Planner, RCA, Reviewer, Ops, Writer) are referenced as@architect,@debugger, etc., and resolved fromcore/agents/.

## Cursor

Cursor natively supports the.claude/plugin structure, making it a near-identical experience to Claude Code. Install with:

`npx @drafthq/draft install cursor`

Commands use/draft:*syntax:/draft:init,/draft:new-track,/draft:implement. The same plugin.json, the same skill files, the same agent definitions — no separate build step required.

## GitHub Copilot

Copilot does not have a plugin system that can read skill files at runtime. Instead, Draft uses a.github/copilot-instructions.mdfile — a single, large generated file (~23,600 lines) that encodes the entire Draft methodology inline.

This file is produced by the build pipeline (scripts/build-integrations.sh) and includes:

* All 33 skill definitions (minus frontmatter, plus syntax transforms)
* All 62 core reference files (methodology, knowledge base, shared procedures, templates, agent definitions)
* Quality disciplines, communication style, and proactive behaviors
* Intent mapping for natural language triggers
Two key syntax transformations apply:

Installation copies the generated file into the project:

`npx @drafthq/draft install copilot`

## Gemini

Gemini uses a.gemini.mdbootstrap file that instructs Gemini where to find Draft's skill files. Rather than inlining all content (as Copilot requires), the bootstrap points to the skills directory and lets Gemini read files as needed.

`npx @drafthq/draft install gemini`

## OpenCode

OpenCode is supported via the same plugin structure as Claude Code.

`npx @drafthq/draft install opencode`

## Codex

Codex is supported via the same plugin structure as Claude Code.

`npx @drafthq/draft install codex`

## The Build Pipeline

The transformation from source skills to platform-specific integrations is handled byscripts/build-integrations.sh, a ~700-line bash script that is the critical path for multi-IDE support.

The pipeline works as follows:

* Skill ordering— ASKILL_ORDERarray defines the 33 skills and their generation order. This order is independent of the alphabetical order inplugin.json.
* Frontmatter extraction— Each skill's YAML frontmatter (name:anddescription:) is validated. The body is extracted viaextract_body(), which strips the frontmatter delimiters.
* Body format validation— The body must follow a strict format: blank line,# Titleheading, blank line, then content. The build skips the first 3 body lines when inlining (the title is replaced by the integration's section header).
* Syntax transformation— Platform-specific transforms are applied:/draft:commandbecomesdraft commandfor Copilot, agent references become@workspace.
* Core file inlining— 62 core reference files (methodology, shared procedures, templates, agents) are inlined into the output, each wrapped in<core-file>tags.
* Verification—verify_output()checks minimum line count (>1000), completeness sentinel (DRAFT_BUILD_COMPLETE), and that no untransformed syntax remains.
The build is atomic: output is written to a temporary file, verified, then moved to the final location. A failed verification deletes the temp file and exits with an error, leaving the previous output intact.

## Choosing Your IDE

All supported IDEs receive the same Draft methodology. The differences are operational, not functional:

The methodology is identical. The context files are identical. The plans, specs, architecture documents, and tracks are identical regardless of which IDE produced them. A team can have one developer using Claude Code and another using Copilot — both work on the samedraft/directory with full compatibility.

Skills (skills/<name>/SKILL.md) are the source of truth. Integration files are generated artifacts. Never edit.github/copilot-instructions.mddirectly — edit the skill, runmake build, and the integration files are regenerated. This ensures all platforms stay in sync.

