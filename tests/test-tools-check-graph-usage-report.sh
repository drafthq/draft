#!/usr/bin/env bash
source tests/test-helpers.sh
test_check_graph_usage_report_help() {
  run_tool "scripts/tools/check-graph-usage-report.sh" --help
  assert_contains "Foundations stub" "$OUTPUT"
  pass
}
run_tests
