#!/usr/bin/env bash
source tests/test-helpers.sh
test_emit_skill_metrics_help() {
  run_tool "scripts/tools/emit-skill-metrics.sh" --help
  assert_contains "Foundations stub" "$OUTPUT"
  pass
}
run_tests
