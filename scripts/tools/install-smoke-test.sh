#!/usr/bin/env bash
# install-smoke-test.sh
#
# Exercises the real first-install path on a throwaway clone.
#
# The v2.8.3 install hang was invisible to `make test` because every suite runs
# against the working tree, and the working tree is never what a new user gets.
# A new user gets `git clone --depth 1` followed by manifest discovery and a
# writer pass over an empty HOME. This reproduces exactly that, in that order,
# so a regression in any of those steps fails a build instead of a user.
#
# Requires: git, node 18+. Does NOT require the `claude` CLI and never touches
# the network — the graph-engine fetch is stubbed out via --no-graph.
#
# Usage:
#   scripts/tools/install-smoke-test.sh                  # clone this repo, run all checks
#   scripts/tools/install-smoke-test.sh --repo <path>    # smoke-test another checkout
#   scripts/tools/install-smoke-test.sh --keep           # leave the sandbox for inspection
#   scripts/tools/install-smoke-test.sh --json
#
# Exit codes:
#   0  install path is healthy
#   1  a check failed
#   2  usage / runtime error

set -euo pipefail

usage() {
    cat <<'EOF'
install-smoke-test.sh — clean-clone install smoke test

Options:
  --repo <path>  Repository to clone (default: this repo)
  --keep         Do not delete the sandbox on exit
  --json         Emit JSON instead of human-readable output
  --help, -h     Show this message
EOF
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    usage
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$SCRIPT_DIR/_lib.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
KEEP=0
EMIT_JSON=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)
            [[ -n "${2:-}" ]] || { echo "install-smoke-test: --repo requires a value" >&2; exit 2; }
            REPO_ROOT="$2"; shift 2 ;;
        --keep) KEEP=1; shift ;;
        --json) EMIT_JSON=1; shift ;;
        --help|-h) usage; exit 0 ;;
        *) echo "install-smoke-test: unknown argument '$1'" >&2; usage >&2; exit 2 ;;
    esac
done

[[ -d "$REPO_ROOT" ]] || { echo "install-smoke-test: no such directory: $REPO_ROOT" >&2; exit 2; }
command -v git  >/dev/null || { echo "install-smoke-test: git not found" >&2; exit 2; }
command -v node >/dev/null || { echo "install-smoke-test: node not found" >&2; exit 2; }

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/draft-install-smoke.XXXXXX")"
cleanup() { [[ "$KEEP" -eq 1 ]] || rm -rf "$SANDBOX"; }
trap cleanup EXIT

CLONE="$SANDBOX/clone"
FAKE_HOME="$SANDBOX/home"
PROJECT="$SANDBOX/project"
mkdir -p "$FAKE_HOME" "$PROJECT"

FAILURES=()
RESULTS=()

# Collapse a file to one truncated line. Done in-shell rather than with
# `| cut -c1-200` because an early-closing reader plus `pipefail` turns a
# harmless truncation into a SIGPIPE failure of the whole script.
oneline() {
    local text
    text="$(tr '\n' ' ' < "$1")"
    printf '%s' "${text:0:200}"
}

lastlines() {
    local text
    text="$(tail -n "$2" "$1" | tr '\n' ' ')"
    printf '%s' "${text:0:200}"
}

record() {
    local name="$1" ok="$2" detail="${3:-}"
    RESULTS+=("$name|$ok|$detail")
    if [[ "$ok" == "true" ]]; then
        [[ "$EMIT_JSON" -eq 1 ]] || echo " PASS: $name${detail:+ — $detail}"
    else
        [[ "$EMIT_JSON" -eq 1 ]] || echo " FAIL: $name${detail:+ — $detail}"
        FAILURES+=("$name")
    fi
}

[[ "$EMIT_JSON" -eq 1 ]] || echo "=== Install smoke test (sandbox: $SANDBOX) ==="

# 1. Shallow clone — the literal first step of `plugin marketplace add`.
#    file:// forces the real transfer path; a plain local path would hardlink
#    and hide size problems.
if git clone --depth 1 --quiet "file://$REPO_ROOT" "$CLONE" 2>"$SANDBOX/clone.err"; then
    record "shallow clone succeeds" "true"
else
    record "shallow clone succeeds" "false" "$(oneline "$SANDBOX/clone.err")"
fi

if [[ -d "$CLONE" ]]; then
    clone_mb="$(du -sm "$CLONE" | cut -f1)"
    record "clone size recorded" "true" "${clone_mb} MB on disk"

    # 2. Manifest discovery — install fails here if plugin.json is malformed or
    #    points at a skills directory the clone does not contain.
    if node -e '
        const fs = require("fs"), path = require("path");
        const root = process.argv[1];
        const plugin = JSON.parse(fs.readFileSync(path.join(root, ".claude-plugin/plugin.json"), "utf8"));
        const market = JSON.parse(fs.readFileSync(path.join(root, ".claude-plugin/marketplace.json"), "utf8"));
        if (!plugin.name) throw new Error("plugin.json has no name");
        if (!Array.isArray(market.plugins) || market.plugins.length === 0) throw new Error("marketplace.json lists no plugins");
        const skills = typeof plugin.skills === "string" ? plugin.skills : "./skills/";
        const dir = path.join(root, skills);
        if (!fs.existsSync(dir)) throw new Error("skills dir missing from clone: " + skills);
        if (fs.readdirSync(dir).length === 0) throw new Error("skills dir is empty in clone");
    ' "$CLONE" 2>"$SANDBOX/manifest.err"; then
        record "plugin manifests resolve in the clone" "true"
    else
        record "plugin manifests resolve in the clone" "false" "$(oneline "$SANDBOX/manifest.err")"
    fi

    # 3. Every shipped skill must carry name+description frontmatter, or the
    #    host silently drops it at discovery time.
    bad_skills=0
    skill_count=0
    while IFS= read -r skill; do
        skill_count=$((skill_count + 1))
        head -n 1 "$skill" | grep -q '^---$' || { bad_skills=$((bad_skills + 1)); continue; }
        fm="$(sed -n '2,/^---$/p' "$skill")"
        grep -q '^name:' <<< "$fm" || { bad_skills=$((bad_skills + 1)); continue; }
        grep -q '^description:' <<< "$fm" || bad_skills=$((bad_skills + 1))
    done < <(find "$CLONE/skills" -name SKILL.md -type f 2>/dev/null | sort)

    if [[ "$skill_count" -eq 0 ]]; then
        record "shipped skills discoverable" "false" "no SKILL.md files in clone"
    else
        record "shipped skills discoverable" \
            "$([[ "$bad_skills" -eq 0 ]] && echo true || echo false)" \
            "$skill_count skills, $bad_skills malformed"
    fi

    # 4. Writer pass against an empty HOME, per host. --dry-run plans every
    #    write without touching disk; --no-graph keeps it offline.
    hosts="$(cd "$CLONE" && node -e '
        const { hosts } = require("./cli/src/hosts");
        console.log(hosts.map((h) => h.id).join(" "));
    ' 2>/dev/null || true)"

    if [[ -z "$hosts" ]]; then
        record "host list enumerable" "false" "cli/src/hosts did not load"
    else
        record "host list enumerable" "true" "$hosts"
        for host in $hosts; do
            if (cd "$PROJECT" && HOME="$FAKE_HOME" node "$CLONE/cli/bin/draft.js" \
                    install "$host" --dry-run --no-graph >"$SANDBOX/$host.log" 2>&1); then
                record "install --dry-run: $host" "true"
            else
                record "install --dry-run: $host" "false" "$(lastlines "$SANDBOX/$host.log" 3)"
            fi
        done
        # A dry run that writes is worse than one that fails — it means the real
        # installer's plan/apply split leaks. Both destinations must be checked:
        # codex and opencode default to project scope and write AGENTS.md into the
        # cwd, so a HOME-only assertion misses the likeliest leak.
        record "dry run left HOME untouched" \
            "$([[ -z "$(ls -A "$FAKE_HOME")" ]] && echo true || echo false)" \
            "$(ls -A "$FAKE_HOME" | tr '\n' ' ')"
        record "dry run left the project dir untouched" \
            "$([[ -z "$(ls -A "$PROJECT")" ]] && echo true || echo false)" \
            "$(ls -A "$PROJECT" | tr '\n' ' ')"
    fi

    # 5. Engine fetcher is present and self-documenting (never invoked here —
    #    it downloads).
    if [[ -x "$CLONE/scripts/fetch-memory-engine.sh" ]]; then
        record "graph engine fetcher shipped and executable" "true"
    else
        record "graph engine fetcher shipped and executable" "false" "scripts/fetch-memory-engine.sh missing or not executable"
    fi
fi

if [[ "$EMIT_JSON" -eq 1 ]]; then
    printf '{"sandbox":"%s","failures":%d,"checks":[' "$SANDBOX" "${#FAILURES[@]}"
    sep=""
    for r in "${RESULTS[@]}"; do
        IFS='|' read -r name ok detail <<< "$r"
        # json_escape (from _lib.sh) also handles backslashes and control chars —
        # a Windows path or a stack trace in a captured stderr line used to emit
        # invalid JSON.
        printf '%s{"name":"%s","ok":%s,"detail":"%s"}' "$sep" "$(json_escape "$name")" "$ok" "$(json_escape "$detail")"
        sep=","
    done
    printf ']}\n'
else
    echo ""
    if [[ "${#FAILURES[@]}" -eq 0 ]]; then
        echo "Install path healthy — ${#RESULTS[@]} checks passed."
    else
        echo "Install path BROKEN — ${#FAILURES[@]} of ${#RESULTS[@]} checks failed:"
        printf '  - %s\n' "${FAILURES[@]}"
    fi
fi

[[ "${#FAILURES[@]}" -eq 0 ]] || exit 1
exit 0
