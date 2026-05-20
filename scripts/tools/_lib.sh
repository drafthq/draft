#!/usr/bin/env bash
# Shared helpers for scripts/tools/*.sh.
#
# Sourced, not executed. No side effects at source time.

# shellcheck shell=bash

json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\t'/\\t}"
    s="${s//$'\r'/}"
    printf '%s' "$s"
}

# Extract a top-level YAML frontmatter field value from a Markdown file.
get_yaml_field() {
    local file="$1"
    local key="$2"
    awk -v key="$key" '
        NR == 1 && /^---$/ { in_fm = 1; next }
        in_fm && /^---$/ { exit }
        in_fm {
            if ($0 ~ "^"key":[[:space:]]*") {
                val = $0
                sub("^"key":[[:space:]]*", "", val)
                if (val ~ /^".*"$/) { val = substr(val, 2, length(val)-2) }
                sub(/[[:space:]]+$/, "", val)
                print val
                exit
            }
        }
    ' "$file"
}

# Locate the `graph` binary (Draft knowledge graph CLI, native only).
# Sets GRAPH_BIN globally; returns 0 if found, 1 otherwise.
# Preference: PATH > bundled graph/bin/<arch>/graph under known roots.
find_graph_bin() {
    local repo_abs="$1"
    local self_repo="$2"
    GRAPH_BIN=""
    GRAPH_CLANG_BIN=""

    # Resolve arch for vendored layout (linux-amd64, darwin-arm64, ...)
    local os arch norm
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64) norm="amd64" ;;
        aarch64|arm64) norm="arm64" ;;
        *) norm="$arch" ;;
    esac
    local ARCH="${os}-${norm}"

    # 1. PATH (highest)
    if command -v graph >/dev/null 2>&1; then
        GRAPH_BIN="graph"
        if command -v graph-clang >/dev/null 2>&1; then
            GRAPH_CLANG_BIN="graph-clang"
        fi
        return 0
    fi

    # 2. Breadcrumb + common roots, looking for arch-specific native
    local roots=()
    for bc in \
        "$HOME/.cursor/plugins/local/draft/.draft-install-path" \
        "$HOME/.claude-plugin/../.draft-install-path" \
        "$HOME/.claude/plugins/draft/.draft-install-path"; do
        if [[ -f "$bc" ]]; then
            local pr; pr="$(cat "$bc" 2>/dev/null || true)"
            [[ -n "$pr" && -d "$pr" ]] && roots+=("$pr")
        fi
    done
    [[ -n "$repo_abs" && -d "$repo_abs" ]] && roots+=("$repo_abs")
    [[ -n "$self_repo" && -d "$self_repo" ]] && roots+=("$self_repo")

    for pr in "${roots[@]}"; do
        local cand="$pr/graph/bin/$ARCH/graph"
        if [[ -x "$cand" ]]; then
            GRAPH_BIN="$cand"
            local clang_cand="$pr/graph/bin/$ARCH/graph-clang"
            [[ -x "$clang_cand" ]] && GRAPH_CLANG_BIN="$clang_cand"
            return 0
        fi
    done

    return 1
}
