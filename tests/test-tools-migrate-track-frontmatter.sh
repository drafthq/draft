#!/usr/bin/env bash
source tests/test-helpers.sh
test_migrate_track_frontmatter_help() {
  run_tool "scripts/tools/migrate-track-frontmatter.sh" --help
  assert_contains "Foundations stub" "$OUTPUT"
  pass
}
run_tests
