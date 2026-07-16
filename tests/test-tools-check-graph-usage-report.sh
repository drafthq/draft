#!/usr/bin/env bash
# Test suite for scripts/tools/check-graph-usage-report.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/check-graph-usage-report.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== check-graph-usage-report.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

run() { set +e; OUT="$("$TOOL" "$@" 2>&1)"; RC=$?; set -e; }

# --- Valid report: section + all four bullets ---
VALID="$FIXTURE/valid.md"
cat > "$VALID" <<'EOF'
# Some Output

## Graph Usage Report
- Graph files queried: graph-callers.sh, hotspot-rank.sh
- Modules identified via graph: auth, billing
- Files identified via graph: src/auth.go
- Filesystem grep fallbacks: none
EOF
run "$VALID"
assert "valid report → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"

# --- Missing section ---
NOSEC="$FIXTURE/nosec.md"
printf '# Output with no report\n' > "$NOSEC"
run "$NOSEC"
assert "missing section → exit 1" "$([[ "$RC" == "1" ]] && echo true || echo false)"

# --- Missing one required bullet ---
PARTIAL="$FIXTURE/partial.md"
cat > "$PARTIAL" <<'EOF'
## Graph Usage Report
- Graph files queried: graph-arch.sh
- Modules identified via graph: core
- Files identified via graph: a.go
EOF
run "$PARTIAL"
assert "missing bullet → exit 1" "$([[ "$RC" == "1" ]] && echo true || echo false)"
assert "missing bullet named in output" \
    "$(echo "$OUT" | grep -qF 'Filesystem grep fallbacks:' && echo true || echo false)"

# --- NONE requires a populated Justification ---
NONE_BAD="$FIXTURE/none-bad.md"
cat > "$NONE_BAD" <<'EOF'
## Graph Usage Report
- Graph files queried: NONE
- Modules identified via graph: n/a
- Files identified via graph: n/a
- Filesystem grep fallbacks: n/a
EOF
run "$NONE_BAD"
assert "NONE without Justification → exit 1" "$([[ "$RC" == "1" ]] && echo true || echo false)"

NONE_OK="$FIXTURE/none-ok.md"
cat > "$NONE_OK" <<'EOF'
## Graph Usage Report
- Graph files queried: NONE
- Justification: docs-only change, no code touched
- Modules identified via graph: n/a
- Files identified via graph: n/a
- Filesystem grep fallbacks: n/a
EOF
run "$NONE_OK"
assert "NONE with Justification → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"

# --- Skip marker exempts the file ---
SKIP="$FIXTURE/skip.md"
printf '<!-- graph-usage-report:skip -->\n# No report needed here\n' > "$SKIP"
run "$SKIP"
assert "skip-marked file → exit 0" "$([[ "$RC" == "0" ]] && echo true || echo false)"

# --- Usage errors ---
run
assert "no args → exit 2" "$([[ "$RC" == "2" ]] && echo true || echo false)"
run "$FIXTURE/does-not-exist.md"
assert "missing file → exit 1" "$([[ "$RC" == "1" ]] && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
