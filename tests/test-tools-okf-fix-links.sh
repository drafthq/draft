#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/okf-fix-links.sh"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== okf-fix-links.sh tests ==="
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
D="$FIXTURE/draft"
mkdir -p "$D/wiki/systems" "$D/wiki/features" "$D/wiki/overview"
cat > "$D/wiki/systems/codegen.md" <<'EOF'
---
type: Module
title: codegen
description: codegen module
resource: crates/codegen
---
# codegen
EOF
cat > "$D/wiki/features/getting-started.md" <<'EOF'
---
type: Feature
title: Getting started (product feature)
description: product onboarding
resource: docs
---
# Getting started (product feature)
EOF
cat > "$D/wiki/overview/getting-started.md" <<'EOF'
---
type: Runbook
title: Getting started — build and run
description: build runbook
resource: README
---
# Getting started — build and run
EOF

cat > "$D/architecture.md" <<'EOF'
# Architecture

## Contents
- [codegen](#codegen)
- [Getting started (product feature)](#wrong-anchor)

# codegen

See also [codegen](codegen.md) and [product start](getting-started.md).

# Getting started (product feature)

Body.
EOF

run() { set +e; OUT="$("$TOOL" "$@" 2>&1)"; RC=$?; set -e; }

run --file "$D/architecture.md" --wiki "$D/wiki" --fix
assert "fix+check → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"
assert "rewrote sibling to wiki/systems" \
    "$(grep -q 'wiki/systems/codegen.md' "$D/architecture.md" && echo true || echo false)"
assert "product getting-started prefers features" \
    "$(grep -q 'wiki/features/getting-started.md' "$D/architecture.md" && echo true || echo false)"

echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
