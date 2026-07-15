#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/okf-emit-catalog.sh"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== okf-emit-catalog.sh tests ==="
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
B="$FIXTURE/wiki"
mkdir -p "$B" "$FIXTURE/repo/crates/alpha/src"
echo '//! Alpha crate docs.' > "$FIXTURE/repo/crates/alpha/src/lib.rs"
echo '# Repo' > "$FIXTURE/repo/README.md"

cat > "$FIXTURE/plan.json" <<'EOF'
{"version":1,"expected":[
 {"concept_id":"systems/alpha.md","type":"Module","resource":"crates/alpha","fan_in":0,"required":true,"reason_if_deferred":null},
 {"concept_id":"systems/beta.md","type":"Module","resource":"crates/beta","fan_in":0,"required":true,"reason_if_deferred":null}
]}
EOF

run() { set +e; OUT="$("$TOOL" "$@" 2>&1)"; RC=$?; set -e; }

run --plan "$FIXTURE/plan.json" --bundle "$B" --repo "$FIXTURE/repo"
assert "emit → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"
assert "alpha page exists" "$([[ -f "$B/systems/alpha.md" ]] && echo true || echo false)"
assert "beta page exists" "$([[ -f "$B/systems/beta.md" ]] && echo true || echo false)"
assert "alpha has mermaid" "$(grep -q '```mermaid' "$B/systems/alpha.md" && echo true || echo false)"
assert "alpha has x-grounded-paths" "$(grep -q 'x-grounded-paths' "$B/systems/alpha.md" && echo true || echo false)"

# skip existing
run --plan "$FIXTURE/plan.json" --bundle "$B" --repo "$FIXTURE/repo"
assert "second run skips" "$(echo "$OUT" | grep -q 'skipped_existing=2' && echo true || echo false)"

echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
