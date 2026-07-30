#!/usr/bin/env bash
#
# Shared validation library for Draft skill files.
#
# Sourced by test suites. Defines constants and validation functions
# but does not execute anything when sourced.
#
# Usage:
#   source scripts/lib.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="$ROOT_DIR/skills"
CORE_DIR="$ROOT_DIR/core"
TOOLS_DIR="$ROOT_DIR/scripts/tools"

# ─────────────────────────────────────────────────────────
# Skill ordering (canonical order for all references)
# ─────────────────────────────────────────────────────────

SKILL_ORDER=(
    draft
    init
    graph
    new-track
    decompose
    implement
    coverage
    deploy-checklist
    bughunt
    review
    upload
    plan
    ops
    docs
    discover
    jira
    integrations
    quick-review
    deep-review
    testing-strategy
    learn
    adr
    debug
    standup
    tech-debt
    incident-response
    documentation
    status
    revert
    change
    tour
    impact
    assist-review
)

# ─────────────────────────────────────────────────────────
# Skill metadata: one row per skill — "<name>|<display header>|<copilot trigger>"
# The name and header never contain "|"; the trigger may (e.g. "[file|pr N]"),
# so lookups split on the FIRST TWO pipes only. Coverage against SKILL_ORDER is
# enforced by tests/test-trigger-functions.sh.
# ─────────────────────────────────────────────────────────

SKILL_META=(
    'draft|Draft Overview|"help" or "draft"'
    'init|Init Command|"init draft", "build the code graph", or "draft init [refresh] [--graph-only] [--module-only]"'
    'graph|Graph Command|"build graph", "refresh graph", or "draft graph [path]"'
    'new-track|New Track Command|"new feature" or "draft new-track <description>"'
    'decompose|Decompose Command|"break into modules" or "draft decompose"'
    'implement|Implement Command|"implement" or "draft implement"'
    'coverage|Coverage Command|"check coverage" or "draft coverage"'
    'deploy-checklist|Deploy Checklist Command|"deploy checklist" or "draft deploy-checklist [track <id>]"'
    'bughunt|Bug Hunt Command|"hunt bugs" or "draft bughunt [--track <id>]"'
    'review|Review Command|"review code" or "draft review [--track <id>] [--full]"'
    'upload|Upload Command|"upload for review" or "draft upload [track <id>]"'
    'plan|Plan Router|"plan feature" or "draft plan <intent>" (new-track, decompose, adr, tech-debt, change)'
    'ops|Ops Router|"ops deploy" or "draft ops <intent>" (deploy-checklist, incident, standup, status, revert)'
    'docs|Docs Router|"write docs" or "draft docs <intent>" (documentation)'
    'discover|Discover Router|"discover debug" or "draft discover <intent>" (debug, bughunt, reviews, coverage, learn, index, etc.)'
    'jira|Jira Router|"jira preview", "jira create", or "jira review <ID>"'
    'integrations|Integrations Router|"integrations", "integrations jira-preview", or "integrations jira-create"'
    'quick-review|Quick Review Command|"quick review" or "draft quick-review [file|pr <number>]"'
    'deep-review|Deep Review Command|"deep review" or "draft deep-review [module]"'
    'testing-strategy|Testing Strategy Command|"test strategy" or "draft testing-strategy [track <id>|path]"'
    'learn|Learn Command|"learn patterns" or "draft learn [promote|migrate|path]"'
    'adr|ADR Command|"document decision" or "draft adr [title]"'
    'debug|Debug Command|"debug bug" or "draft debug [description|track <id>]"'
    'standup|Standup Command|"standup" or "draft standup [date|week|save]"'
    'tech-debt|Tech Debt Command|"tech debt" or "draft tech-debt [path|track <id>]"'
    'incident-response|Incident Response Command|"incident" or "draft incident-response [new|update|postmortem]"'
    'documentation|Documentation Command|"write docs" or "draft documentation [readme|runbook|api|onboarding]"'
    'status|Status Command|"status" or "draft status"'
    'revert|Revert Command|"revert" or "draft revert"'
    'change|Change Command|"handle change" or "draft change <description>"'
    'tour|Tour Command|"tour" or "draft tour"'
    'impact|Impact Command|"impact" or "draft impact"'
    'assist-review|Assist Review Command|"assist review" or "draft assist-review"'
)

# get_skill_header <skill> — display header for integration sections.
get_skill_header() {
    local skill="$1" row rest
    for row in "${SKILL_META[@]}"; do
        if [[ "${row%%|*}" == "$skill" ]]; then
            rest="${row#*|}"
            printf '%s\n' "${rest%%|*}"
            return 0
        fi
    done
    printf '%s\n' "$(echo "${skill:0:1}" | tr '[:lower:]' '[:upper:]')${skill:1} Command"
}

# get_copilot_trigger <skill> — natural-language trigger for the Copilot header.
get_copilot_trigger() {
    local skill="$1" row rest
    for row in "${SKILL_META[@]}"; do
        if [[ "${row%%|*}" == "$skill" ]]; then
            rest="${row#*|}"
            printf '%s\n' "${rest#*|}"
            return 0
        fi
    done
    printf '"draft %s"\n' "$skill"
}


# ─────────────────────────────────────────────────────────
# Core reference files (inlined by Claude plugin at runtime)
# ─────────────────────────────────────────────────────────

CORE_FILES=(
    # Methodology
    "methodology.md"
    "knowledge-base.md"
    # Shared procedures
    "shared/draft-context-loading.md"
    "shared/git-report-metadata.md"
    "shared/pattern-learning.md"
    "shared/condensation.md"
    "shared/cross-skill-dispatch.md"
    "shared/jira-sync.md"
    "shared/graph-query.md"
    "shared/okf-retrieval.md"
    "shared/parallel-analysis.md"
    # Foundations additions (Phase 0)
    "shared/context-verify.md"
    "shared/discovery-schema.md"
    "shared/graph-usage-report.md"
    "shared/parallel-fanout.md"
    "shared/red-flags.md"
    "shared/template-contract.md"
    "shared/template-hygiene.md"
    "shared/tool-resolver.md"
    "shared/verification-gates.md"
    # Templates
    "templates/guardrails.md"
    "templates/intake-questions.md"
    "templates/ai-context.md"
    "templates/ai-profile.md"
    "templates/architecture.md"
    "templates/jira.md"
    "templates/product.md"
    "templates/tech-stack.md"
    "templates/workflow.md"
    "templates/spec.md"
    "templates/plan.md"
    "templates/metadata.json"
    # Foundations additions
    "templates/ai-context-export.md"
    "templates/session-summary.md"
    # Index templates (monorepo)
    "templates/service-index.md"
    "templates/dependency-graph.md"
    "templates/tech-matrix.md"
    "templates/root-product.md"
    "templates/root-architecture.md"
    "templates/root-tech-stack.md"
    "templates/rca.md"
    # Foundations / internal design templates (added during quality tooling work)
    "templates/CHANGELOG.md"
    "templates/discovery.md"
    "templates/hld.md"
    "templates/lld.md"
    # OKF taxonomy bundle templates (DRAFT_INIT_MODE=okf)
    "templates/okf/index.md"
    "templates/okf/concept.md"
    "templates/okf/section-index.md"
    "templates/okf/ai-context-index.md"
    # Agents
    "agents/architect.md"
    "agents/debugger.md"
    "agents/planner.md"
    "agents/rca.md"
    "agents/reviewer.md"
    "agents/writer.md"
    "agents/ops.md"
    # VCS abstraction
    "shared/vcs-commands.md"
    # Guardrails system (Foundations)
    "guardrails.md"
    "guardrails/README.md"
    "guardrails/security.md"
    "guardrails/code-quality.md"
    "guardrails/design-norms.md"
    "guardrails/review-checks.md"
    "guardrails/secure-patterns.md"
    "guardrails/dependency-triage.md"
    "guardrails/language-standards.md"
)

# ─────────────────────────────────────────────────────────
# Deterministic tool scripts (under scripts/tools/)
# Skills invoke these for mechanical work — git metadata,
# file classification, TODO aging, hotspot ranking, etc.
# ─────────────────────────────────────────────────────────

TOOLS=(
    "git-metadata.sh"
    "classify-files.sh"
    "parse-git-log.sh"
    "scan-markers.sh"
    "hotspot-rank.sh"
    "cycle-detect.sh"
    "parse-reports.sh"
    "detect-test-framework.sh"
    "run-coverage.sh"
    "freshness-check.sh"
    "adr-index.sh"
    "manage-symlinks.sh"
    "mermaid-from-graph.sh"
    "graph-snapshot.sh"
    "graph-init.sh"
    "graph-preflight.sh"
    "graph-impact.sh"
    "graph-callers.sh"
    "graph-arch.sh"
    # graph-tooling-v2: generic passthrough + purpose-built capability wrappers
    "graph-query.sh"
    "graph-snippet.sh"
    "graph-search.sh"
    "graph-tests.sh"
    "graph-deps.sh"
    "graph-hierarchy.sh"
    "graph-errors.sh"
    "graph-risk.sh"
    "graph-traces.sh"
    "validate-frontmatter.sh"
    # Foundations hygiene/verification tools
    "check-graph-usage-report.sh"
    "check-repo-size.sh"
    "check-scope-conflicts.sh"
    "check-skill-line-caps.sh"
    "check-template-noop.sh"
    "check-track-hygiene.sh"
    "diff-templates-vs-tracks.sh"
    "emit-skill-metrics.sh"
    "fix-whitespace.sh"
    "install-smoke-test.sh"
    "migrate-track-frontmatter.sh"
    "render-track.sh"
    "verify-citations.sh"
    "verify-doc-anchors.sh"
    "verify-graph-binary.sh"
    "resolve-tools.sh"
    # OKF taxonomy emitter (DRAFT_INIT_MODE=okf)
    "okf-validate.sh"
    "okf-render-views.sh"
    # OKF completeness enforcement (deterministic plan + coverage/quality gates)
    "okf-plan-concepts.sh"
    "okf-validate-quality.sh"
    "okf-coverage-check.sh"
    "okf-validate-all.sh"
    "okf-emit-catalog.sh"
    "okf-fix-links.sh"
)

# ─────────────────────────────────────────────────────────
# Validation functions
# ─────────────────────────────────────────────────────────

# Validate a skill name against kebab-case regex.
# Prevents path traversal, uppercase, special chars.
is_valid_skill_name() {
    local name="$1"
    [[ "$name" =~ ^[a-z][a-z0-9]*(-[a-z0-9]+)*$ ]]
}

# Extract body content from a SKILL.md file (strip YAML frontmatter).
# Returns non-zero and prints to stderr on validation failure.
extract_body() {
    local file="$1"

    if [[ "$(sed -n '1p' "$file")" != "---" ]]; then
        echo "ERROR: Missing YAML frontmatter in $file" >&2
        echo "  Skill files must start with --- delimiter on line 1" >&2
        return 1
    fi

    if ! awk 'NR > 1 && /^---$/ { found=1; exit } END { exit !found }' "$file"; then
        echo "ERROR: Missing closing YAML frontmatter delimiter in $file" >&2
        return 1
    fi

    local frontmatter
    frontmatter=$(awk '
        NR == 1 && /^---$/ { in_frontmatter=1; next }
        /^---$/ && in_frontmatter { exit }
        in_frontmatter { print }
    ' "$file")

    if ! printf '%s\n' "$frontmatter" | grep -q "^name:"; then
        echo "ERROR: Missing 'name:' field in frontmatter of $file" >&2
        return 1
    fi

    if ! printf '%s\n' "$frontmatter" | grep -q "^description:"; then
        echo "ERROR: Missing 'description:' field in frontmatter of $file" >&2
        return 1
    fi

    awk '
        BEGIN { in_frontmatter = 0; found_end = 0 }
        /^---$/ {
            if (NR == 1 && in_frontmatter == 0) {
                in_frontmatter = 1
                next
            } else if (found_end == 0) {
                found_end = 1
                next
            }
        }
        found_end == 1 { print }
    ' "$file"
}

# Validate body format: line 1 blank, line 2 starts with #, line 3 blank.
# $3 (optional): pre-extracted body — skips a second extract_body parse when
# the caller already has it.
validate_skill_body_format() {
    local skill="$1"
    local skill_file="$2"

    local body_head line1 line2 line3
    if (( $# >= 3 )); then
        body_head=$(printf '%s\n' "$3" | sed -n '1,3p')
    else
        body_head=$(extract_body "$skill_file" | sed -n '1,3p' || true)
    fi
    line1=$(echo "$body_head" | sed -n '1p')
    line2=$(echo "$body_head" | sed -n '2p')
    line3=$(echo "$body_head" | sed -n '3p')
    if [[ -n "$line1" ]] || [[ ! "$line2" =~ ^#\  ]] || [[ -n "$line3" ]]; then
        echo "ERROR: Skill '$skill' body format invalid (expected: blank, '# Title', blank). Got:" >&2
        echo "  Line 1: '${line1}'" >&2
        echo "  Line 2: '${line2}'" >&2
        echo "  Line 3: '${line3}'" >&2
        return 1
    fi
}
