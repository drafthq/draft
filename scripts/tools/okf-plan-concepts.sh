#!/usr/bin/env bash
# okf-plan-concepts.sh — derive the DETERMINISTIC expected-concept set for an OKF
# bundle, BEFORE any page is written.
#
# The OKF emitter used to let the LLM enumerate the concept list in-context, so
# under context pressure it silently under-enumerated and modules went
# undocumented — and okf-validate.sh only ever checked the pages that *did* get
# written. This tool makes the boundary of the work a tool output: every package
# / module / component the graph knows about (at or above a fan-in floor), plus
# every entrypoint, becomes a REQUIRED concept the bundle must contain. Pages
# below the floor (or matching an allow-defer glob) are recorded as deferred with
# a reason, never silently dropped.
#
# Discovery priority:
#   1. --manifest FILE  — explicit component list (authoritative; every entry required)
#   2. graph            — graph-arch.sh packages (fan_in) + entry_points
#   3. heuristic        — top-level source dirs (engine unavailable; degraded:true)
#
# Output: concept-plan.json (see schema below). The generation loop iterates
# `generated_order`; okf-coverage-check.sh gates promotion on every required
# `concept_id` existing as a non-stub page.
#
# Usage:
#   okf-plan-concepts.sh --repo DIR [--scope PATH] [--manifest FILE]
#                        [--min-fan-in N] [--allow-defer GLOB]... [--out FILE] [--json]
#
# Exit codes: 0 plan written, 1 invocation error, 2 no expected set could be
#             derived (graph + manifest both unavailable).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/tools/_lib.sh
source "$SCRIPT_DIR/_lib.sh"

REPO="."
SCOPE="."
MANIFEST=""
MIN_FAN_IN=2
OUT=""
JSON=0
ALLOW_DEFER=()

usage() {
    cat <<'EOF'
okf-plan-concepts.sh — derive the deterministic expected-concept set for an OKF bundle.

Usage:
  okf-plan-concepts.sh --repo DIR [--scope PATH] [--manifest FILE]
                       [--min-fan-in N] [--allow-defer GLOB]... [--out FILE] [--json]

Flags:
  --repo DIR         Repository root (default: cwd).
  --scope PATH       Sub-tree for module-scoped init (default: .).
  --manifest FILE    Component list (one component per line; '#' comments; blanks
                     ignored). When present it is authoritative — every entry is
                     required and the graph is not consulted.
  --min-fan-in N     Package fan-in floor for "required" (default: 2). Packages
                     below the floor are deferred with a reason.
  --allow-defer GLOB Defer (don't require) components whose name matches GLOB.
                     Repeatable. Deferred entries still appear in the plan.
  --out FILE         Write the plan JSON here (default: stdout).
  --json             Also echo the plan JSON to stdout when --out is given.
  --help             Show this help.

Exit: 0 plan written, 1 invocation error, 2 no expected set derivable.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) REPO="$2"; shift 2;;
        --scope) SCOPE="$2"; shift 2;;
        --manifest) MANIFEST="$2"; shift 2;;
        --min-fan-in) MIN_FAN_IN="$2"; shift 2;;
        --allow-defer) ALLOW_DEFER+=("$2"); shift 2;;
        --out) OUT="$2"; shift 2;;
        --json) JSON=1; shift;;
        --help|-h) usage; exit 0;;
        -*) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
        *) echo "Unexpected arg: $1" >&2; usage >&2; exit 1;;
    esac
done

[[ -d "$REPO" ]] || { echo "ERROR: --repo '$REPO' is not a directory" >&2; exit 1; }
[[ "$MIN_FAN_IN" =~ ^[0-9]+$ ]] || { echo "ERROR: --min-fan-in must be an integer" >&2; exit 1; }

# Slugify a component name into a bundle-safe filename stem.
slug() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' \
        | sed -E 's/^-+//; s/-+$//; s/-+/-/g'
}

# Does $1 match any --allow-defer glob?
is_deferred_name() {
    local name="$1" g
    for g in "${ALLOW_DEFER[@]:-}"; do
        [[ -z "$g" ]] && continue
        # shellcheck disable=SC2053
        [[ "$name" == $g ]] && return 0
    done
    return 1
}

# Accumulators (parallel arrays describing each expected concept).
E_ID=(); E_TYPE=(); E_RES=(); E_FANIN=(); E_REQ=(); E_REASON=()
SOURCE="heuristic"
DEGRADED="false"

add_concept() {
    # name section type resource fan_in required reason
    local name="$1" section="$2" type="$3" resource="$4" fan_in="$5" required="$6" reason="$7"
    local stem; stem="$(slug "$name")"
    [[ -n "$stem" ]] || stem="component"
    E_ID+=("$section/$stem.md")
    E_TYPE+=("$type")
    E_RES+=("$resource")
    E_FANIN+=("$fan_in")
    E_REQ+=("$required")
    E_REASON+=("$reason")
}

# --- 1. Manifest path (authoritative) ---
plan_from_manifest() {
    local line name
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        name="$(printf '%s' "$line" | sed -E 's/^[[:space:]]*-?[[:space:]]*//; s/[[:space:]]*$//')"
        [[ -z "$name" ]] && continue
        if is_deferred_name "$name"; then
            add_concept "$name" systems Module "$name" 0 false "manifest: allow-defer match"
        else
            add_concept "$name" systems Module "$name" 0 true ""
        fi
    done < "$MANIFEST"
    SOURCE="manifest"
}

# --- 2. Graph path ---
plan_from_graph() {
    local arch; arch="$(scripts_graph_arch)" || return 1
    [[ -n "$arch" ]] || return 1
    echo "$arch" | jq -e '.packages != null' >/dev/null 2>&1 || return 1

    SOURCE="graph"
    local name fan_in type required reason
    # Packages → systems/<pkg>.md
    while IFS=$'\t' read -r name fan_in; do
        [[ -z "$name" ]] && continue
        if is_deferred_name "$name"; then
            required=false; reason="allow-defer match"; type=Module
        elif (( fan_in >= MIN_FAN_IN )); then
            required=true; reason=""; type=Subsystem
        else
            required=false; reason="fan_in $fan_in < floor $MIN_FAN_IN"; type=Module
        fi
        add_concept "$name" systems "$type" "$name" "$fan_in" "$required" "$reason"
    done < <(echo "$arch" | jq -r '.packages[]? | [.name, (.fan_in // 0)] | @tsv')

    # Entry points → entrypoints/<name>.md (always required)
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        if is_deferred_name "$name"; then
            add_concept "$name" entrypoints Entrypoint "$name" 0 false "allow-defer match"
        else
            add_concept "$name" entrypoints Entrypoint "$name" 0 true ""
        fi
    done < <(echo "$arch" | jq -r '
        (.entry_points // [])[]? | if type=="object" then (.name // .path // empty) else . end' \
        | sort -u)
}

# graph-arch.sh wrapper that tolerates the "unavailable" sentinel.
scripts_graph_arch() {
    local out
    out="$("$SCRIPT_DIR/graph-arch.sh" --repo "$REPO" 2>/dev/null || true)"
    [[ -n "$out" ]] || return 1
    echo "$out" | jq -e '.source == "unavailable"' >/dev/null 2>&1 && return 1
    printf '%s' "$out"
}

# --- 3. Heuristic fallback ---
plan_from_heuristic() {
    SOURCE="heuristic"
    DEGRADED="true"
    local scope_dir="$REPO/$SCOPE"
    [[ -d "$scope_dir" ]] || scope_dir="$REPO"
    local d name
    while IFS= read -r d; do
        name="$(basename "$d")"
        case "$name" in
            test|tests|qa|tools|vendor|node_modules|.git|dist|build|target) continue;;
            .*) continue;;
        esac
        # Only dirs that actually contain source-ish files.
        if find "$d" -maxdepth 2 -type f \
            \( -name '*.go' -o -name '*.py' -o -name '*.js' -o -name '*.ts' \
               -o -name '*.rs' -o -name '*.java' -o -name '*.rb' -o -name '*.sh' \
               -o -name '*.c' -o -name '*.cpp' -o -name '*.kt' \) 2>/dev/null \
            | head -1 | grep -q .; then
            if is_deferred_name "$name"; then
                add_concept "$name" systems Module "$name" 0 false "allow-defer match"
            else
                add_concept "$name" systems Module "$name" 0 true ""
            fi
        fi
    done < <(find "$scope_dir" -mindepth 1 -maxdepth 1 -type d | sort)
}

# --- Drive discovery in priority order ---
if [[ -n "$MANIFEST" ]]; then
    [[ -f "$MANIFEST" ]] || { echo "ERROR: --manifest not found: $MANIFEST" >&2; exit 1; }
    plan_from_manifest
elif plan_from_graph; then
    :
else
    plan_from_heuristic
fi

if [[ ${#E_ID[@]} -eq 0 ]]; then
    echo "ERROR: no expected concepts derived (graph + manifest unavailable, heuristic empty)" >&2
    exit 2
fi

# Required-first, then deferred; stable within group (topological-ish: high fan-in
# subsystems first so forward cross-links resolve during generation).
emit_plan() {
    local n=${#E_ID[@]} i
    # Build sortable index lines: <req_rank>\t<fanin_desc>\t<idx>
    local order=()
    for ((i=0; i<n; i++)); do
        local rank=1; [[ "${E_REQ[$i]}" == "true" ]] && rank=0
        order+=("$(printf '%d\t%010d\t%d' "$rank" "$(( 9999999999 - ${E_FANIN[$i]:-0} ))" "$i")")
    done
    local sorted; sorted="$(printf '%s\n' "${order[@]}" | sort)"

    local req=0 def=0
    for ((i=0; i<n; i++)); do
        [[ "${E_REQ[$i]}" == "true" ]] && req=$((req+1)) || def=$((def+1))
    done

    {
        printf '{\n'
        printf '  "version": 1,\n'
        printf '  "repo": "%s",\n' "$(json_escape "$REPO")"
        printf '  "scope": "%s",\n' "$(json_escape "$SCOPE")"
        printf '  "source": "%s",\n' "$SOURCE"
        printf '  "degraded": %s,\n' "$DEGRADED"
        printf '  "min_fan_in": %d,\n' "$MIN_FAN_IN"
        # generated_order
        printf '  "generated_order": ['
        local first=1
        while IFS=$'\t' read -r _ _ idx; do
            [[ -z "$idx" ]] && continue
            [[ $first -eq 1 ]] && first=0 || printf ','
            printf '"%s"' "$(json_escape "${E_ID[$idx]}")"
        done <<< "$sorted"
        printf '],\n'
        # expected[]
        printf '  "expected": [\n'
        first=1
        while IFS=$'\t' read -r _ _ idx; do
            [[ -z "$idx" ]] && continue
            [[ $first -eq 1 ]] && first=0 || printf ',\n'
            local reason_json="null"
            [[ -n "${E_REASON[$idx]}" ]] && reason_json="\"$(json_escape "${E_REASON[$idx]}")\""
            printf '    {"concept_id":"%s","type":"%s","resource":"%s","fan_in":%d,"required":%s,"reason_if_deferred":%s}' \
                "$(json_escape "${E_ID[$idx]}")" \
                "$(json_escape "${E_TYPE[$idx]}")" \
                "$(json_escape "${E_RES[$idx]}")" \
                "${E_FANIN[$idx]:-0}" \
                "${E_REQ[$idx]}" \
                "$reason_json"
        done <<< "$sorted"
        printf '\n  ],\n'
        printf '  "counts": {"expected_total": %d, "required": %d, "deferred": %d}\n' "$n" "$req" "$def"
        printf '}\n'
    }
}

PLAN_JSON="$(emit_plan)"

# Validate our own output parses before writing.
if command -v jq >/dev/null 2>&1; then
    echo "$PLAN_JSON" | jq -e '.expected' >/dev/null 2>&1 \
        || { echo "ERROR: generated plan is not valid JSON (internal error)" >&2; exit 1; }
fi

if [[ -n "$OUT" ]]; then
    mkdir -p "$(dirname "$OUT")"
    printf '%s' "$PLAN_JSON" > "$OUT"
    echo "concept plan → $OUT (source=$SOURCE, $(echo "$PLAN_JSON" | jq -r '.counts.required') required, $(echo "$PLAN_JSON" | jq -r '.counts.deferred') deferred)" >&2
    [[ $JSON -eq 1 ]] && printf '%s' "$PLAN_JSON"
else
    printf '%s' "$PLAN_JSON"
fi
exit 0
