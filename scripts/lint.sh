#!/usr/bin/env bash
# ============================================================
# lint.sh — Run shellcheck and markdownlint-cli
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT"

echo "Running linters..."

exit_code=0

# Shellcheck
if command -v shellcheck &> /dev/null; then
    echo "[*] Running shellcheck..."
    while IFS= read -r -d '' file; do
        if ! shellcheck --severity=warning -e SC1091,SC1090,SC2034,SC2164,SC2143 "$file"; then
            echo "✗ Shellcheck failed for $file"
            exit_code=1
        fi
    done < <(find scripts tests -name "*.sh" -print0)
    echo "✓ Shellcheck complete."
else
    echo "⚠ shellcheck not found. Skipping shell linting."
fi

echo ""

# Markdownlint
if command -v markdownlint &> /dev/null; then
    echo "[*] Running markdownlint..."
    if ! markdownlint "**/*.md" --ignore "node_modules" --ignore "draft.tmp" --ignore "draft/tracks" --ignore "integrations"; then
        echo "✗ Markdownlint found issues."
        exit_code=1
    else
        echo "✓ Markdownlint complete."
    fi
else
    echo "⚠ markdownlint-cli not found. Skipping markdown linting."
fi

if [ $exit_code -eq 0 ]; then
    echo -e "\nAll lint checks passed successfully!"
else
    echo -e "\nLint checks failed."
fi

exit $exit_code
