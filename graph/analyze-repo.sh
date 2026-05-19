#!/bin/bash
# =============================================================================
# analyze-repo.sh — Comprehensive codebase analysis for Draft knowledge graph
# Usage: ./analyze-repo.sh <directory> [--output <report.md>]
# =============================================================================

set -uo pipefail

DIR="${1:-.}"
OUTPUT="${3:-repo-analysis-report.md}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

# Resolve absolute path
DIR=$(realpath "$DIR")
REPO_NAME=$(basename "$DIR")

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log() { echo -e "${CYAN}[analyze]${NC} $1"; }
done_() { echo -e "${GREEN}[done]${NC} $1"; }
warn() { echo -e "${YELLOW}[warn]${NC} $1"; }

# =============================================================================
# REPORT BUILDER
# =============================================================================
REPORT="$TMPDIR_WORK/report.md"

h1() { echo -e "\n# $1\n" >> "$REPORT"; }
h2() { echo -e "\n## $1\n" >> "$REPORT"; }
h3() { echo -e "\n### $1\n" >> "$REPORT"; }
row() { echo "$1" >> "$REPORT"; }
blank() { echo "" >> "$REPORT"; }
code_start() { echo '```' >> "$REPORT"; }
code_end() { echo '```' >> "$REPORT"; }
table_header() { echo "$1" >> "$REPORT"; echo "$2" >> "$REPORT"; }

# =============================================================================
# SECTION 1: OVERVIEW
# =============================================================================
log "Collecting overview..."

TOTAL_FILES=$(find "$DIR" -type f | wc -l)
TOTAL_DIRS=$(find "$DIR" -type d | wc -l)
TOTAL_SIZE=$(du -sh "$DIR" 2>/dev/null | cut -f1)
TOTAL_LINES=$(find "$DIR" -type f \( -name "*.cc" -o -name "*.cpp" -o -name "*.c" \
  -o -name "*.h" -o -name "*.hpp" -o -name "*.go" -o -name "*.py" \
  -o -name "*.java" -o -name "*.proto" \) \
  -exec cat {} \; 2>/dev/null | wc -l)

cat >> "$REPORT" << EOF
# Codebase Analysis Report
**Repository:** \`$REPO_NAME\`
**Path:** \`$DIR\`
**Generated:** $TIMESTAMP

---

## 1. Overview

| Metric | Value |
|--------|-------|
| Total Files | $TOTAL_FILES |
| Total Directories | $TOTAL_DIRS |
| Total Size | $TOTAL_SIZE |
| Total Source Lines | $(printf "%'d" $TOTAL_LINES) |

EOF

done_ "Overview"

# =============================================================================
# SECTION 2: FILE TYPE DISTRIBUTION
# =============================================================================
log "Analyzing file type distribution..."

h2 "2. File Type Distribution"

row "### 2.1 By Extension (all types)"
blank
row '```'
find "$DIR" -type f | \
  sed 's/.*\.//' | \
  tr '[:upper:]' '[:lower:]' | \
  sort | uniq -c | sort -rn | head -40 >> "$REPORT"
row '```'
blank

# =============================================================================
# DYNAMIC LANGUAGE DETECTION — top 10 by file count
# Maps extension → canonical language name + category + LOC divisor
# =============================================================================

# Build extension frequency table (reuse what section 2.1 already computed)
EXT_TABLE="$TMPDIR_WORK/ext_table.txt"
find "$DIR" -type f | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]' | \
  grep -v "^/" | sort | uniq -c | sort -rn > "$EXT_TABLE"

# Known extension → "Language|Category|avg_fn_lines" mappings
declare -A EXT_LANG
EXT_LANG[cc]="C++ Source|source|30"
EXT_LANG[cpp]="C++ Source|source|30"
EXT_LANG[cxx]="C++ Source|source|30"
EXT_LANG[c]="C Source|source|30"
EXT_LANG[h]="C/C++ Header|header|20"
EXT_LANG[hpp]="C/C++ Header|header|20"
EXT_LANG[hxx]="C/C++ Header|header|20"
EXT_LANG[go]="Go|source|20"
EXT_LANG[py]="Python|source|25"
EXT_LANG[java]="Java|source|25"
EXT_LANG[rs]="Rust|source|25"
EXT_LANG[js]="JavaScript|source|25"
EXT_LANG[ts]="TypeScript|source|25"
EXT_LANG[tsx]="TypeScript|source|25"
EXT_LANG[jsx]="JavaScript|source|25"
EXT_LANG[rb]="Ruby|source|20"
EXT_LANG[swift]="Swift|source|25"
EXT_LANG[kt]="Kotlin|source|25"
EXT_LANG[scala]="Scala|source|25"
EXT_LANG[cs]="C#|source|25"
EXT_LANG[proto]="Protobuf|api|0"
EXT_LANG[thrift]="Thrift|api|0"
EXT_LANG[yaml]="YAML|config|0"
EXT_LANG[yml]="YAML|config|0"
EXT_LANG[json]="JSON|config|0"
EXT_LANG[toml]="TOML|config|0"
EXT_LANG[xml]="XML|config|0"
EXT_LANG[md]="Markdown|docs|0"
EXT_LANG[sh]="Shell|script|0"
EXT_LANG[bash]="Shell|script|0"
EXT_LANG[cmake]="CMake|build|0"
EXT_LANG[mk]="Makefile|build|0"
EXT_LANG[bzl]="Bazel|build|0"
EXT_LANG[bazel]="Bazel|build|0"
EXT_LANG[sql]="SQL|data|0"
EXT_LANG[tf]="Terraform|infra|0"

# Extract top-10 extensions with known language mappings
TOP10_EXTS="$TMPDIR_WORK/top10.txt"
> "$TOP10_EXTS"
COUNT=0
while IFS= read -r line; do
  CNT=$(echo "$line" | awk '{print $1}')
  EXT=$(echo "$line" | awk '{print $2}')
  if [ -n "${EXT_LANG[$EXT]+x}" ]; then
    echo "$CNT $EXT ${EXT_LANG[$EXT]}" >> "$TOP10_EXTS"
    COUNT=$(( COUNT + 1 ))
    [ $COUNT -ge 10 ] && break
  fi
done < "$EXT_TABLE"

# Always-needed counts (used throughout the rest of the script)
get_count() { grep -E "^[[:space:]]*[0-9]+ $1$" "$EXT_TABLE" | awk '{print $1}' | head -1 || echo 0; }

CC_COUNT=$(( $(get_count cc) + $(get_count cpp) + $(get_count cxx) ))
C_COUNT=$(get_count c)
H_COUNT=$(( $(get_count h) + $(get_count hpp) + $(get_count hxx) ))
GO_COUNT=$(get_count go)
PY_COUNT=$(get_count py)
JAVA_COUNT=$(get_count java)
PROTO_COUNT=$(get_count proto)
JS_COUNT=$(( $(get_count js) + $(get_count jsx) ))
TS_COUNT=$(( $(get_count ts) + $(get_count tsx) ))
RUST_COUNT=$(get_count rs)
YAML_COUNT=$(( $(get_count yaml) + $(get_count yml) ))
JSON_COUNT=$(get_count json)
CMAKE_COUNT=$(find "$DIR" -type f \( -name "CMakeLists.txt" -o -name "*.cmake" \) | wc -l)
MAKE_COUNT=$(find "$DIR" -type f \( -name "Makefile" -o -name "*.mk" -o -name "makefile" \) | wc -l)
BAZEL_COUNT=$(find "$DIR" -type f \( -name "BUILD" -o -name "*.bazel" -o -name "*.bzl" \) | wc -l)
TEST_COUNT=$(find "$DIR" -type f \( -name "*test*" -o -name "*spec*" -o -name "*mock*" \) | wc -l)
GEN_COUNT=$(find "$DIR" -type f \( -name "*.pb.cc" -o -name "*.pb.h" -o -name "*_generated*" -o -name "*.pb.go" -o -name "*pb2.py" \) | wc -l)
MD_COUNT=$(get_count md)
SH_COUNT=$(( $(get_count sh) + $(get_count bash) ))

# Write top-10 dynamic table
h3 "2.2 Top 10 Languages by File Count"
blank
row "| Rank | Extension | Language | Files | Category |"
row "|------|-----------|----------|-------|----------|"

RANK=1
while IFS=' ' read -r CNT EXT LANG_INFO; do
  LANG=$(echo "$LANG_INFO" | cut -d'|' -f1)
  CAT=$(echo "$LANG_INFO" | cut -d'|' -f2)
  row "| $RANK | .$EXT | $LANG | $CNT | $CAT |"
  RANK=$(( RANK + 1 ))
done < "$TOP10_EXTS"
blank

# Write full fixed category table (always useful for graph decisions)
cat >> "$REPORT" << EOF
### 2.3 Full Category Breakdown

| Category | Type | Files | Graph Relevance |
|----------|------|-------|-----------------|
| C++ Source | .cc/.cpp/.cxx | $CC_COUNT | ✅ index (include graph) |
| C/C++ Headers | .h/.hpp | $H_COUNT | ✅ index (declarations) |
| C Source | .c | $C_COUNT | ✅ index |
| Go | .go | $GO_COUNT | ✅ tree-sitter |
| Python | .py | $PY_COUNT | ✅ tree-sitter |
| Java | .java | $JAVA_COUNT | ✅ tree-sitter / SCIP |
| Rust | .rs | $RUST_COUNT | ✅ tree-sitter |
| JavaScript | .js/.jsx | $JS_COUNT | ✅ tree-sitter |
| TypeScript | .ts/.tsx | $TS_COUNT | ✅ tree-sitter |
| Protobuf | .proto | $PROTO_COUNT | ✅ proto-parser (API surface) |
| YAML/JSON | config | $(( YAML_COUNT + JSON_COUNT )) | ⚠️ config only |
| Build files | cmake/make/bazel | $(( CMAKE_COUNT + MAKE_COUNT + BAZEL_COUNT )) | ⚠️ build graph only |
| Test files | *test*/*spec* | $TEST_COUNT | ⚠️ separate index |
| Generated | *.pb.* | $GEN_COUNT | ❌ exclude |
| Markdown | .md | $MD_COUNT | ⚠️ docs only |
| Shell | .sh | $SH_COUNT | ❌ skip |

EOF

done_ "File type distribution"

# =============================================================================
# SECTION 3: SIZE BREAKDOWN
# =============================================================================
log "Analyzing size breakdown..."

h2 "3. Size Breakdown"

h3 "3.1 Top-level Directories by Size"
blank
row '```'
du -sh "$DIR"/*/ 2>/dev/null | sort -rh | head -20 >> "$REPORT"
row '```'
blank

h3 "3.2 Source Lines by Language (detected languages only)"
blank

# Helper: count lines for a set of extensions
lines_for_exts() {
  local pattern="$1"
  find "$DIR" -type f $pattern -exec cat {} \; 2>/dev/null | wc -l
}

row "| Language | Extension | Files | Lines | Est. Symbols |"
row "|----------|-----------|-------|-------|--------------|"

# Only emit rows for languages actually present (file count > 0)
declare -A LANG_LINES # store for later use

emit_lang_row() {
  local label="$1" exts="$2" files="$3" avg_lines="$4" note="$5"
  [ "$files" -eq 0 ] && return
  local find_args=""
  IFS=',' read -ra EXT_LIST <<< "$exts"
  for e in "${EXT_LIST[@]}"; do
    find_args="$find_args -o -name \"*.$e\""
  done
  find_args="${find_args# -o }"
  local lines
  lines=$(eval "find \"$DIR\" -type f \( $find_args \) -exec cat {} \;" 2>/dev/null | wc -l)
  LANG_LINES[$label]=$lines
  local est_sym=""
  if [ "$avg_lines" -gt 0 ]; then
    est_sym="~$(( lines / avg_lines ))"
  else
    est_sym="$note"
  fi
  row "| $label | .$exts | $files | $(printf "%'d" $lines) | $est_sym |"
}

emit_lang_row "C++ Source" "cc,cpp,cxx" "$CC_COUNT" 30 ""
emit_lang_row "C/C++ Header" "h,hpp,hxx" "$H_COUNT" 20 "decls"
emit_lang_row "C Source" "c" "$C_COUNT" 30 ""
emit_lang_row "Go" "go" "$GO_COUNT" 20 ""
emit_lang_row "Python" "py" "$PY_COUNT" 25 ""
emit_lang_row "Java" "java" "$JAVA_COUNT" 25 ""
emit_lang_row "Rust" "rs" "$RUST_COUNT" 25 ""
emit_lang_row "JavaScript" "js,jsx" "$JS_COUNT" 25 ""
emit_lang_row "TypeScript" "ts,tsx" "$TS_COUNT" 25 ""
emit_lang_row "Protobuf" "proto" "$PROTO_COUNT" 0 "service defs"

blank

# Capture CC_LINES for use in later sections
CC_LINES=${LANG_LINES["C++ Source"]:-0}
H_LINES=${LANG_LINES["C/C++ Header"]:-0}
GO_LINES=${LANG_LINES["Go"]:-0}
PY_LINES=${LANG_LINES["Python"]:-0}

done_ "Size breakdown"

# =============================================================================
# SECTION 4: MODULE STRUCTURE
# =============================================================================
log "Analyzing module structure..."

h2 "4. Module Structure (Top-level Directories)"
blank

# Build dynamic header based on which languages are present
MOD_HEADER="| Module | Size"
MOD_SEP="|--------|------"
[ $CC_COUNT -gt 0 ] && { MOD_HEADER="$MOD_HEADER | .cc"; MOD_SEP="$MOD_SEP|-----"; }
[ $H_COUNT -gt 0 ] && { MOD_HEADER="$MOD_HEADER | .h"; MOD_SEP="$MOD_SEP|----"; }
[ $GO_COUNT -gt 0 ] && { MOD_HEADER="$MOD_HEADER | .go"; MOD_SEP="$MOD_SEP|-----"; }
[ $PY_COUNT -gt 0 ] && { MOD_HEADER="$MOD_HEADER | .py"; MOD_SEP="$MOD_SEP|-----"; }
[ $JAVA_COUNT -gt 0 ] && { MOD_HEADER="$MOD_HEADER | .java"; MOD_SEP="$MOD_SEP|------"; }
[ $RUST_COUNT -gt 0 ] && { MOD_HEADER="$MOD_HEADER | .rs"; MOD_SEP="$MOD_SEP|-----"; }
[ $TS_COUNT -gt 0 ] && { MOD_HEADER="$MOD_HEADER | .ts"; MOD_SEP="$MOD_SEP|-----"; }
[ $PROTO_COUNT -gt 0 ] && { MOD_HEADER="$MOD_HEADER | .proto"; MOD_SEP="$MOD_SEP|-------"; }
MOD_HEADER="$MOD_HEADER | Tests | Notes |"
MOD_SEP="$MOD_SEP|-------|-------|"

row "$MOD_HEADER"
row "$MOD_SEP"

for subdir in "$DIR"/*/; do
  [ -d "$subdir" ] || continue
  MOD=$(basename "$subdir")
  MOD_SIZE=$(du -sh "$subdir" 2>/dev/null | cut -f1)
  MOD_TEST=$(find "$subdir" \( -name "*test*" -o -name "*spec*" \) 2>/dev/null | wc -l)
  NOTE=""

  ROW="| $MOD | $MOD_SIZE"
  if [ $CC_COUNT -gt 0 ]; then
    V=$(find "$subdir" \( -name "*.cc" -o -name "*.cpp" \) 2>/dev/null | wc -l)
    ROW="$ROW | $V"
  fi
  if [ $H_COUNT -gt 0 ]; then
    V=$(find "$subdir" \( -name "*.h" -o -name "*.hpp" \) 2>/dev/null | wc -l)
    ROW="$ROW | $V"
  fi
  if [ $GO_COUNT -gt 0 ]; then
    V=$(find "$subdir" -name "*.go" 2>/dev/null | wc -l)
    ROW="$ROW | $V"
  fi
  if [ $PY_COUNT -gt 0 ]; then
    V=$(find "$subdir" -name "*.py" 2>/dev/null | wc -l)
    ROW="$ROW | $V"
  fi
  if [ $JAVA_COUNT -gt 0 ]; then
    V=$(find "$subdir" -name "*.java" 2>/dev/null | wc -l)
    ROW="$ROW | $V"
  fi
  if [ $RUST_COUNT -gt 0 ]; then
    V=$(find "$subdir" -name "*.rs" 2>/dev/null | wc -l)
    ROW="$ROW | $V"
  fi
  if [ $TS_COUNT -gt 0 ]; then
    V=$(find "$subdir" \( -name "*.ts" -o -name "*.tsx" \) 2>/dev/null | wc -l)
    ROW="$ROW | $V"
  fi
  if [ $PROTO_COUNT -gt 0 ]; then
    V=$(find "$subdir" -name "*.proto" 2>/dev/null | wc -l)
    ROW="$ROW | $V"
    [ $V -gt 0 ] && NOTE="has-API"
  fi
  [ $MOD_TEST -eq 0 ] && NOTE="${NOTE:+$NOTE |}no-tests"
  ROW="$ROW | $MOD_TEST | $NOTE |"
  row "$ROW"
done

blank
done_ "Module structure"

# =============================================================================
# SECTION 5: DEPENDENCY GRAPH (#include analysis)
# =============================================================================
log "Analyzing #include dependencies..."

h2 "5. Dependency Graph (#include Analysis)"

h3 "5.1 External Dependencies (what bridge/ depends on)"
blank
row "Which external modules/libraries are included most frequently:"
blank
row '```'
grep -r "^#include" "$DIR" --include="*.h" --include="*.cc" -h 2>/dev/null | \
  grep '"' | \
  sed 's/.*"\(.*\)".*/\1/' | \
  cut -d'/' -f1 | \
  grep -v "^$" | \
  sort | uniq -c | sort -rn | head -30 >> "$REPORT"
row '```'
blank

h3 "5.2 Internal Module Dependencies (bridge/ sub-modules)"
blank
row "Which internal modules include from other internal modules:"
blank
row '```'

# Extract inter-module include pairs
grep -rn "^#include \"$(basename $DIR)/" "$DIR" \
  --include="*.h" --include="*.cc" 2>/dev/null | \
  sed "s|$DIR/\([^/]*\)/.*#include \"$(basename $DIR)/\([^/]*\)/.*|\1 → \2|" | \
  grep " → " | \
  sort | uniq -c | sort -rn | head -30 >> "$REPORT"

row '```'
blank

h3 "5.3 Most Included Internal Headers (high fan-in = critical files)"
blank
row '```'
grep -r "^#include" "$DIR" --include="*.cc" --include="*.h" -h 2>/dev/null | \
  grep '"' | \
  sed 's/.*"\(.*\)".*/\1/' | \
  grep "$(basename $DIR)" | \
  sort | uniq -c | sort -rn | head -30 >> "$REPORT"
row '```'
blank

h3 "5.4 System / Third-party Dependencies (<angle bracket> includes)"
blank
row '```'
grep -r "^#include" "$DIR" --include="*.cc" --include="*.h" -h 2>/dev/null | \
  grep '<' | \
  sed 's/.*<\(.*\)>.*/\1/' | \
  cut -d'/' -f1 | \
  grep -v "^$" | \
  sort | uniq -c | sort -rn | head -30 >> "$REPORT"
row '```'
blank

done_ "Dependency graph"

# =============================================================================
# SECTION 6: COMPLEXITY HOTSPOTS
# =============================================================================
log "Finding complexity hotspots..."

h2 "6. Complexity Hotspots"

h3 "6.1 Largest Source Files (by line count)"
blank
row "| Lines | File |"
row "|-------|------|"

find "$DIR" -type f \( -name "*.cc" -o -name "*.cpp" -o -name "*.h" -o -name "*.go" \) \
  -exec wc -l {} \; 2>/dev/null | \
  sort -rn | head -30 | \
  grep -v "^0 " | \
  awk '{printf "| %s | `%s` |\n", $1, $2}' >> "$REPORT"

blank

h3 "6.2 Files > 1000 Lines (complexity risk)"
blank
LARGE_FILES=$(find "$DIR" -type f \( -name "*.cc" -o -name "*.cpp" -o -name "*.h" \) \
  -exec wc -l {} \; 2>/dev/null | awk '$1 > 1000' | wc -l)
XLARGE_FILES=$(find "$DIR" -type f \( -name "*.cc" -o -name "*.cpp" -o -name "*.h" \) \
  -exec wc -l {} \; 2>/dev/null | awk '$1 > 2000' | wc -l)
XXLARGE_FILES=$(find "$DIR" -type f \( -name "*.cc" -o -name "*.cpp" -o -name "*.h" \) \
  -exec wc -l {} \; 2>/dev/null | awk '$1 > 5000' | wc -l)

cat >> "$REPORT" << EOF
| Threshold | Count | Risk |
|-----------|-------|------|
| > 500 lines | $(find "$DIR" -type f \( -name "*.cc" -o -name "*.cpp" -o -name "*.h" \) -exec wc -l {} \; 2>/dev/null | awk '$1>500' | wc -l) | Medium |
| > 1000 lines | $LARGE_FILES | High |
| > 2000 lines | $XLARGE_FILES | Very High |
| > 5000 lines | $XXLARGE_FILES | Critical |

EOF

h3 "6.3 Hotspot Files by Module"
blank
row '```'
for subdir in "$DIR"/*/; do
  [ -d "$subdir" ] || continue
  MOD=$(basename "$subdir")
  LARGE=$(find "$subdir" -type f \( -name "*.cc" -o -name "*.h" \) \
    -exec wc -l {} \; 2>/dev/null | awk '$1>1000' | wc -l)
  [ $LARGE -gt 0 ] && echo " $MOD: $LARGE files > 1000 lines" >> "$REPORT"
done
row '```'
blank

done_ "Complexity hotspots"

# =============================================================================
# SECTION 7: PROTO / API SURFACE
# =============================================================================
log "Analyzing protobuf definitions..."

h2 "7. Protobuf / API Surface"

if [ $PROTO_COUNT -gt 0 ]; then
  h3 "7.1 Proto Files by Module"
  blank
  row '```'
  find "$DIR" -name "*.proto" | \
    sed "s|$DIR/\([^/]*\)/.*|\1|" | \
    sort | uniq -c | sort -rn >> "$REPORT"
  row '```'
  blank

  h3 "7.2 Service Definitions"
  blank
  row '```'
  grep -r "^service " "$DIR" --include="*.proto" -h 2>/dev/null | \
    sort | uniq >> "$REPORT"
  row '```'
  blank

  h3 "7.3 RPC Methods (API surface)"
  blank
  RPC_COUNT=$(grep -r "^\s*rpc " "$DIR" --include="*.proto" 2>/dev/null | wc -l)
  row "Total RPC methods: **$RPC_COUNT**"
  blank
  row '```'
  grep -r "^\s*rpc " "$DIR" --include="*.proto" -h 2>/dev/null | \
    sed 's/^\s*//' | \
    sort | head -50 >> "$REPORT"
  row '```'
  blank

  h3 "7.4 Key Message Types"
  blank
  row '```'
  grep -r "^message " "$DIR" --include="*.proto" -h 2>/dev/null | \
    sort | uniq -c | sort -rn | head -30 >> "$REPORT"
  row '```'
  blank
else
  row "_No .proto files found._"
  blank
fi

done_ "Proto analysis"

# =============================================================================
# SECTION 8: TEST COVERAGE MAP
# =============================================================================
log "Mapping test coverage..."

h2 "8. Test Coverage Map"

h3 "8.1 Test Files by Module"
blank
row "| Module | Test Files | Source Files | Coverage Ratio |"
row "|--------|-----------|--------------|----------------|"

for subdir in "$DIR"/*/; do
  [ -d "$subdir" ] || continue
  MOD=$(basename "$subdir")
  SRC=$(find "$subdir" -name "*.cc" -not -name "*test*" 2>/dev/null | wc -l)
  TST=$(find "$subdir" \( -name "*test*" -o -name "*_test.cc" -o -name "*Test.cc" \) \
    -name "*.cc" 2>/dev/null | wc -l)
  [ $SRC -eq 0 ] && continue
  RATIO=$(awk "BEGIN {printf \"%.0f%%\", ($TST/$SRC)*100}")
  row "| $MOD | $TST | $SRC | $RATIO |"
done

blank

h3 "8.2 Test Directories"
blank
row '```'
find "$DIR" -type d \( -name "test" -o -name "tests" -o -name "test_data" \) | \
  sed "s|$DIR/||" | sort >> "$REPORT"
row '```'
blank

h3 "8.3 Modules with Zero Test Files"
blank
row '```'
for subdir in "$DIR"/*/; do
  [ -d "$subdir" ] || continue
  MOD=$(basename "$subdir")
  TST=$(find "$subdir" -name "*test*" 2>/dev/null | wc -l)
  [ $TST -eq 0 ] && echo " $MOD (no test files)" >> "$REPORT"
done
row '```'
blank

done_ "Test coverage map"

# =============================================================================
# SECTION 9: SYMBOL DENSITY
# =============================================================================
log "Estimating symbol density..."

h2 "9. Symbol Density Estimates"

h3 "9.1 C++ Symbol Counts"
blank

CPP_CLASSES=$(grep -r "^class \|^\s*class " "$DIR" --include="*.h" --include="*.cc" -h 2>/dev/null | \
  grep -v "//" | grep -v "^\s*//" | wc -l)
CPP_STRUCTS=$(grep -r "^struct \|^\s*struct " "$DIR" --include="*.h" -h 2>/dev/null | \
  grep -v "//" | wc -l)
CPP_NAMESPACES=$(grep -r "^namespace " "$DIR" --include="*.h" --include="*.cc" -h 2>/dev/null | \
  sort | uniq | wc -l)
CPP_ENUMS=$(grep -r "^enum \|^\s*enum " "$DIR" --include="*.h" -h 2>/dev/null | \
  grep -v "//" | wc -l)
CPP_TYPEDEFS=$(grep -r "^typedef \|^using " "$DIR" --include="*.h" -h 2>/dev/null | \
  grep -v "//" | wc -l)

cat >> "$REPORT" << EOF
| Symbol Type | Count | Notes |
|-------------|-------|-------|
| Classes | $CPP_CLASSES | from .h + .cc |
| Structs | $CPP_STRUCTS | from .h |
| Namespaces | $CPP_NAMESPACES | unique |
| Enums | $CPP_ENUMS | from .h |
| Typedefs/Using | $CPP_TYPEDEFS | from .h |
| Est. Functions (LOC/30) | ~$(( CC_LINES / 30 )) | rough estimate |

EOF

h3 "9.2 Go Symbol Counts"
blank
if [ "$GO_COUNT" -gt 0 ]; then
  GO_FUNCS=$(grep -r "^func " "$DIR" --include="*.go" -h 2>/dev/null | wc -l)
  GO_TYPES=$(grep -r "^type " "$DIR" --include="*.go" -h 2>/dev/null | wc -l)
  GO_INTERFACES=$(grep -r "^type.*interface" "$DIR" --include="*.go" -h 2>/dev/null | wc -l)
  cat >> "$REPORT" << EOF
| Symbol Type | Count |
|-------------|-------|
| Functions | $GO_FUNCS |
| Types | $GO_TYPES |
| Interfaces | $GO_INTERFACES |

EOF
else
  GO_FUNCS=0
  row "_No Go files found._"
  blank
fi

h3 "9.3 Python Symbol Counts"
blank
if [ "$PY_COUNT" -gt 0 ]; then
  PY_FUNCS=$(grep -r "^def \|^ def " "$DIR" --include="*.py" -h 2>/dev/null | wc -l)
  PY_CLASSES=$(grep -r "^class " "$DIR" --include="*.py" -h 2>/dev/null | wc -l)
  cat >> "$REPORT" << EOF
| Symbol Type | Count |
|-------------|-------|
| Functions/methods | $PY_FUNCS |
| Classes | $PY_CLASSES |

EOF
else
  row "_No Python files found._"
  blank
fi

h3 "9.4 Java Symbol Counts"
blank
if [ "$JAVA_COUNT" -gt 0 ]; then
  JAVA_CLASSES=$(grep -r "^public class \|^class \|^public interface " "$DIR" --include="*.java" -h 2>/dev/null | wc -l)
  JAVA_METHODS=$(grep -r "^\s*public \|^\s*private \|^\s*protected " "$DIR" --include="*.java" -h 2>/dev/null | grep "(" | wc -l)
  cat >> "$REPORT" << EOF
| Symbol Type | Count |
|-------------|-------|
| Classes/Interfaces | $JAVA_CLASSES |
| Methods (est.) | $JAVA_METHODS |

EOF
else
  row "_No Java files found._"
  blank
fi

h3 "9.6 Namespace Distribution (C++)"
blank
row '```'
grep -r "^namespace " "$DIR" --include="*.h" --include="*.cc" -h 2>/dev/null | \
  grep -v "//" | \
  sed 's/namespace \([a-zA-Z_0-9]*\).*/\1/' | \
  sort | uniq -c | sort -rn | head -20 >> "$REPORT"
row '```'
blank

done_ "Symbol density"

# =============================================================================
# SECTION 10: BUILD SYSTEM ANALYSIS
# =============================================================================
log "Analyzing build system..."

h2 "10. Build System"

h3 "10.1 Build Files by Type"
blank
cat >> "$REPORT" << EOF
| Build System | Files |
|-------------|-------|
| CMake | $CMAKE_COUNT |
| Makefile | $MAKE_COUNT |
| Bazel | $BAZEL_COUNT |

EOF

h3 "10.2 Build Files by Module"
blank
row '```'
for subdir in "$DIR"/*/; do
  [ -d "$subdir" ] || continue
  MOD=$(basename "$subdir")
  BLD=$(find "$subdir" \( -name "CMakeLists.txt" -o -name "Makefile" -o -name "BUILD" -o -name "*.bzl" \) 2>/dev/null | wc -l)
  [ $BLD -gt 0 ] && echo " $MOD: $BLD build files" >> "$REPORT"
done
row '```'
blank

done_ "Build system"

# =============================================================================
# SECTION 11: GRAPH FEASIBILITY ASSESSMENT
# =============================================================================
log "Computing graph feasibility..."

h2 "11. Knowledge Graph Feasibility Assessment"

# Estimate graph sizes
EST_NODES=$(( CPP_CLASSES + CPP_STRUCTS + GO_FUNCS + PROTO_COUNT * 5 + CC_COUNT ))
EST_EDGES=$(find "$DIR" -type f \( -name "*.cc" -o -name "*.h" \) \
  -exec grep -c "^#include" {} \; 2>/dev/null | \
  awk '{s+=$1} END {print s}')
EST_NODES_JSONL=$(( EST_NODES * 200 / 1024 / 1024 )) # ~200 bytes per node
EST_EDGES_JSONL=$(( EST_EDGES * 150 / 1024 / 1024 )) # ~150 bytes per edge

cat >> "$REPORT" << EOF
### 11.1 Estimated Graph Size

| Metric | Estimate | Implication |
|--------|----------|-------------|
| Total nodes | ~$EST_NODES | |
| Total edges (#include) | ~$EST_EDGES | |
| nodes.jsonl size | ~${EST_NODES_JSONL}MB | |
| edges.jsonl size | ~${EST_EDGES_JSONL}MB | |
| Total graph size | ~$(( EST_NODES_JSONL + EST_EDGES_JSONL ))MB | |

### 11.2 Extraction Strategy Recommendation

| Layer | Method | Accuracy | Effort |
|-------|--------|----------|--------|
| Module graph (dir-level) | Directory structure | 100% | Trivial |
| Include dependencies | grep #include | 100% | Low |
| Proto API surface | Proto parser | 100% | Low |
| C++ classes/structs | grep patterns | ~85% | Low |
| Go functions/types | Tree-sitter | ~95% | Medium |
| C++ function calls | Requires clang | ~99% | High |
| C++ template resolution | Requires clang | ~95% | Very High |

### 11.3 Recommended Graph Levels

**Level 1 — Module Graph** (always load, tiny)
- Nodes: $(ls -d "$DIR"/*/ 2>/dev/null | wc -l) modules
- Edges: inter-module #include count
- Size: < 10KB
- LLM consumable: ✅ always

**Level 2 — File Graph per Module** (load on demand)
- Nodes: avg $(( CC_COUNT / $(ls -d "$DIR"/*/ 2>/dev/null | wc -l) )) files per module
- Edges: #include edges within module
- Size: ~1-3MB per module
- LLM consumable: ✅ per-module session

**Level 3 — Proto API Index** (always load, small)
- Nodes: $PROTO_COUNT proto files, $RPC_COUNT RPCs
- Size: < 100KB
- LLM consumable: ✅ always

**Level 4 — Symbol Index** (on demand, for bughunt/validate)
- Nodes: ~$EST_NODES classes/structs
- Size: ~${EST_NODES_JSONL}MB
- LLM consumable: ⚠️ slice required

### 11.4 Files to EXCLUDE from Graph

EOF

row '```'
echo "Exclusion patterns:" >> "$REPORT"
echo " *.pb.cc *.pb.h — protobuf generated" >> "$REPORT"
echo " *_generated.* — generated code" >> "$REPORT"
echo " */test/* *_test.cc — test files (index separately)" >> "$REPORT"
echo " */third_party/* — vendored deps" >> "$REPORT"
echo " */vendor/* — vendored deps" >> "$REPORT"
echo " *.json *.yaml *.csv — data files" >> "$REPORT"
echo " *.pem *.key *.crt — certs/keys" >> "$REPORT"
echo "Generated count in repo: $GEN_COUNT files" >> "$REPORT"
row '```'
blank

done_ "Feasibility assessment"

# =============================================================================
# SECTION 12: DRAFT GRAPH CONFIG RECOMMENDATION
# =============================================================================
log "Generating Draft graph config..."

h2 "12. Recommended Draft Graph Configuration"

cat >> "$REPORT" << 'CONFIGEOF'
Based on this analysis, the recommended \`draft/graph/schema.yaml\`:

CONFIGEOF

row '```yaml'
cat >> "$REPORT" << EOF
# draft/graph/schema.yaml
repo: $REPO_NAME
analyzed: $TIMESTAMP

indexer:
  cpp:
    method: include-graph # grep-based, 100% accurate
    symbol_extraction: regex # class/struct/namespace patterns
    exclude_generated: true
    exclude_patterns:
      - "*.pb.cc"
      - "*.pb.h"
      - "*_generated*"
      - "*/test/*"
      - "*_test.cc"
  go:
    method: tree-sitter # accurate for Go
  proto:
    method: proto-parser # dedicated proto parser

graph_levels:
  module_graph:
    always_load: true
    nodes: directory # top-level dirs = modules
    edges: include_cross_module
  file_graph:
    load_on_demand: true # per module session
    nodes: source_files
    edges: include_within_module
  proto_index:
    always_load: true
    nodes: services_and_messages
  symbol_index:
    load_on_demand: true # only for bughunt/validate
    nodes: classes_structs_namespaces

modules:
EOF

for subdir in "$DIR"/*/; do
  [ -d "$subdir" ] || continue
  MOD=$(basename "$subdir")
  MOD_SIZE=$(du -sh "$subdir" 2>/dev/null | cut -f1)
  echo " $MOD: # $MOD_SIZE" >> "$REPORT"
done

row '```'
blank

done_ "Config recommendation"

# =============================================================================
# SECTION 13: QUICK STATS SUMMARY
# =============================================================================
log "Writing summary..."

h2 "13. Summary — Key Numbers for Graph Design"

GO_FUNCS=${GO_FUNCS:-0}
PY_FUNCS=${PY_FUNCS:-0}

cat >> "$REPORT" << EOF
|--------|-------|----------------|
| Source files (.cc+.h+.go) | $(( CC_COUNT + H_COUNT + GO_COUNT )) | Parse target |
| Excluded (generated/test) | $(( GEN_COUNT + TEST_COUNT )) | Skip these |
| C++ LOC | $(printf "%'d" $CC_LINES) | High complexity |
| Est. C++ symbols | ~$(( CPP_CLASSES + CPP_STRUCTS )) classes/structs | Node count |
| Go functions | $GO_FUNCS | Tree-sitter viable |
| Proto RPCs | $RPC_COUNT | API surface |
| Top-level modules | $(ls -d "$DIR"/*/ 2>/dev/null | wc -l) | Module graph nodes |
| #include edges (total) | ~$EST_EDGES | Edge count |
| Files > 1000 lines | $LARGE_FILES | Hotspot targets |
| Test coverage | $(( TEST_COUNT )) test files | Quality signal |
| Recommended approach | Include graph + Proto parser | Not tree-sitter for C++ |

EOF

# =============================================================================
# WRITE FINAL REPORT
# =============================================================================
cp "$REPORT" "$OUTPUT"

echo ""
echo -e "${BOLD}=== Analysis Complete ===${NC}"
echo -e "Report written to: ${GREEN}$OUTPUT${NC}"
echo ""
echo "Key findings:"
echo -e " Total source files: ${CYAN}$(( CC_COUNT + H_COUNT + GO_COUNT ))${NC}"
echo -e " C++ lines of code: ${CYAN}$(printf "%'d" $CC_LINES)${NC}"
echo -e " Estimated symbols: ${CYAN}~$(( CPP_CLASSES + CPP_STRUCTS ))${NC} classes/structs"
echo -e " Proto RPCs: ${CYAN}$RPC_COUNT${NC}"
echo -e " Top-level modules: ${CYAN}$(ls -d "$DIR"/*/ 2>/dev/null | wc -l)${NC}"
echo -e " Est. #include edges: ${CYAN}~$EST_EDGES${NC}"
echo -e " Files > 1000 lines: ${CYAN}$LARGE_FILES${NC}"
echo ""
