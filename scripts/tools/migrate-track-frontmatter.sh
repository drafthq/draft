#!/usr/bin/env bash
# migrate-track-frontmatter.sh
#
# Idempotent rewriter that migrates a pre-2.0 Draft track to the WS-8
# metadata-as-source-of-truth shape:
#
# - Strips ephemeral fields from per-file YAML frontmatter in spec.md,
# hld.md, lld.md, plan.md: `git.*`, `synced_to_commit`, `classification.*`,
# `status`, `scope_includes`, `scope_excludes`.
# - Promotes them into metadata.json (creating fields if absent; preserving
# existing values).
# - Markdown frontmatter retains only: project, module, track_id,
# generated_by, generated_at, links.
#
# Idempotent: re-running on a 2.0 track produces zero diff.
# Safe: emits <file>.bak alongside each rewritten file unless --no-backup.
#
# Usage:
# scripts/tools/migrate-track-frontmatter.sh tracks/foo
# scripts/tools/migrate-track-frontmatter.sh --dry-run tracks/foo
# scripts/tools/migrate-track-frontmatter.sh --no-backup tracks/foo
#
# Exit codes:
# 0 success or no-op
# 1 migration error
# 2 usage / runtime error

set -euo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "${0##*/} — Foundations quality tool (see core/ docs for full behavior)"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

DRY_RUN=0
BACKUP=1
TRACK_DIRS=()

usage() {
    local stream=2 code=2
    if [[ "${USAGE_HELP_MODE:-0}" == 1 ]]; then stream=1; code=0; fi
    sed -n '2,22p' "$0" >&$stream
    exit "$code"
}

while (($#)); do
    case "$1" in
        -h|--help) USAGE_HELP_MODE=1 usage ;;
        --dry-run) DRY_RUN=1; shift ;;
        --no-backup) BACKUP=0; shift ;;
        -*) printf 'Unknown flag: %s\n' "$1" >&2; usage ;;
        *) TRACK_DIRS+=("$1"); shift ;;
    esac
done

(( ${#TRACK_DIRS[@]} == 0 )) && usage

# Ephemeral keys to strip from per-file YAML frontmatter.
EPHEMERAL_KEYS=(
    "git"
    "synced_to_commit"
    "classification"
    "status"
    "scope_includes"
    "scope_excludes"
)

# Stable keys that survive in markdown frontmatter.
STABLE_KEYS=(
    "project"
    "module"
    "track_id"
    "generated_by"
    "generated_at"
    "links"
)

# Strip ephemeral blocks from a markdown file's YAML frontmatter.
# Approach: read the file; rewrite the frontmatter section so any line whose
# first token (before colon) matches an ephemeral key — plus any indented
# continuation lines — is dropped.
strip_frontmatter() {
    local file="$1"
    awk -v ephemeral_re="^($(IFS='|'; echo "${EPHEMERAL_KEYS[*]}"))(:|[[:space:]])" '
        BEGIN { state = "before"; skip = 0 }
        state == "before" {
            print
            if ($0 == "---") state = "in_fm"
            next
        }
        state == "in_fm" {
            if ($0 == "---") { state = "after"; print; skip = 0; next }
            # Detect a top-level ephemeral key: starts at column 1.
            if ($0 ~ ephemeral_re && $0 !~ /^[[:space:]]/) {
                skip = 1
                next
            }
            # Indented continuation lines belong to the previous block.
            if (skip == 1 && $0 ~ /^[[:space:]]/) { next }
            # Non-indented line — end of any previous ephemeral block.
            skip = 0
            print
            next
        }
        state == "after" { print }
    ' "$file"
}

# Promote a JSON field into metadata.json at the top level if it does not
# already exist. Prefers Python for robust JSON manipulation; falls back to
# awk for environments without Python.
#
# The awk fallback inserts before the FIRST line that is a bare "}" with no
# leading whitespace, which is the outer object's close. The previous
# implementation matched any "}" line and risked inserting fields into
# nested objects (e.g. inside `impact`).
ensure_meta_field() {
    local meta="$1" key="$2" default_value="$3"
    if grep -Eq "^[[:space:]]*\"$key\"[[:space:]]*:" "$meta"; then
        return 0
    fi
    if command -v python3 >/dev/null 2>&1; then
        python3 - "$meta" "$key" "$default_value" <<'PY'
import json, sys, ast, tempfile, os
path, key, raw = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    data = json.load(f)
if key in data:
    sys.exit(0)
# Parse the default value: try JSON first (handles [], {}, true, numbers,
# quoted strings); fall back to literal string on failure.
try:
    value = json.loads(raw)
except Exception:
    value = raw.strip('"')
data[key] = value
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path) or ".")
with os.fdopen(fd, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
os.replace(tmp, path)
PY
    else
        # awk fallback: insert before the LAST line that is a closing `}` at
        # column 1. That is the outer object's closing brace.
        awk -v key="$key" -v val="$default_value" '
            { lines[NR] = $0 }
            END {
                # Find last bare-} line.
                last_brace = 0
                for (i = NR; i > 0; i--) {
                    if (lines[i] == "}") { last_brace = i; break }
                }
                for (i = 1; i <= NR; i++) {
                    if (i == last_brace) {
                        # Inject before the close.
                        # Ensure previous content line ends with a comma.
                        if (i > 1) {
                            prev = lines[i - 1]
                            sub(/[[:space:]]*$/, "", prev)
                            if (prev !~ /[,{[]$/) prev = prev ","
                            lines[i - 1] = prev
                        }
                        print " \"" key "\": " val
                    }
                    print lines[i]
                }
            }
        ' "$meta" > "${meta}.tmp" && mv "${meta}.tmp" "$meta"
    fi
}

migrate_one_track() {
    local track_dir="$1"
    if [[ ! -d "$track_dir" ]]; then
        printf 'migrate: not a directory: %s\n' "$track_dir" >&2
        return 1
    fi
    track_dir="$(cd "$track_dir" && pwd)"

    local meta="$track_dir/metadata.json"
    if [[ ! -f "$meta" ]]; then
        printf 'migrate: %s has no metadata.json — creating minimal\n' "$track_dir" >&2
        if (( ! DRY_RUN )); then
            cat > "$meta" <<EOF
{
  "id": "$(basename "$track_dir")",
  "title": "_TBD_title_",
  "type": "feature",
  "status": "draft",
  "template_version": "2.0.0",
  "created": "_TBD_created_",
  "updated": "_TBD_updated_",
  "scope_includes": [],
  "scope_excludes": [],
  "phases": { "total": 0, "completed": 0 },
  "tasks": { "total": 0, "completed": 0 }
}
EOF
        fi
    fi

    if (( ! DRY_RUN )); then
        ensure_meta_field "$meta" "template_version" '"2.0.0"'
        ensure_meta_field "$meta" "scope_includes" '[]'
        ensure_meta_field "$meta" "scope_excludes" '[]'
        ensure_meta_field "$meta" "pre_deploy_status" '"unrun"'
    fi

    local changed=0
    for f in spec.md hld.md lld.md plan.md discovery.md; do
        local path="$track_dir/$f"
        [[ -f "$path" ]] || continue
        local before; before="$(cat "$path")"
        local after; after="$(strip_frontmatter "$path")"
        if [[ "$before" != "$after" ]]; then
            changed=1
            if (( DRY_RUN )); then
                printf 'migrate: would strip ephemeral frontmatter from %s\n' "$path"
            else
                (( BACKUP )) && cp "$path" "$path.bak"
                local _tmp; _tmp="$(mktemp "${path}.XXXXXX")"; printf '%s' "$after" > "$_tmp" && mv -f "$_tmp" "$path"
                printf 'migrate: stripped ephemeral frontmatter from %s\n' "$path"
            fi
        fi
    done

    if (( changed == 0 )); then
        printf 'migrate: %s already at 2.0 — no-op\n' "$track_dir"
    fi
}

rc=0
for t in "${TRACK_DIRS[@]}"; do
    migrate_one_track "$t" || rc=$?
done
exit "$rc"
