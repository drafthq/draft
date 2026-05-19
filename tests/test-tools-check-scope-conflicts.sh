#!/usr/bin/env bash
source tests/test-helpers.sh
test_check_scope_conflicts_help() {
  run_tool "scripts/tools/check-scope-conflicts.sh" --help
  assert_contains "Foundations stub" "$OUTPUT"
  pass
}
run_tests
