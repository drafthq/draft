#!/usr/bin/env bash
# Test suite for scripts/tools/git-metadata.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/git-metadata.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== git-metadata.sh tests ==="
echo ""

# --- JSON output is valid JSON and has required fields ---
json_out="$("$TOOL" --json)"
if command -v jq >/dev/null 2>&1; then
    if echo "$json_out" | jq . >/dev/null 2>&1; then
        assert "JSON output parses with jq" "true"
    else
        assert "JSON output parses with jq" "false"
    fi
elif command -v python3 >/dev/null 2>&1; then
    if echo "$json_out" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
        assert "JSON output parses with python3" "true"
    else
        assert "JSON output parses with python3" "false"
    fi
else
    echo " SKIP: neither jq nor python3 available"
fi

for field in project module generated_at git synced_to_commit; do
    if echo "$json_out" | grep -q "\"$field\""; then
        assert "JSON output contains '$field'" "true"
    else
        assert "JSON output contains '$field'" "false"
    fi
done

# --- YAML output begins and ends with --- delimiters ---
yaml_out="$("$TOOL" --yaml)"
first_line="$(echo "$yaml_out" | sed -n '1p')"
last_line="$(echo "$yaml_out" | sed -n '$p')"
assert "YAML output starts with ---" \
    "$([[ "$first_line" == "---" ]] && echo true || echo false)"
assert "YAML output ends with ---" \
    "$([[ "$last_line" == "---" ]] && echo true || echo false)"

# --- YAML output includes required fields ---
for field in "project:" "module:" "generated_at:" "git:" "synced_to_commit:"; do
    if echo "$yaml_out" | grep -q "^${field}\|^ ${field}"; then
        assert "YAML output contains '$field'" "true"
    else
        assert "YAML output contains '$field'" "false"
    fi
done

# --- Custom flags propagate ---
custom="$("$TOOL" --json --project MyProj --module core --track-id T-42 --generated-by draft:bughunt)"
for expect in '"project": "MyProj"' '"module": "core"' '"track_id": "T-42"' '"generated_by": "draft:bughunt"'; do
    if echo "$custom" | grep -qF "$expect"; then
        assert "Custom flag propagates: $expect" "true"
    else
        assert "Custom flag propagates: $expect" "false"
    fi
done

# --- Commit SHA is 40 hex chars ---
sha="$(echo "$json_out" | grep -oE '"commit": "[0-9a-f]{40}"' | head -1)"
assert "git.commit is full 40-char SHA" \
    "$([[ -n "$sha" ]] && echo true || echo false)"

# --- --project-metadata writes draft/metadata.json ---
PM_DIR="$(mktemp -d)"
trap 'rm -rf "$PM_DIR"' EXIT
mkdir -p "$PM_DIR/draft"

set +e
pm_out="$("$TOOL" --project-metadata --project "test-proj" --generated-by "draft:init" --output-dir "$PM_DIR" 2>&1)"
pm_rc=$?
set -e
assert "--project-metadata exits 0" "$([[ "$pm_rc" == "0" ]] && echo true || echo false)"
assert "--project-metadata writes draft/metadata.json" \
    "$([[ -f "$PM_DIR/draft/metadata.json" ]] && echo true || echo false)"

if [[ -f "$PM_DIR/draft/metadata.json" ]]; then
    pm_json="$(cat "$PM_DIR/draft/metadata.json")"

    # JSON is valid
    if command -v python3 >/dev/null 2>&1; then
        valid="$(echo "$pm_json" | python3 -c 'import json,sys; json.load(sys.stdin); print("ok")' 2>/dev/null || echo "fail")"
        assert "--project-metadata output is valid JSON" "$([[ "$valid" == "ok" ]] && echo true || echo false)"
    fi

    # Required fields present
    for field in project schema_version generated_by generated_at git synced_to_commit; do
        assert "--project-metadata JSON has '$field'" \
            "$(echo "$pm_json" | grep -q "\"$field\"" && echo true || echo false)"
    done

    # synced_to_commit is a 40-char SHA
    pm_sha="$(echo "$pm_json" | grep -oE '"synced_to_commit": "[0-9a-f]{40}"' | head -1)"
    assert "--project-metadata synced_to_commit is 40-char SHA" \
        "$([[ -n "$pm_sha" ]] && echo true || echo false)"

    # project field matches --project flag
    assert "--project-metadata project name propagates" \
        "$(echo "$pm_json" | grep -q '"project": "test-proj"' && echo true || echo false)"

    # generated_by matches --generated-by flag
    assert "--project-metadata generated_by propagates" \
        "$(echo "$pm_json" | grep -q '"generated_by": "draft:init"' && echo true || echo false)"

    # Idempotent re-run: same SHA both times
    "$TOOL" --project-metadata --project "test-proj" --generated-by "draft:init" --output-dir "$PM_DIR" >/dev/null 2>&1 || true
    pm_sha2="$(cat "$PM_DIR/draft/metadata.json" | grep -oE '"synced_to_commit": "[0-9a-f]{40}"' | head -1)"
    assert "--project-metadata is idempotent (same SHA on re-run)" \
        "$([[ "$pm_sha" == "$pm_sha2" ]] && echo true || echo false)"
fi

# Error when draft/ dir absent
NO_DRAFT_DIR="$(mktemp -d)"
trap 'rm -rf "$PM_DIR" "$NO_DRAFT_DIR"' EXIT
set +e
"$TOOL" --project-metadata --output-dir "$NO_DRAFT_DIR" >/dev/null 2>&1
err_rc=$?
set -e
assert "--project-metadata exits nonzero when draft/ absent" \
    "$([[ "$err_rc" != "0" ]] && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
