#!/usr/bin/env bash
# Test suite for scripts/tools/graph-impact.sh (codebase-memory-mcp engine)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/graph-impact.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== graph-impact.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# --- Invocation error: neither --file nor --symbol ---
set +e
"$TOOL" --repo "$FIXTURE" >/dev/null 2>&1
rc=$?
set -e
assert "Missing --file/--symbol → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"

# --- Fallback: engine disabled ---
set +e
out="$(DRAFT_MEMORY_DISABLE=1 "$TOOL" --repo "$FIXTURE" --symbol foo)"
rc=$?
set -e
assert "Exit 2 when engine unavailable" "$([[ "$rc" == "2" ]] && echo true || echo false)"
if command -v jq >/dev/null 2>&1; then
    assert "Fallback emits {impacted:[], source:unavailable}" \
        "$(echo "$out" | jq -e '.impacted == [] and .source == "unavailable"' >/dev/null 2>&1 && echo true || echo false)"

    EMPTY="$FIXTURE/emptybin/codebase-memory-mcp"
    mkdir -p "$FIXTURE/emptybin"
    cat > "$EMPTY" <<'EMPTYMOCK'
#!/usr/bin/env bash
if [[ "$1" == "--version" ]]; then echo "codebase-memory-mcp 0.0.0-mock"; exit 0; fi
[[ "$1" == "cli" ]] || { echo '{}'; exit 0; }
case "$2" in
  list_projects)    echo '{"projects":[]}' ;;
  index_repository) echo '{"project":"mock","status":"indexed"}' ;;
  query_graph)      echo '{}' ;;
  *) echo '{}' ;;
esac
exit 0
EMPTYMOCK
    chmod +x "$EMPTY"
    set +e
    empty_out="$(DRAFT_MEMORY_BIN="$EMPTY" "$TOOL" --repo "$FIXTURE" --symbol foo)"
    empty_rc=$?
    set -e
    assert "Shapeless {} from query_graph exits 2" "$([[ "$empty_rc" == "2" ]] && echo true || echo false)"
    assert "Shapeless {} from query_graph is unavailable, not empty impact" \
        "$(echo "$empty_out" | jq -e '.source == "unavailable"' >/dev/null 2>&1 && echo true || echo false)"

    # Graph mock: answers each Cypher (read from stdin) by its target and depth.
    #   lib.py  ← app.main (hop 1 and 2), tests test_core (hop 1), cli.run (hop 2),
    #             imported by pkg/consts.py.   empty.py exists, has no dependents.
    #   core    ← app.main (hop 1), core itself (recursion — not a dependent).
    #   many    ← 250 distinct callers.  dup ← 5000 raw rows, 3 distinct symbols.
    GRAPH="$FIXTURE/graphbin/codebase-memory-mcp"
    mkdir -p "$FIXTURE/graphbin"
    cat > "$GRAPH" <<'GRAPHMOCK'
#!/usr/bin/env bash
if [[ "$1" == "--version" ]]; then echo "codebase-memory-mcp 0.0.0-mock"; exit 0; fi
case "$2" in
  list_projects)    echo '{"projects":[]}'; exit 0 ;;
  index_repository) echo '{"project":"mock","status":"indexed"}'; exit 0 ;;
  query_graph)      ;;
  *) echo '{}'; exit 0 ;;
esac
q="$(jq -r .query)"
rows() { printf '{"columns":[],"rows":%s,"total":0}\n' "$1"; }
case "$q" in
  *"*1..1"*"file_path = 'lib.py'"*)
    rows '[["m.app.main","main","app.py","false"],["m.tests.test_core","test_core","tests/test_lib.py","true"]]' ;;
  *"*2..2"*"file_path = 'lib.py'"*)
    rows '[["m.cli.run","run","cli/run.py","false"],["m.app.main","main","app.py","false"]]' ;;
  *"IMPORTS"*"file_path = 'lib.py'"*) rows '[["pkg/consts.py"]]' ;;
  *"*1..1"*"{name:'core'}"*) rows '[["m.app.main","main","app.py","false"]]' ;;
  *"*1..1"*"{name:'many'}"*) rows "$(jq -nc '[range(250) | ["m.c\(.)", "c\(.)", "f\(.).py", "false"]]')" ;;
  *"*1..1"*"{name:'dup'}"*)  rows "$(jq -nc '[range(5000) | ["m.d\(. % 3)", "d\(. % 3)", "d.py", "false"]]')" ;;
  *"(f) WHERE f.file_path = 'empty.py'"*) rows '[["empty.py"]]' ;;
  *) rows '[]' ;;
esac
GRAPHMOCK
    chmod +x "$GRAPH"
    impact() { DRAFT_MEMORY_BIN="$GRAPH" "$TOOL" --repo "$FIXTURE" "$@" 2>/dev/null || true; }
    j() { echo "$1" | jq -e "$2" >/dev/null 2>&1 && echo true || echo false; }

    # --- File impact: cross-file dependents, not the file's own symbols ---
    fout="$(impact --file lib.py)"
    assert "File impact reaches a cross-file caller at hop 2" \
        "$(j "$fout" '.kind == "file" and any(.impacted[]; .file == "cli/run.py" and .hop == 2)')"
    assert "A dependent reachable at hops 1 and 2 is listed once, at hop 1" \
        "$(j "$fout" '[.impacted[] | select(.qualified == "m.app.main")] | length == 1 and .[0].hop == 1')"
    assert "Importers count as hop-1 dependents" \
        "$(j "$fout" 'any(.impacted[]; .file == "pkg/consts.py" and .hop == 1)')"
    assert "downstream_files is the deduped dependent file set" \
        "$(j "$fout" '.downstream_files == ["app.py","cli/run.py","pkg/consts.py","tests/test_lib.py"]')"
    assert "affected_modules are the top-level segments (root files → \".\")" \
        "$(j "$fout" '.affected_modules == [".","cli","pkg","tests"]')"
    assert "max_depth is the deepest hop reached" "$(j "$fout" '.max_depth == 2')"
    assert "by_category splits test from code files" "$(j "$fout" '.by_category == {code:3, test:1}')"
    assert "File impact reports status ok from the live graph" \
        "$(j "$fout" '.status == "ok" and .source == "memory-graph" and .truncated == false')"
    assert "--file ./lib.py is normalized to the repo-relative path" \
        "$(j "$(impact --file ./lib.py)" '.status == "ok"')"
    assert "--file with an absolute path under the repo is normalized" \
        "$(j "$(impact --file "$FIXTURE/lib.py")" '.status == "ok"')"
    assert "A known file with no dependents is no-edges, not a bare empty success" \
        "$(j "$(impact --file empty.py)" '.status == "no-edges" and .impacted == []')"
    assert "A file the graph does not know is no-match" \
        "$(j "$(impact --file nope.py)" '.status == "no-match"')"

    # --- Symbol impact carries caller file paths; the target is not its own dependent ---
    sout="$(impact --symbol core)"
    assert "Symbol impact entries carry the caller's file" \
        "$(j "$sout" '.kind == "symbol" and .impacted == [{name:"main", file:"app.py", qualified:"m.app.main", hop:1}]')"

    # --- Large results: list capped at 200, aggregates stay complete ---
    mout="$(impact --symbol many)"
    assert "impacted is capped at 200 and flagged truncated" \
        "$(j "$mout" '(.impacted | length) == 200 and .truncated == true')"
    assert "downstream_files still counts every dependent file" \
        "$(j "$mout" '(.downstream_files | length) == 250')"
    assert "Hitting the engine row limit is flagged truncated" \
        "$(j "$(impact --symbol dup)" '(.impacted | length) == 3 and .truncated == true')"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
