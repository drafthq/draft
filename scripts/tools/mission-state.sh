#!/usr/bin/env bash
# mission-state.sh
#
# External brain for an autonomous Draft mission. Persists the loop's position
# to <repo>/draft/.state/mission.json so a run survives context compaction,
# session loss, or a crash mid-phase.
#
# Every write is atomic (temp file -> JSON validation -> .bak -> rename), so a
# crash never leaves a truncated state file — the exact corruption a resume
# would then be unable to recover from.
#
# Usage:
# scripts/tools/mission-state.sh init --source jira:ENG-4412 [--force]
# scripts/tools/mission-state.sh get phase
# scripts/tools/mission-state.sh set phase=build phase_status=in_progress
# scripts/tools/mission-state.sh validate
# scripts/tools/mission-state.sh show [--json]
#
# Common flags: --repo <path> (default .)
#
# Exit codes:
# 0 ok
# 1 schema violation / missing state
# 2 usage / runtime error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

usage() {
    local stream=2 code=2
    if [[ "${USAGE_HELP_MODE:-0}" == 1 ]]; then stream=1; code=0; fi
    sed -n '2,24p' "$0" >&$stream
    exit "$code"
}

command -v jq >/dev/null 2>&1 || { echo "mission-state.sh requires jq" >&2; exit 2; }

REPO="."
FORCE=0
SOURCE=""
MISSION_ID=""
EMIT_JSON=0
CMD=""
ARGS=()

while (($#)); do
    case "$1" in
        -h|--help) USAGE_HELP_MODE=1 usage ;;
        --repo) REPO="${2:-}"; shift 2 ;;
        --source) SOURCE="${2:-}"; shift 2 ;;
        --mission-id) MISSION_ID="${2:-}"; shift 2 ;;
        --force) FORCE=1; shift ;;
        --json) EMIT_JSON=1; shift ;;
        -*) printf 'Unknown flag: %s\n' "$1" >&2; usage ;;
        *)
            if [[ -z "$CMD" ]]; then CMD="$1"; else ARGS+=("$1"); fi
            shift
            ;;
    esac
done

[[ -n "$CMD" ]] || usage
[[ -d "$REPO" ]] || { echo "No such repo: $REPO" >&2; exit 2; }

STATE_DIR="$REPO/draft/.state"
STATE_FILE="$STATE_DIR/mission.json"

# Canonical field set. An unknown top-level key is a schema violation: a typo'd
# field is silently lost otherwise, and the loop then reads a default forever.
FIELDS=(
    schema_version mission_id source phase phase_status tracks current_track
    next_task last_commit recovery_attempts dispatch_budget started_at
    updated_at handoff_notes
)
PHASES=(intake decompose contract build validate recover ship "done")
PHASE_STATUSES=(pending in_progress complete blocked)
INT_FIELDS=(recovery_attempts dispatch_budget)
ARRAY_FIELDS=(tracks)

contains() {
    local needle="$1"; shift
    local item
    for item in "$@"; do [[ "$item" == "$needle" ]] && return 0; done
    return 1
}

now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }

head_commit() {
    git -C "$REPO" rev-parse HEAD 2>/dev/null || echo ""
}

require_state() {
    [[ -f "$STATE_FILE" ]] || { echo "No mission state at $STATE_FILE (run: mission-state.sh init)" >&2; exit 1; }
}

# Atomic write: validate the candidate as JSON before it can replace a good file.
write_state() {
    local payload="$1" tmp
    mkdir -p "$STATE_DIR"
    tmp="$(mktemp "$STATE_DIR/.mission.XXXXXX")"
    printf '%s\n' "$payload" >"$tmp"
    if ! jq empty "$tmp" 2>/dev/null; then
        rm -f "$tmp"
        echo "Refusing to write malformed mission state" >&2
        exit 2
    fi
    [[ -f "$STATE_FILE" ]] && cp "$STATE_FILE" "$STATE_FILE.bak"
    apply_dest_mode "$tmp" "$STATE_FILE"
    mv "$tmp" "$STATE_FILE"
}

cmd_init() {
    if [[ -f "$STATE_FILE" && "$FORCE" != 1 ]]; then
        echo "Mission state already exists at $STATE_FILE (use --force to reset)" >&2
        exit 1
    fi
    [[ -n "$SOURCE" ]] || { echo "init requires --source (e.g. jira:ENG-4412)" >&2; exit 2; }
    [[ -n "$MISSION_ID" ]] || MISSION_ID="$(printf '%s' "$SOURCE" | tr -c 'A-Za-z0-9' '-' | tr -s '-' | sed 's/^-//;s/-$//')"
    local ts; ts="$(now_iso)"
    write_state "$(jq -n \
        --arg mission_id "$MISSION_ID" \
        --arg source "$SOURCE" \
        --arg started_at "$ts" \
        --arg updated_at "$ts" \
        --arg last_commit "$(head_commit)" \
        '{
            schema_version: "1.0.0",
            mission_id: $mission_id,
            source: $source,
            phase: "intake",
            phase_status: "pending",
            tracks: [],
            current_track: "",
            next_task: "",
            last_commit: $last_commit,
            recovery_attempts: 0,
            dispatch_budget: 3,
            started_at: $started_at,
            updated_at: $updated_at,
            handoff_notes: { done: [], next: [], blocked: [] }
        }')"
    echo "Initialized mission $MISSION_ID at $STATE_FILE"
}

cmd_get() {
    require_state
    local path="${ARGS[0]:-}"
    [[ -n "$path" ]] || { echo "get requires a field" >&2; exit 2; }
    jq -r --arg p "$path" 'getpath($p | split(".")) | if type == "array" then join(",") elif . == null then "" else . end' "$STATE_FILE"
}

cmd_set() {
    require_state
    ((${#ARGS[@]})) || { echo "set requires at least one field=value" >&2; exit 2; }
    local payload; payload="$(cat "$STATE_FILE")"
    local pair field value
    for pair in "${ARGS[@]}"; do
        [[ "$pair" == *=* ]] || { echo "Not a field=value pair: $pair" >&2; exit 2; }
        field="${pair%%=*}"
        value="${pair#*=}"
        contains "$field" "${FIELDS[@]}" || { echo "Unknown field: $field" >&2; exit 1; }
        case "$field" in
            phase)
                contains "$value" "${PHASES[@]}" || { echo "Invalid phase: $value (want: ${PHASES[*]})" >&2; exit 1; } ;;
            phase_status)
                contains "$value" "${PHASE_STATUSES[@]}" || { echo "Invalid phase_status: $value (want: ${PHASE_STATUSES[*]})" >&2; exit 1; } ;;
            handoff_notes|schema_version)
                echo "Field is not settable via set: $field" >&2; exit 2 ;;
        esac
        if contains "$field" "${INT_FIELDS[@]}"; then
            [[ "$value" =~ ^[0-9]+$ ]] || { echo "$field must be a non-negative integer, got: $value" >&2; exit 1; }
            payload="$(printf '%s' "$payload" | jq --arg f "$field" --argjson v "$value" '.[$f] = $v')"
        elif contains "$field" "${ARRAY_FIELDS[@]}"; then
            payload="$(printf '%s' "$payload" | jq --arg f "$field" --arg v "$value" \
                '.[$f] = ($v | if . == "" then [] else split(",") end)')"
        else
            payload="$(printf '%s' "$payload" | jq --arg f "$field" --arg v "$value" '.[$f] = $v')"
        fi
    done
    payload="$(printf '%s' "$payload" | jq \
        --arg ts "$(now_iso)" --arg c "$(head_commit)" \
        '.updated_at = $ts | .last_commit = $c')"
    write_state "$payload"
}

cmd_validate() {
    require_state
    local violations=0
    if ! jq empty "$STATE_FILE" 2>/dev/null; then
        echo "[malformed] $STATE_FILE is not valid JSON"
        exit 1
    fi
    local key
    while IFS= read -r key; do
        if ! contains "$key" "${FIELDS[@]}"; then
            echo "[unknown-field] $key"
            violations=$((violations + 1))
        fi
    done < <(jq -r 'keys[]' "$STATE_FILE")
    for key in "${FIELDS[@]}"; do
        if [[ "$(jq -r --arg k "$key" 'has($k)' "$STATE_FILE")" != "true" ]]; then
            echo "[missing-field] $key"
            violations=$((violations + 1))
        fi
    done
    local phase phase_status
    phase="$(jq -r '.phase // ""' "$STATE_FILE")"
    phase_status="$(jq -r '.phase_status // ""' "$STATE_FILE")"
    contains "$phase" "${PHASES[@]}" || { echo "[invalid-phase] $phase"; violations=$((violations + 1)); }
    contains "$phase_status" "${PHASE_STATUSES[@]}" || { echo "[invalid-phase-status] $phase_status"; violations=$((violations + 1)); }
    for key in "${INT_FIELDS[@]}"; do
        if [[ "$(jq -r --arg k "$key" '.[$k] | type' "$STATE_FILE")" != "number" ]]; then
            echo "[not-a-number] $key"
            violations=$((violations + 1))
        fi
    done
    if [[ "$(jq -r '.tracks | type' "$STATE_FILE")" != "array" ]]; then
        echo "[not-an-array] tracks"
        violations=$((violations + 1))
    fi
    local note
    for note in "done" next blocked; do
        if [[ "$(jq -r --arg n "$note" '.handoff_notes[$n] | type' "$STATE_FILE")" != "array" ]]; then
            echo "[not-an-array] handoff_notes.$note"
            violations=$((violations + 1))
        fi
    done
    if ((violations > 0)); then
        echo "mission state INVALID ($violations violation(s))"
        exit 1
    fi
    echo "mission state valid: $(jq -r '.mission_id' "$STATE_FILE") phase=$phase/$phase_status"
}

cmd_show() {
    require_state
    if ((EMIT_JSON)); then
        cat "$STATE_FILE"
    else
        jq -r '"mission:   \(.mission_id)",
               "source:    \(.source)",
               "phase:     \(.phase)/\(.phase_status)",
               "tracks:    \(.tracks | join(", "))",
               "current:   \(.current_track)",
               "next_task: \(.next_task)",
               "recovery:  \(.recovery_attempts)/\(.dispatch_budget)",
               "commit:    \(.last_commit)"' "$STATE_FILE"
    fi
}

case "$CMD" in
    init) cmd_init ;;
    get) cmd_get ;;
    set) cmd_set ;;
    validate) cmd_validate ;;
    show) cmd_show ;;
    *) printf 'Unknown command: %s\n' "$CMD" >&2; usage ;;
esac
