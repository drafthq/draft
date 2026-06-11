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
    index
    graph
    new-track
    decompose
    implement
    coverage
    deploy-checklist
    bughunt
    review
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
    "templates/track-architecture.md"
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
    "graph-impact.sh"
    "graph-callers.sh"
    "validate-frontmatter.sh"
    # Foundations hygiene/verification tools
    "check-graph-usage-report.sh"
    "check-scope-conflicts.sh"
    "check-skill-line-caps.sh"
    "check-template-noop.sh"
    "check-track-hygiene.sh"
    "diff-templates-vs-tracks.sh"
    "emit-skill-metrics.sh"
    "fix-whitespace.sh"
    "migrate-track-frontmatter.sh"
    "render-track.sh"
    "verify-citations.sh"
    "verify-doc-anchors.sh"
    "verify-graph-binary.sh"
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
validate_skill_body_format() {
    local skill="$1"
    local skill_file="$2"

    local body_head line1 line2 line3
    body_head=$(extract_body "$skill_file" | sed -n '1,3p' || true)
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
