#!/usr/bin/env bash
# okf-emit-catalog.sh — deterministically emit minimum-viable concept pages for
# every REQUIRED entry in a concept-plan.json that does not yet have a page.
#
# Purpose: XL monorepos cannot rely on the LLM to narrate every Module page in
# one shot. This tool writes quality-gate-passing catalog pages from plan
# metadata + optional Cargo/README crumbs so init can complete without gaps.
# Agents may later enrich top-N hotspots; the catalog is the completeness floor.
#
# Usage:
#   okf-emit-catalog.sh --plan FILE --bundle DIR [--repo DIR] [--force]
#
# Exit: 0 ok, 1 error, 2 plan/bundle missing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/tools/_lib.sh
source "$SCRIPT_DIR/_lib.sh"

PLAN=""
BUNDLE=""
REPO="."
FORCE=0

usage() {
    cat <<'EOF'
okf-emit-catalog.sh — write minimum-viable concept pages for missing plan entries.

Usage:
  okf-emit-catalog.sh --plan FILE --bundle DIR [--repo DIR] [--force]

Flags:
  --plan FILE    concept-plan.json (required)
  --bundle DIR   wiki/ bundle directory (required)
  --repo DIR     repository root for grounding (default: .)
  --force        Overwrite existing pages (default: skip if present)
  --help         Show help

Exit: 0 ok, 1 error, 2 missing plan/bundle.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --plan) PLAN="${2:?--plan requires a value}"; shift 2;;
        --bundle) BUNDLE="${2:?--bundle requires a value}"; shift 2;;
        --repo) REPO="${2:?--repo requires a value}"; shift 2;;
        --force) FORCE=1; shift;;
        --help|-h) usage; exit 0;;
        -*) echo "Unknown flag: $1" >&2; usage >&2; exit 1;;
        *) echo "Unexpected arg: $1" >&2; exit 1;;
    esac
done

[[ -n "$PLAN" && -f "$PLAN" ]] || { echo "ERROR: --plan required" >&2; exit 2; }
[[ -n "$BUNDLE" && -d "$BUNDLE" ]] || { echo "ERROR: --bundle directory required" >&2; exit 2; }
[[ -d "$REPO" ]] || { echo "ERROR: --repo is not a directory" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required" >&2; exit 1; }

BUNDLE="${BUNDLE%/}"
REPO="$(cd "$REPO" && pwd)"
TS="${OKF_CATALOG_TS:-$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "1970-01-01T00:00:00Z")}"

wrote=0
skipped=0

# Best-effort one-line description from resource path.
sniff_desc() {
    local res="$1" lib
    lib="$REPO/$res/src/lib.rs"
    [[ -f "$lib" ]] || lib="$REPO/$res/lib.rs"
    if [[ -f "$lib" ]]; then
        awk '/^\/\/!/ { sub(/^\/\/![[:space:]]?/, ""); print; exit }' "$lib"
        return
    fi
    if [[ -f "$REPO/$res/README.md" ]]; then
        awk 'NF && !/^#/ { print; exit }' "$REPO/$res/README.md"
        return
    fi
    printf 'Workspace component at %s.' "$res"
}

write_page() {
    local cid="$1" ctype="$2" resource="$3" fan_in="$4"
    local out="$BUNDLE/$cid"
    mkdir -p "$(dirname "$out")"
    if [[ -f "$out" && $FORCE -eq 0 ]]; then
        skipped=$((skipped+1))
        return
    fi

    local title stem section
    stem="$(basename "$cid" .md)"
    section="$(dirname "$cid")"
    title="$stem"
    local desc
    desc="$(sniff_desc "$resource")"
    [[ -n "$desc" ]] || desc="Open when changing the ${stem} component at ${resource}."

    # Routing description (load-bearing for concept map).
    local routing="Open when changing \`${stem}\` (${resource}). ${desc}"
    routing="$(printf '%s' "$routing" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g' | cut -c1-280)"

    local g1 g2
    g1="$resource"
    [[ -e "$REPO/$resource" ]] || g1="README.md"
    if [[ -f "$REPO/$resource/src/lib.rs" ]]; then
        g1="$resource/src/lib.rs"
    elif [[ -f "$REPO/$resource/Cargo.toml" ]]; then
        g1="$resource/Cargo.toml"
    elif [[ -f "$REPO/$resource/package.json" ]]; then
        g1="$resource/package.json"
    elif [[ -f "$REPO/$resource/go.mod" ]]; then
        g1="$resource/go.mod"
    fi
    g2="README.md"
    [[ -f "$REPO/README.md" ]] || g2="Cargo.toml"
    [[ -f "$REPO/$g2" || -f "$REPO/Cargo.toml" ]] || g2="."

    # Types that need mermaid + full sections
    local needs_diagram=0
    case "$ctype" in
        Subsystem|Module|Feature|Entrypoint) needs_diagram=1;;
    esac

    {
        echo "---"
        echo "type: $ctype"
        echo "title: \"$title\""
        echo "description: >"
        echo "  $routing"
        echo "resource: \"$resource\""
        echo "tags: [catalog, auto-emitted]"
        echo "timestamp: \"$TS\""
        echo "x-grounded-paths: [\"$g1\", \"$g2\"]"
        echo "x-hotspot-score: 0.0"
        echo "x-callers: []"
        echo "x-catalog: true"
        echo "---"
        echo ""
        echo "# $title"
        echo ""
        echo "## What it is"
        echo ""
        echo "Catalog entry for **\`${stem}\`** at \`${resource}\` (auto-emitted from the concept plan)."
        echo ""
        echo "$desc"
        echo ""
        echo "Fan-in (plan): ${fan_in}. Enrich this page during deep analysis if it is a hotspot."
        echo ""
        if [[ $needs_diagram -eq 1 ]]; then
            echo "## How it works"
            echo ""
            echo "Primary implementation lives under \`${resource}\`. Prefer \`cargo check -p ${stem}\` /"
            echo "package-local tests when iterating. Full control-flow diagrams belong in a later deep-dive."
            echo ""
            echo '```mermaid'
            echo "flowchart TB"
            echo "  Consumer[Downstream consumers] --> C[\"${stem}\"]"
            echo "  C --> Impl[\"${resource}\"]"
            echo '```'
            echo ""
            echo "## Used by"
            echo ""
            echo "- Parent wiki indexes under \`${section}/\`"
            echo "- Workspace members that depend on \`${stem}\` (see package manifest)"
            echo ""
            echo "## Blast radius"
            echo ""
            echo "Changes to public APIs in \`${resource}\` may break dependent packages in this monorepo."
            echo "Run targeted tests for \`${stem}\` and re-check direct reverse dependents."
            echo ""
            echo "## See also"
            echo ""
            echo "- [section index](index.md)"
            echo "- Repository README / architecture overview"
            echo ""
            echo "## Notes"
            echo ""
            echo "- Emitted by \`okf-emit-catalog.sh\` so completeness does not depend on LLM coverage."
            echo "- Safe to overwrite with a richer concept page on refresh/deep-dive (\`--force\`)."
        else
            echo "## How it works"
            echo ""
            echo "See \`${resource}\` and related package docs."
            echo ""
            echo "## See also"
            echo ""
            echo "- [section index](index.md)"
        fi
    } > "$out"
    wrote=$((wrote+1))
}

while IFS=$'\t' read -r cid ctype resource fan_in required; do
    [[ -z "$cid" ]] && continue
    [[ "$required" == "true" ]] || continue
    write_page "$cid" "${ctype:-Module}" "${resource:-.}" "${fan_in:-0}"
done < <(jq -r '.expected[] | [.concept_id, (.type // "Module"), (.resource // "."), ((.fan_in // 0)|tostring), (.required|tostring)] | @tsv' "$PLAN")

# Ensure section index stubs exist so render/section-indexes can run.
for sec in overview systems features reference entrypoints; do
    dir="$BUNDLE/$sec"
    [[ -d "$dir" ]] || continue
    if [[ ! -f "$dir/index.md" ]]; then
        cat > "$dir/index.md" <<EOF
---
title: "$sec"
---

# $sec

## Concept Map

<!-- CONCEPT-MAP:START -->
<!-- CONCEPT-MAP:END -->
EOF
    fi
done

# Bundle root index if missing — only link section dirs that exist (no dangling rows).
if [[ ! -f "$BUNDLE/index.md" ]]; then
    {
        echo "---"
        echo "type: Subsystem"
        echo "title: Project Wiki"
        echo "description: >"
        echo "  Root index of the project wiki. Start here, then route via the Concept Map."
        echo "resource: ."
        echo "tags: [index]"
        echo "timestamp: \"$TS\""
        echo "okf_version: \"0.1\""
        echo "okf_types_version: \"0.1\""
        echo "---"
        echo ""
        echo "# Project Wiki"
        echo ""
        echo "## Sections"
        echo ""
        echo "| Section | Index |"
        echo "|---------|-------|"
        for sec in overview systems features reference entrypoints; do
            if [[ -d "$BUNDLE/$sec" && -f "$BUNDLE/$sec/index.md" ]]; then
                echo "| $sec | [$sec/index.md]($sec/index.md) |"
            fi
        done
        echo ""
        echo "## Concept Map"
        echo ""
        echo "<!-- CONCEPT-MAP:START -->"
        echo "<!-- CONCEPT-MAP:END -->"
    } > "$BUNDLE/index.md"
fi

echo "okf-emit-catalog: wrote=$wrote skipped_existing=$skipped plan=$PLAN bundle=$BUNDLE"
exit 0
