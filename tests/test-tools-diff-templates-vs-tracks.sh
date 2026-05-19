#!/usr/bin/env bash
source tests/test-helpers.sh
test_diff_templates_vs_tracks_help() {
  run_tool "scripts/tools/diff-templates-vs-tracks.sh" --help
  assert_contains "Foundations stub" "$OUTPUT"
  pass
}
run_tests
