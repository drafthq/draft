#!/usr/bin/env bash
# record-evidence.sh
#
# Runs a verification command and records corroborating evidence that it ran.
# An autonomous loop cannot be trusted to report its own green: a status field
# the agent writes about itself proves nothing. This captures the command, its
# full output, its real exit code, and the commit it ran against, so a gate can
# check the claim instead of believing it.
#
# Evidence lands under <repo>/draft/.state/evidence/:
# <phase>-<label>-<timestamp>.log full combined output
# index.jsonl one JSON record per run, newest last
#
# The recorded commit is HEAD at run time. Evidence therefore goes stale the
# moment new work lands — which is the point: a green from three commits ago
# cannot be carried forward.
#
# Usage:
# scripts/tools/record-evidence.sh --phase build --label tests -- npm test
# scripts/tools/record-evidence.sh --latest --phase build --label tests
#
# Common flags: --repo <path> (default .)
#
# Exit codes:
# run mode the wrapped command's exit code
# --latest 0 record found (printed as JSON), 1 none
# 2 usage / runtime error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

usage() {
    local stream=2 code=2
    if [[ "${USAGE_HELP_MODE:-0}" == 1 ]]; then stream=1; code=0; fi
    sed -n '2,27p' "$0" >&$stream
    exit "$code"
}

command -v jq >/dev/null 2>&1 || { echo "record-evidence.sh requires jq" >&2; exit 2; }

REPO="."
PHASE=""
LABEL=""
QUERY=0
CMD=()

while (($#)); do
    case "$1" in
        -h|--help) USAGE_HELP_MODE=1 usage ;;
        --repo) REPO="${2:-}"; shift 2 ;;
        --phase) PHASE="${2:-}"; shift 2 ;;
        --label) LABEL="${2:-}"; shift 2 ;;
        --latest) QUERY=1; shift ;;
        --) shift; CMD=("$@"); break ;;
        -*) printf 'Unknown flag: %s\n' "$1" >&2; usage ;;
        *) printf 'Unexpected argument: %s\n' "$1" >&2; usage ;;
    esac
done

[[ -n "$PHASE" ]] || { echo "--phase is required" >&2; exit 2; }
[[ -n "$LABEL" ]] || { echo "--label is required" >&2; exit 2; }
[[ -d "$REPO" ]] || { echo "No such repo: $REPO" >&2; exit 2; }

EVIDENCE_DIR="$REPO/draft/.state/evidence"
INDEX="$EVIDENCE_DIR/index.jsonl"

if ((QUERY)); then
    [[ -f "$INDEX" ]] || exit 1
    record="$(jq -c -s --arg p "$PHASE" --arg l "$LABEL" \
        'map(select(.phase == $p and .label == $l)) | last // empty' "$INDEX")"
    [[ -n "$record" ]] || exit 1
    printf '%s\n' "$record"
    exit 0
fi

((${#CMD[@]})) || { echo "No command given (use -- <command>)" >&2; exit 2; }

mkdir -p "$EVIDENCE_DIR"
ts="$(date -u +%Y%m%dT%H%M%SZ)"
log_rel="evidence/$PHASE-$LABEL-$ts.log"
log_path="$REPO/draft/.state/$log_rel"

# Capture the wrapped command's own exit code, not tee's.
set +e
"${CMD[@]}" 2>&1 | tee "$log_path"
exit_code="${PIPESTATUS[0]}"
set -e

jq -c -n \
    --arg phase "$PHASE" \
    --arg label "$LABEL" \
    --arg command "${CMD[*]}" \
    --arg log "$log_rel" \
    --argjson exit_code "$exit_code" \
    --arg commit "$(git -C "$REPO" rev-parse HEAD 2>/dev/null || echo "")" \
    --arg recorded_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{phase: $phase, label: $label, command: $command, log: $log,
      exit_code: $exit_code, commit: $commit, recorded_at: $recorded_at}' >>"$INDEX"

exit "$exit_code"
