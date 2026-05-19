'use strict';

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// =============================================================================
// LOGGING
// =============================================================================
const CYAN = '\x1b[36m';
const GREEN = '\x1b[32m';
const YELLOW= '\x1b[33m';
const RED = '\x1b[31m';
const NC = '\x1b[0m';

const log = (msg) => console.log(`${CYAN}[graph]${NC} ${msg}`);
const done = (msg) => console.log(`${GREEN}[done]${NC} ${msg}`);
const warn = (msg) => console.error(`${YELLOW}[warn]${NC} ${msg}`);
const die = (msg) => { console.error(`${RED}[error]${NC} ${msg}`); process.exit(1); };

// =============================================================================
// ARG PARSER — minimal, no dependencies
// =============================================================================
function parseArgs(argv) {
  const args = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (!next || next.startsWith('--')) {
        args[key] = true; // boolean flag
      } else {
        // support repeatable args as array
        if (args[key] !== undefined) {
          args[key] = [].concat(args[key], next);
        } else {
          args[key] = next;
        }
        i++;
      }
    } else {
      args._.push(a);
    }
  }
  return args;
}

// =============================================================================
// FILE WALKER
// =============================================================================

// Directories that are always skipped — universal build artifacts and package stores.
// These parallel the `node_modules` hardcode and prevent analyzing generated output.
const SKIP_ARTIFACT_DIRS = new Set(['node_modules', 'dist', 'build', 'out']);

/**
 * Walk a directory recursively, yielding absolute file paths.
 * Skips symlinks, hidden dirs, node_modules, and common build artifact dirs.
 *
 * Exclude patterns are tested against paths relative to `root` (defaults to
 * `dir`). This means the glob `*​/test/*` requires a parent component before
 * "test/", so a top-level `test/` module is NOT excluded while nested
 * `icebox/test/` subdirectories still are.
 *
 * @param {string} dir
 * @param {string[]} extensions e.g. ['.cc', '.h']
 * @param {RegExp[]} excludeRes compiled exclude patterns
 * @param {string} [root] root directory for computing relative exclude paths
 * @returns {string[]}
 */
function walkFiles(dir, extensions, excludeRes = [], root = null) {
  const resolveRoot = root || dir;
  const results = [];
  const extSet = new Set(extensions);

  function walk(current) {
    let entries;
    try { entries = fs.readdirSync(current, { withFileTypes: true }); }
    catch (_) { return; }

    for (const entry of entries) {
      if (entry.name.startsWith('.')) continue;
      const full = path.join(current, entry.name);
      const rel = path.relative(resolveRoot, full);

      if (entry.isSymbolicLink()) continue;

      if (entry.isDirectory()) {
        if (SKIP_ARTIFACT_DIRS.has(entry.name)) continue;
        if (shouldExclude(rel, excludeRes)) continue;
        walk(full);
      } else if (entry.isFile()) {
        if (shouldExclude(rel, excludeRes)) continue;
        if (extSet.size === 0 || extSet.has(path.extname(entry.name))) {
          results.push(full);
        }
      }
    }
  }

  walk(dir);
  return results;
}

// Source extensions recognized across all language extractors.
const ALL_SOURCE_EXTS = new Set([
  '.go', '.py',
  '.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs',
  '.c', '.h', '.cc', '.cpp', '.cxx', '.hpp', '.hxx', '.h++',
  '.proto',
  '.java', '.rs', '.rb', '.swift', '.kt', '.cs', '.scala', '.php', '.lua',
]);

/**
 * Walk the repo once and collect all source files, partitioned by extension.
 * Returns a Map keyed by extension (e.g. '.go' → ['/abs/path/foo.go', ...]).
 * Callers use allFiles.get('.go') instead of calling walkFiles per language.
 *
 * @param {string} repo
 * @param {RegExp[]} excludeRes pre-compiled exclude patterns
 * @returns {Map<string, string[]>}
 */
function collectAllFiles(repo, excludeRes = []) {
  const map = new Map();
  const files = walkFiles(repo, [...ALL_SOURCE_EXTS], excludeRes);
  for (const f of files) {
    const ext = path.extname(f);
    if (!map.has(ext)) map.set(ext, []);
    map.get(ext).push(f);
  }
  return map;
}

/**
 * Convert glob-style exclusion patterns to RegExp.
 * Supports * and ** wildcards.
 */
function compileExcludes(patterns) {
  return patterns.map(p => {
    const escaped = p
      .replace(/[.+^${}()|[\]\\]/g, '\\$&') // escape regex special chars
      .replace(/\*\*/g, '<<<GLOBSTAR>>>')
      .replace(/\*/g, '[^/]*')
      .replace(/<<<GLOBSTAR>>>/g, '.*');
    return new RegExp(escaped);
  });
}

function shouldExclude(filePath, excludeRes) {
  const normalized = filePath.replace(/\\/g, '/');
  return excludeRes.some(re => re.test(normalized));
}

// =============================================================================
// FILE SIZE
// =============================================================================
function fileSizeKB(filePath) {
  try {
    return Math.round(fs.statSync(filePath).size / 1024);
  } catch (_) {
    return 0;
  }
}

function dirSizeKB(dirPath) {
  let total = 0;
  try {
    const files = walkFiles(dirPath, []);
    for (const f of files) total += fileSizeKB(f);
  } catch (_) {}
  return total;
}

// =============================================================================
// JSONL WRITER
// =============================================================================
function sanitizeRecord(obj) {
  if (typeof obj === 'string') {
    return obj
      .replace(/\0/g, '')
      .replace(/[\uD800-\uDFFF]/g, '')
      .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '');
  }
  if (Array.isArray(obj)) return obj.map(sanitizeRecord);
  if (obj && typeof obj === 'object') {
    const out = {};
    for (const [k, v] of Object.entries(obj)) {
      out[sanitizeRecord(k)] = sanitizeRecord(v);
    }
    return out;
  }
  return obj;
}

function writeJsonl(filePath, records) {
  // Stream records directly to disk — avoids building a full lines[] array
  // in memory, which matters for large indexes (100k+ symbols).
  let count = 0;
  const fd = fs.openSync(filePath, 'w');
  try {
    for (const r of records) {
      let line;
      try {
        line = JSON.stringify(r);
      } catch (_) {
        try { line = JSON.stringify(sanitizeRecord(r)); }
        catch (_2) { continue; /* skip unfixable records */ }
      }
      fs.writeSync(fd, line + '\n');
      count++;
    }
  } finally {
    fs.closeSync(fd);
  }
  return count;
}

// =============================================================================
// TREE-SITTER INIT (shared across all extractors)
// =============================================================================

let _treeSitterParser = undefined; // undefined = not yet attempted; false = failed; class = ready

/**
 * Initialize web-tree-sitter once, shared across all language extractors.
 * Subsequent calls return the cached result immediately — no redundant WASM init.
 *
 * @returns {Promise<Function|null>} The Parser class, or null if unavailable.
 */
async function initTreeSitter() {
  if (_treeSitterParser !== undefined) return _treeSitterParser || null;
  try {
    const Parser = require('web-tree-sitter');
    await Parser.init();
    _treeSitterParser = Parser;
    return Parser;
  } catch (_) {
    _treeSitterParser = false;
    return null;
  }
}

// =============================================================================
// LINE COUNTER (fast, streaming)
// =============================================================================
function countLines(filePath) {
  try {
    const buf = fs.readFileSync(filePath);
    let count = 0;
    for (let i = 0; i < buf.length; i++) {
      if (buf[i] === 10) count++; // \n
    }
    return count;
  } catch (_) {
    return 0;
  }
}

/** Count lines from an in-memory buffer/string without re-reading from disk. */
function countLinesFromContent(content) {
  if (!content) return 0;
  // +1 matches the old countLines (which counted \n chars); trailing newline
  // already contributes. Keeping the semantic of countLines for compatibility.
  let count = 0;
  for (let i = 0; i < content.length; i++) {
    if (content.charCodeAt(i) === 10) count++;
  }
  return count;
}

// =============================================================================
// AST WALK (shared across all tree-sitter extractors)
// =============================================================================
/**
 * Iterative DFS with enter/leave visitors. Shared by all tree-sitter extractors.
 * Push a leave-sentinel before children so leave() fires after all descendants
 * are processed (mirrors call-stack order).
 */
function walkNodeEnterLeave(node, enter, leave) {
  const stack = [{ n: node, phase: 0 }]; // phase 0 = enter, 1 = leave
  while (stack.length > 0) {
    const frame = stack.pop();
    if (frame.phase === 1) { leave(frame.n); continue; }
    stack.push({ n: frame.n, phase: 1 });
    enter(frame.n);
    for (let i = frame.n.childCount - 1; i >= 0; i--) {
      stack.push({ n: frame.n.child(i), phase: 0 });
    }
  }
}

// =============================================================================
// C/C++ SOURCE EXTENSIONS (shared by extractor-c and extractor-includes)
// =============================================================================
const C_CPP_EXTS_LIST = ['.c', '.h', '.cc', '.cpp', '.cxx', '.hpp', '.hxx', '.h++'];

// =============================================================================
// UNIVERSAL CTAGS DETECTION (shared by extractor-c and extractor-ctags)
// =============================================================================
// Returns the ctags binary path if universal-ctags is available, else null.
// Exuberant-ctags is rejected — it does not support --output-format=json, and
// calling it with that flag silently produces empty output per file.
let _ctagsBinCache = null;
let _ctagsChecked = false;
function detectUniversalCtags() {
  if (_ctagsChecked) return _ctagsBinCache;
  _ctagsChecked = true;
  try {
    const ver = execSync('ctags --version 2>&1', { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] });
    if (/universal/i.test(ver)) {
      _ctagsBinCache = 'ctags';
      return _ctagsBinCache;
    }
    return null;
  } catch (_) {
    return null;
  }
}

module.exports = {
  log, done, warn, die,
  parseArgs,
  walkFiles,
  collectAllFiles,
  compileExcludes,
  shouldExclude,
  fileSizeKB,
  dirSizeKB,
  writeJsonl,
  countLines,
  countLinesFromContent,
  initTreeSitter,
  walkNodeEnterLeave,
  C_CPP_EXTS_LIST,
  detectUniversalCtags,
};
