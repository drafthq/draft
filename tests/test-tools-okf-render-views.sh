#!/usr/bin/env bash
# Test suite for scripts/tools/okf-render-views.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/okf-render-views.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== okf-render-views.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

B="$FIXTURE/wiki"
mkdir -p "$B/overview" "$B/systems"

cat > "$B/index.md" <<'EOF'
---
type: Subsystem
title: Root
description: bundle root
resource: .
---

# Root

## Concept Map

<!-- CONCEPT-MAP:START -->
STALE CONTENT TO BE REPLACED
<!-- CONCEPT-MAP:END -->
EOF

cat > "$B/overview/index.md" <<'EOF'
---
type: Subsystem
title: Overview
description: section index
resource: .
---

# Overview
EOF

cat > "$B/systems/auth.md" <<'EOF'
---
type: Module
title: Auth Pipeline
description: >
  Login, session, token issuance. Open for anything touching authentication.
resource: src/auth/
---

# Auth Pipeline

```mermaid
flowchart LR
  A --> B
```
EOF

run() { set +e; OUT="$("$TOOL" "$@" 2>&1)"; RC=$?; set -e; }

# --- render architecture.md ---
run "$B" --arch-out "$FIXTURE/architecture.md"
assert "render → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"
assert "architecture.md created" "$([[ -f "$FIXTURE/architecture.md" ]] && echo true || echo false)"
assert "rendered view has the generated banner" \
    "$(grep -q 'Rendered View' "$FIXTURE/architecture.md" && echo true || echo false)"
assert "rendered view includes a concept page title" \
    "$(grep -q 'Auth Pipeline' "$FIXTURE/architecture.md" && echo true || echo false)"
assert "rendered view preserves Mermaid block" \
    "$(grep -q 'flowchart LR' "$FIXTURE/architecture.md" && echo true || echo false)"

# Frontmatter must NOT leak into the rendered concat (no 'resource: src/auth/' line).
assert "frontmatter stripped from concat (no leaked resource: line)" \
    "$(grep -q '^resource: src/auth/' "$FIXTURE/architecture.md" && echo false || echo true)"

# overview/index ordered before systems/auth (section order).
LINE_OV=$(grep -n 'Overview' "$FIXTURE/architecture.md" | tail -1 | cut -d: -f1)
LINE_AU=$(grep -n 'Auth Pipeline' "$FIXTURE/architecture.md" | tail -1 | cut -d: -f1)
assert "canonical section order (overview before systems)" \
    "$([[ "$LINE_OV" -lt "$LINE_AU" ]] && echo true || echo false)"

# --- inject concept map ---
run "$B" --concept-map-into "$B/index.md"
assert "concept-map inject → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"
assert "stale concept-map content replaced" \
    "$(grep -q 'STALE CONTENT' "$B/index.md" && echo false || echo true)"
assert "concept map lists Auth Pipeline with its routing line" \
    "$(grep -q 'Auth Pipeline.*authentication' "$B/index.md" && echo true || echo false)"
assert "concept map excludes section index pages" \
    "$(grep -Eq '\| \[Overview\]\(overview/index.md\)' "$B/index.md" && echo false || echo true)"
assert "markers preserved after injection" \
    "$(grep -q 'CONCEPT-MAP:END' "$B/index.md" && echo true || echo false)"

# --- errors ---
run "$FIXTURE/nope" --arch-out "$FIXTURE/x.md"
assert "missing bundle → exit 2" "$([[ "$RC" == "2" ]] && echo true || echo false)"

run "$B"
assert "no action flags → exit 1" "$([[ "$RC" == "1" ]] && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
