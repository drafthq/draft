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

# --- Reverse index: a concept page absent from the path-index is an orphan ---
build_valid_bundle "$FIXTURE/wiki"
# auth.md exists as a concept but the index maps no source to it.
cat > "$FIXTURE/path-to-concept.json" <<'EOF'
{
  "src/auth/login.go": ["systems/other.md"]
}
EOF
# (forward would dangle on other.md, so use an index that only covers a non-auth page)
cat > "$FIXTURE/path-to-concept.json" <<'EOF'
{
  "src/misc/x.go": []
}
EOF
run "$FIXTURE/wiki" --path-index "$FIXTURE/path-to-concept.json" --reverse
assert "Reverse: ungrounded concept page → exit 1" "$([[ "$RC" == "1" ]] && echo true || echo false)"
assert "Reverse: error names the orphan page" \
    "$(echo "$OUT" | grep -q 'systems/auth.md' && echo true || echo false)"

# --- Reverse passes when every concept page is grounded ---
cat > "$FIXTURE/path-to-concept.json" <<'EOF'
{
  "src/auth/login.go": ["systems/auth.md"]
}
EOF
run "$FIXTURE/wiki" --path-index "$FIXTURE/path-to-concept.json" --reverse
assert "Reverse: all pages grounded → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"

# --- --structure-only disables the reverse check (back-compat) ---
cat > "$FIXTURE/path-to-concept.json" <<'EOF'
{
  "src/misc/x.go": []
}
EOF
run "$FIXTURE/wiki" --path-index "$FIXTURE/path-to-concept.json" --reverse --structure-only
assert "--structure-only suppresses reverse orphan failure → exit 0" \
    "$([[ "$RC" == "0" ]] && echo true || echo false)"

# --- Empty placeholder page (no frontmatter, no body) → fail ---
build_valid_bundle "$FIXTURE/wiki"
: > "$FIXTURE/wiki/systems/empty.md"
run "$FIXTURE/wiki"
assert "Empty page → invalid (exit 1)" "$([[ "$RC" == "1" ]] && echo true || echo false)"
assert "Empty page error names it" "$(echo "$OUT" | grep -q 'systems/empty.md: empty page' && echo true || echo false)"

# --- Untyped non-meta page (body but no frontmatter type) → fail ---
build_valid_bundle "$FIXTURE/wiki"
cat > "$FIXTURE/wiki/systems/notes.md" <<'EOF'
# Random notes

Some prose that was dropped here without a concept frontmatter block.
EOF
run "$FIXTURE/wiki"
assert "Untyped non-meta page → invalid (exit 1)" "$([[ "$RC" == "1" ]] && echo true || echo false)"
assert "Untyped page flagged" "$(echo "$OUT" | grep -q 'systems/notes.md: untyped page' && echo true || echo false)"

# --- Empty section index (meta) is allowed, not flagged as a concept ---
build_valid_bundle "$FIXTURE/wiki"
cat > "$FIXTURE/wiki/systems/index.md" <<'EOF'
---
type: Subsystem
title: Systems
description: Section index.
resource: .
---

# Systems

<!-- CONCEPT-MAP:START -->
<!-- CONCEPT-MAP:END -->
EOF
run "$FIXTURE/wiki"
assert "Meta index.md not treated as empty concept → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"

# --- Unreplaced {ALL_CAPS} template token (even in an index page) → fail ---
build_valid_bundle "$FIXTURE/wiki"
cat > "$FIXTURE/wiki/systems/index.md" <<'EOF'
---
type: Subsystem
title: "{SECTION_TITLE}"
description: Section index.
resource: .
---

# {SECTION_TITLE}
EOF
run "$FIXTURE/wiki"
assert "Template token → invalid (exit 1)" "$([[ "$RC" == "1" ]] && echo true || echo false)"
assert "Template token flagged" "$(echo "$OUT" | grep -q "unreplaced template token '{SECTION_TITLE}'" && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
