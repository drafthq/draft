#!/usr/bin/env bash
# Test suite for scripts/tools/okf-coverage-check.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/okf-coverage-check.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== okf-coverage-check.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
B="$FIXTURE/wiki"

run() { set +e; OUT="$("$TOOL" "$@" 2>&1)"; RC=$?; set -e; }

# A real (non-stub) page body for a given concept file.
write_real_page() {
    local f="$1"
    mkdir -p "$(dirname "$f")"
    cat > "$f" <<'EOF'
---
type: Subsystem
title: A Concept
description: A real concept page with enough body to clear the stub threshold here.
resource: src/x/
---

# A Concept

## What it is
Line of real content one.
Line two.
Line three.
Line four.
Line five.
Line six.
Line seven.
Line eight.
Line nine.
Line ten.
Line eleven.
EOF
}

mkdir -p "$B/systems"

# Plan: auth required+present, billing required+missing, tools deferred.
cat > "$FIXTURE/plan.json" <<'EOF'
{"version":1,"expected":[
 {"concept_id":"systems/auth.md","type":"Subsystem","resource":"src/auth/","fan_in":9,"required":true,"reason_if_deferred":null},
 {"concept_id":"systems/billing.md","type":"Subsystem","resource":"src/billing/","fan_in":5,"required":true,"reason_if_deferred":null},
 {"concept_id":"systems/tools.md","type":"Module","resource":"tools/","fan_in":1,"required":false,"reason_if_deferred":"fan_in 1 < floor 2"}
]}
EOF

# --- Missing required page → exit 1, names the missing concept ---
write_real_page "$B/systems/auth.md"
run --plan "$FIXTURE/plan.json" --bundle "$B" --json --no-coverage-page
assert "Missing required → exit 1" "$([[ "$RC" == "1" ]] && echo true || echo false)"
assert "Reports billing as missing" \
    "$(echo "$OUT" | jq -e '[.missing[]]|index("systems/billing.md")' >/dev/null && echo true || echo false)"
assert "Deferred component not counted as required" \
    "$(echo "$OUT" | jq -e '.required==2' >/dev/null && echo true || echo false)"

# --- All required present + real → exit 0 ---
write_real_page "$B/systems/billing.md"
run --plan "$FIXTURE/plan.json" --bundle "$B" --json --no-coverage-page
assert "All required present → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"
assert "coverage_pct 100" \
    "$(echo "$OUT" | jq -e '.coverage_pct==100' >/dev/null && echo true || echo false)"

# --- A present-but-stub required page → exit 1 (stub array) ---
cat > "$B/systems/billing.md" <<'EOF'
---
type: Subsystem
title: Billing
description: stub
resource: src/billing/
---

# Billing
EOF
run --plan "$FIXTURE/plan.json" --bundle "$B" --json --no-coverage-page
assert "Stub required page → exit 1" "$([[ "$RC" == "1" ]] && echo true || echo false)"
assert "billing reported in stub array" \
    "$(echo "$OUT" | jq -e '[.stub[].concept_id]|index("systems/billing.md")' >/dev/null && echo true || echo false)"

# --- coverage.md is generated with marker + MISSING row ---
rm -f "$B/systems/billing.md"
run --plan "$FIXTURE/plan.json" --bundle "$B"
assert "coverage.md generated" "$([[ -f "$B/systems/coverage.md" ]] && echo true || echo false)"
assert "coverage.md carries the generated marker" \
    "$(grep -q 'okf:coverage-generated' "$B/systems/coverage.md" && echo true || echo false)"
assert "coverage.md marks billing MISSING" \
    "$(grep -q 'MISSING' "$B/systems/coverage.md" && echo true || echo false)"
assert "coverage.md lists deferred reason for tools" \
    "$(grep -q 'Deferred' "$B/systems/coverage.md" && echo true || echo false)"

# --- coverage.md links to non-systems concepts (entrypoints/) must not dangle ---
# Regression: links were emitted as ${cid#systems/}, which resolves wrong from
# systems/coverage.md for entrypoints/* concepts (needs ../). Generate a bundle
# with an entrypoints concept, then run the structure validator over it.
EPFIX="$FIXTURE/ep"
mkdir -p "$EPFIX/systems" "$EPFIX/entrypoints"
cat > "$EPFIX/index.md" <<'EOF'
---
okf_version: "0.1"
---

# Wiki

- [main](entrypoints/main.md)
EOF
cat > "$EPFIX/plan.json" <<'EOF'
{"version":1,"expected":[
 {"concept_id":"entrypoints/main.md","type":"Entrypoint","resource":"main","fan_in":3,"required":true,"reason_if_deferred":null}
]}
EOF
write_real_page "$EPFIX/entrypoints/main.md"
run --plan "$EPFIX/plan.json" --bundle "$EPFIX"
assert "coverage.md generated for entrypoints plan" "$([[ -f "$EPFIX/systems/coverage.md" ]] && echo true || echo false)"
assert "entrypoints row links with ../ prefix" \
    "$(grep -q '(\.\./entrypoints/main.md)' "$EPFIX/systems/coverage.md" && echo true || echo false)"
set +e
VOUT="$("$ROOT_DIR/scripts/tools/okf-validate.sh" "$EPFIX" 2>&1)"; VRC=$?
set -e
assert "generated coverage.md has no dangling cross-link → structure exit 0" \
    "$([[ "$VRC" == "0" ]] && echo true || echo false)"

# --- Missing plan / bundle → exit 2 ---
run --plan "$FIXTURE/nope.json" --bundle "$B"
assert "Missing plan → exit 2" "$([[ "$RC" == "2" ]] && echo true || echo false)"
run --plan "$FIXTURE/plan.json" --bundle "$FIXTURE/nobundle"
assert "Missing bundle → exit 2" "$([[ "$RC" == "2" ]] && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
