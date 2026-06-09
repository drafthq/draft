#!/usr/bin/env bash
# check-template-noop.sh
#
# CI gate enforcing WS-0 contract: any commit that touches skills/** or
# scripts/tools/** must also touch core/templates/**, or carry the literal
# tag [template-noop] in the commit message.
#
# Rationale: skill-only or validator-only schema changes silently drift from
# the templates. Forcing them to travel together (or explicitly opt out) keeps
# templates as the single canonical schema source.
#
# Usage:
# scripts/tools/check-template-noop.sh # HEAD vs HEAD~1
# scripts/tools/check-template-noop.sh <base> # HEAD vs base
# scripts/tools/check-template-noop.sh <base>..<head> # range form
#
# Exit codes:
# 0 OK (no relevant changes, or templates also touched, or [template-noop])
# 1 violation
# 2 usage / runtime error

set -euo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "${0##*/} — Foundations quality tool (see core/ docs for full behavior)"
    exit 0
fi

BASE="${1:-HEAD~1}"
RANGE="$BASE..HEAD"
if [[ "$BASE" == *..* ]]; then
    RANGE="$BASE"
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'check-template-noop: not inside a git repository\n' >&2
    exit 2
fi

# Diff name-only across the range.
changed_files="$(git diff --name-only "$RANGE" 2>/dev/null || true)"
if [[ -z "$changed_files" ]]; then
    printf 'check-template-noop: no changes in range %s\n' "$RANGE"
    exit 0
fi

touches_skills_or_tools=0
touches_templates=0

while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    case "$f" in
        skills/*|scripts/tools/*)
            # Skip changes to the templates themselves living under scripts.
            touches_skills_or_tools=1 ;;
        core/templates/*)
            touches_templates=1 ;;
    esac
done <<< "$changed_files"

if ((touches_skills_or_tools == 0)); then
    printf 'check-template-noop: no skills/** or scripts/tools/** changes in range %s\n' "$RANGE"
    exit 0
fi

if ((touches_templates == 1)); then
    printf 'check-template-noop: OK — skills/tools changes accompanied by core/templates/** changes.\n'
    exit 0
fi

# Look for [template-noop] tag in any commit message in the range.
commit_log="$(git log --format=%B "$RANGE" 2>/dev/null || true)"
if printf '%s' "$commit_log" | grep -Fq '[template-noop]'; then
    printf 'check-template-noop: OK — [template-noop] tag present in commit message.\n'
    exit 0
fi

cat >&2 <<EOF
check-template-noop: FAIL
  Range: $RANGE
  skills/** or scripts/tools/** changed without touching core/templates/**.
  Either:
    (a) update core/templates/* to reflect the schema change, or
    (b) add [template-noop] to the commit message if this is intentionally a no-op
        for the template schema (e.g. pure bug fix, refactor, perf improvement).
EOF
exit 1
