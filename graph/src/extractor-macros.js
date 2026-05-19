'use strict';

const fs = require('fs');
const path = require('path');
const { walkFiles, C_CPP_EXTS_LIST, stableSymbolId } = require('./util');

/**
 * T3.4: index `#define` macro definitions in C/C++ source files.
 *
 * We don't expand macros — that requires a real preprocessor. We just
 * enumerate them so consumers can answer "what is `MY_MACRO`?".
 *
 * Output:
 * { macros: [{ name, file, module, line, params? }, ...] }
 *
 * Heuristics:
 * - Skip header guards: NAMES that match the file's basename + _H_? are dropped.
 * - Skip very short numeric-only definitions if name looks like a header guard.
 * - Function-like macros capture their parameter names: `#define MAX(a,b) ...`
 * → `params: ['a', 'b']`.
 * - Multi-line macros (trailing `\`) only contribute the first line.
 */
function buildMacroIndex(repo, excludeRes = [], allFiles = null) {
  const cFiles = allFiles
    ? C_CPP_EXTS_LIST.flatMap(ext => allFiles.get(ext) || [])
    : walkFiles(repo, C_CPP_EXTS_LIST, excludeRes);

  const macros = [];

  for (const f of cFiles) {
    const rel = path.relative(repo, f);
    const parts = rel.split(path.sep);
    const module = parts.length > 1 ? parts[0] : '__root__';
    const baseGuard = path.basename(f).replace(/[.\-]/g, '_').toUpperCase();

    let content;
    try { content = fs.readFileSync(f, 'utf8'); }
    catch (_) { continue; }

    const lines = content.split('\n');
    for (let i = 0; i < lines.length; i++) {
      const trimmed = lines[i].trimStart();
      if (!trimmed.startsWith('#define')) continue;

      // `#define NAME(params) body` or `#define NAME body`
      const m = trimmed.match(/^#define\s+(\w+)(\s*\(([^)]*)\))?/);
      if (!m) continue;
      const name = m[1];
      const isFn = !!m[2];
      const params = isFn
        ? m[3].split(',').map(s => s.trim()).filter(Boolean)
        : null;

      // Drop common header guards. We accept either:
      // FOO_H, _FOO_H, __FOO_H_, FOO_HPP, FOO_HXX, INCLUDE_FOO_H_
      if (looksLikeHeaderGuard(name, baseGuard)) continue;

      const rec = {
        name, file: rel, module,
        line: i + 1,
      };
      if (params) rec.params = params;
      rec.id = stableSymbolId({ kind: 'macro', file: rel, name });
      macros.push(rec);
    }
  }

  return { macros };
}

function looksLikeHeaderGuard(name, baseGuard) {
  // Accept canonical guard suffixes regardless of trailing underscore count
  // (so __FOO_H__ matches as well as FOO_H).
  if (!/_H(PP|XX)?_*$|_INCLUDED_*$/i.test(name)) return false;
  // Tighten: reject only if name's base resembles the file's own basename.
  // Otherwise a meaningful macro like `WANT_FILE_H` would be lost.
  const stripped = name.replace(/^_+|_+$/g, '');
  const base = baseGuard.replace(/^_+|_+$/g, '');
  return base.includes(stripped) || stripped.includes(base);
}

module.exports = { buildMacroIndex, looksLikeHeaderGuard };
