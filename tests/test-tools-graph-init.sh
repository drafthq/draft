#!/usr/bin/env bash
# Test suite for scripts/tools/graph-init.sh (scope-aware, root-first builder)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/graph-init.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== graph-init.sh tests ==="
echo ""

# --- Fallback: engine disabled → exit 2, nothing built ---
FX1="$(mktemp -d)"; FX1="$(cd "$FX1" && pwd -P)"
trap 'rm -rf "$FX1"' EXIT
set +e
DRAFT_MEMORY_DISABLE=1 "$TOOL" --scope "$FX1" --no-fetch >/dev/null 2>&1
rc=$?
set -e
assert "Exit 2 when engine unavailable" "$([[ "$rc" == "2" ]] && echo true || echo false)"
assert "No graph dir written on fallback" "$([[ ! -f "$FX1/draft/graph/schema.yaml" ]] && echo true || echo false)"

if command -v jq >/dev/null 2>&1 && command -v git >/dev/null 2>&1; then
    MOCK="$(make_mock_memory_engine "$FX1/mockbin")"

    # --- Root init: scope == git toplevel → whole-repo snapshot, no root-link ---
    R="$(mktemp -d)"; R="$(cd "$R" && pwd -P)"
    git -C "$R" init -q
    set +e
    DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --scope "$R" --no-fetch --json >"$R/out.json" 2>/dev/null
    rc=$?
    set -e
    assert "Root init → exit 0" "$([[ "$rc" == "0" ]] && echo true || echo false)"
    assert "Root snapshot written" "$([[ -f "$R/draft/graph/schema.yaml" ]] && echo true || echo false)"
    assert "Root init reports is_root=1" \
        "$(jq -e '.is_root == 1 and .root_built == 1' "$R/out.json" >/dev/null 2>&1 && echo true || echo false)"
    assert "Root init writes NO root-link.json" \
        "$([[ ! -f "$R/draft/graph/root-link.json" ]] && echo true || echo false)"
    rm -rf "$R"

    # --- Module init (default): builds root spine + module snapshot + linked pointer ---
    M="$(mktemp -d)"; M="$(cd "$M" && pwd -P)"
    git -C "$M" init -q
    mkdir -p "$M/services/auth"
    set +e
    DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --scope "$M/services/auth" --no-fetch --json >"$M/out.json" 2>/dev/null
    rc=$?
    set -e
    assert "Module init → exit 0" "$([[ "$rc" == "0" ]] && echo true || echo false)"
    assert "Root spine built from sub-module" "$([[ -f "$M/draft/graph/schema.yaml" ]] && echo true || echo false)"
    assert "Module snapshot built" "$([[ -f "$M/services/auth/draft/graph/schema.yaml" ]] && echo true || echo false)"
    assert "root-link.json written" "$([[ -f "$M/services/auth/draft/graph/root-link.json" ]] && echo true || echo false)"
    assert "root-link status is linked" \
        "$(jq -e '.status == "linked"' "$M/services/auth/draft/graph/root-link.json" >/dev/null 2>&1 && echo true || echo false)"
    assert "root-link relpath climbs to root graph" \
        "$(jq -e '.root_graph == "../../../../draft/graph"' "$M/services/auth/draft/graph/root-link.json" >/dev/null 2>&1 && echo true || echo false)"
    assert "summary reports link_status=linked" \
        "$(jq -e '.link_status == "linked" and .is_root == 0' "$M/out.json" >/dev/null 2>&1 && echo true || echo false)"
    rm -rf "$M"

    # --- Module-only: skips root, marks link pending ---
    MO="$(mktemp -d)"; MO="$(cd "$MO" && pwd -P)"
    git -C "$MO" init -q
    mkdir -p "$MO/pkg/x"
    set +e
    DRAFT_MEMORY_BIN="$MOCK" "$TOOL" --scope "$MO/pkg/x" --module-only --no-fetch --json >"$MO/out.json" 2>/dev/null
    rc=$?
    set -e
    assert "Module-only → exit 0" "$([[ "$rc" == "0" ]] && echo true || echo false)"
    assert "Module-only does NOT build root spine" "$([[ ! -f "$MO/draft/graph/schema.yaml" ]] && echo true || echo false)"
    assert "Module-only builds module snapshot" "$([[ -f "$MO/pkg/x/draft/graph/schema.yaml" ]] && echo true || echo false)"
    assert "Module-only marks link pending" \
        "$(jq -e '.status == "pending"' "$MO/pkg/x/draft/graph/root-link.json" >/dev/null 2>&1 && echo true || echo false)"
    rm -rf "$MO"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
