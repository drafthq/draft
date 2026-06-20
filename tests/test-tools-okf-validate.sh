#!/usr/bin/env bash
# Test suite for scripts/tools/okf-validate.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/okf-validate.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== okf-validate.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# Build a minimal valid OKF bundle.
build_valid_bundle() {
    local b="$1"
    rm -rf "$b"
    mkdir -p "$b/overview" "$b/systems"
    cat > "$b/index.md" <<'EOF'
---
type: Subsystem
title: Repo Wiki
description: Root index of the knowledge bundle.
resource: .
okf_types_version: 0.1
---

# Repo Wiki

- [Overview](overview/index.md)
- [Auth](systems/auth.md)
EOF
    cat > "$b/overview/index.md" <<'EOF'
---
type: Subsystem
title: Overview
description: System map and getting started.
resource: .
---

# Overview

Back to [root](../index.md).
EOF
    cat > "$b/systems/auth.md" <<'EOF'
---
type: Module
title: Auth Pipeline
description: Login, session, token issuance. Open for anything touching auth.
resource: src/auth/
tags: [auth, security]
x-grounded-paths: [src/auth/login.go]
---

# Auth Pipeline

See the [overview](../overview/index.md).
EOF
}

run() {
    set +e
    OUT="$("$TOOL" "$@" 2>&1)"
    RC=$?
    set -e
}

# --- Valid bundle → exit 0 ---
build_valid_bundle "$FIXTURE/wiki"
run "$FIXTURE/wiki"
assert "Valid bundle → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"

# --- --json reports valid:true ---
run "$FIXTURE/wiki" --json
assert "--json on valid bundle reports valid:true" \
    "$(echo "$OUT" | grep -q '"valid":true' && echo true || echo false)"
assert "--json reports 3 concepts" \
    "$(echo "$OUT" | grep -q '"concepts":3' && echo true || echo false)"

# --- Missing bundle dir → exit 2 ---
run "$FIXTURE/nope"
assert "Missing bundle dir → exit 2" "$([[ "$RC" == "2" ]] && echo true || echo false)"

# --- Dangling cross-link → exit 1 ---
build_valid_bundle "$FIXTURE/wiki"
printf '\nBroken: [gone](systems/ghost.md)\n' >> "$FIXTURE/wiki/index.md"
run "$FIXTURE/wiki"
assert "Dangling cross-link → exit 1" "$([[ "$RC" == "1" ]] && echo true || echo false)"
assert "Dangle error names the target" \
    "$(echo "$OUT" | grep -q 'ghost.md' && echo true || echo false)"

# --- Missing required frontmatter field (resource) → exit 1 ---
build_valid_bundle "$FIXTURE/wiki"
cat > "$FIXTURE/wiki/systems/auth.md" <<'EOF'
---
type: Module
title: Auth Pipeline
description: Login and session.
---

# Auth Pipeline
EOF
run "$FIXTURE/wiki"
assert "Concept missing 'resource' → exit 1" "$([[ "$RC" == "1" ]] && echo true || echo false)"
assert "Error mentions missing 'resource'" \
    "$(echo "$OUT" | grep -q "resource" && echo true || echo false)"

# --- Unknown concept type → exit 1 ---
build_valid_bundle "$FIXTURE/wiki"
cat > "$FIXTURE/wiki/systems/auth.md" <<'EOF'
---
type: Wizard
title: Auth Pipeline
description: Login and session.
resource: src/auth/
---

# Auth Pipeline
EOF
run "$FIXTURE/wiki"
assert "Unknown type 'Wizard' → exit 1" "$([[ "$RC" == "1" ]] && echo true || echo false)"
assert "Error names the bad type" \
    "$(echo "$OUT" | grep -q "Wizard" && echo true || echo false)"

# --- External links and anchors are ignored (no false dangle) ---
build_valid_bundle "$FIXTURE/wiki"
printf '\n[site](https://example.com) and [frag](#section)\n' >> "$FIXTURE/wiki/index.md"
run "$FIXTURE/wiki"
assert "External/anchor links ignored → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"

# --- path-index completeness: valid index → exit 0 ---
build_valid_bundle "$FIXTURE/wiki"
cat > "$FIXTURE/path-to-concept.json" <<'EOF'
{
  "src/auth/login.go": ["systems/auth.md"],
  "src/auth/session.go": ["systems/auth.md"]
}
EOF
run "$FIXTURE/wiki" --path-index "$FIXTURE/path-to-concept.json"
assert "Valid path-index → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"

# --- path-index referencing a missing page → exit 1 ---
cat > "$FIXTURE/path-to-concept.json" <<'EOF'
{
  "src/auth/login.go": ["systems/auth.md"],
  "src/billing/charge.go": ["systems/billing.md"]
}
EOF
run "$FIXTURE/wiki" --path-index "$FIXTURE/path-to-concept.json"
assert "path-index naming missing page → exit 1" "$([[ "$RC" == "1" ]] && echo true || echo false)"
assert "Error names the missing page" \
    "$(echo "$OUT" | grep -q 'systems/billing.md' && echo true || echo false)"

# --- path-index with .md-keyed source paths (doc groundings) → keys ignored, exit 0 ---
# Source paths may themselves end in .md (grounding a concept to a doc file). The
# validator must check only array VALUES (pages), never keys.
build_valid_bundle "$FIXTURE/wiki"
cat > "$FIXTURE/path-to-concept.json" <<'EOF'
{
  "docs/INVARIANTS.md": ["systems/auth.md"],
  "src/auth/login.go": ["systems/auth.md"]
}
EOF
run "$FIXTURE/wiki" --path-index "$FIXTURE/path-to-concept.json"
assert ".md-keyed source path (doc grounding) does not false-dangle → exit 0" \
    "$([[ "$RC" == "0" ]] && echo true || echo false)"

# --- Missing root index.md → exit 1 ---
build_valid_bundle "$FIXTURE/wiki"
rm "$FIXTURE/wiki/index.md"
run "$FIXTURE/wiki"
assert "Missing root index.md → exit 1" "$([[ "$RC" == "1" ]] && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
