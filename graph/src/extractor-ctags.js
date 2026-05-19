'use strict';

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const { walkFiles, countLines, warn, detectUniversalCtags } = require('./util');

// Languages handled by dedicated extractors — skip these in ctags
const SKIP_EXTS = new Set([
  '.go', '.py', '.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs',
  '.c', '.h', '.cc', '.cpp', '.cxx', '.hpp', '.hxx',
  '.proto',
]);

// Languages ctags handles well
const CTAGS_EXTS = new Set([
  '.java', '.rs', '.rb', '.swift', '.kt', '.cs', '.scala',
  '.php', '.lua', '.r', '.m', // .m = Objective-C
]);

/**
 * Universal ctags fallback extractor.
 *
 * Runs universal-ctags for languages not covered by dedicated tree-sitter
 * extractors (Java, Rust, Ruby, Swift, Kotlin, C#, etc.).
 *
 * Gracefully skips if ctags is not installed — no degradation to existing
 * extraction pipeline.
 *
 * Emits: kind: 'ctags-sym' records into per-module JSONL only
 * (no global index — coverage is opportunistic).
 *
 * @param {string} repo
 * @param {RegExp[]} excludeRes pre-compiled exclude patterns
 * @param {Map<string,string[]>|null} allFiles pre-collected file map, or null to walk
 */
function buildCtagsIndex(repo, excludeRes = [], allFiles = null) {
  const bin = detectUniversalCtags();
  if (!bin) { warnIfCtagsNonUniversal(); return { symbols: [] }; }

  const files = allFiles
    ? [...CTAGS_EXTS].flatMap(ext => allFiles.get(ext) || [])
    : walkFiles(repo, [...CTAGS_EXTS], excludeRes);

  if (files.length === 0) return { symbols: [] };

  const symbols = [];

  // Batch by module to limit individual ctags invocations
  const byModule = new Map();
  for (const f of files) {
    const rel = path.relative(repo, f);
    const parts = rel.split(path.sep);
    const module = parts.length > 1 ? parts[0] : '__root__';
    if (!byModule.has(module)) byModule.set(module, []);
    byModule.get(module).push({ f, rel });
  }

  for (const [module, entries] of byModule) {
    // Process up to 100 files per batch
    const BATCH = 100;
    for (let i = 0; i < entries.length; i += BATCH) {
      const batch = entries.slice(i, i + BATCH);
      // Pre-build O(1) lookup for tag.path → batch entry. ctags can emit either
      // the path we passed in or its resolved form, so index by both.
      const batchByPath = new Map();
      const linesCache = new Map(); // avoid re-reading the same file per tag
      for (const e of batch) {
        batchByPath.set(e.f, e);
        const resolved = path.resolve(e.f);
        if (resolved !== e.f) batchByPath.set(resolved, e);
      }
      const ctagsArgs = ['--output-format=json', '--fields=+nKz', '-f', '-', ...batch.map(e => e.f)];
      try {
        const result = spawnSync(bin, ctagsArgs,
          { encoding: 'utf8', timeout: 30000, maxBuffer: 10 * 1024 * 1024 });
        if (result.error) throw result.error;
        const output = result.stdout || '';
        for (const line of output.split('\n')) {
          if (!line.trim() || line.startsWith('!_')) continue;
          try {
            const tag = JSON.parse(line);
            // Only index meaningful symbol kinds
            if (!isIndexableKind(tag.kind)) continue;
            const entryMatch = tag.path ? batchByPath.get(tag.path) : null;
            const relPath = entryMatch ? entryMatch.rel : path.relative(repo, tag.path || '');
            let totalLines = 0;
            if (entryMatch) {
              if (!linesCache.has(entryMatch.f)) linesCache.set(entryMatch.f, countLines(entryMatch.f));
              totalLines = linesCache.get(entryMatch.f);
            }
            symbols.push({
              name: tag.name,
              file: relPath,
              module,
              line: tag.line || 1,
              lines: totalLines,
              ctagsKind: normalizeCtagsKind(tag.kind),
              language: tag.language ? tag.language.toLowerCase() : 'unknown',
            });
          } catch (_) {}
        }
      } catch (e) {
        warn(`ctags failed for module ${module}: ${e.message}`);
      }
    }
  }

  return { symbols };
}

// =============================================================================
// HELPERS
// =============================================================================

// Emit a one-time warning if a non-universal ctags is on PATH; otherwise silent.
let _warnedNonUniversal = false;
function warnIfCtagsNonUniversal() {
  if (_warnedNonUniversal) return;
  _warnedNonUniversal = true;
  try {
    const { execSync } = require('child_process');
    const ver = execSync('ctags --version 2>&1', { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] });
    if (!/universal/i.test(ver)) {
      warn('ctags found but is not universal-ctags (no JSON support) — skipping ctags extraction');
    }
  } catch (_) { /* ctags absent — silent */ }
}

const INDEXABLE_KINDS = new Set([
  'function', 'method', 'class', 'interface', 'enum', 'struct', 'trait',
  'f', 'm', 'c', 'i', 'g', 's', 't',
]);

function isIndexableKind(kind) {
  if (!kind) return false;
  return INDEXABLE_KINDS.has(kind.toLowerCase());
}

function normalizeCtagsKind(kind) {
  if (!kind) return 'unknown';
  const k = kind.toLowerCase();
  if (k === 'function' || k === 'f' || k === 'method' || k === 'm') return 'function';
  if (k === 'class' || k === 'c') return 'class';
  if (k === 'interface' || k === 'i') return 'interface';
  if (k === 'enum' || k === 'g') return 'enum';
  if (k === 'struct' || k === 's') return 'struct';
  if (k === 'trait' || k === 't') return 'trait';
  return k;
}

module.exports = { buildCtagsIndex };
