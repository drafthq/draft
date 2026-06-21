#!/usr/bin/env bash
# Test suite for scripts/tools/okf-validate-quality.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/okf-validate-quality.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== okf-validate-quality.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
B="$FIXTURE/wiki"

run() { set +e; OUT="$("$TOOL" "$@" 2>&1)"; RC=$?; set -e; }

write_good_subsystem() {
    mkdir -p "$B/systems"
    cat > "$B/index.md" <<'EOF'
---
type: Subsystem
title: Wiki
description: Root index of the knowledge bundle for the test repo.
resource: .
---

# Wiki
- [Auth](systems/auth.md)
EOF
    cat > "$B/systems/auth.md" <<'EOF'
---
type: Subsystem
title: Auth Pipeline
description: Login, session, token issuance — open for anything touching authentication or identity.
resource: src/auth/
x-grounded-paths: ["src/auth/login.go", "src/auth/session.go"]
---

# Auth Pipeline

## What it is

The authentication subsystem owns login, session lifecycle, and token issuance.
Its boundary is everything under src/auth/. Downstream services depend on the
session token contract it publishes.

## How it works

Requests enter through the login handler, which validates credentials, mints a
session, and issues a signed token.

```mermaid
flowchart LR
  Login --> Validate --> Session --> Token
```

## Used by

- [root](../index.md)

## Blast radius

Changing the token contract breaks consumers. Grounded in login.go, session.go.

## See also

- [root](../index.md)
EOF
}

# --- Valid bundle → pass ---
rm -rf "$B"; write_good_subsystem
run "$B"
assert "Valid bundle → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"

# --- Missing bundle → exit 2 ---
run "$FIXTURE/nope"
assert "Missing bundle → exit 2" "$([[ "$RC" == "2" ]] && echo true || echo false)"

# --- Stub redirect page fails (Q-STUB + Q-SEC + Q-DIAG) ---
rm -rf "$B"; write_good_subsystem
cat > "$B/systems/billing.md" <<'EOF'
---
type: Subsystem
title: Billing
description: Billing module.
resource: src/billing/
---

# Billing

See architecture.md.
EOF
run "$B" --json
assert "Stub page → fail (exit 1)" "$([[ "$RC" == "1" ]] && echo true || echo false)"
assert "Stub flagged Q-STUB" \
    "$(echo "$OUT" | jq -e '[.failures[]|select(.page=="systems/billing.md" and .check=="Q-STUB")]|length>0' >/dev/null && echo true || echo false)"
assert "Stub flagged Q-DIAG (no mermaid)" \
    "$(echo "$OUT" | jq -e '[.failures[]|select(.check=="Q-DIAG")]|length>0' >/dev/null && echo true || echo false)"

# --- Bad mermaid syntax (& chaining) fails Q-MERMAID ---
rm -rf "$B"; write_good_subsystem
cat > "$B/systems/auth.md" <<'EOF'
---
type: Subsystem
title: Auth Pipeline
description: Login, session, token issuance — open for anything touching authentication or identity.
resource: src/auth/
x-grounded-paths: ["src/auth/login.go", "src/auth/session.go"]
---

# Auth Pipeline

## What it is

The authentication subsystem owns login, session lifecycle, and token issuance.
Its boundary is everything under src/auth/. Downstream services depend on it for
session token verification across the platform.

## How it works

Requests flow through validate then session then token, all signed and verified
on each subsequent request by the middleware exported here.

```mermaid
flowchart LR
  A & B --> C
```

## Used by

- [root](../index.md)

## Blast radius

Changing the token contract breaks consumers. Grounded in login.go, session.go.

## See also

- [root](../index.md)
EOF
run "$B" --json
assert "Bad mermaid → fail" "$([[ "$RC" == "1" ]] && echo true || echo false)"
assert "Bad mermaid flagged Q-MERMAID" \
    "$(echo "$OUT" | jq -e '[.failures[]|select(.check=="Q-MERMAID")]|length>0' >/dev/null && echo true || echo false)"

# --- Per-type leniency: a short Dependency page passes (no mermaid/sections req) ---
rm -rf "$B"; write_good_subsystem
mkdir -p "$B/reference"
cat > "$B/reference/jq.md" <<'EOF'
---
type: Dependency
title: jq
description: JSON processor used by the graph wrappers to slice engine output safely.
resource: jq
---

# jq

## What it is

A command-line JSON processor. Draft's graph tool wrappers pipe the engine's
architecture JSON through jq to extract packages, routes, and hotspots.

## Used by

- [Auth](../systems/auth.md)
EOF
run "$B"
assert "Short Dependency page passes (per-type thresholds)" \
    "$([[ "$RC" == "0" ]] && echo true || echo false)"

# --- Duplicate "What it is" paragraph → warning (pass) / fail under --strict ---
rm -rf "$B"; write_good_subsystem
cat > "$B/systems/clone.md" <<'EOF'
---
type: Subsystem
title: Clone
description: A second subsystem with a copy-pasted opening paragraph to trip Q-DUP detection.
resource: src/clone/
x-grounded-paths: ["src/clone/a.go", "src/clone/b.go"]
---

# Clone

## What it is

The authentication subsystem owns login, session lifecycle, and token issuance.
Its boundary is everything under src/auth/. Downstream services depend on the
session token contract it publishes.

## How it works

It does things in a way that is sufficiently long to clear the line threshold for
this concept type without tripping any other check in the suite here.

```mermaid
flowchart LR
  X --> Y --> Z
```

## Used by

- [root](../index.md)

## Blast radius

Some blast radius text grounded in clone/a.go and clone/b.go for completeness.

## See also

- [root](../index.md)
EOF
run "$B" --json
assert "Duplicate paragraph is a warning (exit 0 without --strict)" \
    "$([[ "$RC" == "0" ]] && echo true || echo false)"
assert "Q-DUP reported as warning" \
    "$(echo "$OUT" | jq -e '[.warnings[]|select(.check=="Q-DUP")]|length>0' >/dev/null && echo true || echo false)"
run "$B" --strict
assert "Duplicate paragraph fails under --strict" \
    "$([[ "$RC" == "1" ]] && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
