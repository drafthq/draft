#!/usr/bin/env bash
#
# Build integration files from skill sources
# Generates: GitHub Copilot copilot-instructions.md
#
# Note: Cursor integration removed - Cursor now supports .claude-plugin/ structure natively.
#
# Skills are the single source of truth for all integrations.
#
# Adding a new skill:
#   1. Create skills/<name>/SKILL.md
#   2. Add the skill name to SKILL_ORDER array in lib.sh
#   3. Add display name and trigger to the case statements below
#   4. Run this script
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="$ROOT_DIR/skills"
CORE_DIR="$ROOT_DIR/core"
COPILOT_OUTPUT="$ROOT_DIR/integrations/copilot/.github/copilot-instructions.md"

# Source shared library for SKILL_ORDER, CORE_FILES, extract_body
source "$SCRIPT_DIR/lib.sh"

# ─────────────────────────────────────────────────────────
# Skill metadata: display headers
# ─────────────────────────────────────────────────────────

get_skill_header() {
    local skill="$1"
    case "$skill" in
        draft)             echo "Draft Overview" ;;
        init)              echo "Init Command" ;;
        index)             echo "Index Command" ;;
        new-track)         echo "New Track Command" ;;
        decompose)         echo "Decompose Command" ;;
        implement)         echo "Implement Command" ;;
        coverage)          echo "Coverage Command" ;;
        deploy-checklist)  echo "Deploy Checklist Command" ;;
        bughunt)           echo "Bug Hunt Command" ;;
        review)            echo "Review Command" ;;
        quick-review)      echo "Quick Review Command" ;;
        deep-review)       echo "Deep Review Command" ;;
        testing-strategy)  echo "Testing Strategy Command" ;;
        learn)             echo "Learn Command" ;;
        adr)               echo "ADR Command" ;;
        debug)             echo "Debug Command" ;;
        standup)           echo "Standup Command" ;;
        tech-debt)         echo "Tech Debt Command" ;;
        incident-response) echo "Incident Response Command" ;;
        documentation)     echo "Documentation Command" ;;
        status)            echo "Status Command" ;;
        revert)            echo "Revert Command" ;;
        change)            echo "Change Command" ;;
        plan)              echo "Plan Router" ;;
        ops)               echo "Ops Router" ;;
        docs)              echo "Docs Router" ;;
        discover)          echo "Discover Router" ;;
        jira)              echo "Jira Router" ;;
        integrations)      echo "Integrations Router" ;;
        tour)              echo "Tour Command" ;;
        impact)            echo "Impact Command" ;;
        assist-review)     echo "Assist Review Command" ;;
        *)                 echo "$(echo "${skill:0:1}" | tr '[:lower:]' '[:upper:]')${skill:1} Command" ;;
    esac
}

# ─────────────────────────────────────────────────────────
# Skill metadata: triggers (natural language → command)
# ─────────────────────────────────────────────────────────

get_copilot_trigger() {
    local skill="$1"
    case "$skill" in
        draft)             echo "\"help\" or \"draft\"" ;;
        init)              echo "\"init draft\" or \"draft init [refresh]\"" ;;
        index)             echo "\"index services\" or \"draft index [--init-missing]\"" ;;
        new-track)         echo "\"new feature\" or \"draft new-track <description>\"" ;;
        decompose)         echo "\"break into modules\" or \"draft decompose\"" ;;
        implement)         echo "\"implement\" or \"draft implement\"" ;;
        coverage)          echo "\"check coverage\" or \"draft coverage\"" ;;
        deploy-checklist)  echo "\"deploy checklist\" or \"draft deploy-checklist [track <id>]\"" ;;
        bughunt)           echo "\"hunt bugs\" or \"draft bughunt [--track <id>]\"" ;;
        review)            echo "\"review code\" or \"draft review [--track <id>] [--full]\"" ;;
        quick-review)      echo "\"quick review\" or \"draft quick-review [file|pr <number>]\"" ;;
        deep-review)       echo "\"deep review\" or \"draft deep-review [module]\"" ;;
        testing-strategy)  echo "\"test strategy\" or \"draft testing-strategy [track <id>|path]\"" ;;
        learn)             echo "\"learn patterns\" or \"draft learn [promote|migrate|path]\"" ;;
        adr)               echo "\"document decision\" or \"draft adr [title]\"" ;;
        debug)             echo "\"debug bug\" or \"draft debug [description|track <id>]\"" ;;
        standup)           echo "\"standup\" or \"draft standup [date|week|save]\"" ;;
        tech-debt)         echo "\"tech debt\" or \"draft tech-debt [path|track <id>]\"" ;;
        incident-response) echo "\"incident\" or \"draft incident-response [new|update|postmortem]\"" ;;
        documentation)     echo "\"write docs\" or \"draft documentation [readme|runbook|api|onboarding]\"" ;;
        status)            echo "\"status\" or \"draft status\"" ;;
        revert)            echo "\"revert\" or \"draft revert\"" ;;
        change)            echo "\"handle change\" or \"draft change <description>\"" ;;
        plan)              echo "\"plan feature\" or \"draft plan <intent>\" (new-track, decompose, adr, tech-debt, change)" ;;
        ops)               echo "\"ops deploy\" or \"draft ops <intent>\" (deploy-checklist, incident, standup, status, revert)" ;;
        docs)              echo "\"write docs\" or \"draft docs <intent>\" (documentation)" ;;
        discover)          echo "\"discover debug\" or \"draft discover <intent>\" (debug, bughunt, reviews, coverage, learn, index, etc.)" ;;
        jira)              echo "\"jira preview\", \"jira create\", or \"jira review <ID>\"" ;;
        integrations)      echo "\"integrations\", \"integrations jira-preview\", or \"integrations jira-create\"" ;;
        tour)              echo "\"tour\" or \"draft tour\"" ;;
        impact)            echo "\"impact\" or \"draft impact\"" ;;
        assist-review)     echo "\"assist review\" or \"draft assist-review\"" ;;
        *)                 echo "\"draft $skill\"" ;;
    esac
}

# ─────────────────────────────────────────────────────────
# Syntax transforms for Copilot (no slash commands or @mentions)
# ─────────────────────────────────────────────────────────

transform_copilot_syntax() {
    # Skill names are kebab-case: [a-z][a-z0-9-]*. Reject anything else so
    # placeholder-laden examples like "/draft:<id>" or addresses like
    # "foo@draft.com" don't get mangled. Use `#` as the sed delimiter so the
    # alternations in `(^|...)` don't collide with `|`.
    sed -E \
        -e 's#/draft:(<[a-z-]+>)#draft \1#g' \
        -e 's#/draft:([a-z][a-z0-9-]*)#draft \1#g' \
        -e 's#(^|[^[:alnum:]_.-])@draft([^[:alnum:]_.-])#\1draft\2#g' \
        -e 's#(^|[^[:alnum:]_.-])@draft$#\1draft#g' \
        -e 's#`@draft`#`draft`#g' \
        -e 's#`@draft #`draft #g' \
        -e 's#@(architect|debugger|planner|rca|reviewer|ops|writer)([^[:alnum:]_-])#@workspace\2#g' \
        -e 's#@(architect|debugger|planner|rca|reviewer|ops|writer)$#@workspace#g'
}

# ─────────────────────────────────────────────────────────
# Emit all core reference files as appendices
# ─────────────────────────────────────────────────────────

emit_core_files() {
    local transform_fn="$1"

    echo ""
    echo "---"
    echo ""
    echo "# Core Reference Files"
    echo ""
    echo "> These files are inlined for integrations that cannot access the core/ directory at runtime."
    echo ""

    for core_file in "${CORE_FILES[@]}"; do
        local full_path="$CORE_DIR/$core_file"
        if [[ -f "$full_path" ]]; then
            echo ""
            echo "---"
            echo ""
            echo "## core/${core_file}"
            echo ""
            echo "<core-file path=\"core/${core_file}\">"
            echo ""
            "$transform_fn" < "$full_path"
            echo ""
            echo "</core-file>"
        else
            echo "" >&2
            echo "ERROR: Core file not found: $full_path" >&2
            exit 1
        fi
    done
}

# ─────────────────────────────────────────────────────────
# Shared content blocks
# ─────────────────────────────────────────────────────────

emit_quality_disciplines() {
    cat << 'QUALITY'
## Quality Disciplines

### Verification Before Completion
**Iron Law:** No completion claims without fresh verification evidence.
- Run verification command (test/build/lint) IN THIS MESSAGE
- Show output as evidence
- Only then mark `[x]`

### Systematic Debugging (Debugger Agent)
**Iron Law:** No fixes without root cause investigation first.

When blocked (`[!]`), follow the four phases IN ORDER:

1. **Investigate** - Read errors, reproduce, trace data flow (NO fixes yet)
   - Read full error message, stack trace, logs
   - Reproduce consistently
   - Trace data from input to error point
   - Document what you observe

2. **Analyze** - Find similar working code, list differences
   - Compare working vs. failing cases
   - Check and verify each assumption
   - Narrow to the smallest change that breaks

3. **Hypothesize** - Single hypothesis, smallest test
   - One cause, one test — predict outcome before running
   - If wrong, return to Analyze (don't try random fixes)

4. **Implement** - Regression test first, then fix
   - Write a test that fails now, will pass after fix
   - Minimal fix for root cause only
   - Run full test suite to confirm no breakage
   - Document root cause in plan.md

**Anti-patterns:** "Let me try this...", changing multiple things at once, skipping reproduction, fixing without understanding. If after 3 hypothesis cycles no root cause found: document findings, list eliminations, ask for external input.

### Three-Stage Review (Reviewer Agent)
At phase boundaries, run ALL three stages in order:

**Stage 1: Automated Validation** (REQUIRED) — Is the code structurally sound and secure?
- Architecture conformance (no pattern violations, module boundaries respected)
- Dead code detection (no unused exports, no unreachable paths)
- Dependency cycle check (no circular imports)
- Security scan (no hardcoded secrets, no injection risks)
- Performance anti-patterns (no N+1 queries, no blocking I/O in async)

**If Stage 1 FAILS:** Stop. List structural failures and return to implementation.

**Stage 2: Spec Compliance** (only if Stage 1 passes) — Did we build what was specified?
- All functional requirements implemented
- All acceptance criteria met
- No missing features, no scope creep
- Edge cases and error scenarios addressed

**If Stage 2 FAILS:** Stop. List gaps and return to implementation.

**Stage 3: Code Quality** (only if Stage 2 passes) — Is the code well-crafted?
- Follows project patterns (tech-stack.md)
- Appropriate error handling
- Tests cover real logic (not implementation details)
- No obvious performance or security issues

**Issue Classification:**
- **Critical** — Blocks release, breaks functionality, security issue → Must fix before proceeding
- **Important** — Degrades quality, creates tech debt → Should fix before phase complete
- **Minor** — Style, optimization → Note for later, don't block

Only proceed to next phase if Stage 1 passes and no Critical issues remain.

### Architecture Agent (when architecture mode enabled)

**Module Decomposition Rules:**
1. Single Responsibility — each module owns one concern
2. Size Constraint — 1-3 files per module; split if more
3. Clear API Boundary — every module has a defined public interface
4. Minimal Coupling — communicate through interfaces, not internals
5. Testable in Isolation — each module can be unit-tested independently

**Cycle-Breaking:** When circular dependencies detected:
- Extract shared interface into a new `<concern>-types` or `<concern>-core` module
- Invert dependency (accept callback/interface instead of importing)
- Merge if modules are actually one concern split artificially

**Story Lifecycle:**
QUALITY
}

emit_communication() {
    cat << 'COMMUNICATION'
## Communication Style

Lead with conclusions. Be concise. Prioritize clarity over comprehensiveness.

- Direct, professional tone
- Code over explanation when implementing
- Complete, runnable code blocks
- Show only changed lines with context for updates
- Ask clarifying questions only when requirements are genuinely ambiguous

COMMUNICATION
}

emit_proactive() {
    cat << 'PROACTIVE'
## Proactive Behaviors

1. **Context Loading** - Always read relevant draft files before acting
2. **Progress Tracking** - Update plan.md and metadata.json after each task
3. **Verification Prompts** - Ask for manual verification at phase boundaries
4. **Commit Suggestions** - Suggest commits following workflow.md patterns

## Error Recovery

If user seems lost:
- Check status to orient them
- Reference the active track's spec.md for requirements
- Suggest next steps based on plan.md state
PROACTIVE
}

# ─────────────────────────────────────────────────────────
# Build the copilot-instructions.md
# ─────────────────────────────────────────────────────────

build_copilot() {
    # ── Header ────────────────────────────────────────────
    cat << 'COMMON_HEADER'
# Draft - Context-Driven Development

You are operating with the Draft methodology for Context-Driven Development.

**Measure twice, code once.**

## Core Workflow

**Context -> Spec & Plan -> Implement**

Every feature follows this lifecycle:
1. **Setup** - Initialize project context (once per project)
2. **New Track** - Create specification and plan
3. **Implement** - Execute tasks with TDD workflow
4. **Verify** - Confirm acceptance criteria met

## Project Context Files

When `draft/` exists in the project, always consider:
- `draft/.ai-context.md` - Source of truth for AI agents (dense codebase understanding)
- `draft/.ai-profile.md` - Ultra-compact profile (always loaded, 20-50 lines)
- `draft/architecture.md` - Human-readable engineering guide (source of truth)
- `draft/product.md` - Product vision and goals
- `draft/tech-stack.md` - Technical constraints
- `draft/workflow.md` - TDD and commit preferences
- `draft/tracks.md` - Active work items
- `draft/guardrails.md` - Hard rules and learned patterns

## Available Commands

| Command | Purpose |
|---------|---------|
COMMON_HEADER

    # Command table - 5 routers are the recommended primary interface
    echo "| \`draft\` | Show overview and available commands |"
    echo "| \`draft init\` | Initialize project (run once) |"
    echo "| \`draft new-track <description>\` | Create feature/bug track |"
    echo "| \`draft implement\` | Execute tasks from plan |"
    echo "| \`draft review [--track <id>]\` | Three-stage code review |"

    echo "| \`draft plan <intent>\` | Planning & architecture router (new-track, decompose, adr, tech-debt, change) |"
    echo "| \`draft ops <intent>\` | Operations & lifecycle router (deploy-checklist, incident, standup, status, revert) |"
    echo "| \`draft docs <intent>\` | Authoring router (documentation) |"
    echo "| \`draft discover <intent>\` | Investigation & quality router (debug, bughunt, reviews, coverage, learn...) |"
    echo "| \`draft jira [preview|create|review <ID>]\` | Unified Jira integration (preview, create, review) |"

    echo "| \`draft decompose\` | Module decomposition with dependency mapping |"
    echo "| \`draft coverage\` | Code coverage report (target 95%+) |"
    echo "| \`draft deploy-checklist [track <id>]\` | Pre-deployment verification checklist |"
    echo "| \`draft bughunt [--track <id>]\` | Systematic bug discovery |"
    echo "| \`draft quick-review [file|pr <number>]\` | Lightweight 4-dimension review |"
    echo "| \`draft deep-review [module]\` | Exhaustive production-grade module audit |"
    echo "| \`draft testing-strategy [track <id>|path]\` | Design test strategy with coverage targets |"
    echo "| \`draft learn [promote\\|migrate]\` | Discover coding patterns, update guardrails |"
    echo "| \`draft adr [title]\` | Architecture Decision Records |"
    echo "| \`draft debug [description|track <id>]\` | Structured debugging session |"
    echo "| \`draft standup [date|week|save]\` | Generate standup summary |"
    echo "| \`draft tech-debt [path|track <id>]\` | Identify and prioritize tech debt |"
    echo "| \`draft incident-response [new|update|postmortem]\` | Incident management lifecycle |"
    echo "| \`draft documentation [readme|runbook|api|onboarding]\` | Technical documentation |"
    echo "| \`draft status\` | Show progress overview |"
    echo "| \`draft revert\` | Git-aware rollback |"
    echo "| \`draft change <description>\` | Handle mid-track requirement changes |"
    echo "| \`draft index [--init-missing]\` | Aggregate monorepo service contexts |"
    echo "| \`draft tour\` | Interactive onboarding tour |"
    echo "| \`draft impact\` | Telemetry and analytics insights |"
    echo "| \`draft assist-review\` | Assist human reviewers with architectural risk audit |"

    # Rest of common header
    cat << 'COMMON_HEADER2'

## Intent Mapping

Recognize these natural language patterns:

| User Says | Action |
|-----------|--------|
| "set up the project" | Run init |
| "index services", "aggregate context" | Run index |
| "new feature", "add X" | Create new track |
| "break into modules", "decompose" | Run decompose |
| "start implementing" | Execute implement |
| "check coverage", "test coverage" | Run coverage |
| "deploy checklist", "pre-deploy check" | Run deploy-checklist |
| "hunt bugs", "find bugs" | Run bughunt |
| "review code", "review track", "check quality" | Run review |
| "quick review", "lightweight review" | Run quick-review |
| "deep review", "production audit", "module audit" | Run deep-review |
| "test strategy", "plan tests" | Run testing-strategy |
| "learn patterns", "update guardrails", "discover conventions" | Run learn |
| "document decision", "create ADR" | Create architecture decision record |
| "debug bug", "investigate issue" | Run debug |
| "standup", "daily summary" | Run standup |
| "tech debt", "identify debt" | Run tech-debt |
| "incident", "outage", "postmortem" | Run incident-response |
| "write docs", "document" | Run documentation |
| "what's the status" | Show status |
| "undo", "revert" | Run revert |
| "requirements changed", "scope changed", "update the spec" | Run change |
| "plan the work", "new feature", "tech debt", "adr", "decompose" | Run draft plan (router) |
| "ops task", "deploy", "incident", "standup", "status", "revert" | Run draft ops (router) |
| "write docs", "documentation" | Run draft docs (router) |
| "discover", "debug", "review code", "hunt bugs", "coverage" | Run draft discover (router) |
| "jira", "send to Jira", "jira review" | Run draft jira (router) |
| "tour", "onboard me" | Run tour |
| "impact", "analytics" | Run impact |
| "assist review", "help reviewer" | Run assist-review |
| "help", "what commands" | Show draft overview |
| "the plan" | Read active track's plan.md |
| "the spec" | Read active track's spec.md |

## Tracks

A **track** is a high-level unit of work (feature, bug fix, refactor). Each track contains:
- `spec.md` - Requirements and acceptance criteria
- `plan.md` - Phased task breakdown
- `metadata.json` - Status and timestamps

Located at: `draft/tracks/<track-id>/`

## Status Markers

Recognize and use these throughout plan.md:
- `[ ]` - Pending
- `[~]` - In Progress
- `[x]` - Completed
- `[!]` - Blocked

COMMON_HEADER2

    # ── Skill loop ────────────────────────────────────────
    for skill in "${SKILL_ORDER[@]}"; do
        # Skip 'draft' skill — its content (commands table, core workflow,
        # status markers) is already covered by the static header above.
        if [[ "$skill" == "draft" ]]; then
            continue
        fi

        # Validate skill name format (security: prevent path traversal)
        if ! is_valid_skill_name "$skill"; then
            echo "ERROR: Invalid skill name '$skill' (must be kebab-case)" >&2
            exit 1
        fi

        local skill_file="$SKILLS_DIR/$skill/SKILL.md"
        if [[ -f "$skill_file" ]]; then
            # Extract body once and cache
            local skill_body
            skill_body=$(extract_body "$skill_file")

            # Validate body format (blank, '# Title', blank) via shared helper.
            validate_skill_body_format "$skill" "$skill_file" || exit 1

            echo ""
            echo "---"
            echo ""
            echo "## $(get_skill_header "$skill")"
            echo ""
            echo "When user says $(get_copilot_trigger "$skill"):"
            echo ""
            # Emit body from line 4 onward (skip blank, title, blank)
            echo "$skill_body" | transform_copilot_syntax | tail -n +4

            # Inline progressive-disclosure references (skills/<skill>/references/*.md)
            # Sorted alphabetically for determinism. Skills with no references/ dir are skipped.
            local refs_dir="$SKILLS_DIR/$skill/references"
            if [[ -d "$refs_dir" ]]; then
                local ref_file
                while IFS= read -r -d '' ref_file; do
                    echo ""
                    transform_copilot_syntax < "$ref_file"
                done < <(find "$refs_dir" -maxdepth 1 -type f -name '*.md' -print0 | sort -z)
            fi
        else
            echo "" >&2
            echo "ERROR: Skill file not found: $skill_file" >&2
            exit 1
        fi
    done

    # ── Quality disciplines ───────────────────────────────
    echo ""
    echo "---"
    echo ""

    emit_quality_disciplines

    # Story lifecycle with draft command
    echo "1. Placeholder during \`draft decompose\` → \"[placeholder]\" in architecture.md"
    echo "2. Written during \`draft implement\` → code comment at file top, summary in architecture.md"
    echo "3. Updated during refactoring → code comment is source of truth"
    echo ""
    echo "### Red Flags - STOP if you're:"
    echo "- Making completion claims without running verification"
    echo "- Fixing bugs without investigating root cause"
    echo "- Skipping spec compliance check at phase boundary"
    echo "- Writing code before tests (when TDD enabled)"
    echo "- Reporting status without reading actual files"
    echo ""

    # ── Communication and behaviors ───────────────────────
    echo ""
    echo "---"
    echo ""

    emit_communication
    emit_proactive

    # ── Inline core files ─────────────────────────────────
    emit_core_files "transform_copilot_syntax"

    # Completeness sentinel — verified by verify_output
    echo ""
    echo "<!-- DRAFT_BUILD_COMPLETE -->"
}

# ─────────────────────────────────────────────────────────
# Verification
# ─────────────────────────────────────────────────────────

verify_output() {
    local output_file="$1"

    local line_count old_syntax_count at_draft_count
    read -r line_count old_syntax_count at_draft_count < <(awk '
        {
            total_lines++
            if (/\/draft:/) old_count++
            if (/@draft/) at_count++
        }
        END {
            print total_lines+0, old_count+0, at_count+0
        }
    ' "$output_file")

    echo "  Lines: $line_count"

    # Verify completeness sentinel
    if ! tail -5 "$output_file" | grep -q "DRAFT_BUILD_COMPLETE"; then
        echo "  FAIL: Missing completeness sentinel — output may be truncated" >&2
        return 1
    fi

    # Verify minimum line count
    if [[ "$line_count" -lt 1000 ]]; then
        echo "  FAIL: Output too small ($line_count lines, expected >1000) — likely truncated" >&2
        return 1
    fi

    # Count skills included (mirror build_copilot: 'draft' is excluded from output)
    local skill_count=0 skill_total=0
    for skill in "${SKILL_ORDER[@]}"; do
        [[ "$skill" == "draft" ]] && continue
        skill_total=$((skill_total + 1))
        if [[ -f "$SKILLS_DIR/$skill/SKILL.md" ]]; then
            skill_count=$((skill_count + 1))
        fi
    done
    echo "  Skills: $skill_count/$skill_total (draft excluded — content in static header)"

    # Verify no /draft: references remain
    if [[ "$old_syntax_count" -gt 0 ]]; then
        echo "  WARNING: Found $old_syntax_count '/draft:' references (should be 0)" >&2
        return 1
    else
        echo "  Syntax check: OK (no /draft: references)"
    fi

    # Verify no @draft references remain
    if [[ "$at_draft_count" -gt 0 ]]; then
        echo "  WARNING: Found $at_draft_count '@draft' references (should be 0)" >&2
        echo "  Offending lines:" >&2
        grep -n '@draft' "$output_file" | head -5 >&2
        return 1
    else
        echo "  Syntax check: OK (no @draft references)"
    fi

    echo "  Agent refs: preserved (not stripped)"

    return 0
}

# ─────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────

main() {
    echo "Building integrations from skills..."
    echo ""

    # Ensure output directory exists
    mkdir -p "$(dirname "$COPILOT_OUTPUT")"

    local start_seconds=$SECONDS

    # Generate Copilot integration (atomic: write to temp, verify, then mv)
    echo "── Copilot ─────────────────────────────────────"
    local copilot_tmp
    copilot_tmp=$(mktemp "${COPILOT_OUTPUT}.XXXXXX")
    trap 'rm -f "$copilot_tmp"' EXIT
    build_copilot > "$copilot_tmp"
    echo "  Generated: $COPILOT_OUTPUT"
    if verify_output "$copilot_tmp"; then
        mv "$copilot_tmp" "$COPILOT_OUTPUT"
        trap - EXIT
    else
        rm -f "$copilot_tmp"
        trap - EXIT
        exit 1
    fi
    echo ""

    local elapsed=$((SECONDS - start_seconds))
    echo "All integrations built successfully. (${elapsed}s)"
}

main "$@"
