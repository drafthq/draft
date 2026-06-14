#!/usr/bin/env bash
# Test suite for scripts/tools/okf-bundle.sh (OKF root index for a draft/ bundle)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/okf-bundle.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== okf-bundle.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

D="$FIXTURE/draft"
mkdir -p "$D/tracks/T-001" "$D/graph/okf"
printf -- '---\ntype: Architecture\nproject: "demoproj"\n---\n\n# Arch\n' > "$D/architecture.md"
printf -- '---\ntype: ContextMap\nproject: "demoproj"\n---\n\n# Ctx\n' > "$D/.ai-context.md"
printf -- '---\ntype: Product\nproject: "demoproj"\n---\n\n# Product\n' > "$D/product.md"
printf -- '---\ntype: TrackIndex\n---\n\n# Tracks\n' > "$D/tracks.md"
printf -- '---\ntype: Spec\nproject: "demoproj"\ntrack_id: "T-001"\n---\n\n# Spec\n' > "$D/tracks/T-001/spec.md"
printf '{"title":"Add login"}\n' > "$D/tracks/T-001/metadata.json"
printf -- '# graph\n' > "$D/graph/okf/index.md"   # reserved index: no frontmatter

# --- Missing dir → exit 2 ---
set +e
"$TOOL" --dir "$FIXTURE/nope" >/dev/null 2>&1
rc=$?
set -e
assert "Exit 2 when bundle dir is absent" "$([[ "$rc" == "2" ]] && echo true || echo false)"

# --- Generate index ---
set +e
"$TOOL" --dir "$D" >/dev/null 2>&1
rc=$?
set -e
assert "Generate → exit 0" "$([[ "$rc" == "0" ]] && echo true || echo false)"
assert "index.md written" "$([[ -f "$D/index.md" ]] && echo true || echo false)"
assert "root index.md declares okf_version, not a concept type (§11)" \
    "$(grep -q '^okf_version: "0.1"' "$D/index.md" && ! grep -q '^type:' "$D/index.md" && echo true || echo false)"
assert "index.md derives project name into the heading" \
    "$(grep -q '^# demoproj' "$D/index.md" && echo true || echo false)"
assert "links each present concept (§6 bullet form)" \
    "$(grep -qF '* [Architecture](architecture.md) - ' "$D/index.md" \
        && grep -qF '* [Product](product.md) - ' "$D/index.md" && echo true || echo false)"
assert "omits concepts not present (no workflow.md link)" \
    "$(grep -q 'workflow.md' "$D/index.md" && echo false || echo true)"
assert "links track via metadata title" \
    "$(grep -qF '* [Add login](tracks/T-001/spec.md)' "$D/index.md" && echo true || echo false)"
assert "links the graph sub-bundle" \
    "$(grep -qF '* [Graph bundle](graph/okf/index.md)' "$D/index.md" && echo true || echo false)"

# --- The generated bundle is OKF v0.1 conformant end-to-end ---
set +e
"$ROOT_DIR/scripts/tools/okf-check.sh" --dir "$D" --quiet >/dev/null 2>&1
rc=$?
set -e
assert "generated draft/ bundle passes okf-check" "$([[ "$rc" == "0" ]] && echo true || echo false)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
