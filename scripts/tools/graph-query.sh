#!/usr/bin/env bash
# graph-query.sh — generic read-only escape hatch to the knowledge-graph engine.
#
# The highest-leverage single addition (graph-tooling-v2 Phase 2): unlocks all 20
# edge types and ~30 pre-computed node properties with no new wrapper. Two modes:
#
#   --cypher 'MATCH ...'         run arbitrary read-only openCypher (write verbs
#                                are rejected before the engine ever sees them).
#   --tool NAME --json '{...}'   passthrough to any read-only engine tool
#                                (get_code_snippet, search_graph, get_graph_schema,
#                                trace_path, …). Destructive tools are rejected, and
#                                a `query` field in --json is scanned for write
#                                verbs exactly like --cypher.
#
# Dialect limits (engine v0.8.x — see _graph_queries.sh for the full list):
#   SAFE   : fixed-length patterns, `=`, `<`, `STARTS WITH`, `NOT x STARTS WITH`,
#            `AND`, `OR`, rel-type alternation `[:A|B]`, `count(x)`.
#   UNSAFE : coalesce(), `<>`/`!=`/`<=`/`>=`, NOT EXISTS(...), NOT (pattern),
#            WITH-grouping aggregation, multi-pattern joins.
# Passthrough returns the engine's raw error, not a silent empty result.
#
# Usage:
#   scripts/tools/graph-query.sh --repo DIR --cypher 'MATCH (n) RETURN n LIMIT 5'
#   scripts/tools/graph-query.sh --repo DIR --tool get_graph_schema --json '{}'
#
# Output: the raw engine JSON on success; {"source":"unavailable"} (exit 2) when
# the engine is unavailable. Exit 1 on invocation error / rejected write.
set -euo pipefail

# shellcheck source=_graph_queries.sh
source "$(dirname "${BASH_SOURCE[0]}")/_graph_queries.sh"

REPO="."
CYPHER=""
TOOL=""
TOOL_JSON="{}"

usage() {
    cat <<'EOF'
graph-query.sh — generic read-only passthrough to the knowledge-graph engine.

Usage:
  scripts/tools/graph-query.sh --repo DIR --cypher 'MATCH ... RETURN ...'
  scripts/tools/graph-query.sh --repo DIR --tool NAME [--json '{...}']

Flags:
  --repo DIR     Repository root (default: cwd).
  --cypher STR   Read-only openCypher query (write verbs CREATE/MERGE/DELETE/SET/
                 REMOVE/DROP/DETACH are rejected). The {project} is injected.
  --tool NAME    Engine tool to call (read-only allowlist). Combine with --json.
  --json STR     JSON args for --tool (the project is injected if absent). A
                 `query` field is write-verb checked like --cypher.
  --help         Show this help.

Dialect: avoid coalesce(), <>, NOT EXISTS, NOT(pattern), WITH-aggregation,
multi-pattern joins. Use =, <, STARTS WITH, AND/OR, [:A|B] alternation.

Output: raw engine JSON on success; {"source":"unavailable"} (exit 2) when the
engine is unavailable; exit 1 on invocation error or a rejected write verb.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) REPO="${2:?--repo requires a value}"; shift 2;;
        --cypher) CYPHER="${2:?--cypher requires a value}"; shift 2;;
        --tool) TOOL="${2:?--tool requires a value}"; shift 2;;
        --json) TOOL_JSON="${2:?--json requires a value}"; shift 2;;
        --help|-h) usage; exit 0;;
        *) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
    esac
done

[[ -d "$REPO" ]] || { echo "ERROR: --repo '$REPO' is not a directory" >&2; exit 1; }
if [[ -n "$CYPHER" && -n "$TOOL" ]]; then
    echo "ERROR: use either --cypher or --tool, not both" >&2; exit 1
fi
if [[ -z "$CYPHER" && -z "$TOOL" ]]; then
    echo "ERROR: provide --cypher or --tool" >&2; usage >&2; exit 1
fi

# Read-only allowlist for --tool mode. Destructive/mutating tools are not exposed
# through this generic hatch (delete_project, index_repository, manage_adr,
# ingest_traces) — use the purpose-built wrappers, which guard them explicitly.
TOOL_ALLOW=" get_architecture query_graph trace_path detect_changes get_code_snippet search_graph search_code get_graph_schema index_status list_projects "

if [[ -n "$TOOL" ]]; then
    [[ "$TOOL_ALLOW" == *" $TOOL "* ]] || {
        echo "ERROR: tool '$TOOL' is not in the read-only allowlist" >&2
        echo "Allowed:$TOOL_ALLOW" >&2
        exit 1
    }
fi

# Drop the contents of every quoted span before scanning for write verbs below.
# A raw substring grep can't tell a CREATE/SET/DELETE clause from a symbol
# literally named 'create', 'set', 'delete', etc. — exactly the method names
# real codebases are full of — so quoted spans must be blanked out first or
# every query about one of them gets wrongly rejected. Cypher quotes strings
# with either ' or " and identifiers with `, and the engine accepts all three,
# so all three must be handled. Escaped quotes (`\'`, produced by gq_escape in
# _graph_queries.sh) must not be read as closing a span early, and an
# unterminated span fails closed (rejected) rather than letting the rest of the
# query — write verbs included — go unscanned.
strip_quoted_spans() {
    local s="$1" out="" i=0 len ch quote
    len="${#s}"
    while (( i < len )); do
        ch="${s:i:1}"
        if [[ "$ch" != "'" && "$ch" != '"' && "$ch" != '`' ]]; then
            out+="$ch"
            i=$((i + 1))
            continue
        fi
        quote="$ch"
        out+="$quote"
        i=$((i + 1))
        while :; do
            (( i < len )) || return 1
            ch="${s:i:1}"
            if [[ "$ch" == '\' ]]; then
                i=$((i + 2))
                continue
            fi
            i=$((i + 1))
            if [[ "$ch" == "$quote" ]]; then
                out+="$quote"
                break
            fi
        done
    done
    printf '%s' "$out"
}

# Reject write verbs BEFORE the engine sees the query.
reject_write_verbs() {
    local stripped upper
    stripped="$(strip_quoted_spans "$1")" || {
        echo "ERROR: write verbs are not allowed (read-only passthrough)" >&2
        exit 1
    }
    upper="$(printf '%s' "$stripped" | tr '[:lower:]' '[:upper:]')"
    if printf '%s' "$upper" | grep -Eqw 'CREATE|MERGE|DELETE|SET|REMOVE|DROP|DETACH'; then
        echo "ERROR: write verbs are not allowed (read-only passthrough)" >&2
        exit 1
    fi
}

if [[ -n "$CYPHER" ]]; then
    reject_write_verbs "$CYPHER"
fi

# --tool carries Cypher too: query_graph takes it in the payload's `query` field,
# so guarding only --cypher left the read-only contract fully bypassable via
# `--tool query_graph --json '{"query":"MATCH (n) DETACH DELETE n"}'`. Scan any
# `query` a tool payload carries, not just query_graph's, so a future
# query-bearing tool is covered by construction. jq-gated: without jq nothing can
# reach the engine anyway (graph_bootstrap fails first).
if [[ -n "$TOOL" ]] && command -v jq >/dev/null 2>&1; then
    echo "$TOOL_JSON" | jq -e . >/dev/null 2>&1 || { echo "ERROR: --json is not valid JSON" >&2; exit 1; }
    TOOL_QUERY="$(echo "$TOOL_JSON" | jq -r '.query // empty' 2>/dev/null || true)"
    [[ -z "$TOOL_QUERY" ]] || reject_write_verbs "$TOOL_QUERY"
fi

unavailable() { echo '{"source":"unavailable"}'; exit 2; }

graph_bootstrap "$REPO" || unavailable

if [[ -n "$CYPHER" ]]; then
    RES="$(gq_run "$PROJECT" "$CYPHER" || true)"
    [[ -n "$RES" ]] || unavailable
    printf '%s\n' "$RES"
else
    # Inject the resolved project into the tool args unless the caller set one.
    ARGS="$(echo "$TOOL_JSON" | jq -c --arg p "$PROJECT" 'if has("project") then . else . + {project:$p} end')"
    RES="$(memory_cli "$TOOL" "$ARGS" 2>/dev/null || true)"
    [[ -n "$RES" ]] || unavailable
    echo "$RES" | jq -e . >/dev/null 2>&1 || unavailable
    printf '%s\n' "$RES"
fi
