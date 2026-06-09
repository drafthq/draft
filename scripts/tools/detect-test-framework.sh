#!/usr/bin/env bash
# detect-test-framework.sh — detect test framework(s) used in a repo.
#
# Output: JSON {languages:[{language, framework, runner_command, test_globs, config_file}]}
#
# Detection rules (first match per language wins):
# python → pytest (pytest.ini | pyproject.toml has "[tool.pytest.ini_options]")
# | unittest (has tests but no pytest config)
# go → go test (go.mod + any *_test.go)
# javascript/typescript → vitest | jest | mocha (by package.json scripts / devDependencies)
# rust → cargo test (Cargo.toml + tests/)
# shell → plain bash (tests/ dir has test-*.sh)
#
# Usage:
# scripts/tools/detect-test-framework.sh [--root DIR]
#
# Exit codes: 0 (always; empty languages array is valid output).
set -euo pipefail

# shellcheck source=_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

ROOT="."

usage() {
    cat <<'EOF'
detect-test-framework.sh — detect language test frameworks.

Usage:
  scripts/tools/detect-test-framework.sh [--root DIR]

Flags:
  --root DIR Repository root (default: cwd).
  --help Show this help.

Output: JSON {languages:[{language, framework, runner_command, test_globs, config_file}]}
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --root) ROOT="$2"; shift 2;;
        --help|-h) usage; exit 0;;
        *) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
    esac
done

if [[ ! -d "$ROOT" ]]; then
    echo "ERROR: --root '$ROOT' is not a directory" >&2
    exit 1
fi

cd "$ROOT"

emit_lang() {
    local language="$1" framework="$2" runner="$3" globs="$4" config="$5"
    printf '{"language":"%s","framework":"%s","runner_command":"%s","test_globs":%s,"config_file":%s}' \
        "$(json_escape "$language")" \
        "$(json_escape "$framework")" \
        "$(json_escape "$runner")" \
        "$globs" \
        "$([[ -z "$config" ]] && echo null || echo "\"$(json_escape "$config")\"")"
}

RESULTS=()

# ── Python ──
PY_CONFIG=""
PY_FRAMEWORK=""
if [[ -f pytest.ini ]]; then
    PY_CONFIG="pytest.ini"; PY_FRAMEWORK="pytest"
elif [[ -f pyproject.toml ]] && grep -q 'tool.pytest' pyproject.toml 2>/dev/null; then
    PY_CONFIG="pyproject.toml"; PY_FRAMEWORK="pytest"
elif [[ -f setup.cfg ]] && grep -qE '^\[tool:pytest\]' setup.cfg 2>/dev/null; then
    PY_CONFIG="setup.cfg"; PY_FRAMEWORK="pytest"
fi
if [[ -z "$PY_FRAMEWORK" ]]; then
    if find . -maxdepth 4 \( -name 'test_*.py' -o -name '*_test.py' \) \
        -not -path './.git/*' -not -path './node_modules/*' -print -quit 2>/dev/null | grep -q .; then
        PY_FRAMEWORK="unittest"
    fi
fi
if [[ -n "$PY_FRAMEWORK" ]]; then
    RESULTS+=("$(emit_lang "python" "$PY_FRAMEWORK" \
        "$([[ "$PY_FRAMEWORK" == pytest ]] && echo 'pytest' || echo 'python -m unittest')" \
        '["test_*.py","*_test.py"]' \
        "$PY_CONFIG")")
fi

# ── Go ──
if [[ -f go.mod ]]; then
    if find . -maxdepth 6 -name '*_test.go' -not -path './vendor/*' -print -quit 2>/dev/null | grep -q .; then
        RESULTS+=("$(emit_lang "go" "go test" "go test ./..." '["*_test.go"]' "go.mod")")
    fi
fi

# ── JS/TS ── (single file read, match in-memory)
if [[ -f package.json ]]; then
    PKG_JSON="$(<package.json)"
    JS_FRAMEWORK=""
    if [[ "$PKG_JSON" == *'"vitest"'* ]]; then
        JS_FRAMEWORK="vitest"
    elif [[ "$PKG_JSON" == *'"jest"'* ]]; then
        JS_FRAMEWORK="jest"
    elif [[ "$PKG_JSON" == *'"mocha"'* ]]; then
        JS_FRAMEWORK="mocha"
    fi
    if [[ -n "$JS_FRAMEWORK" ]]; then
        RESULTS+=("$(emit_lang "javascript" "$JS_FRAMEWORK" \
            "npm test" \
            '["*.test.[jt]s","*.test.[jt]sx","*.spec.[jt]s","*.spec.[jt]sx"]' \
            "package.json")")
    fi
fi

# ── Rust ──
if [[ -f Cargo.toml ]]; then
    RESULTS+=("$(emit_lang "rust" "cargo test" "cargo test" '["tests/*.rs","src/**/*_test.rs"]' "Cargo.toml")")
fi

# ── Shell ──
if find . -maxdepth 3 -type d -name tests -print -quit 2>/dev/null | grep -q .; then
    if find tests -maxdepth 2 -name 'test-*.sh' -print -quit 2>/dev/null | grep -q .; then
        RESULTS+=("$(emit_lang "shell" "bash" "./tests/run-all.sh" '["tests/test-*.sh"]' "")")
    fi
fi

# Assemble
printf '{"languages":['
first=true
for r in ${RESULTS[@]+"${RESULTS[@]}"}; do
    if $first; then first=false; else printf ','; fi
    printf '%s' "$r"
done
printf ']}\n'
