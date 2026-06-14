#!/usr/bin/env bash
# Test suite for scripts/tools/okf-check.sh (OKF v0.1 §9 conformance checker)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOL="$ROOT_DIR/scripts/tools/okf-check.sh"

source "$SCRIPT_DIR/test-helpers.sh"

echo "=== okf-check.sh tests ==="
echo ""

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# --- Missing dir → exit 2 ---
set +e
"$TOOL" --dir "$FIXTURE/nope" >/dev/null 2>&1
rc=$?
set -e
assert "Exit 2 when dir is absent" "$([[ "$rc" == "2" ]] && echo true || echo false)"

# --- Conformant bundle → exit 0 ---
G="$FIXTURE/good"
mkdir -p "$G/sub"
printf -- '---\nokf_version: "0.1"\n---\n\n# Root\n\n# Items\n\n* [A](a.md) - alpha\n' > "$G/index.md"
printf -- '---\ntype: Concept\ntitle: A\n---\n\n# A\n' > "$G/a.md"
printf -- '# Sub listing\n\n* [B](b.md) - beta\n' > "$G/sub/index.md"            # nested index: no frontmatter
printf -- '---\ntype: Concept\n---\n\n# B\n' > "$G/sub/b.md"
printf -- '# Update Log\n\n## 2026-05-01\n* **Creation**: seeded.\n' > "$G/log.md"
set +e
out="$("$TOOL" --dir "$G" 2>&1)"
rc=$?
set -e
assert "Conformant bundle → exit 0" "$([[ "$rc" == "0" ]] && echo true || echo false)"
assert "Reports conformant summary" "$(echo "$out" | grep -q 'conformant' && echo true || echo false)"

# --- Violations: each class flagged, exit 1 ---
B="$FIXTURE/bad"
mkdir -p "$B/sub"
printf -- '---\ntype: Repository\n---\n\n# Root\n' > "$B/index.md"               # root index: non-okf_version key
printf -- '# no frontmatter concept\n' > "$B/nofm.md"                             # §9.1
printf -- '---\ntitle: X\n---\n\n# no type\n' > "$B/notype.md"                    # §9.2
printf -- '---\ntype: Concept\n---\n\n# nested index has frontmatter\n' > "$B/sub/index.md"  # §6
printf -- '# Log\n\n## May 2026\n* bad date heading\n' > "$B/log.md"             # §7
set +e
out="$("$TOOL" --dir "$B" 2>&1)"
rc=$?
set -e
assert "Non-conformant bundle → exit 1" "$([[ "$rc" == "1" ]] && echo true || echo false)"
assert "Flags missing frontmatter (§9.1)" \
    "$(echo "$out" | grep -q 'nofm.md.*frontmatter' && echo true || echo false)"
assert "Flags missing type (§9.2)" \
    "$(echo "$out" | grep -q "notype.md.*type" && echo true || echo false)"
assert "Flags nested index.md frontmatter (§6)" \
    "$(echo "$out" | grep -q 'sub/index.md.*frontmatter' && echo true || echo false)"
assert "Flags non-okf_version key in root index (§11)" \
    "$(echo "$out" | grep -q 'index.md.*okf_version' && echo true || echo false)"
assert "Flags non-ISO log date heading (§7)" \
    "$(echo "$out" | grep -q 'log.md.*ISO' && echo true || echo false)"

# --- --quiet suppresses per-file lines but keeps exit code ---
set +e
qout="$("$TOOL" --dir "$B" --quiet 2>&1)"
rc=$?
set -e
assert "--quiet still exits 1 on violations" "$([[ "$rc" == "1" ]] && echo true || echo false)"
assert "--quiet suppresses FAIL lines" \
    "$(echo "$qout" | grep -q '^FAIL' && echo false || echo true)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
