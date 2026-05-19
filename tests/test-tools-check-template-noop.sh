#!/usr/bin/env bash
source tests/test-helpers.sh
test_check_template_noop_help() {
  run_tool "scripts/tools/check-template-noop.sh" --help
  assert_contains "Foundations stub" "$OUTPUT"
  pass
}
run_tests
