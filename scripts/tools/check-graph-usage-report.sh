#!/usr/bin/env bash
# check-graph-usage-report.sh — validate that a skill output / template contains
# the mandatory Graph Usage Report footer required by core/shared/graph-query.md.
#
# Usage:
# check-graph-usage-report.sh <file> [<file> ...]
#
# Behavior:
# - Exits 0 when every input file contains a well-formed `## Graph Usage Report`
# section with the five required bullets.
# - Exits 1 when any file is missing the section or any required bullet.
# - Exits 2 on usage error (no files supplied, missing argument).
#
# A file is exempt if the very first line matches `<!-- graph-usage-report:skip -->`
# (intended for non-code-touching templates that legitimately have no graph step).

set -euo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    cat <<'EOF'
check-graph-usage-report.sh — validate that a skill output / template contains
the mandatory Graph Usage Report footer required by core/shared/graph-query.md.

Usage:
  check-graph-usage-report.sh <file> [<file> ...]

Required bullets under the `## Graph Usage Report` section:
  - Graph files queried:
  - Modules identified via graph:
  - Files identified via graph:
  - Filesystem grep fallbacks:

When `Graph files queried:` is `NONE`, a `- Justification:` line with a non-empty
value is also required.

A file is exempt if its first line is `<!-- graph-usage-report:skip -->`.

Exit codes:
  0 every input file is valid
  1 any input file fails validation
  2 usage error (no files supplied)
EOF
    exit 0
fi

if [ "$#" -lt 1 ]; then
    echo "usage: $0 <file> [<file> ...]" >&2
    exit 2
fi

REQUIRED_BULLETS=(
    "- Graph files queried:"
    "- Modules identified via graph:"
    "- Files identified via graph:"
    "- Filesystem grep fallbacks:"
)

fail=0

for f in "$@"; do
    if [ ! -f "$f" ]; then
        echo "MISSING: $f does not exist" >&2
        fail=1
        continue
    fi

    if head -1 "$f" | grep -q '^<!-- graph-usage-report:skip -->'; then
        continue
    fi

    if ! grep -q '^## Graph Usage Report' "$f"; then
        echo "FAIL: $f — missing '## Graph Usage Report' section" >&2
        fail=1
        continue
    fi

    section_start=$(grep -n '^## Graph Usage Report' "$f" | head -1 | cut -d: -f1)
    section_body=$(awk -v start="$section_start" 'NR > start { if (/^## /) exit; print }' "$f")

    for bullet in "${REQUIRED_BULLETS[@]}"; do
        if ! printf '%s\n' "$section_body" | grep -qF -- "$bullet"; then
            echo "FAIL: $f — Graph Usage Report missing bullet: '$bullet'" >&2
            fail=1
        fi
    done

    if printf '%s\n' "$section_body" | grep -qE -- '^- Graph files queried:[[:space:]]*NONE'; then
        if ! printf '%s\n' "$section_body" | grep -qE -- '^- Justification[^:]*:[[:space:]]*[^[:space:]]'; then
            echo "FAIL: $f — 'Graph files queried: NONE' requires a populated Justification line" >&2
            fail=1
        fi
    fi
done

exit "$fail"
