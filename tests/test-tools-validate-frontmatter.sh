#!/usr/bin/env bash
# Test suite for scripts/tools/validate-frontmatter.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/validate-frontmatter.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== validate-frontmatter.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# Valid file (default requirement: name + description)
cat > "$FIXTURE/ok.md" <<'EOF'
---
name: sample
description: a sample skill
---

# Sample
EOF
set +e
"$TOOL" "$FIXTURE/ok.md" >/dev/null 2>&1
rc=$?
set -e
assert "Valid file → exit 0" "$([[ "$rc" == "0" ]] && echo true || echo false)"

# Missing opening --- delimiter
cat > "$FIXTURE/no-open.md" <<'EOF'
name: x
description: y

# body
EOF
set +e
"$TOOL" "$FIXTURE/no-open.md" >/dev/null 2>&1
rc=$?
set -e
assert "Missing opening --- → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# Missing closing --- delimiter
cat > "$FIXTURE/no-close.md" <<'EOF'
---
name: x
description: y

# body
EOF
set +e
"$TOOL" "$FIXTURE/no-close.md" >/dev/null 2>&1
rc=$?
set -e
assert "Missing closing --- → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# Missing required field
cat > "$FIXTURE/no-desc.md" <<'EOF'
---
name: x
---

# body
EOF
set +e
"$TOOL" "$FIXTURE/no-desc.md" >/dev/null 2>&1
rc=$?
set -e
assert "Missing 'description' → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --require override
cat > "$FIXTURE/report.md" <<'EOF'
---
project: draft
generated_at: "2026-04-22T00:00:00Z"
git:
  branch: main
---

# report
EOF
set +e
"$TOOL" "$FIXTURE/report.md" --require project,generated_at,git >/dev/null 2>&1
rc=$?
set -e
assert "Custom --require set satisfied → exit 0" "$([[ "$rc" == "0" ]] && echo true || echo false)"

# File not found → exit 2
set +e
"$TOOL" "$FIXTURE/none.md" >/dev/null 2>&1
rc=$?
set -e
assert "Missing file → exit 2" "$([[ "$rc" == "2" ]] && echo true || echo false)"

# --mode project-doc: clean file (no forbidden fields) → exit 0
cat > "$FIXTURE/project-doc-clean.md" <<'EOF'
---
project: my-service
module: root
generated_by: draft:init
generated_at: "2026-01-01T00:00:00Z"
---

# My Service
EOF
set +e
"$TOOL" "$FIXTURE/project-doc-clean.md" --mode project-doc --require project,generated_by >/dev/null 2>&1
rc=$?
set -e
assert "--mode project-doc: clean file → exit 0" "$([[ "$rc" == "0" ]] && echo true || echo false)"

# --mode project-doc: file with git: block → exit 1
cat > "$FIXTURE/project-doc-git.md" <<'EOF'
---
project: my-service
generated_by: draft:init
generated_at: "2026-01-01T00:00:00Z"
git:
  branch: main
  commit: abc123
---

# My Service
EOF
set +e
"$TOOL" "$FIXTURE/project-doc-git.md" --mode project-doc --require project,generated_by >/dev/null 2>&1
rc=$?
set -e
assert "--mode project-doc: git: block present → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --mode project-doc: file with synced_to_commit → exit 1
cat > "$FIXTURE/project-doc-synced.md" <<'EOF'
---
project: my-service
generated_by: draft:init
generated_at: "2026-01-01T00:00:00Z"
synced_to_commit: "abc1234567890abc1234567890abc1234567890ab"
---

# My Service
EOF
set +e
"$TOOL" "$FIXTURE/project-doc-synced.md" --mode project-doc --require project,generated_by >/dev/null 2>&1
rc=$?
set -e
assert "--mode project-doc: synced_to_commit present → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --mode project-doc: file with both git: and synced_to_commit → exit 1
cat > "$FIXTURE/project-doc-both.md" <<'EOF'
---
project: my-service
generated_by: draft:init
generated_at: "2026-01-01T00:00:00Z"
git:
  branch: main
synced_to_commit: "abc1234567890abc1234567890abc1234567890ab"
---

# My Service
EOF
set +e
err_msg="$("$TOOL" "$FIXTURE/project-doc-both.md" --mode project-doc --require project,generated_by 2>&1)"
rc=$?
set -e
assert "--mode project-doc: git: + synced_to_commit both present → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"
assert "--mode project-doc: error message mentions draft/metadata.json" \
    "$(echo "$err_msg" | grep -q "draft/metadata.json" && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
