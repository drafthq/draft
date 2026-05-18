#!/usr/bin/env bash
#
# Build integration files from skill sources
# Generates: GitHub Copilot copilot_instructions.md
#
# Note: Cursor integration removed - Cursor now supports .claude-plugin/ structure natively.
#
# Skills are the single source of truth for all integrations.
#
# Adding a new skill:
# 1. Create skills/<name>/SKILL.md
# 2. Add the skill name to SKILL_ORDER array in lib.sh
# 3. Add display name and trigger to the case statements below
# 4. Run this script
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="$ROOT_DIR/skills"
CORE_DIR="$ROOT_DIR/core"
COPILOT_OUTPUT="$ROOT_DIR/integrations/copilot/.github/copilot-instructions.md"
COPILOT_OUTPUT_LEGACY="$ROOT_DIR/integrations/copilot/.github/copilot_instructions.md"

# Source shared library for SKILL_ORDER, CORE_FILES, extract_body
source "$SCRIPT_DIR/lib.sh"

# ─────────────────────────────────────────────────────────
# Skill metadata: display headers
# ─────────────────────────────────────────────────────────

get_skill_header() {
    local skill="$1"
    case "$skill" in
        draft) echo "Draft Overview" ;;
        init) echo "Init Command" ;;
        plan) echo "Plan Command" ;;
        index) echo "Index Command" ;;
        new-track) echo "New Track Command" ;;
        decompose) echo "Decompose Command" ;;
        implement) echo "Implement Command" ;;
        coverage) echo "Coverage Command" ;;
        deploy-checklist) echo "Deploy Checklist Command" ;;
        bughunt) echo "Bug Hunt Command" ;;
        review) echo "Review Command" ;;
        quick-review) echo "Quick Review Command" ;;
        deep-review) echo "Deep Review Command" ;;
        testing-strategy) echo "Testing Strategy Command" ;;
        learn) echo "Learn Command" ;;
        adr) echo "ADR Command" ;;
        debug) echo "Debug Command" ;;
        standup) echo "Standup Command" ;;
        tech-debt) echo "Tech Debt Command" ;;
        incident-response) echo "Incident Response Command" ;;
        documentation) echo "Documentation Command" ;;
        status) echo "Status Command" ;;
        revert) echo "Revert Command" ;;
        change) echo "Change Command" ;;
        jira-preview) echo "Jira Preview Command" ;;
        jira-create) echo "Jira Create Command" ;;
        discover) echo "Discover Command" ;;
        ops) echo "Ops Command" ;;
        docs) echo "Docs Command" ;;
        integrations) echo "Integrations Command" ;;
        tour) echo "Tour Command" ;;
        impact) echo "Impact Command" ;;
        assist-review) echo "Assist Review Command" ;;
        *) echo "$(echo "${skill:0:1}" | tr '[:lower:]' '[:upper:]')${skill:1} Command" ;;
    esac
}

# ─────────────────────────────────────────────────────────
# Skill metadata: triggers (natural language → command)
# ─────────────────────────────────────────────────────────

get_copilot_trigger() {
    local skill="$1"
    case "$skill" in
        draft) echo "\"help\" or \"draft\"" ;;
        init) echo "\"init draft\" or \"draft init [refresh]\"" ;;
        plan) echo "\"plan this\" or \"draft plan [new-track|decompose|change|adr]\"" ;;
        index) echo "\"index services\" or \"draft index [--init-missing]\"" ;;
        new-track) echo "\"new feature\" or \"draft new-track <description>\"" ;;
        decompose) echo "\"break into modules\" or \"draft decompose\"" ;;
        implement) echo "\"implement\" or \"draft implement [status|coverage|revert]\"" ;;
        coverage) echo "\"check coverage\" or \"draft coverage\"" ;;
        deploy-checklist) echo "\"deploy checklist\" or \"draft deploy-checklist [track <id>]\"" ;;
        bughunt) echo "\"hunt bugs\" or \"draft bughunt [--track <id>]\"" ;;
        review) echo "\"review code\" or \"draft review [quick|bughunt|deep|assist|track <id>|project|files <pattern>|commits <range>|full]\"" ;;
        quick-review) echo "\"quick review\" or \"draft quick-review [file|pr <number>]\"" ;;
        deep-review) echo "\"deep review\" or \"draft deep-review [module]\"" ;;
        testing-strategy) echo "\"test strategy\" or \"draft testing-strategy [track <id>|path]\"" ;;
        learn) echo "\"learn patterns\" or \"draft learn [promote|migrate|path]\"" ;;
        adr) echo "\"document decision\" or \"draft adr [title]\"" ;;
        debug) echo "\"debug bug\" or \"draft debug [description|track <id>]\"" ;;
        standup) echo "\"standup\" or \"draft standup [date|week|save]\"" ;;
        tech-debt) echo "\"tech debt\" or \"draft tech-debt [path|track <id>]\"" ;;
        incident-response) echo "\"incident\" or \"draft incident-response [new|update|postmortem]\"" ;;
        documentation) echo "\"write docs\" or \"draft documentation [readme|runbook|api|onboarding]\"" ;;
        status) echo "\"status\" or \"draft status\"" ;;
        revert) echo "\"revert\" or \"draft revert\"" ;;
        change) echo "\"handle change\" or \"draft change <description>\"" ;;
        jira-preview) echo "\"preview jira\" or \"draft jira-preview [track-id]\"" ;;
        jira-create) echo "\"create jira\" or \"draft jira-create [track-id]\"" ;;
        discover) echo "\"discover features\" or \"draft discover [path]\"" ;;
        ops) echo "\"ops\" or \"draft ops [debug|deploy-checklist|incident-response|standup]\"" ;;
        docs) echo "\"docs\" or \"draft docs [documentation|testing-strategy|tech-debt|tour]\"" ;;
        integrations) echo "\"integrations\" or \"draft integrations [jira-preview|jira-create]\"" ;;
        tour) echo "\"tour\" or \"draft tour\"" ;;
        impact) echo "\"impact\" or \"draft impact\"" ;;
        assist-review) echo "\"assist review\" or \"draft assist-review\"" ;;
        *) echo "\"draft $skill\"" ;;
    esac
}

# ─────────────────────────────────────────────────────────
# Syntax transforms for Copilot (no slash commands or @mentions)
# ─────────────────────────────────────────────────────────

transform_copilot_syntax() {
    sed -E \
        -e 's|/draft:([a-z0-9<>-]+)|draft \1|g' \
        -e 's|@draft([^a-z0-9_-])|draft\1|g' \
        -e 's|@draft$|draft|g' \
        -e 's|`@draft`|`draft`|g' \
        -e 's|`@draft |`draft |g' \
        -e 's#@(architect|debugger|planner|rca|reviewer|ops|writer)([^a-z0-9_-])#@workspace\2#g' \
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
# Build the copilot_instructions.md
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

    # Command table
    echo "| \`draft\` | Show overview and available commands |"
    echo "| \`draft init\` | Initialize project (run once) |"
    echo "| \`draft index [--init-missing]\` | Aggregate monorepo service contexts |"
    echo "| \`draft new-track <description>\` | Create feature/bug track |"
    echo "| \`draft decompose\` | Module decomposition with dependency mapping |"
    echo "| \`draft implement\` | Execute tasks from plan |"
    echo "| \`draft coverage\` | Code coverage report (target 95%+) |"
    echo "| \`draft deploy-checklist [track <id>]\` | Pre-deployment verification checklist |"
    echo "| \`draft bughunt [--track <id>]\` | Systematic bug discovery |"
    echo "| \`draft review [--track <id>]\` | Three-stage code review |"
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
    echo "| \`draft discover [path]\` | Discover features and patterns |"
    echo "| \`draft ops [debug|deploy-checklist|incident-response|standup]\` | Canonical operations entry point |"
    echo "| \`draft docs [documentation|testing-strategy|tech-debt|tour]\` | Canonical documentation entry point |"
    echo "| \`draft integrations [jira-preview|jira-create]\` | Canonical integrations entry point |"
    echo "| \`draft jira-preview [track-id]\` | Generate jira-export.md for review |"
    echo "| \`draft jira-create [track-id]\` | Create Jira issues from export via MCP |"
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
| "discover features", "discover patterns" | Run discover |
| "ops", "debug", "deploy", "incident", "standup" | Run ops |
| "docs", "documentation", "test strategy", "tech debt", "tour" | Run docs |
| "integrations", "jira" | Run integrations |
| "preview jira", "export to jira" | Run jira-preview |
| "create jira", "push to jira" | Run jira-create |
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
        if [[ ! "$skill" =~ ^[a-z][a-z0-9]*(-[a-z0-9]+)*$ ]]; then
            echo "ERROR: Invalid skill name '$skill' (must be kebab-case)" >&2
            exit 1
        fi

        local skill_file="$SKILLS_DIR/$skill/SKILL.md"
        if [[ -f "$skill_file" ]]; then
            # Extract body once and cache
            local skill_body
            skill_body=$(extract_body "$skill_file")

            # Validate body format: line 1 blank, line 2 starts with #, line 3 blank
            local line1 line2 line3
            line1=$(echo "$skill_body" | sed -n '1p')
            line2=$(echo "$skill_body" | sed -n '2p')
            line3=$(echo "$skill_body" | sed -n '3p')
            if [[ -n "$line1" ]] || [[ ! "$line2" =~ ^#[[:space:]] ]] || [[ -n "$line3" ]]; then
                echo "ERROR: Skill '$skill' body format invalid (expected: blank, '# Title', blank). Got:" >&2
                echo " Line 1: '${line1}'" >&2
                echo " Line 2: '${line2}'" >&2
                echo " Line 3: '${line3}'" >&2
                exit 1
            fi

            echo ""
            echo "---"
            echo ""
            echo "## $(get_skill_header "$skill")"
            echo ""
            echo "When user says $(get_copilot_trigger "$skill"):"
            echo ""
            # Emit body from line 4 onward (skip blank, title, blank)
            echo "$skill_body" | transform_copilot_syntax | tail -n +4

            # Emit progressive disclosure references
            local refs_dir="$SKILLS_DIR/$skill/references"
            if [[ -d "$refs_dir" ]]; then
                local ref_file
                # Use find + sort for deterministic alphabetical order
                while IFS= read -r ref_file; do
                    if [[ -f "$ref_file" ]]; then
                        echo ""
                        cat "$ref_file" | transform_copilot_syntax
                    fi
                done < <(find "$refs_dir" -maxdepth 1 -name "*.md" | sort)
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

    echo " Lines: $line_count"

    # Verify completeness sentinel
    if ! tail -5 "$output_file" | grep -q "DRAFT_BUILD_COMPLETE"; then
        echo " FAIL: Missing completeness sentinel — output may be truncated" >&2
        return 1
    fi

    # Verify minimum line count
    if [[ "$line_count" -lt 1000 ]]; then
        echo " FAIL: Output too small ($line_count lines, expected >1000) — likely truncated" >&2
        return 1
    fi

    # Count skills included
    local skill_count=0
    for skill in "${SKILL_ORDER[@]}"; do
        if [[ -f "$SKILLS_DIR/$skill/SKILL.md" ]]; then
            skill_count=$((skill_count + 1))
        fi
    done
    echo " Skills: $skill_count/${#SKILL_ORDER[@]}"

    # Verify no /draft: references remain
    if [[ "$old_syntax_count" -gt 0 ]]; then
        echo " WARNING: Found $old_syntax_count '/draft:' references (should be 0)" >&2
        return 1
    else
        echo " Syntax check: OK (no /draft: references)"
    fi

    # Verify no @draft references remain
    if [[ "$at_draft_count" -gt 0 ]]; then
        echo " WARNING: Found $at_draft_count '@draft' references (should be 0)" >&2
        echo " Offending lines:" >&2
        grep -n '@draft' "$output_file" | head -5 >&2
        return 1
    else
        echo " Syntax check: OK (no @draft references)"
    fi

    echo " Agent refs: preserved (not stripped)"

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
    # Remove legacy output file name to avoid stale artifacts.
    rm -f "$COPILOT_OUTPUT_LEGACY"

    local start_seconds=$SECONDS

    # Generate Copilot integration (atomic: write to temp, verify, then mv)
    echo "── Copilot ─────────────────────────────────────"
    local copilot_tmp
    copilot_tmp=$(mktemp "${COPILOT_OUTPUT}.XXXXXX")
    trap 'rm -f "$copilot_tmp"' EXIT
    build_copilot > "$copilot_tmp"
    echo " Generated: $COPILOT_OUTPUT"
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
