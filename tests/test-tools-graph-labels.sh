#!/usr/bin/env bash
# Regression guard for graph-tooling-v2:
#   - Phase 0 lock: no wrapper may re-pin `:Function {` on a name match (code
#     units are mostly :Method; pinning :Function silently returns []).
#   - Guardrail 2: Cypher literals live ONLY in _graph_queries.sh. The single
#     exception is graph-query.sh, the generic passthrough, where Cypher appears
#     only as a help-text example (the user supplies the real query).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOLS_DIR="$ROOT_DIR/scripts/tools"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== graph label / Cypher-centralization regression tests ==="
echo ""

# --- No `:Function {` anywhere under scripts/tools/ ---
PINNED="$(grep -rl ':Function {' "$TOOLS_DIR" 2>/dev/null || true)"
assert "No wrapper re-pins ':Function {' (Phase 0 lock)" \
    "$([[ -z "$PINNED" ]] && echo true || echo false)"
[[ -n "$PINNED" ]] && echo "  offending: $PINNED"

# --- Cypher literals (MATCH (...)) only in _graph_queries.sh / graph-query.sh ---
OFFENDERS=""
while IFS= read -r -d '' f; do
    base="$(basename "$f")"
    [[ "$base" == "_graph_queries.sh" || "$base" == "graph-query.sh" ]] && continue
    if grep -qE 'MATCH \(' "$f"; then
        OFFENDERS="$OFFENDERS $base"
    fi
done < <(find "$TOOLS_DIR" -maxdepth 1 -name '*.sh' -print0 | sort -z)
assert "No embedded Cypher literal outside _graph_queries.sh (Guardrail 2)" \
    "$([[ -z "$OFFENDERS" ]] && echo true || echo false)"
[[ -n "$OFFENDERS" ]] && echo "  offending:$OFFENDERS"

# --- The query module exists and exposes the canonical builders ---
GQ="$TOOLS_DIR/_graph_queries.sh"
assert "_graph_queries.sh exists" "$([[ -f "$GQ" ]] && echo true || echo false)"
if [[ -f "$GQ" ]]; then
    for fn in gq_q_callers gq_q_cycles2 gq_q_imports gq_q_tests gq_q_risk gq_run gq_symbol_status; do
        assert "_graph_queries.sh defines $fn" \
            "$(grep -qE "^${fn}\(\)" "$GQ" && echo true || echo false)"
    done
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
