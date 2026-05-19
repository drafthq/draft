#!/usr/bin/env bash
source tests/test-helpers.sh
test_verify_citations_help() {
  run_tool "scripts/tools/verify-citations.sh" --help
  assert_contains "Foundations stub" "$OUTPUT"
  pass
}
run_tests
