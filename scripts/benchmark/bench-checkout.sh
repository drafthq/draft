#!/usr/bin/env bash
# bench-checkout.sh
#
# Prepares one worktree per corpus entry at pre-merge state, so a review session
# sees exactly what the original reviewer saw.
#
# The integrity of the whole benchmark rests on this step: if the fix commit is
# reachable from the checked-out tree, the review can read the answer. Every
# checkout is therefore verified to be an ancestor of the fix, never a
# descendant, and the check is fatal.
#
# Corpus format (tab-separated, '#' comments and blank lines ignored):
#   repo <TAB> pr <TAB> head_sha <TAB> fix_sha <TAB> issue <TAB> severity <TAB> description
# `repo` is a clone URL or owner/name (GitHub assumed for the short form).
#
# Usage:
#   scripts/benchmark/bench-checkout.sh --corpus docs/benchmark/corpus.tsv --out /tmp/bench
#   scripts/benchmark/bench-checkout.sh --corpus <f> --out <d> --only owner/name#123
#
# Exit codes:
#   0  every entry prepared and verified
#   1  one or more entries failed
#   2  usage / runtime error

set -euo pipefail

usage() {
    cat <<'EOF'
bench-checkout.sh — prepare pre-merge worktrees for the efficacy benchmark

Options:
  --corpus <file>  Corpus TSV (required)
  --out <dir>      Output directory for clones (required)
  --only <ref>     Prepare a single entry, given as repo#pr
  --cache <dir>    Bare-clone cache (default: <out>/.cache)
  --help, -h       Show this message
EOF
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    usage
    exit 0
fi

CORPUS=""
OUT=""
ONLY=""
CACHE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --corpus) [[ -n "${2:-}" ]] || { echo "bench-checkout: --corpus requires a value" >&2; exit 2; }; CORPUS="$2"; shift 2 ;;
        --out)    [[ -n "${2:-}" ]] || { echo "bench-checkout: --out requires a value" >&2; exit 2; };    OUT="$2"; shift 2 ;;
        --only)   [[ -n "${2:-}" ]] || { echo "bench-checkout: --only requires a value" >&2; exit 2; };   ONLY="$2"; shift 2 ;;
        --cache)  [[ -n "${2:-}" ]] || { echo "bench-checkout: --cache requires a value" >&2; exit 2; };  CACHE="$2"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) echo "bench-checkout: unknown argument '$1'" >&2; usage >&2; exit 2 ;;
    esac
done

[[ -n "$CORPUS" ]] || { echo "bench-checkout: --corpus is required" >&2; exit 2; }
[[ -n "$OUT" ]]    || { echo "bench-checkout: --out is required" >&2; exit 2; }
[[ -f "$CORPUS" ]] || { echo "bench-checkout: no such corpus file: $CORPUS" >&2; exit 2; }
command -v git >/dev/null || { echo "bench-checkout: git not found" >&2; exit 2; }

CACHE="${CACHE:-$OUT/.cache}"
mkdir -p "$OUT" "$CACHE"

prepared=0
failed=0

clone_url() {
    case "$1" in
        *://*|git@*) printf '%s' "$1" ;;
        */*)         printf 'https://github.com/%s.git' "$1" ;;
        *)           return 1 ;;
    esac
}

while IFS=$'\t' read -r repo pr head_sha fix_sha issue severity desc; do
    [[ -z "${repo:-}" || "$repo" == \#* ]] && continue

    if [[ -n "$ONLY" && "$ONLY" != "$repo#$pr" ]]; then
        continue
    fi

    slug="$(printf '%s' "$repo" | tr '/:@' '---' | tr -s '-')-pr$pr"
    dest="$OUT/$slug"
    url="$(clone_url "$repo")" || { echo "SKIP $repo#$pr — cannot derive a clone URL"; failed=$((failed + 1)); continue; }

    echo "── $repo#$pr → $dest"

    if [[ -z "${head_sha:-}" || -z "${fix_sha:-}" ]]; then
        echo "   FAIL: head_sha and fix_sha are both required"
        failed=$((failed + 1))
        continue
    fi

    mirror="$CACHE/$(printf '%s' "$repo" | tr '/:@' '---' | tr -s '-').git"
    if [[ -d "$mirror" ]]; then
        git --git-dir "$mirror" fetch --quiet --all --tags || true
    elif ! git clone --quiet --bare "$url" "$mirror"; then
        echo "   FAIL: clone failed ($url)"
        failed=$((failed + 1))
        continue
    fi

    for sha in "$head_sha" "$fix_sha"; do
        if ! git --git-dir "$mirror" cat-file -e "${sha}^{commit}" 2>/dev/null; then
            # A PR head is often unreachable from branches; fetch the PR ref.
            git --git-dir "$mirror" fetch --quiet origin "refs/pull/$pr/head:refs/bench/pr-$pr" 2>/dev/null || true
        fi
    done

    missing=""
    for sha in "$head_sha" "$fix_sha"; do
        git --git-dir "$mirror" cat-file -e "${sha}^{commit}" 2>/dev/null || missing="$missing $sha"
    done
    if [[ -n "$missing" ]]; then
        echo "   FAIL: commits not found in $repo:$missing"
        failed=$((failed + 1))
        continue
    fi

    # The load-bearing assertion: the review must not be able to reach the fix.
    if git --git-dir "$mirror" merge-base --is-ancestor "$fix_sha" "$head_sha" 2>/dev/null; then
        echo "   FAIL: fix_sha is an ancestor of head_sha — the tree contains the answer"
        failed=$((failed + 1))
        continue
    fi
    if ! git --git-dir "$mirror" merge-base --is-ancestor "$head_sha" "$fix_sha" 2>/dev/null; then
        echo "   WARN: head_sha is not an ancestor of fix_sha (rebase or squash merge?) — verify by hand"
    fi

    rm -rf "$dest"
    if ! git clone --quiet --no-checkout --shared "$mirror" "$dest" 2>/dev/null; then
        echo "   FAIL: could not create working clone"
        failed=$((failed + 1))
        continue
    fi
    # Detached head: nothing about the branch state should hint at what came next.
    if ! git -C "$dest" checkout --quiet --detach "$head_sha" 2>/dev/null; then
        echo "   FAIL: could not check out $head_sha"
        failed=$((failed + 1))
        continue
    fi

    # Metadata for the grader, kept out of the reviewed tree.
    cat > "$OUT/$slug.meta" <<META
repo=$repo
pr=$pr
head_sha=$head_sha
fix_sha=$fix_sha
issue=${issue:-}
severity=${severity:-}
description=${desc:-}
worktree=$dest
META

    changed="$(git -C "$dest" diff --shortstat "$(git -C "$dest" rev-parse "$head_sha^")" "$head_sha" 2>/dev/null || echo 'unknown')"
    echo "   OK: detached at ${head_sha:0:8} · last commit: $changed"
    prepared=$((prepared + 1))
done < "$CORPUS"

echo ""
echo "Prepared $prepared entr$([[ "$prepared" -eq 1 ]] && echo y || echo ies), $failed failed."
if [[ "$prepared" -gt 0 ]]; then
    cat <<'NEXT'

Next: for each worktree, in a FRESH agent session with no knowledge of the fix,
  cd <worktree> && /draft:review          # zero-setup run  -> save review-zero.md
  cd <worktree> && /draft:init            # then index it
  cd <worktree> && /draft:review          # indexed run     -> save review-indexed.md
Do not open the corpus row, the issue, or the fix commit in that session.
NEXT
fi

[[ "$failed" -eq 0 ]] || exit 1
exit 0
