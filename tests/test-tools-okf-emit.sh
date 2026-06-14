#!/usr/bin/env bash
# Test suite for scripts/tools/okf-emit.sh (Open Knowledge Format bundle emit)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/okf-emit.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== okf-emit.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# --- No architecture.json → exit 2, nothing emitted ---
set +e
"$TOOL" --repo "$FIXTURE" --snapshot "$FIXTURE/graph" --out "$FIXTURE/graph/okf" >/dev/null 2>&1
rc=$?
set -e
assert "Exit 2 when architecture.json is absent" "$([[ "$rc" == "2" ]] && echo true || echo false)"
assert "No bundle written without a snapshot" "$([[ ! -f "$FIXTURE/graph/okf/index.md" ]] && echo true || echo false)"

if command -v jq >/dev/null 2>&1; then
    # --- Happy path: packages + boundaries → cross-linked concept files ---
    SNAP="$FIXTURE/graph"
    mkdir -p "$SNAP"
    cat > "$SNAP/architecture.json" <<'JSON'
{
  "project": "fixture",
  "total_nodes": 10,
  "total_edges": 4,
  "languages": [{"language": "Bash", "file_count": 3}],
  "packages": [
    {"name": "alpha", "node_count": 5, "fan_in": 0, "fan_out": 1},
    {"name": "beta", "node_count": 3, "fan_in": 1, "fan_out": 0}
  ],
  "boundaries": [{"from": "alpha", "to": "beta", "call_count": 2}],
  "hotspots": [{"name": "foo", "qualified_name": "fixture.foo", "fan_in": 7}]
}
JSON

    set +e
    "$TOOL" --repo "$FIXTURE" --snapshot "$SNAP" >/dev/null 2>&1
    rc=$?
    set -e
    assert "Emit → exit 0" "$([[ "$rc" == "0" ]] && echo true || echo false)"

    OKF="$SNAP/okf"
    assert "index.md written" "$([[ -f "$OKF/index.md" ]] && echo true || echo false)"
    assert "index.md declares OKF type: Repository" \
        "$(grep -q '^type: Repository' "$OKF/index.md" && echo true || echo false)"
    assert "index.md links each module concept" \
        "$(grep -q '\[alpha\](modules/alpha.md)' "$OKF/index.md" && grep -q '\[beta\](modules/beta.md)' "$OKF/index.md" && echo true || echo false)"
    assert "index.md surfaces hotspots" \
        "$(grep -q 'foo' "$OKF/index.md" && echo true || echo false)"

    assert "module concept file written" "$([[ -f "$OKF/modules/alpha.md" ]] && echo true || echo false)"
    assert "module declares OKF type: Module" \
        "$(grep -q '^type: Module' "$OKF/modules/alpha.md" && echo true || echo false)"
    assert "outbound boundary becomes a cross-link" \
        "$(grep -q '## Depends on' "$OKF/modules/alpha.md" && grep -q '\[beta\](beta.md)' "$OKF/modules/alpha.md" && echo true || echo false)"
    assert "inbound boundary becomes a back-link" \
        "$(grep -q '## Depended on by' "$OKF/modules/beta.md" && grep -q '\[alpha\](alpha.md)' "$OKF/modules/beta.md" && echo true || echo false)"

    # --- Degraded: no packages → index.md still emitted, no module files ---
    SNAP2="$FIXTURE/graph2"
    mkdir -p "$SNAP2"
    echo '{"project": "empty", "total_nodes": 0, "total_edges": 0}' > "$SNAP2/architecture.json"
    "$TOOL" --repo "$FIXTURE" --snapshot "$SNAP2" >/dev/null 2>&1
    assert "Degraded snapshot still emits index.md" "$([[ -f "$SNAP2/okf/index.md" ]] && echo true || echo false)"
    mod_count="$(find "$SNAP2/okf/modules" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
    assert "Degraded snapshot emits no module files" "$([[ "$mod_count" == "0" ]] && echo true || echo false)"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
