#!/usr/bin/env bash
# _graph_queries.sh — canonical Cypher builders + fail-loud runner for the
# codebase-memory-mcp engine. Sourced by the graph-*.sh wrappers; never executed.
#
# Single source of query truth (graph-tooling-v2 Guardrail 2): no Cypher literal
# should live in a wrapper entrypoint. A label or dialect fix is a one-line edit
# here, not a hunt across N scripts (the Phase 0 :Function bug was duplicated
# across two files precisely because the Cypher was inlined).
#
# Dialect notes (engine v0.8.x, verified live against this engine):
#   SAFE   : fixed-length patterns, single/multi-hop explicit patterns, `=`, `<`,
#            `STARTS WITH`, `NOT x STARTS WITH`, `AND`, `OR`, relationship-type
#            alternation `[:A|B]`, simple `count(x)`.
#   UNSAFE : coalesce(), `<>` / `!=` / `<=` / `>=`, `NOT EXISTS(...)`,
#            `NOT (pattern)`, `WITH`-grouping aggregation, multi-pattern joins.
#            Every builder below stays inside the SAFE set.
#
# Label-agnostic on name matches: code units are :Method ⪢ :Function in OO repos;
# pinning :Function silently returns [] (the graph-tooling-v2 Phase 0 bug). CALLS
# edges only connect callables, so dropping the label stays precise.

# shellcheck shell=bash

# Pull in memory_cli / find_memory_bin / MEMORY_BIN if a wrapper sourced only us.
_GQ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$(type -t memory_cli 2>/dev/null)" != function ]]; then
    # shellcheck source=_lib.sh
    source "$_GQ_DIR/_lib.sh"
fi

# Escape single quotes for embedding inside a Cypher single-quoted string literal.
gq_escape() {
    local s="$1"
    printf '%s' "${s//\'/\\\'}"
}

# ── Cypher builders. Each echoes one query string. $1 = pre-escaped symbol. ──

gq_q_exists()            { printf "MATCH (f {name:'%s'}) RETURN f.name AS name LIMIT 1" "$1"; }
gq_q_callers()           { printf "MATCH (c)-[:CALLS]->(f {name:'%s'}) RETURN c.name AS caller, c.file_path AS file LIMIT 200" "$1"; }
gq_q_callers_prod()      { printf "MATCH (c)-[:CALLS]->(f {name:'%s'}) WHERE c.is_test=false AND NOT c.file_path STARTS WITH 'tests/' RETURN c.name AS caller, c.file_path AS file LIMIT 200" "$1"; }
gq_q_callers_qualified() { printf "MATCH (c)-[:CALLS]->(f {qualified_name:'%s'}) RETURN c.name AS caller, c.file_path AS file LIMIT 200" "$1"; }
gq_q_cycles2()           { printf "MATCH (a)-[:CALLS]->(b)-[:CALLS]->(a) WHERE a.qualified_name < b.qualified_name RETURN a.qualified_name AS a, b.qualified_name AS b LIMIT 100"; }
gq_q_cycles3()           { printf "MATCH (a)-[:CALLS]->(b)-[:CALLS]->(c)-[:CALLS]->(a) RETURN a.qualified_name AS a, b.qualified_name AS b, c.qualified_name AS c LIMIT 100"; }
gq_q_tests()             { printf "MATCH (t)-[:TESTS]->(f {name:'%s'}) RETURN t.qualified_name AS test, t.file_path AS file LIMIT 200" "$1"; }
gq_q_tested_all()        { printf "MATCH (t)-[:TESTS]->(f) RETURN f.qualified_name AS symbol LIMIT 2000"; }
gq_q_exported()          { printf "MATCH (f) WHERE f.is_exported=true RETURN f.qualified_name AS symbol, f.file_path AS file LIMIT 2000"; }
gq_q_imports()           { printf "MATCH (a)-[:IMPORTS]->(b) RETURN a.file_path AS src, b.file_path AS dst LIMIT 1000"; }
gq_q_co_change()         { printf "MATCH (a:File)-[r:FILE_CHANGES_WITH]->(b:File) RETURN a.name AS src, b.name AS dst, r.coupling_score AS score ORDER BY r.coupling_score DESC LIMIT 40"; }
gq_q_inherits()          { printf "MATCH (c)-[:INHERITS]->(p) RETURN c.qualified_name AS child, p.qualified_name AS parent LIMIT 500"; }
gq_q_inherits_sym()      { printf "MATCH (c)-[:INHERITS]->(p) WHERE c.name='%s' RETURN c.qualified_name AS child, p.qualified_name AS parent LIMIT 200" "$1"; }
gq_q_derived_sym()       { printf "MATCH (c)-[:INHERITS]->(p) WHERE p.name='%s' RETURN c.qualified_name AS child, p.qualified_name AS parent LIMIT 200" "$1"; }
gq_q_writes()            { printf "MATCH (f {name:'%s'})-[:WRITES]->(v) RETURN v.name AS target, v.file_path AS file LIMIT 200" "$1"; }
gq_q_raises()            { printf "MATCH (f {name:'%s'})-[:RAISES|THROWS]->(e) RETURN e.name AS error, e.qualified_name AS qualified LIMIT 200" "$1"; }
gq_q_raisers()           { printf "MATCH (f)-[:RAISES|THROWS]->(e {name:'%s'}) RETURN f.qualified_name AS raiser, f.file_path AS file LIMIT 200" "$1"; }
gq_q_node_props()        { printf "MATCH (f) RETURN f.qualified_name AS q, f.complexity AS c, f.cognitive AS cog, f.is_entry_point AS ep LIMIT 10000"; }
gq_q_risk()              { printf "MATCH (f) WHERE f.unguarded_recursion=true OR f.alloc_in_loop=true OR f.recursion_in_loop=true OR f.linear_scan_in_loop=true RETURN f.qualified_name AS symbol, f.file_path AS file, f.complexity AS complexity, f.unguarded_recursion AS unguarded_recursion, f.alloc_in_loop AS alloc_in_loop, f.recursion_in_loop AS recursion_in_loop, f.linear_scan_in_loop AS linear_scan_in_loop LIMIT 200"; }

# ── Runner + classifier ──

# gq_run <project> <cypher>
# Runs query_graph and echoes the validated raw engine JSON. Builds the JSON
# payload with jq so a quote/backslash in the query can never produce invalid
# JSON. Requires MEMORY_BIN (set by find_memory_bin) and jq. Returns:
#   0  valid JSON emitted on stdout
#   3  engine unavailable / no binary / non-JSON output  (FAIL-LOUD: the caller
#      must NOT treat this as an empty true-negative result)
gq_run() {
    local project="$1" query="$2"
    [[ -n "${MEMORY_BIN:-}" ]] || return 3
    command -v jq >/dev/null 2>&1 || return 3
    local payload res
    payload="$(jq -n --arg p "$project" --arg q "$query" '{project:$p, query:$q}')" || return 3
    res="$(memory_cli query_graph "$payload" 2>/dev/null || true)"
    [[ -n "$res" ]] || return 3
    printf '%s' "$res" | jq -e . >/dev/null 2>&1 || return 3
    printf '%s' "$res"
}

# gq_rows_len <json> -> integer row count (0 on parse failure).
gq_rows_len() {
    printf '%s' "$1" | jq -r '(.rows // []) | length' 2>/dev/null || printf '0'
}

# gq_symbol_status <project> <sym_esc> <result_json> -> ok | no-edges | no-match
# Fail-loud disambiguation (Guardrail 4): an empty result is only a true negative
# ("no-edges") when the node actually exists; otherwise it is "no-match". An
# existence probe runs only when the primary result is empty (hot path stays one
# query).
gq_symbol_status() {
    local project="$1" sym="$2" result="$3"
    if [[ "$(gq_rows_len "$result")" -gt 0 ]]; then
        printf 'ok'; return
    fi
    local ex
    ex="$(gq_run "$project" "$(gq_q_exists "$sym")" || true)"
    if [[ -n "$ex" && "$(gq_rows_len "$ex")" -gt 0 ]]; then
        printf 'no-edges'
    else
        printf 'no-match'
    fi
}
