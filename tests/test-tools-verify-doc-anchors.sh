#!/usr/bin/env bash
source tests/test-helpers.sh
test_verify_doc_anchors_help() {
  run_tool "scripts/tools/verify-doc-anchors.sh" --help
  assert_contains "Foundations stub" "$OUTPUT"
  pass
}
run_tests
