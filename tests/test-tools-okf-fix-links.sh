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

# --- link resolution must not depend on the caller's cwd ---
# `Path(path)` in the checker's candidate list resolved links against the process
# CWD, so an unrelated same-named file there flipped a dangling link to "clean".
CWD_D="$(mktemp -d)"
mkdir -p "$CWD_D/wiki/systems" "$CWD_D/elsewhere"
printf -- '---\ntype: Subsystem\ntitle: R\ndescription: d\nresource: .\n---\n\n# R\n' > "$CWD_D/wiki/index.md"
printf -- '---\ntype: Module\ntitle: A\ndescription: d\nresource: .\n---\n\n# A\n' > "$CWD_D/wiki/systems/a.md"
printf '# Arch\n\n[dangling](totally-not-here.md)\n' > "$CWD_D/architecture.md"

set +e
( cd "$CWD_D/elsewhere" && "$TOOL" --file "$CWD_D/architecture.md" --wiki "$CWD_D/wiki" ) >/dev/null 2>&1
rc_clean_cwd=$?
touch "$CWD_D/elsewhere/totally-not-here.md"
( cd "$CWD_D/elsewhere" && "$TOOL" --file "$CWD_D/architecture.md" --wiki "$CWD_D/wiki" ) >/dev/null 2>&1
rc_polluted_cwd=$?
set -e
rm -rf "$CWD_D"

assert "dangling link fails from a clean cwd → exit 1" \
    "$([[ "$rc_clean_cwd" == "1" ]] && echo true || echo false)"
assert "same-named file in the caller's cwd does NOT make it pass" \
    "$([[ "$rc_polluted_cwd" == "1" ]] && echo true || echo false)"

echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
