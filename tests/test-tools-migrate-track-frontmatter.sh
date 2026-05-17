#!/usr/bin/env bash
# Test suite for scripts/tools/migrate-track-frontmatter.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/migrate-track-frontmatter.sh"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== migrate-track-frontmatter.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# --- Pre-2.0 track with ephemeral fields in spec.md frontmatter ---
mkdir -p "$FIXTURE/tracks/legacy"
cat > "$FIXTURE/tracks/legacy/metadata.json" <<'EOF'
{
  "id": "legacy",
  "title": "Legacy track",
  "type": "feature",
  "status": "draft",
  "phases": { "total": 0, "completed": 0 },
  "tasks": { "total": 0, "completed": 0 }
}
EOF
cat > "$FIXTURE/tracks/legacy/spec.md" <<'EOF'
---
project: scribe
module: root
track_id: legacy
generated_by: draft:new-track
generated_at: "2026-01-01T00:00:00Z"
git:
  branch: main
  commit: abc1234567890
  dirty: false
synced_to_commit: abc1234567890
classification:
  criticality: standard
  data_classification: internal
status: draft
---

# Spec body.
EOF

"$TOOL" "$FIXTURE/tracks/legacy" >/dev/null 2>&1
assert "Migration exited 0" "true"
assert "Backup created" "$([[ -f "$FIXTURE/tracks/legacy/spec.md.bak" ]] && echo true || echo false)"

assert "git: block stripped from spec.md frontmatter" \
    "$(! grep -q '^git:' "$FIXTURE/tracks/legacy/spec.md" && echo true || echo false)"
assert "synced_to_commit stripped from spec.md frontmatter" \
    "$(! grep -q '^synced_to_commit:' "$FIXTURE/tracks/legacy/spec.md" && echo true || echo false)"
assert "classification: block stripped from spec.md frontmatter" \
    "$(! grep -q '^classification:' "$FIXTURE/tracks/legacy/spec.md" && echo true || echo false)"
assert "track_id preserved" \
    "$(grep -q '^track_id:' "$FIXTURE/tracks/legacy/spec.md" && echo true || echo false)"

# --- template_version promoted into metadata.json ---
assert "template_version field added to metadata.json" \
    "$(grep -q '"template_version"' "$FIXTURE/tracks/legacy/metadata.json" && echo true || echo false)"

# --- Idempotency: re-run → no-op ---
output="$("$TOOL" "$FIXTURE/tracks/legacy" 2>&1)"
assert "Re-run idempotent (no-op announced)" \
    "$(echo "$output" | grep -q "already at 2.0" && echo true || echo false)"

# --- --dry-run leaves files alone ---
mkdir -p "$FIXTURE/tracks/legacy2"
cat > "$FIXTURE/tracks/legacy2/metadata.json" <<'EOF'
{ "id": "legacy2" }
EOF
cat > "$FIXTURE/tracks/legacy2/spec.md" <<'EOF'
---
project: x
git:
  branch: main
synced_to_commit: deadbeef
---

# body
EOF
before_md="$(cat "$FIXTURE/tracks/legacy2/spec.md")"
"$TOOL" --dry-run "$FIXTURE/tracks/legacy2" >/dev/null 2>&1
after_md="$(cat "$FIXTURE/tracks/legacy2/spec.md")"
assert "--dry-run preserves spec.md byte-exactly" \
    "$([[ "$before_md" == "$after_md" ]] && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
