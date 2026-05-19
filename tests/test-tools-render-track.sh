#!/usr/bin/env bash
source tests/test-helpers.sh
test_render_track_help() {
  run_tool "scripts/tools/render-track.sh" --help
  assert_contains "Foundations stub" "$OUTPUT"
  pass
}
run_tests
