#!/usr/bin/env bash
# run-coverage.sh — normalized coverage dispatcher.
#
# Dispatches to a language-specific coverage runner and emits a normalized
# JSON report:
# {language, tool, total:{lines,branches}, per_file:[{path,lines,branches,uncovered_lines}]}
#
# The actual coverage run is language-specific and may be slow. Use
# `--schema-check` in CI to validate output shape without running tests.
#
# Usage:
# scripts/tools/run-coverage.sh <language> [--path DIR]
# [--schema-check]
#
# Languages: python (pytest --cov), go (go test -coverprofile), javascript (nyc), shell (n/a → 2)
#
# Exit codes: 0 OK, 1 invocation error, 2 tool unavailable (emits empty-schema JSON).
set -euo pipefail

LANGUAGE=""
COVERAGE_PATH="."
SCHEMA_CHECK="false"

usage() {
    cat <<'EOF'
run-coverage.sh — normalized coverage report dispatcher.

Usage:
  scripts/tools/run-coverage.sh <language> [--path DIR] [--schema-check]

Languages:
  python pytest --cov (requires pytest-cov)
  go go test -coverprofile
  javascript nyc/c8 (via package.json)
  shell not supported — emits schema-valid empty report (exit 2)

Flags:
  --path DIR Path to run coverage against (default: cwd).
  --schema-check Emit schema-valid empty JSON without running any tests (for CI).
  --help Show this help.

Output schema (always present, even on exit 2):
  {
    "language": "<lang>",
    "tool": "<coverage-tool>",
    "total": {"lines": <float 0..1>, "branches": <float 0..1|null>},
    "per_file": [{"path","lines","branches","uncovered_lines":[<int>...]}]
  }
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --path) COVERAGE_PATH="$2"; shift 2;;
        --schema-check) SCHEMA_CHECK="true"; shift;;
        --help|-h) usage; exit 0;;
        -*) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
        *)
            if [[ -z "$LANGUAGE" ]]; then
                LANGUAGE="$1"; shift
            else
                echo "Unexpected positional arg: $1" >&2; exit 1
            fi
            ;;
    esac
done

if [[ -z "$LANGUAGE" ]]; then
    echo "ERROR: language is required (see --help)" >&2
    exit 1
fi

emit_empty() {
    local lang="$1" tool="$2"
    printf '{"language":"%s","tool":"%s","total":{"lines":null,"branches":null},"per_file":[]}\n' \
        "$lang" "$tool"
}

# Schema-only mode: never run the real coverage tool.
if [[ "$SCHEMA_CHECK" == "true" ]]; then
    case "$LANGUAGE" in
        python) tool="pytest-cov";;
        go) tool="go-cover";;
        javascript) tool="nyc";;
        typescript) tool="nyc";;
        shell) tool="none";;
        *)
            echo "ERROR: unsupported language '$LANGUAGE'" >&2
            exit 1
            ;;
    esac
    emit_empty "$LANGUAGE" "$tool"
    [[ "$LANGUAGE" == "shell" ]] && exit 2
    exit 0
fi

case "$LANGUAGE" in
    python)
        if ! command -v pytest >/dev/null 2>&1; then
            emit_empty python pytest-cov
            exit 2
        fi
        # Run, capture JSON if coverage.py is available.
        tmp_json="$(mktemp)"
        trap 'rm -f "$tmp_json"' EXIT
        (cd "$COVERAGE_PATH" && pytest --cov --cov-report=json:"$tmp_json" >/dev/null 2>&1) || true
        if [[ -s "$tmp_json" ]] && command -v jq >/dev/null 2>&1; then
            jq '{language:"python", tool:"pytest-cov",
                 total:{lines: (.totals.percent_covered // 0) / 100, branches: null},
                 per_file: (.files | to_entries | map({
                    path: .key,
                    lines: (.value.summary.percent_covered // 0) / 100,
                    branches: null,
                    uncovered_lines: (.value.missing_lines // [])
                 }))}' "$tmp_json"
            exit 0
        fi
        emit_empty python pytest-cov
        exit 2
        ;;
    go)
        if ! command -v go >/dev/null 2>&1; then
            emit_empty go go-cover
            exit 2
        fi
        tmp_cov="$(mktemp)"
        trap 'rm -f "$tmp_cov"' EXIT
        (cd "$COVERAGE_PATH" && go test -coverprofile="$tmp_cov" ./... >/dev/null 2>&1) || true
        if [[ -s "$tmp_cov" ]]; then
            total=$(go tool cover -func="$tmp_cov" 2>/dev/null | awk '/^total:/ {gsub(/%/, "", $3); print $3/100}')
            total="${total:-null}"
            printf '{"language":"go","tool":"go-cover","total":{"lines":%s,"branches":null},"per_file":[]}\n' \
                "$total"
            exit 0
        fi
        emit_empty go go-cover
        exit 2
        ;;
    javascript|typescript)
        # Real coverage via nyc/c8 is not yet wired — emit empty schema (exit 2)
        # so consumers can degrade gracefully. See --schema-check for CI validation.
        emit_empty "$LANGUAGE" nyc
        exit 2
        ;;
    shell)
        emit_empty shell none
        exit 2
        ;;
    *)
        echo "ERROR: unsupported language '$LANGUAGE'" >&2
        exit 1
        ;;
esac
