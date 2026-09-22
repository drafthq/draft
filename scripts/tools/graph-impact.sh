#!/usr/bin/env bash
# graph-impact.sh — blast radius for a file or symbol, from the knowledge graph.
#
# Everything that depends on the target, up to --depth CALLS hops: callers of the
# symbol, or callers of anything defined in the file plus the files that import
# it. Callers inside the target file are not downstream and are skipped.
#
# Usage:
#   scripts/tools/graph-impact.sh --repo DIR (--file PATH | --symbol NAME) [--depth N]
#
# Output: JSON {target, kind, impacted:[{name,file,qualified,hop}], downstream_files,
#   affected_modules, max_depth, by_category:{code,test}, status, truncated, source}.
#   `impacted` lists each dependent once at its nearest hop, capped at 200; the
#   aggregates always cover the full set. `truncated` is true when the list was
#   capped or the engine row limit was hit. A module is a file's top-level path
#   segment ("." for root files), as in classify-files.sh.
#   status = ok | no-edges (target known, nothing depends on it) | no-match
#            (target unknown to the graph)
#   source = "memory-graph" | "unavailable"
#
# Exit codes: 0 OK, 1 invocation error, 2 graph engine unavailable.
set -euo pipefail

# shellcheck source=_graph_queries.sh
source "$(dirname "${BASH_SOURCE[0]}")/_graph_queries.sh"

REPO="."
FILE=""
SYMBOL=""
DEPTH=3

usage() {
    cat <<'EOF'
graph-impact.sh — blast radius for a file or symbol.

Usage:
  scripts/tools/graph-impact.sh --repo DIR (--file PATH | --symbol NAME) [--depth N]

Flags:
  --repo DIR     Repository root (default: cwd).
  --file PATH    Dependents of a file (repo-relative, ./-prefixed, or absolute).
  --symbol NAME  Dependents (transitive callers) of a function.
  --depth N      Caller traversal depth (default: 3).
  --help         Show this help.

Output: JSON {target, kind, impacted, downstream_files, affected_modules,
max_depth, by_category, status, truncated, source}. Exit 2 when engine unavailable.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) REPO="${2:?--repo requires a value}"; shift 2;;
        --file) FILE="${2:?--file requires a value}"; shift 2;;
        --symbol) SYMBOL="${2:?--symbol requires a value}"; shift 2;;
        --depth) DEPTH="${2:?--depth requires a value}"; shift 2;;
        --help|-h) usage; exit 0;;
        *) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
    esac
done

[[ -d "$REPO" ]] || { echo "ERROR: --repo '$REPO' is not a directory" >&2; exit 1; }
[[ -n "$FILE" || -n "$SYMBOL" ]] || { echo "ERROR: provide --file or --symbol" >&2; usage >&2; exit 1; }
[[ "$DEPTH" =~ ^[0-9]+$ ]] || { echo "ERROR: --depth must be a non-negative integer" >&2; exit 1; }

unavailable() {
    local t="$1" k="$2"
    jq -n --arg t "$t" --arg k "$k" '{target:$t, kind:$k, impacted:[], source:"unavailable"}' 2>/dev/null \
        || echo '{"impacted":[],"source":"unavailable"}'
    exit 2
}

if [[ -n "$SYMBOL" ]]; then TARGET="$SYMBOL"; KIND="symbol"; else TARGET="$FILE"; KIND="file"; fi

graph_bootstrap "$REPO" || unavailable "$TARGET" "$KIND"

if [[ -n "$SYMBOL" ]]; then
    T_ESC="$(gq_escape "$SYMBOL")"
    DEPENDENTS=gq_q_dependents_symbol; EXISTS=gq_q_exists
else
    # The graph keys files by repo-relative path.
    REL="${FILE#"$REPO_ABS"/}"; REL="${REL#./}"
    T_ESC="$(gq_escape "$REL")"
    DEPENDENTS=gq_q_dependents_file; EXISTS=gq_q_file_exists
fi

# Accumulate {q,name,file,test,hop} JSONL in a temp file: the row sets of a hot
# target can exceed argv limits.
ROWS="$(mktemp)"
trap 'rm -f "$ROWS"' EXIT
TRUNC=false
for ((k = 1; k <= DEPTH; k++)); do
    R="$(gq_run "$PROJECT" "$("$DEPENDENTS" "$T_ESC" "$k")")" || unavailable "$TARGET" "$KIND"
    [[ "$(gq_rows_len "$R")" -lt "$GQ_DEP_LIMIT" ]] || TRUNC=true
    jq -c --argjson k "$k" '.rows[] | {q:(.[0] // ""), name:(.[1] // ""), file:(.[2] // ""),
        test:((.[3] | tostring) == "true"), hop:$k}' <<< "$R" >> "$ROWS"
done
if [[ -n "$FILE" ]]; then
    R="$(gq_run "$PROJECT" "$(gq_q_importers "$T_ESC")")" || unavailable "$TARGET" "$KIND"
    [[ "$(gq_rows_len "$R")" -lt "$GQ_DEP_LIMIT" ]] || TRUNC=true
    jq -c '.rows[] | {q:"", name:.[0], file:.[0], test:false, hop:1}' <<< "$R" >> "$ROWS"
fi

# Nothing depends on it: a true negative only if the graph knows the target.
STATUS=ok
if [[ ! -s "$ROWS" ]]; then
    EX="$(gq_run "$PROJECT" "$("$EXISTS" "$T_ESC")")" || unavailable "$TARGET" "$KIND"
    if [[ "$(gq_rows_len "$EX")" -gt 0 ]]; then STATUS=no-edges; else STATUS=no-match; fi
fi

jq -s --arg t "$TARGET" --arg kind "$KIND" --arg status "$STATUS" --argjson trunc "$TRUNC" '
    (group_by([.q, .file]) | map(min_by(.hop))) as $u
    | ($u | map(.file) | map(select(. != "")) | unique) as $files
    | ($u | map(select(.test) | .file) | unique) as $tests
    | {target:$t, kind:$kind,
       impacted: ($u | sort_by(.hop, .file, .name) | .[:200]
                  | map({name, file, qualified:.q, hop})),
       downstream_files: $files,
       affected_modules: ($files | map(if test("/") then split("/")[0] else "." end) | unique),
       max_depth: ($u | map(.hop) | max // 0),
       by_category: {code: ($files - $tests | length), test: ($tests | length)},
       status: $status,
       truncated: ($trunc or ($u | length) > 200),
       source: "memory-graph"}' "$ROWS"
