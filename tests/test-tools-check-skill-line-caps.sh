#!/usr/bin/env bash
source tests/test-helpers.sh
test_check_skill_line_caps_help() {
  run_tool "scripts/tools/check-skill-line-caps.sh" --help
  assert_contains "Foundations stub" "$OUTPUT"
  pass
}
run_tests
