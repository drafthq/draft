#!/usr/bin/env bash
source tests/test-helpers.sh
test_fix_whitespace_help() {
  run_tool "scripts/tools/fix-whitespace.sh" --help
  assert_contains "Foundations stub" "$OUTPUT"
  pass
}

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
