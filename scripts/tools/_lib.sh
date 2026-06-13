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
# Discover track directories under a repo root (default: caller's Draft repo).
discover_track_dirs() {
    local repo_root="${1:-}"
    [[ -n "$repo_root" ]] || return 0
    find "$repo_root" -type d -path '*/tracks/*' -maxdepth 4 -mindepth 2 \
        -not -path '*/.*' 2>/dev/null | sort
}

# Extract a string value from minified or pretty-printed JSON.
read_json_str() {
    local file="$1" key="$2"
    [[ -f "$file" ]] || return 0
    awk -v key="$key" '
        {
            pat = "\""key"\"[[:space:]]*:[[:space:]]*\"[^\"]*\""
            if (match($0, pat)) {
                s = substr($0, RSTART, RLENGTH)
                sub("^\""key"\"[[:space:]]*:[[:space:]]*\"", "", s)
                sub("\"$", "", s)
                print s
                exit
            }
        }' "$file"
}

# Parse scope_includes / scope_excludes from metadata.json or spec.md frontmatter.
read_scope_array() {
    local file="$1" key="$2"
    [[ -f "$file" ]] || return 0
    case "$file" in
        *.json)
            awk -v key="$key" '
                {
                    pat = "\""key"\"[[:space:]]*:[[:space:]]*\\[[^]]*\\]"
                    if (match($0, pat)) {
                        s = substr($0, RSTART, RLENGTH)
                        sub("^\""key"\"[[:space:]]*:[[:space:]]*", "", s)
                        gsub(/[\[\]",]/, " ", s)
                        print s
                        exit
                    }
                }' "$file"
            ;;
        *.md)
            awk -v key="$key" '
                NR==1 && /^---$/ { in_fm=1; next }
                in_fm && /^---$/ { exit }
                in_fm && $0 ~ "^"key":" {
                    sub("^"key":[[:space:]]*", "", $0)
                    gsub(/[\[\]",]/, " ", $0)
                    print $0
                    exit
                }' "$file"
            ;;
    esac
}

# Return the per-skill line cap from a caps config file (or GLOBAL_CAP).
skill_line_cap() {
    local skill_name="$1" caps_conf="$2" global_cap="$3"
    local name cap
    [[ -f "$caps_conf" ]] || { printf '%s' "$global_cap"; return; }
    while read -r name cap; do
        [[ -z "$name" || "$name" == \#* ]] && continue
        if [[ "$name" == "*" ]]; then
            global_cap="$cap"
        elif [[ "$name" == "$skill_name" ]]; then
            printf '%s' "$cap"
            return
        fi
    done < "$caps_conf"
    printf '%s' "$global_cap"
}

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

# Locate the `codebase-memory-mcp` binary (Draft knowledge-graph engine).
# Sets MEMORY_BIN globally; returns 0 if found, 1 otherwise.
# Preference: PATH > Draft-managed install (~/.cache/draft/bin) > vendored bin/<arch> under known roots.
# No legacy fallbacks: the Aether `graph`/`graph-clang` binaries are retired.
find_memory_bin() {
    local repo_abs="$1"
    local self_repo="$2"
    MEMORY_BIN=""
    local bin_name="codebase-memory-mcp"

    # 0. Hard opt-out: force the graph engine off (tests, air-gapped, opt-out users).
    if [[ -n "${DRAFT_MEMORY_DISABLE:-}" ]]; then
        return 1
    fi

    # 1. Explicit override (testing / pinned install).
    if [[ -n "${DRAFT_MEMORY_BIN:-}" && -x "${DRAFT_MEMORY_BIN}" ]]; then
        MEMORY_BIN="$DRAFT_MEMORY_BIN"
        return 0
    fi

    # 2. PATH (highest for dev / global installs).
    if command -v "$bin_name" >/dev/null 2>&1; then
        MEMORY_BIN="$bin_name"
        return 0
    fi

    # 3. Draft-managed install location (install.sh fetches the binary here).
    local managed="$HOME/.cache/draft/bin/$bin_name"
    if [[ -x "$managed" ]]; then
        MEMORY_BIN="$managed"
        return 0
    fi

    # 4. Optional vendored arch-specific binary under known roots.
    local os arch norm
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64) norm="amd64" ;;
        aarch64|arm64) norm="arm64" ;;
        *) norm="$arch" ;;
    esac
    local ARCH="${os}-${norm}"

    local roots=()
    [[ -n "$repo_abs" && -d "$repo_abs" ]] && roots+=("$repo_abs")
    [[ -n "$self_repo" && -d "$self_repo" ]] && roots+=("$self_repo")
    for bc in \
        "$HOME/.cursor/plugins/local/draft/.draft-install-path" \
        "$HOME/.claude/plugins/draft/.draft-install-path"; do
        if [[ -f "$bc" ]]; then
            local pr; pr="$(cat "$bc" 2>/dev/null || true)"
            [[ -n "$pr" && -d "$pr" ]] && roots+=("$pr")
        fi
    done

    for pr in "${roots[@]}"; do
        local cand="$pr/bin/$ARCH/$bin_name"
        if [[ -x "$cand" ]]; then
            MEMORY_BIN="$cand"
            return 0
        fi
    done

    return 1
}

# Run a codebase-memory-mcp CLI tool. Echoes the JSON result (stdout); the engine's
# `level=...` log lines go to stderr and are discarded unless DRAFT_MEMORY_DEBUG is set.
# Usage: memory_cli <tool> [json-args]
memory_cli() {
    local tool="$1"
    local args="${2:-{\}}"
    if [[ -z "${MEMORY_BIN:-}" ]]; then
        return 1
    fi
    if [[ -n "${DRAFT_MEMORY_DEBUG:-}" ]]; then
        "$MEMORY_BIN" cli "$tool" "$args"
    else
        "$MEMORY_BIN" cli "$tool" "$args" 2>/dev/null
    fi
}

# Resolve the engine's project name for a repository absolute path via list_projects.
# Echoes the project name, or nothing if the repo has not been indexed yet.
memory_project_for_repo() {
    local repo_abs="$1"
    command -v jq >/dev/null 2>&1 || return 1
    memory_cli list_projects '{}' 2>/dev/null \
        | jq -r --arg p "$repo_abs" '.projects[]? | select(.root_path == $p) | .name' 2>/dev/null \
        | head -1
}

# Ensure a repository is indexed in the engine; echo its project name.
# Indexes on demand when absent. Returns 1 if the engine is unavailable.
memory_ensure_index() {
    local repo_abs="$1"
    [[ -n "${MEMORY_BIN:-}" ]] || return 1
    command -v jq >/dev/null 2>&1 || return 1
    local proj
    proj="$(memory_project_for_repo "$repo_abs" 2>/dev/null || true)"
    if [[ -z "$proj" ]]; then
        proj="$(memory_cli index_repository "{\"repo_path\":\"$repo_abs\"}" 2>/dev/null \
            | jq -r '.project // empty' 2>/dev/null || true)"
    fi
    [[ -n "$proj" ]] || return 1
    printf '%s' "$proj"
}
