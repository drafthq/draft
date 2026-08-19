#!/usr/bin/env bash
# Shared helpers for scripts/tools/*.sh.
#
# Sourced, not executed. No side effects at source time.

# shellcheck shell=bash

# Give a mktemp-created replacement file the mode its destination should carry.
# mktemp creates 0600 and `mv` swaps the inode, so an atomic rewrite silently
# strips the destination's permissions (a 0644 doc came back 0600). Call this on
# the temp file BEFORE the mv. Uses the destination's current mode when it
# exists, else the mode a plain `>` redirect would have produced under the
# caller's umask.
apply_dest_mode() {
    local tmp="$1" dest="${2:-}" mode=""
    if [[ -n "$dest" && -e "$dest" ]]; then
        mode="$(stat -c '%a' "$dest" 2>/dev/null || stat -f '%Lp' "$dest" 2>/dev/null || true)"
    fi
    [[ -n "$mode" ]] || mode="$(printf '%o' "$(( 0666 & ~0$(umask) ))")"
    chmod "$mode" "$tmp" 2>/dev/null || true
}

json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\t'/\\t}"
    s="${s//$'\r'/}"
    printf '%s' "$s"
}

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

# GitHub-flavored-markdown-ish heading id (shared by TOC, anchors, link fixers).
# Keeps underscores; strips other punctuation; collapses whitespace to '-'.
gfm_slug() {
    local s="${1:-}"
    # shellcheck disable=SC2001
    s="$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]')"
    s="$(printf '%s' "$s" | sed -E 's/[^[:alnum:]_[:space:]-]+//g; s/[[:space:]]+/-/g; s/-+/-/g; s/^-+//; s/-+$//')"
    printf '%s' "$s"
}

# Count entries in an x-grounded-paths frontmatter field.
# Supports both inline (`x-grounded-paths: ["a", "b"]`) and block lists:
#   x-grounded-paths:
#     - "a"
#     - "b"
grounded_paths_count() {
    local file="$1"
    [[ -f "$file" ]] || { echo 0; return; }
    awk '
        NR==1 && /^---$/ { fm=1; next }
        fm && /^---$/ { exit }
        fm && /^x-grounded-paths:[[:space:]]*\[/ {
            line=$0
            sub(/^x-grounded-paths:[[:space:]]*\[/, "", line)
            sub(/\].*$/, "", line)
            gsub(/[[:space:]]/, "", line)
            if (line=="") { print 0; exit }
            n=split(line, a, ",")
            print n
            exit
        }
        fm && /^x-grounded-paths:[[:space:]]*$/ { collect=1; next }
        fm && collect {
            if ($0 ~ /^[[:space:]]*-[[:space:]]*/) { n++; next }
            if ($0 ~ /^[A-Za-z0-9_-]+:/) { print n+0; exit }
        }
        END { if (collect) print n+0 }
    ' "$file"
}

# Locate the `codebase-memory-mcp` binary (Draft knowledge-graph engine).
# Sets MEMORY_BIN globally; returns 0 if found, 1 otherwise.
# Precedence: DRAFT_MEMORY_DISABLE (hard off) > DRAFT_MEMORY_BIN > PATH >
# Draft-managed install (~/.cache/draft/bin) > vendored bin/<arch> under known roots.
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

    for pr in "${roots[@]}"; do
        local cand="$pr/bin/$ARCH/$bin_name"
        if [[ -x "$cand" ]]; then
            MEMORY_BIN="$cand"
            return 0
        fi
    done

    return 1
}

# graph_bootstrap <repo-dir>
# Shared engine bootstrap for the graph-*.sh wrappers: resolves the repo path,
# locates the engine binary, checks jq, and ensures the index. Sets the globals
# REPO_ABS and PROJECT. Returns 1 on any failure so each wrapper routes it to
# its own unavailable-JSON shape (the shapes differ per tool).
graph_bootstrap() {
    local repo="$1" self_repo
    REPO_ABS="$(cd "$repo" 2>/dev/null && pwd)" || return 1
    self_repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    find_memory_bin "$REPO_ABS" "$self_repo" || return 1
    command -v jq >/dev/null 2>&1 || return 1
    PROJECT="$(memory_ensure_index "$REPO_ABS" || true)"
    [[ -n "$PROJECT" ]] || return 1
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

# Total physical RAM in MB (portable). Echoes a positive integer, or nothing.
_total_ram_mb() {
    if [[ -r /proc/meminfo ]]; then
        awk '/^MemTotal:/{printf "%d", $2/1024; exit}' /proc/meminfo
    elif command -v sysctl >/dev/null 2>&1; then   # macOS / BSD
        local bytes; bytes="$(sysctl -n hw.memsize 2>/dev/null || true)"
        [[ -n "$bytes" ]] && printf '%d' "$(( bytes / 1024 / 1024 ))"
    fi
}

# Cgroup memory args for a transient scope. MemoryHigh throttles (reclaim/swap →
# slower, never thrashes the host); MemoryMax is the hard ceiling a few % above.
# Pure (no I/O) so it is unit-testable. Usage: _mem_bound_args <total_mb> <pct>
_mem_bound_args() {
    local total="$1" pct="$2"
    printf 'MemoryHigh=%dM MemoryMax=%dM' \
        "$(( total * pct / 100 ))" "$(( total * (pct + 5) / 100 ))"
}

# Whether this host can confine a process to a memory-bounded cgroup v2 scope.
# Probes once (starts a throwaway scope) and caches the verdict for the process.
_DRAFT_CGROUP_OK=""
_can_cgroup_bound() {
    if [[ -z "$_DRAFT_CGROUP_OK" ]]; then
        if command -v systemd-run >/dev/null 2>&1 \
            && [[ -e /sys/fs/cgroup/cgroup.controllers ]] \
            && systemd-run --user --scope -q -p MemoryMax=64M -- true >/dev/null 2>&1; then
            _DRAFT_CGROUP_OK=yes
        else
            _DRAFT_CGROUP_OK=no
        fi
    fi
    [[ "$_DRAFT_CGROUP_OK" == yes ]]
}

# Index a repository under a memory bound. The codebase-memory-mcp engine
# self-budgets ~50% of *physical* RAM and is not cgroup-aware, so a first index
# of a huge repo can exhaust the host (the original 30 GB hang). On Linux we
# confine it to a transient cgroup scope sized to DRAFT_INDEX_MEM_PCT (default
# 25) of total RAM; CBM_WORKERS caps the engine's parallel working set so the
# throttle has less transient pressure to absorb. Where cgroup v2 + systemd-run
# are unavailable (e.g. macOS) the worker cap is the only bound. Never falls back
# from a started scope to an unbounded run — a bounded OOM fails the index
# cleanly (host stays alive) rather than re-triggering the hang.
# Echoes the engine's JSON result on stdout (same contract as memory_cli).
memory_index_bounded() {
    local repo_abs="$1"
    # Payload built with jq (never string concatenation) so a repo path
    # containing a `"` or `\` can never corrupt the JSON sent to the engine.
    command -v jq >/dev/null 2>&1 || return 1
    local json
    json="$(jq -n --arg r "$repo_abs" '{repo_path:$r}')" || return 1
    export CBM_WORKERS="${CBM_WORKERS:-4}"
    local total pct
    total="$(_total_ram_mb)"
    pct="${DRAFT_INDEX_MEM_PCT:-25}"
    if [[ "${total:-0}" -gt 0 ]] && _can_cgroup_bound; then
        local high_arg max_arg
        read -r high_arg max_arg <<< "$(_mem_bound_args "$total" "$pct")"
        if [[ -n "${DRAFT_MEMORY_DEBUG:-}" ]]; then
            systemd-run --user --scope -q -p "$high_arg" -p "$max_arg" \
                -- "$MEMORY_BIN" cli index_repository "$json"
        else
            systemd-run --user --scope -q -p "$high_arg" -p "$max_arg" \
                -- "$MEMORY_BIN" cli index_repository "$json" 2>/dev/null
        fi
    else
        memory_cli index_repository "$json"
    fi
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
        proj="$(memory_index_bounded "$repo_abs" \
            | jq -r '.project // empty' 2>/dev/null || true)"
    fi
    [[ -n "$proj" ]] || return 1
    printf '%s' "$proj"
}
