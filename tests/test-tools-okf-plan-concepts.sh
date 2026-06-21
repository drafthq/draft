#!/usr/bin/env bash
# Test suite for scripts/tools/okf-plan-concepts.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/okf-plan-concepts.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== okf-plan-concepts.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

run() { set +e; OUT="$("$@" 2>/dev/null)"; RC=$?; set -e; }

# A repo with two source-bearing dirs + one excluded (tests).
REPO="$FIXTURE/repo"
mkdir -p "$REPO/auth" "$REPO/billing" "$REPO/tests"
echo 'echo hi' > "$REPO/auth/a.sh"
echo 'echo hi' > "$REPO/billing/b.sh"
echo 'echo hi' > "$REPO/tests/t.sh"

# --- Heuristic fallback (engine disabled) discovers source dirs, skips tests ---
run env DRAFT_MEMORY_DISABLE=1 "$TOOL" --repo "$REPO"
assert "Heuristic → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"
assert "Heuristic source is 'heuristic'" \
    "$(echo "$OUT" | jq -e '.source=="heuristic"' >/dev/null && echo true || echo false)"
assert "Heuristic flags degraded:true" \
    "$(echo "$OUT" | jq -e '.degraded==true' >/dev/null && echo true || echo false)"
assert "Heuristic includes auth" \
    "$(echo "$OUT" | jq -e '[.expected[].concept_id]|index("systems/auth.md")' >/dev/null && echo true || echo false)"
assert "Heuristic excludes tests/ dir" \
    "$(echo "$OUT" | jq -e '[.expected[].concept_id]|index("systems/tests.md")|not' >/dev/null && echo true || echo false)"
assert "Plan JSON is well-formed (.counts present)" \
    "$(echo "$OUT" | jq -e '.counts.expected_total>=2' >/dev/null && echo true || echo false)"

# --- Manifest path is authoritative ---
printf '# components\nauth\nbilling\nnotifications\n' > "$FIXTURE/manifest.txt"
run "$TOOL" --repo "$REPO" --manifest "$FIXTURE/manifest.txt"
assert "Manifest → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"
assert "Manifest source is 'manifest'" \
    "$(echo "$OUT" | jq -e '.source=="manifest"' >/dev/null && echo true || echo false)"
assert "Manifest yields 3 required concepts" \
    "$(echo "$OUT" | jq -e '.counts.required==3' >/dev/null && echo true || echo false)"
assert "Manifest comment line ignored" \
    "$(echo "$OUT" | jq -e '[.expected[].concept_id]|index("systems/components.md")|not' >/dev/null && echo true || echo false)"

# --- allow-defer moves a component to deferred with a reason ---
run "$TOOL" --repo "$REPO" --manifest "$FIXTURE/manifest.txt" --allow-defer 'notifications'
assert "allow-defer → 1 deferred" \
    "$(echo "$OUT" | jq -e '.counts.deferred==1' >/dev/null && echo true || echo false)"
assert "deferred entry carries a reason" \
    "$(echo "$OUT" | jq -e '[.expected[]|select(.required==false)][0].reason_if_deferred|length>0' >/dev/null && echo true || echo false)"

# --- --out writes a file ---
run "$TOOL" --repo "$REPO" --manifest "$FIXTURE/manifest.txt" --out "$FIXTURE/plan.json"
assert "--out writes the plan file" "$([[ -f "$FIXTURE/plan.json" ]] && echo true || echo false)"
assert "written plan parses" \
    "$(jq -e '.expected' "$FIXTURE/plan.json" >/dev/null 2>&1 && echo true || echo false)"

# --- Missing manifest → exit 1 ---
run "$TOOL" --repo "$REPO" --manifest "$FIXTURE/nope.txt"
assert "Missing manifest → exit 1" "$([[ "$RC" == "1" ]] && echo true || echo false)"

# --- Bad --repo → exit 1 ---
run "$TOOL" --repo "$FIXTURE/nodir"
assert "Bad --repo → exit 1" "$([[ "$RC" == "1" ]] && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
