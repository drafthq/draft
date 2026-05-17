'use strict';

const fs = require('fs');
const path = require('path');

/**
 * T3.1: opt-in reader for compile_commands.json (CMake / Bazel / Bear).
 *
 * We don't run a compiler; we just harvest `-I` / `-iquote` / `-isystem`
 * paths so the include extractor can resolve angle-bracket headers that
 * live inside the repo (e.g. `#include <absl/strings/str_cat.h>` when the
 * project sets `-Ithird_party/abseil-cpp/`).
 *
 * Returns `null` if no compile_commands.json is found, otherwise:
 * {
 * file: "compile_commands.json",
 * entries: <number>,
 * searchPaths: [<repo-relative dirs>, ...], // unique, sorted
 * defines: [<-Dfoo=bar>, ...], // unique macros, capped
 * }
 *
 * Search-path filter: only repo-relative or repo-rooted absolute paths are
 * kept. System paths like `/usr/include` are dropped — they can't help us
 * resolve to a file we already walked.
 */
function readCompileCommands(repo) {
  const candidates = [
    path.join(repo, 'compile_commands.json'),
    path.join(repo, 'build', 'compile_commands.json'),
    path.join(repo, 'out', 'compile_commands.json'),
  ];
  for (const p of candidates) {
    if (fs.existsSync(p)) return parseCompileCommands(p, repo);
  }
  return null;
}

function parseCompileCommands(p, repo) {
  let raw;
  try { raw = fs.readFileSync(p, 'utf8'); }
  catch (_) { return null; }
  let entries;
  try { entries = JSON.parse(raw); }
  catch (_) { return null; }
  if (!Array.isArray(entries)) return null;

  const searchPaths = new Set();
  const defines = new Set();

  for (const e of entries) {
    const tokens = extractTokens(e);
    const cwd = e.directory ? String(e.directory) : repo;
    for (let i = 0; i < tokens.length; i++) {
      const tok = tokens[i];
      // -I / -iquote / -isystem support both joined and split forms.
      const matchIncl = tok.match(/^-(I|iquote|isystem)(.*)$/);
      if (matchIncl) {
        let dir = matchIncl[2];
        if (!dir) { dir = tokens[i + 1]; i++; }
        if (!dir) continue;
        const abs = path.isAbsolute(dir) ? dir : path.resolve(cwd, dir);
        const rel = path.relative(repo, abs);
        if (rel.startsWith('..') || path.isAbsolute(rel)) continue; // outside repo
        if (rel === '') continue;
        searchPaths.add(rel.replace(/\\/g, '/'));
        continue;
      }
      // Capture macros so callers can show them; cap to keep output small.
      if (tok.startsWith('-D') && defines.size < 200) {
        defines.add(tok);
      }
    }
  }

  return {
    file: path.relative(repo, p),
    entries: entries.length,
    searchPaths: Array.from(searchPaths).sort(),
    defines: Array.from(defines).sort(),
  };
}

// compile_commands.json entries can have either `arguments` (array) or
// `command` (single shell-style string). Tokenize both into a flat string[].
function extractTokens(entry) {
  if (Array.isArray(entry.arguments)) return entry.arguments.map(String);
  if (typeof entry.command === 'string') return shlexish(entry.command);
  return [];
}

// Minimal shell-like tokenizer: respects single + double quotes, ignores
// backslash escapes (rare in compile_commands). Good enough for harvesting
// -I/-D/-isystem flags; we don't execute anything.
function shlexish(s) {
  const out = [];
  let cur = '';
  let q = null;
  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (q) {
      if (c === q) { q = null; continue; }
      cur += c;
      continue;
    }
    if (c === '"' || c === "'") { q = c; continue; }
    if (/\s/.test(c)) {
      if (cur) { out.push(cur); cur = ''; }
      continue;
    }
    cur += c;
  }
  if (cur) out.push(cur);
  return out;
}

module.exports = { readCompileCommands, parseCompileCommands };
