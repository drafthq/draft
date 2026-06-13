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

finish_test() {
    local suite_name="${1:-test suite}"
    echo ""
    echo "=== Results: $PASS passed, $FAIL failed ==="
    exit "$FAIL"
}

# Write a mock codebase-memory-mcp engine to $1 and echo its path.
# The mock answers `--version` and `cli <tool> <json>` with deterministic JSON,
# so graph-engine tools can be exercised in CI without the real binary.
make_mock_memory_engine() {
    local dir="$1"
    local bin="$dir/codebase-memory-mcp"
    mkdir -p "$dir"
    cat > "$bin" <<'MOCK'
#!/usr/bin/env bash
# Deterministic mock of codebase-memory-mcp for tests.
if [[ "$1" == "--version" ]]; then echo "codebase-memory-mcp 0.0.0-mock"; exit 0; fi
[[ "$1" == "cli" ]] || { echo '{}'; exit 0; }
tool="$2"
case "$tool" in
  list_projects)    echo '{"projects":[]}' ;;
  index_repository) echo '{"project":"mock","status":"indexed","nodes":3,"edges":2}' ;;
  index_status)     echo '{"project":"mock","nodes":3,"edges":2,"status":"ready"}' ;;
  get_architecture)
    echo '{"project":"mock","hotspots":[{"name":"foo","qualified_name":"mock.foo","fan_in":5},{"name":"bar","qualified_name":"mock.bar","fan_in":2}],"routes":[{"method":"GET","path":"/health","handler":"healthz"}]}' ;;
  query_graph)
    echo '{"columns":["a","b"],"rows":[["mock.a","mock.b"]],"total":1}' ;;
  trace_path)
    echo '{"function":"foo","direction":"both","callees":[],"callers":[{"name":"bar","qualified_name":"mock.bar","hop":1}]}' ;;
  detect_changes)
    echo '{"changed_files":["a.sh"],"changed_count":1,"impacted_symbols":[{"name":"foo","label":"Function","file":"a.sh"}]}' ;;
  *) echo '{}' ;;
esac
exit 0
MOCK
    chmod +x "$bin"
    printf '%s' "$bin"
}
