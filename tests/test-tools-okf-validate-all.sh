#!/usr/bin/env bash
# Test suite for scripts/tools/okf-validate-all.sh (orchestrator)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/okf-validate-all.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== okf-validate-all.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
B="$FIXTURE/wiki"

run() { set +e; OUT="$("$TOOL" "$@" 2>&1)"; RC=$?; set -e; }

build_good_bundle() {
    rm -rf "$B"; mkdir -p "$B/systems"
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

cat > "$FIXTURE/plan-ok.json" <<'EOF'
{"version":1,"expected":[{"concept_id":"systems/auth.md","type":"Subsystem","resource":"src/auth/","fan_in":9,"required":true,"reason_if_deferred":null}]}
EOF
cat > "$FIXTURE/plan-gap.json" <<'EOF'
{"version":1,"expected":[
 {"concept_id":"systems/auth.md","type":"Subsystem","resource":"src/auth/","fan_in":9,"required":true,"reason_if_deferred":null},
 {"concept_id":"systems/billing.md","type":"Subsystem","resource":"src/billing/","fan_in":5,"required":true,"reason_if_deferred":null}]}
EOF

# --- All layers pass on a complete bundle ---
build_good_bundle
run "$B" --plan "$FIXTURE/plan-ok.json" --json
assert "Complete bundle → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"
assert "All three layers pass" \
    "$(echo "$OUT" | jq -e '.layers.structure=="pass" and .layers.quality=="pass" and .layers.coverage=="pass"' >/dev/null && echo true || echo false)"

# --- Coverage gap fails overall even though structure+quality pass ---
build_good_bundle
run "$B" --plan "$FIXTURE/plan-gap.json" --json
assert "Coverage gap → exit 1" "$([[ "$RC" == "1" ]] && echo true || echo false)"
assert "structure+quality pass, coverage fails" \
    "$(echo "$OUT" | jq -e '.layers.structure=="pass" and .layers.quality=="pass" and .layers.coverage=="fail"' >/dev/null && echo true || echo false)"
assert "Overall valid:false" \
    "$(echo "$OUT" | jq -e '.valid==false' >/dev/null && echo true || echo false)"

# --- Without --plan, coverage is skipped (layers 1-2 only) ---
build_good_bundle
run "$B" --json
assert "No plan → coverage skipped" \
    "$(echo "$OUT" | jq -e '.layers.coverage=="skip"' >/dev/null && echo true || echo false)"
assert "No plan → still passes structure+quality (exit 0)" \
    "$([[ "$RC" == "0" ]] && echo true || echo false)"

# --- A structural break fails layer 1 ---
build_good_bundle
printf '\n[gone](systems/ghost.md)\n' >> "$B/index.md"
run "$B" --plan "$FIXTURE/plan-ok.json" --json
assert "Dangling link → structure fail, exit 1" \
    "$([[ "$RC" == "1" ]] && echo "$OUT" | jq -e '.layers.structure=="fail"' >/dev/null && echo true || echo false)"

# --- Report file is written ---
build_good_bundle
run "$B" --plan "$FIXTURE/plan-ok.json" --report "$FIXTURE/report.json"
assert "--report writes a file" "$([[ -f "$FIXTURE/report.json" ]] && echo true || echo false)"
assert "report is valid JSON" \
    "$(jq -e '.layers' "$FIXTURE/report.json" >/dev/null 2>&1 && echo true || echo false)"

# --- Missing bundle → exit 2 ---
run "$FIXTURE/nope"
assert "Missing bundle → exit 2" "$([[ "$RC" == "2" ]] && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
