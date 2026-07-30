#!/usr/bin/env bash
# check-repo-size.sh
#
# Guards the size of the tree at HEAD.
#
# `claude plugin marketplace add <owner>/<repo>` git-clones this repository, so
# every byte tracked at HEAD is downloaded before the plugin can be installed.
# In v2.8.3 ~670 MB of audiobook .m4a files in HEAD stalled that first install
# step with no error message — an install-breaking regression that no test
# caught. This is that test.
#
# The threshold is deliberately loose (default 10 MB against a ~6 MB HEAD): it
# exists to catch binary assets landing in HEAD, not to police prose growth.
#
# Usage:
#   scripts/tools/check-repo-size.sh                 # default cap, human output
#   scripts/tools/check-repo-size.sh --max-mb 5      # custom cap
#   scripts/tools/check-repo-size.sh --json          # machine-readable
#   scripts/tools/check-repo-size.sh --rev v3.6.0    # audit a past revision
#
# Exit codes:
#   0  tree at HEAD is within the cap
#   1  cap exceeded
#   2  usage / runtime error

set -euo pipefail

usage() {
    cat <<'EOF'
check-repo-size.sh — fail if the tree at HEAD exceeds a size cap

Options:
  --max-mb <n>   Cap in megabytes (default: 10)
  --rev <rev>    Revision to measure (default: HEAD)
  --repo <path>  Repository root (default: this repo)
  --top <n>      Largest blobs to list (default: 10)
  --json         Emit JSON instead of human-readable output
  --help, -h     Show this message
EOF
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    usage
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

MAX_MB=10
REV="HEAD"
TOP=10
EMIT_JSON=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --max-mb)
            [[ -n "${2:-}" ]] || { echo "check-repo-size: --max-mb requires a value" >&2; exit 2; }
            MAX_MB="$2"; shift 2 ;;
        --rev)
            [[ -n "${2:-}" ]] || { echo "check-repo-size: --rev requires a value" >&2; exit 2; }
            REV="$2"; shift 2 ;;
        --repo)
            [[ -n "${2:-}" ]] || { echo "check-repo-size: --repo requires a value" >&2; exit 2; }
            REPO_ROOT="$2"; shift 2 ;;
        --top)
            [[ -n "${2:-}" ]] || { echo "check-repo-size: --top requires a value" >&2; exit 2; }
            TOP="$2"; shift 2 ;;
        --json) EMIT_JSON=1; shift ;;
        --help|-h) usage; exit 0 ;;
        *) echo "check-repo-size: unknown argument '$1'" >&2; usage >&2; exit 2 ;;
    esac
done

[[ "$MAX_MB" =~ ^[0-9]+$ ]] || { echo "check-repo-size: --max-mb must be an integer, got '$MAX_MB'" >&2; exit 2; }
[[ "$TOP" =~ ^[0-9]+$ ]]    || { echo "check-repo-size: --top must be an integer, got '$TOP'" >&2; exit 2; }
[[ -d "$REPO_ROOT" ]]       || { echo "check-repo-size: no such directory: $REPO_ROOT" >&2; exit 2; }

cd "$REPO_ROOT"
git rev-parse --git-dir >/dev/null 2>&1 || { echo "check-repo-size: $REPO_ROOT is not a git repository" >&2; exit 2; }
git rev-parse --verify --quiet "$REV" >/dev/null || { echo "check-repo-size: unknown revision '$REV'" >&2; exit 2; }

# `ls-tree -l` gives per-blob sizes; symlinks/submodules report '-' and are skipped.
listing="$(git ls-tree -r -l "$REV")"

total_bytes=0
file_count=0
while read -r _mode _type _sha size _path; do
    [[ "$size" =~ ^[0-9]+$ ]] || continue
    total_bytes=$((total_bytes + size))
    file_count=$((file_count + 1))
done <<< "$listing"

max_bytes=$((MAX_MB * 1024 * 1024))
status="ok"
[[ "$total_bytes" -gt "$max_bytes" ]] && status="over"

total_mb="$(awk -v b="$total_bytes" 'BEGIN { printf "%.2f", b / 1048576 }')"

if [[ "$EMIT_JSON" -eq 1 ]]; then
    printf '{"rev":"%s","status":"%s","total_bytes":%d,"total_mb":%s,"max_mb":%d,"files":%d}\n' \
        "$REV" "$status" "$total_bytes" "$total_mb" "$MAX_MB" "$file_count"
else
    echo "Tree at $REV: ${total_mb} MB across $file_count files (cap: ${MAX_MB} MB)"
    if [[ "$status" == "over" ]]; then
        echo ""
        echo "Largest tracked blobs:"
        # Materialize the sorted list before slicing it. Piping straight into
        # `head` lets head close the pipe early, which under `pipefail` surfaces
        # sort's SIGPIPE as a hard failure — non-deterministically, depending on
        # whether the output fit in the pipe buffer.
        largest="$(awk '$4 ~ /^[0-9]+$/ { printf "  %8.2f MB  %s\n", $4 / 1048576, $5 }' <<< "$listing" | sort -rn)"
        head -n "$TOP" <<< "$largest"
    fi
fi

if [[ "$status" == "over" ]]; then
    echo "" >&2
    echo "FAIL: HEAD exceeds ${MAX_MB} MB. 'plugin marketplace add' clones this tree —" >&2
    echo "      oversized blobs stall install with no error. Ship large assets as" >&2
    echo "      GitHub Release attachments instead of committing them." >&2
    exit 1
fi

exit 0
