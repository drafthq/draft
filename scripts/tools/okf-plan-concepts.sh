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
DEFER_BELOW_FLOOR=0
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
  --min-fan-in N     Fan-in threshold that types a package as a Subsystem (>=N)
                     vs a Module (<N) and orders it first (default: 2). By default
                     EVERY graph package is required regardless of fan-in — the
                     floor no longer exempts anything.
  --defer-below-floor  Restore the old behavior: packages with fan_in < --min-fan-in
                     are deferred (not required) instead of required-as-Module.
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
        --repo) REPO="${2:?--repo requires a value}"; shift 2;;
        --scope) SCOPE="${2:?--scope requires a value}"; shift 2;;
        --manifest) MANIFEST="${2:?--manifest requires a value}"; shift 2;;
        --min-fan-in) MIN_FAN_IN="${2:?--min-fan-in requires a value}"; shift 2;;
        --defer-below-floor) DEFER_BELOW_FLOOR=1; shift;;
        --allow-defer) ALLOW_DEFER+=("$2"); shift 2;;
        --out) OUT="${2:?--out requires a value}"; shift 2;;
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
DISCOVERY_META=()   # e.g. cargo, npm, go, graph, heuristic

# Graph package names that are almost always tokenizer/type noise, not modules.
is_noise_package_name() {
    local n="$1"
    case "$n" in
        str|list|dict|int|bool|float|string|type|mod|Cargo|cargo|profile|int64|uint|byte|char|void|null|None|true|false|i32|i64|u32|u64|f32|f64|Option|Result|Error|Self|self)
            return 0;;
    esac
    return 1
}

# True if concept_id already recorded.
has_concept_id() {
    local want="$1" id
    for id in "${E_ID[@]:-}"; do
        [[ "$id" == "$want" ]] && return 0
    done
    return 1
}

add_concept() {
    # name section type resource fan_in required reason
    local name="$1" section="$2" type="$3" resource="$4" fan_in="$5" required="$6" reason="$7"
    local stem; stem="$(slug "$name")"
    [[ -n "$stem" ]] || stem="component"
    local cid="$section/$stem.md"
    # Dedupe by concept_id (cargo + graph may both see the same crate).
    if has_concept_id "$cid"; then
        return 0
    fi
    E_ID+=("$cid")
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

# --- 2a. Language-aware workspace inventories (Cargo / npm / Go) ---
# These produce crate/package-level concepts that graph .packages often collapse
# or mis-label (especially Rust monorepos). Prefer path-grounded resources.

plan_from_cargo_workspace() {
    local cargo="$REPO/Cargo.toml"
    [[ -f "$cargo" ]] || return 1
    # Only treat as workspace if [workspace] present with members.
    grep -qE '^\[workspace\]' "$cargo" || return 1
    grep -qE 'members\s*=' "$cargo" || return 1

    local members=()
    # Extract quoted paths inside the members = [ ... ] array (possibly multi-line).
    local in_members=0 line m
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ members[[:space:]]*=[[:space:]]*\[ ]]; then
            in_members=1
        fi
        if [[ $in_members -eq 1 ]]; then
            while [[ "$line" =~ \"([^\"]+)\" ]]; do
                m="${BASH_REMATCH[1]}"
                members+=("$m")
                line="${line#*\"$m\"}"
            done
            [[ "$line" == *"]"* ]] && in_members=0
        fi
    done < "$cargo"

    [[ ${#members[@]} -gt 0 ]] || return 1

    local path name ct required reason type
    local added=0
    for path in "${members[@]}"; do
        [[ -z "$path" ]] && continue
        # Skip globs we can't expand cheaply without bash nullglob walk
        if [[ "$path" == *"*"* ]]; then
            local base="${path%%/\*}"
            [[ -d "$REPO/$base" ]] || continue
            while IFS= read -r ct; do
                name="$(basename "$(dirname "$ct")")"
                [[ -z "$name" ]] && continue
                if is_deferred_name "$name"; then
                    required=false; reason="allow-defer match"
                else
                    required=true; reason=""
                fi
                type=Module
                # Entrypoint packaging root if only main.rs and no lib.rs (heuristic)
                if [[ -f "$(dirname "$ct")/src/main.rs" && ! -f "$(dirname "$ct")/src/lib.rs" ]]; then
                    type=Module
                fi
                add_concept "$name" systems "$type" "$(dirname "$ct" | sed "s|^$REPO/||")" 0 "$required" "$reason"
                added=$((added+1))
            done < <(find "$REPO/$base" -mindepth 1 -maxdepth 3 -type f -name 'Cargo.toml' 2>/dev/null | sort)
            continue
        fi
        [[ -f "$REPO/$path/Cargo.toml" || -f "$REPO/$path" ]] || continue
        local res="$path"
        [[ -f "$REPO/$path" && "$path" == */Cargo.toml ]] && res="$(dirname "$path")"
        name="$(basename "$res")"
        if is_deferred_name "$name"; then
            required=false; reason="allow-defer match"
        else
            required=true; reason=""
        fi
        add_concept "$name" systems Module "$res" 0 "$required" "$reason"
        added=$((added+1))
    done
    [[ $added -gt 0 ]] || return 1
    DISCOVERY_META+=("cargo")
    return 0
}

plan_from_npm_workspaces() {
    local pkg="$REPO/package.json"
    [[ -f "$pkg" ]] || return 1
    command -v jq >/dev/null 2>&1 || return 1
    # workspaces may be array or { packages: [] }
    local names
    names="$(jq -r '
        if .workspaces|type=="array" then .workspaces[]
        elif .workspaces.packages|type=="array" then .workspaces.packages[]
        else empty end
    ' "$pkg" 2>/dev/null || true)"
    [[ -n "$names" ]] || return 1
    local path name required reason added=0
    while IFS= read -r path; do
        [[ -z "$path" || "$path" == *"*"* ]] && continue
        name="$(basename "$path")"
        if is_deferred_name "$name"; then
            required=false; reason="allow-defer match"
        else
            required=true; reason=""
        fi
        add_concept "$name" systems Module "$path" 0 "$required" "$reason"
        added=$((added+1))
    done <<< "$names"
    [[ $added -gt 0 ]] || return 1
    DISCOVERY_META+=("npm")
    return 0
}

plan_from_go_modules() {
    # go.work use directives, else single go.mod at root, else first-level */go.mod
    local added=0 name required reason path
    if [[ -f "$REPO/go.work" ]]; then
        while IFS= read -r path; do
            path="$(printf '%s' "$path" | sed -E 's/^[[:space:]]*//')"
            [[ -z "$path" || "$path" == //* ]] && continue
            [[ -f "$REPO/$path/go.mod" ]] || continue
            name="$(basename "$path")"
            if is_deferred_name "$name"; then
                required=false; reason="allow-defer match"
            else
                required=true; reason=""
            fi
            add_concept "$name" systems Module "$path" 0 "$required" "$reason"
            added=$((added+1))
        done < <(awk '/^use[[:space:]]*\(/,/^\)/ {if ($1!="use" && $1!="(" && $1!=")") print $1}
                      /^use[[:space:]]+\./ {print $2}' "$REPO/go.work" | tr -d '"')
    fi
    if [[ $added -eq 0 && -f "$REPO/go.mod" ]]; then
        name="$(basename "$REPO")"
        add_concept "$name" systems Module "." 0 true ""
        added=1
    fi
    if [[ $added -eq 0 ]]; then
        while IFS= read -r path; do
            name="$(basename "$(dirname "$path")")"
            add_concept "$name" systems Module "$(dirname "$path" | sed "s|^$REPO/||")" 0 true ""
            added=$((added+1))
        done < <(find "$REPO" -mindepth 2 -maxdepth 3 -type f -name 'go.mod' 2>/dev/null | sort | head -50)
    fi
    [[ $added -gt 0 ]] || return 1
    DISCOVERY_META+=("go")
    return 0
}

# --- 2b. Graph path ---
plan_from_graph() {
    local arch; arch="$(scripts_graph_arch)" || return 1
    [[ -n "$arch" ]] || return 1
    echo "$arch" | jq -e '.packages != null' >/dev/null 2>&1 || return 1

    local have_lang_inventory=0
    [[ ${#DISCOVERY_META[@]} -gt 0 ]] && have_lang_inventory=1

    local name fan_in type required reason
    # Packages → systems/<pkg>.md
    while IFS=$'\t' read -r name fan_in; do
        [[ -z "$name" ]] && continue
        # Drop tokenizer noise when we already have a real inventory (cargo/npm/go).
        if [[ $have_lang_inventory -eq 1 ]] && is_noise_package_name "$name"; then
            continue
        fi
        # Even without inventory, skip pure noise names that do not map to a dir.
        if is_noise_package_name "$name"; then
            local mapped=0
            for d in "$REPO/$name" "$REPO/crates/$name" "$REPO/src/$name" "$REPO/third_party/$name"; do
                [[ -d "$d" ]] && mapped=1 && break
            done
            [[ $mapped -eq 0 ]] && continue
        fi
        if is_deferred_name "$name"; then
            required=false; reason="allow-defer match"; type=Module
        elif (( fan_in >= MIN_FAN_IN )); then
            required=true; reason=""; type=Subsystem
        elif [[ $DEFER_BELOW_FLOOR -eq 1 ]]; then
            required=false; reason="fan_in $fan_in < floor $MIN_FAN_IN"; type=Module
        else
            required=true; reason=""; type=Module
        fi
        # When language inventory exists, graph packages that are coarse parents
        # (e.g. codegen/) become Subsystems only if a matching directory exists.
        if [[ $have_lang_inventory -eq 1 ]]; then
            if [[ -d "$REPO/$name" || -d "$REPO/crates/$name" || -d "$REPO/third_party/$name" || -d "$REPO/prod/$name" ]]; then
                type=Subsystem
                # Prefer real path as resource when known
                for d in "$name" "crates/$name" "third_party/$name" "prod/$name"; do
                    if [[ -d "$REPO/$d" ]]; then
                        add_concept "$name" systems "$type" "$d" "$fan_in" "$required" "$reason"
                        continue 2
                    fi
                done
            else
                # Unmapped graph label with inventory present → skip (not a crate).
                continue
            fi
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
    DISCOVERY_META+=("graph")
    return 0
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
# 1. --manifest (authoritative, exclusive)
# 2. Language inventories (Cargo / npm / Go) — can combine with graph parents
# 3. Graph packages (filtered when inventory present)
# 4. Heuristic top-level dirs
if [[ -n "$MANIFEST" ]]; then
    [[ -f "$MANIFEST" ]] || { echo "ERROR: --manifest not found: $MANIFEST" >&2; exit 1; }
    plan_from_manifest
    DISCOVERY_META+=("manifest")
else
    # Language inventories first so cargo crate names win concept_ids.
    plan_from_cargo_workspace || true
    plan_from_npm_workspaces || true
    plan_from_go_modules || true
    if plan_from_graph; then
        :
    elif [[ ${#E_ID[@]} -eq 0 ]]; then
        plan_from_heuristic
        DISCOVERY_META+=("heuristic")
    fi
    # If graph failed but we have cargo/npm/go, still success.
    if [[ ${#E_ID[@]} -eq 0 ]]; then
        plan_from_heuristic
        DISCOVERY_META+=("heuristic")
    fi
fi

if [[ ${#E_ID[@]} -eq 0 ]]; then
    echo "ERROR: no expected concepts derived (graph + manifest unavailable, heuristic empty)" >&2
    exit 2
fi

# Compose SOURCE label from discovery meta
if [[ ${#DISCOVERY_META[@]} -gt 0 ]]; then
    # de-dupe meta labels
    SOURCE="$(printf '%s\n' "${DISCOVERY_META[@]}" | awk '!s[$0]++' | paste -sd+ -)"
    [[ -z "$SOURCE" ]] && SOURCE="heuristic"
    # degraded only when pure heuristic with no language/graph
    if [[ "$SOURCE" == "heuristic" ]]; then
        DEGRADED="true"
    else
        DEGRADED="false"
    fi
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
        printf '  "discovery": ['
        local di first_d=1
        for di in "${DISCOVERY_META[@]:-}"; do
            [[ -z "$di" ]] && continue
            [[ $first_d -eq 1 ]] && first_d=0 || printf ','
            printf '"%s"' "$(json_escape "$di")"
        done
        printf '],\n'
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
