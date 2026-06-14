#!/usr/bin/env bash
# okf-check.sh — validate a directory against the Open Knowledge Format v0.1 spec.
#
# Implements the §9 conformance criteria of OKF v0.1
# (https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md):
#
#   §9.1  Every non-reserved .md file has a parseable YAML frontmatter block.
#   §9.2  Every such frontmatter block has a non-empty `type` field.
#   §9.3  Reserved files follow their structure when present:
#           index.md  (§6)  — contains NO frontmatter, EXCEPT the bundle-root
#                             index.md MAY carry frontmatter holding only
#                             `okf_version` (§11).
#           log.md    (§7)  — `## ` date headings MUST be ISO 8601 (YYYY-MM-DD).
#
# Consumers are required to be permissive, so this checker only enforces the
# three hard rules above; everything else in the spec is soft guidance.
#
# Usage: scripts/tools/okf-check.sh [--dir DIR] [--quiet]
# Exit codes: 0 conformant, 1 violations found, 2 dir missing.
set -euo pipefail

DIR="draft"
QUIET=0

usage() {
    cat <<'EOF'
okf-check.sh — validate a directory against Open Knowledge Format v0.1 (§9).

Usage:
  scripts/tools/okf-check.sh [--dir DIR] [--quiet]

Flags:
  --dir DIR  Bundle root to validate (default: draft).
  --quiet    Print only the summary line, not per-file violations.
  --help     Show this help.

Exit 0 when conformant, 1 when violations are found, 2 when DIR is absent.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir) DIR="$2"; shift 2;;
        --quiet) QUIET=1; shift;;
        --help|-h) usage; exit 0;;
        -*) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
        *) echo "Unexpected arg: $1" >&2; usage >&2; exit 1;;
    esac
done

[[ -d "$DIR" ]] || { echo "ERROR: --dir '$DIR' is not a directory" >&2; exit 2; }
DIR="${DIR%/}"

# fm_scan FILE -> "STATUS|TYPE|KEYS"  (pipe-delimited; '|' is not IFS-whitespace,
# so empty TYPE/KEYS fields survive `read` instead of collapsing).
#   STATUS: nofm (no frontmatter) | ok (closed block) | unterminated
#   TYPE:   value of the top-level `type:` key, if any
#   KEYS:   comma-separated top-level frontmatter keys
fm_scan() {
    awk '
        NR==1 { if ($0 != "---") { print "nofm||"; exit } ; inblock=1; next }
        inblock && /^---[[:space:]]*$/ { print "ok|" type "|" keys; closed=1; exit }
        inblock {
            if (match($0, /^[A-Za-z_][A-Za-z0-9_]*:/)) {
                k = substr($0, 1, RLENGTH-1)
                keys = keys (keys=="" ? "" : ",") k
                if (k == "type") {
                    v = substr($0, RLENGTH+1)
                    gsub(/^[ \t]+|[ \t]+$/, "", v)
                    gsub(/^"|"$/, "", v)
                    type = v
                }
            }
            next
        }
        END { if (inblock && !closed) print "unterminated|" type "|" keys }
    ' "$1"
}

violations=0
concepts=0
reserved=0

report() { # relpath  message
    violations=$((violations + 1))
    [[ "$QUIET" == "1" ]] || echo "FAIL  $1: $2" >&2
}

while IFS= read -r -d '' file; do
    rel="${file#"$DIR"/}"
    base="$(basename "$file")"

    case "$base" in
        index.md)
            reserved=$((reserved + 1))
            IFS='|' read -r status _ keys < <(fm_scan "$file")
            if [[ "$status" != "nofm" ]]; then
                if [[ "$rel" == "index.md" ]]; then
                    # Bundle-root index.md: frontmatter allowed, but only okf_version (§11).
                    IFS=',' read -ra ks <<< "$keys"
                    for k in "${ks[@]}"; do
                        [[ -z "$k" || "$k" == "okf_version" ]] && continue
                        report "$rel" "root index.md frontmatter may only hold 'okf_version' (§11); found '$k'"
                    done
                else
                    report "$rel" "index.md must not contain frontmatter (§6)"
                fi
            fi
            ;;
        log.md)
            reserved=$((reserved + 1))
            while IFS= read -r h; do
                if ! [[ "$h" =~ ^##[[:space:]]+[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
                    report "$rel" "log.md date heading not ISO 8601 (§7): '$h'"
                fi
            done < <(grep -E '^## ' "$file" 2>/dev/null || true)
            ;;
        *)
            concepts=$((concepts + 1))
            IFS='|' read -r status type _ < <(fm_scan "$file")
            case "$status" in
                nofm)         report "$rel" "missing YAML frontmatter block (§9.1)";;
                unterminated) report "$rel" "unterminated frontmatter block — no closing '---' (§9.1)";;
                ok)
                    [[ -n "$type" ]] || report "$rel" "frontmatter missing required non-empty 'type' (§9.2)"
                    ;;
            esac
            ;;
    esac
done < <(find "$DIR" -type f -name '*.md' -print0 | sort -z)

if [[ "$violations" -eq 0 ]]; then
    echo "OKF v0.1 conformant — $concepts concept file(s), $reserved reserved file(s), 0 violations. ($DIR)"
    exit 0
fi
echo "OKF v0.1 NON-CONFORMANT — $violations violation(s) across $concepts concept + $reserved reserved file(s). ($DIR)" >&2
exit 1
