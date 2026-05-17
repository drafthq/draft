#!/usr/bin/env bash
# Test suite for scripts/tools/ common contract
#
# What this tests (per registered tool):
# - Shebang is #!/usr/bin/env bash
# - Contains `set -euo pipefail`
# - Supports `--help` (exit 0, non-empty output)
# - Script is valid bash (bash -n parses it)
#
# Usage:
# ./tests/test-tools-conventions.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/test-helpers.sh"
source "$ROOT_DIR/scripts/lib.sh"

echo "=== Tools convention tests ==="
echo ""

if [[ ${#TOOLS[@]} -eq 0 ]]; then
    echo "## TOOLS array is empty — nothing to validate"
    echo ""
    echo "=== Results: $PASS passed, $FAIL failed ==="
    exit "$FAIL"
fi

for tool in "${TOOLS[@]}"; do
    [[ -z "$tool" ]] && continue
    full_path="$TOOLS_DIR/$tool"
    echo "## $tool"

    if [[ ! -f "$full_path" ]]; then
        assert "$tool: file exists" "false"
        continue
    fi

    # Shebang check
    shebang="$(sed -n '1p' "$full_path")"
    assert "$tool: shebang is #!/usr/bin/env bash" \
        "$([[ "$shebang" == "#!/usr/bin/env bash" ]] && echo true || echo false)"

    # set -euo pipefail
    if grep -q '^set -euo pipefail' "$full_path"; then
        assert "$tool: uses 'set -euo pipefail'" "true"
    else
        assert "$tool: uses 'set -euo pipefail'" "false"
    fi

    # bash syntax check
    if bash -n "$full_path" 2>/dev/null; then
        assert "$tool: bash syntax valid" "true"
    else
        assert "$tool: bash syntax valid" "false"
    fi

    # --help support
    if out="$("$full_path" --help 2>&1)" && [[ -n "$out" ]]; then
        assert "$tool: --help prints output" "true"
    else
        assert "$tool: --help prints output" "false"
    fi
done

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
