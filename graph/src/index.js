#!/usr/bin/env node
'use strict';

const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

const { buildIncludeGraph } = require('./extractor-includes');
const { buildProtoIndex } = require('./extractor-proto');
const { buildGoIndex } = require('./extractor-go');
const { buildPythonIndex } = require('./extractor-python');
const { buildTsIndex } = require('./extractor-ts');
const { buildCIndex } = require('./extractor-c');
const { buildCtagsIndex } = require('./extractor-ctags');
const { writeGraph } = require('./writer');
const { detectModules } = require('./modules');
const { log, warn, done, die, parseArgs, compileExcludes, collectAllFiles } = require('./util');

// =============================================================================
// CLI
// =============================================================================
const args = parseArgs(process.argv.slice(2));

if (args.help || (!args.repo && !args._[0])) {
  console.log(`
graph — knowledge graph builder for Draft

Usage:
  graph --repo <path> [--out <dir>] [--exclude <pattern>] [--incremental]
  graph --repo <path> --query --symbol <name> --mode callers
  graph --repo <path> --query --file <path> --mode impact

Options:
  --repo <path> Repository root to analyze (required)
  --out <dir> Output directory (default: <repo>/draft/graph)
  --exclude <pattern> Additional exclusion glob (repeatable)
  --incremental Skip unchanged modules (uses hashes.json for diffing)
  --query Query mode (reads existing graph, does not rebuild)
  --symbol <name> Symbol to query (use with --query)
  --file <path> File to query (use with --query)
  --mode <mode> Query mode: callers|impact|hotspots|modules|cycles|mermaid
  --help Show this help
`);
  process.exit(0);
}

const REPO = path.resolve(args.repo || args._[0]);
const FINAL_OUT = path.resolve(args.out || path.join(REPO, 'draft', 'graph'));
// All output goes to a temp dir first; swapped atomically to FINAL_OUT on success.
const TEMP_OUT = FINAL_OUT + '.tmp-' + process.pid;

if (!fs.existsSync(REPO)) die(`Repo path does not exist: ${REPO}`);

// =============================================================================
// QUERY MODE — reads existing graph, no rebuild
// =============================================================================
if (args.query) {
  const { query } = require('./query');
  query({ out: FINAL_OUT, symbol: args.symbol, file: args.file, mode: args.mode });
  // Wait for stdout to flush before exiting (avoids 64KB truncation when piped)
  if (process.stdout.writableNeedDrain) {
    process.stdout.once('drain', () => process.exit(0));
  } else {
    process.stdout.write('', () => process.exit(0));
  }
  return;
}

// =============================================================================
// BUILD MODE
// =============================================================================
const EXCLUDE_DEFAULTS = [
  '*.pb.cc', '*.pb.h', '*_generated*',
  '*/test/*', '*_test.cc', '*_test.go',
  '*/vendor/*', '*/third_party/*',
  '*/dist/*', '*/.next/*', '*/build/*', '*/out/*',
  '*.pem', '*.key', '*.crt',
];

const excludePatterns = [
  ...EXCLUDE_DEFAULTS,
  ...(args.exclude ? [].concat(args.exclude) : []),
];

const INCREMENTAL = !!args.incremental;

const excludeRes = compileExcludes(excludePatterns);

// Single directory walk — distributed to extractors to avoid 7 redundant traversals.
// Called lazily inside main() so REPO is validated first.

// =============================================================================
// INCREMENTAL: hash computation
// =============================================================================

/**
 * Compute a short content-based hash for a module's source files.
 * Hashes sorted file contents so order changes don't invalidate the cache.
 */
function computeModuleHash(modPath) {
  const hash = crypto.createHash('sha256');
  const files = [];
  const walk = (dir) => {
    let entries;
    try { entries = fs.readdirSync(dir, { withFileTypes: true }); }
    catch (_) { return; }
    for (const e of entries) {
      const full = path.join(dir, e.name);
      if (e.isDirectory()) walk(full);
      else files.push(full);
    }
  };
  walk(modPath);
  for (const f of files.sort()) {
    try { hash.update(fs.readFileSync(f)); }
    catch (_) {}
  }
  return hash.digest('hex').slice(0, 16);
}

function loadHashes() {
  // Reads from FINAL_OUT so incremental state survives the temp-dir write cycle.
  try { return JSON.parse(fs.readFileSync(path.join(FINAL_OUT, 'hashes.json'), 'utf8')); }
  catch (_) { return { modules: {} }; }
}

function saveHashes(modules) {
  // Written to TEMP_OUT — committed to FINAL_OUT by the atomic swap below.
  fs.writeFileSync(path.join(TEMP_OUT, 'hashes.json'), JSON.stringify({
    generated: new Date().toISOString(),
    modules,
  }, null, 2), 'utf8');
}

// =============================================================================
// MAIN
// =============================================================================

async function main() {
  log(`Analyzing: ${REPO}`);
  log(`Output: ${FINAL_OUT}`);

  // Clean up orphaned temp/backup dirs from previous crashed runs.
  const parentDir = path.dirname(FINAL_OUT);
  const baseName = path.basename(FINAL_OUT);
  try {
    for (const entry of fs.readdirSync(parentDir, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue;
      const n = entry.name;
      if (n.startsWith(baseName + '.tmp-') || n.startsWith(baseName + '.old-')) {
        fs.rmSync(path.join(parentDir, n), { recursive: true, force: true });
      }
    }
  } catch (_) {}

  // All writes go to TEMP_OUT; swapped into FINAL_OUT atomically on success.
  fs.mkdirSync(TEMP_OUT, { recursive: true });
  fs.mkdirSync(path.join(TEMP_OUT, 'modules'), { recursive: true });

  const allFiles = collectAllFiles(REPO, excludeRes);

  // ── Incremental: load existing hashes ─────────────────────────────────────
  const prevHashes = INCREMENTAL ? loadHashes().modules : {};
  const newHashes = {};
  const skipModules = new Set();

  // ── Phase 1/5: detect modules (top-level dirs with source files) ─────────
  log('Phase 1/5 Detecting modules...');
  const modules = detectModules(REPO, excludePatterns);
  log(` Found ${modules.length} modules`);

  if (INCREMENTAL) {
    for (const mod of modules) {
      const hash = computeModuleHash(mod.path);
      newHashes[mod.name] = hash;
      if (prevHashes[mod.name] === hash) {
        skipModules.add(mod.name);
      }
    }
    const skipped = skipModules.size;
    if (skipped > 0) log(` Incremental: skipping ${skipped} unchanged module(s)`);
  }

  // ── Phase 2/5: C++ include graph ──────────────────────────────────────────
  log('Phase 2/5 Building C++ include graph...');
  const includeGraph = buildIncludeGraph(REPO, modules, excludeRes, allFiles);
  log(` ${includeGraph.nodes.length} file nodes, ${includeGraph.edges.length} include edges`);
  log(` ${includeGraph.moduleEdges.length} inter-module edges`);

  // ── Phase 3/5: Proto index ────────────────────────────────────────────────
  log('Phase 3/5 Parsing proto definitions...');
  const protoIndex = buildProtoIndex(REPO, excludeRes, allFiles);
  log(` ${protoIndex.services.length} services, ${protoIndex.rpcs.length} RPCs, ${protoIndex.messages.length} messages, ${protoIndex.enums.length} enums`);

  // ── Phases 4/5: Go / Python / TS / C++ in parallel ───────────────────────
  log('Phases 4/5 Indexing Go / Python / TS / C++ in parallel...');
  const [goIndex, pythonIndex, tsIndex, cIndex] = await Promise.all([
    buildGoIndex(REPO, excludeRes, allFiles),
    buildPythonIndex(REPO, excludeRes, allFiles),
    buildTsIndex(REPO, excludeRes, allFiles),
    buildCIndex(REPO, excludeRes, allFiles),
  ]);
  log(` Go: ${goIndex.functions.length} functions, ${goIndex.calls.length} calls`);
  log(` Python: ${pythonIndex.functions.length} functions, ${pythonIndex.calls.length} calls`);
  log(` TS/JS: ${tsIndex.functions.length} functions, ${tsIndex.calls.length} calls`);
  log(` C/C++: ${cIndex.functions.length} functions, ${cIndex.calls.length} calls`);

  // ── Phase 5/5: ctags fallback for remaining languages ─────────────────────
  log('Phase 5/5 Running ctags for unsupported languages...');
  const ctagsIndex = buildCtagsIndex(REPO, excludeRes, allFiles);
  log(` ${ctagsIndex.symbols.length} symbols (Java/Rust/Ruby/Swift/etc.)`);

  // ── Write output ──────────────────────────────────────────────────────────
  log('Writing graph files...');
  const stats = writeGraph({
    out: TEMP_OUT,
    existingOut: FINAL_OUT, // for incremental: copy unchanged module files from here
    repo: REPO,
    modules,
    includeGraph,
    protoIndex,
    goIndex,
    pythonIndex,
    tsIndex,
    cIndex,
    ctagsIndex,
    skipModules,
  });

  // ── Save incremental hashes ────────────────────────────────────────────────
  if (INCREMENTAL) {
    saveHashes(newHashes);
  }

  // ── Atomic commit: rename TEMP_OUT → FINAL_OUT ─────────────────────────────
  // On Linux, rename(2) on the same filesystem is atomic: readers always see
  // either the old complete output or the new complete output, never a partial.
  const backupOut = FINAL_OUT + '.old-' + process.pid;
  try {
    if (fs.existsSync(FINAL_OUT)) fs.renameSync(FINAL_OUT, backupOut);
    fs.renameSync(TEMP_OUT, FINAL_OUT);
    if (fs.existsSync(backupOut)) fs.rmSync(backupOut, { recursive: true, force: true });
  } catch (e) {
    die(`Failed to commit output (temp dir preserved at ${TEMP_OUT}): ${e.message}`);
  }

  // ── Summary ───────────────────────────────────────────────────────────────
  const totalCalls = goIndex.calls.length + pythonIndex.calls.length +
                     tsIndex.calls.length + cIndex.calls.length;
  console.log('');
  done('Graph build complete');
  console.log(` module-graph.jsonl ${stats.moduleEdges} edges`);
  console.log(` proto-index.jsonl ${stats.rpcs} RPCs`);
  console.log(` hotspots.jsonl ${stats.hotspots} files`);
  if (stats.tsFunctions > 0) console.log(` ts-index.jsonl ${stats.tsFunctions} functions, ${stats.tsClasses} classes`);
  if (stats.cFunctions > 0) console.log(` c-index.jsonl ${stats.cFunctions} functions, ${stats.cTypes} types`);
  if (stats.ctagsSymbols > 0) console.log(` ctags symbols ${stats.ctagsSymbols}`);
  if (totalCalls > 0) console.log(` call-index.jsonl ${totalCalls} call edges`);
  console.log(` modules/ ${stats.moduleFiles} files`);
  console.log(` Total output: ${stats.totalSizeKB}KB`);
  console.log('');
}

main().catch(die);
