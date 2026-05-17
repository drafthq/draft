#!/usr/bin/env bash
# Shared test helpers for all test suites
#
# Provides assert(). Does NOT duplicate functions
# from scripts/lib.sh — tests that need extract_body, is_valid_skill_name,
# or validate_skill_body_format should source scripts/lib.sh directly.

set -euo pipefail

PASS=0
FAIL=0

assert() {
    local description="$1"
    local result="$2"
    if [[ "$result" == "true" ]]; then
        echo " PASS: $description"
        PASS=$((PASS + 1))
    else
        echo " FAIL: $description"
        FAIL=$((FAIL + 1))
    fi
}
