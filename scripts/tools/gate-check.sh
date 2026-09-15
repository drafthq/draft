#!/usr/bin/env bash
# gate-check.sh
#
# Deterministic phase gate for autonomous Draft runs. Exits non-zero when a
# phase transition is not earned, so the loop cannot advance on an unverified
# claim — the agent's own report is never an input here.
#
# Phases:
# build mission state valid + fresh, passing evidence for every
# required label (default: tests)
# ship everything in build + track hygiene clean for every track
# named in the mission state
#
# Evidence is "fresh" only when it was recorded against the current HEAD. A
# green captured before the last commit does not clear the gate.
#
# Usage:
# scripts/tools/gate-check.sh --phase build
# scripts/tools/gate-check.sh --phase build --require tests --require lint
# scripts/tools/gate-check.sh --phase ship --json
#
# Common flags: --repo <path> (default .)
#
# Exit codes:
# 0 gate passed
# 1 gate failed
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

command -v jq >/dev/null 2>&1 || { echo "gate-check.sh requires jq" >&2; exit 2; }

REPO="."
PHASE=""
EMIT_JSON=0
REQUIRED=()

while (($#)); do
    case "$1" in
        -h|--help) USAGE_HELP_MODE=1 usage ;;
        --repo) REPO="${2:-}"; shift 2 ;;
        --phase) PHASE="${2:-}"; shift 2 ;;
        --require) REQUIRED+=("${2:-}"); shift 2 ;;
        --json) EMIT_JSON=1; shift ;;
        -*) printf 'Unknown flag: %s\n' "$1" >&2; usage ;;
        *) printf 'Unexpected argument: %s\n' "$1" >&2; usage ;;
    esac
done

case "$PHASE" in
    build|ship) ;;
    "") echo "--phase is required (build|ship)" >&2; exit 2 ;;
    *) echo "Unknown phase: $PHASE (want: build|ship)" >&2; exit 2 ;;
esac
[[ -d "$REPO" ]] || { echo "No such repo: $REPO" >&2; exit 2; }

((${#REQUIRED[@]})) || REQUIRED=(tests)

STATE_FILE="$REPO/draft/.state/mission.json"
FAILURES=0
ROWS=()

record() {
    local name="$1" passed="$2" detail="$3"
    ((passed)) || FAILURES=$((FAILURES + 1))
    if ((EMIT_JSON)); then
        ROWS+=("$(jq -c -n --arg n "$name" --argjson p "$passed" --arg d "$detail" \
            '{check: $n, passed: ($p == 1), detail: $d}')")
    else
        printf '[%s] %s — %s\n' "$( ((passed)) && echo PASS || echo FAIL )" "$name" "$detail"
    fi
}

head_commit="$(git -C "$REPO" rev-parse HEAD 2>/dev/null || echo "")"

# --- 1. Mission state is present and schema-valid ---
state_ok=0
if [[ ! -f "$STATE_FILE" ]]; then
    record "mission-state" 0 "no mission state at $STATE_FILE"
elif ! out="$("$SCRIPT_DIR/mission-state.sh" --repo "$REPO" validate 2>&1)"; then
    record "mission-state" 0 "$(printf '%s' "$out" | tr '\n' ';')"
else
    state_ok=1
    record "mission-state" 1 "$out"
fi

# --- 2. Every required label has fresh, passing evidence ---
for label in "${REQUIRED[@]}"; do
    if ! rec="$("$SCRIPT_DIR/record-evidence.sh" --repo "$REPO" --latest --phase "$PHASE" --label "$label" 2>/dev/null)"; then
        record "evidence:$label" 0 "no evidence recorded for phase=$PHASE label=$label"
        continue
    fi
    exit_code="$(printf '%s' "$rec" | jq -r '.exit_code')"
    commit="$(printf '%s' "$rec" | jq -r '.commit')"
    log="$(printf '%s' "$rec" | jq -r '.log')"
    cmd="$(printf '%s' "$rec" | jq -r '.command')"
    if [[ ! -f "$REPO/draft/.state/$log" ]]; then
        record "evidence:$label" 0 "record references $log but the log is missing — claim cannot be corroborated"
    elif [[ "$exit_code" != "0" ]]; then
        record "evidence:$label" 0 "\`$cmd\` exited $exit_code (see draft/.state/$log)"
    elif [[ -n "$head_commit" && "$commit" != "$head_commit" ]]; then
        record "evidence:$label" 0 "recorded at ${commit:0:7}, HEAD is ${head_commit:0:7} — stale, re-run"
    else
        record "evidence:$label" 1 "\`$cmd\` passed at ${commit:0:7} (draft/.state/$log)"
    fi
done

# --- 3. Ship only: track hygiene is clean for every track in the mission ---
if [[ "$PHASE" == "ship" ]]; then
    if ((state_ok)); then
        mapfile -t tracks < <(jq -r '.tracks[]?' "$STATE_FILE")
        if ((${#tracks[@]} == 0)); then
            record "track-hygiene" 0 "mission names no tracks — nothing to ship"
        else
            for track in "${tracks[@]}"; do
                track_dir="$REPO/draft/tracks/$track"
                if [[ ! -d "$track_dir" ]]; then
                    record "track-hygiene:$track" 0 "no such track directory: $track_dir"
                elif out="$("$SCRIPT_DIR/check-track-hygiene.sh" "$track_dir" 2>&1)"; then
                    record "track-hygiene:$track" 1 "hygiene clean"
                else
                    record "track-hygiene:$track" 0 "$(printf '%s' "$out" | grep -c '^\[' || true) violation(s) — run check-track-hygiene.sh $track_dir"
                fi
            done
        fi
    else
        record "track-hygiene" 0 "skipped — mission state is invalid"
    fi
fi

if ((EMIT_JSON)); then
    printf '%s\n' "${ROWS[@]}" | jq -s --arg phase "$PHASE" --argjson failures "$FAILURES" \
        '{phase: $phase, passed: ($failures == 0), failures: $failures, checks: .}'
else
    if ((FAILURES == 0)); then
        printf 'GATE %s: PASS\n' "$PHASE"
    else
        printf 'GATE %s: FAIL (%d check(s) failed)\n' "$PHASE" "$FAILURES"
    fi
fi

((FAILURES == 0)) || exit 1
