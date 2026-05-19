'use strict';

const fs = require('fs');
const path = require('path');
const { walkFiles, compileExcludes, dirSizeKB, fileSizeKB, countLines } = require('./util');

const SOURCE_EXTS = new Set(['.cc', '.cpp', '.cxx', '.c', '.h', '.hpp', '.go', '.py', '.java', '.rs', '.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs', '.proto']);

/**
 * Detect top-level modules in a repo.
 * A "module" is a top-level directory that contains at least one source file
 * (recursively). Non-source directories (docs, configs only) are excluded.
 *
 * @param {string} repo Absolute repo root
 * @param {string[]} excludes Glob patterns to exclude
 * @returns {Module[]}
 */
function detectModules(repo, excludesOrExcludeRes = []) {
  // Accept either raw string[] or pre-compiled RegExp[] for backward compat
  const excludeRes = (excludesOrExcludeRes.length > 0 && excludesOrExcludeRes[0] instanceof RegExp)
    ? excludesOrExcludeRes
    : compileExcludes(excludesOrExcludeRes);
  const modules = [];

  let entries;
  try { entries = fs.readdirSync(repo, { withFileTypes: true }); }
  catch (e) { return modules; }

  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    if (entry.name.startsWith('.')) continue;

    const modPath = path.join(repo, entry.name);
    const counts = countSourceFiles(modPath, excludeRes, repo);

    // Skip dirs with no source files (pure config/docs/data dirs)
    if (counts.total === 0) continue;

    modules.push({
      name: entry.name,
      path: modPath,
      sizeKB: dirSizeKB(modPath),
      files: {
        cc: counts.cc,
        h: counts.h,
        go: counts.go,
        proto: counts.proto,
        py: counts.py,
        java: counts.java,
        rs: counts.rs,
        ts: counts.ts,
        total: counts.total,
      },
    });
  }

  // Check for root-level source files (not inside any module directory)
  const rootCounts = { cc: 0, h: 0, go: 0, proto: 0, py: 0, java: 0, rs: 0, ts: 0, total: 0 };
  let rootSizeKB = 0;
  for (const entry of entries) {
    if (entry.isDirectory()) continue;
    if (entry.name.startsWith('.')) continue;
    const ext = path.extname(entry.name);
    if (!SOURCE_EXTS.has(ext)) continue;
    const full = path.join(repo, entry.name);
    const rel = path.relative(repo, full);
    if (excludeRes.some(re => re.test(rel))) continue;
    rootSizeKB += fileSizeKB(full);
    switch (ext) {
      case '.cc': case '.cpp': case '.cxx': rootCounts.cc++; break;
      case '.h': case '.hpp': rootCounts.h++; break;
      case '.go': rootCounts.go++; break;
      case '.proto': rootCounts.proto++; break;
      case '.py': rootCounts.py++; break;
      case '.java': rootCounts.java++; break;
      case '.rs': rootCounts.rs++; break;
      case '.ts': case '.tsx':
      case '.js': case '.jsx':
      case '.mjs': case '.cjs': rootCounts.ts++; break;
    }
    if (SOURCE_EXTS.has(ext)) rootCounts.total++;
  }

  if (rootCounts.total > 0) {
    modules.push({
      name: '__root__',
      path: repo,
      sizeKB: rootSizeKB,
      files: rootCounts,
      rootOnly: true, // flag: only index root-level files, not subdirectories
    });
  }

  // Sort by name for deterministic output
  modules.sort((a, b) => a.name.localeCompare(b.name));
  return modules;
}

function countSourceFiles(dir, excludeRes, root) {
  const counts = { cc: 0, h: 0, go: 0, proto: 0, py: 0, java: 0, rs: 0, ts: 0, total: 0 };

  const files = walkFiles(dir, [], excludeRes, root);
  for (const f of files) {
    const ext = path.extname(f);
    switch (ext) {
      case '.cc': case '.cpp': case '.cxx': counts.cc++; break;
      case '.h': case '.hpp': counts.h++; break;
      case '.go': counts.go++; break;
      case '.proto': counts.proto++; break;
      case '.py': counts.py++; break;
      case '.java': counts.java++; break;
      case '.rs': counts.rs++; break;
      case '.ts': case '.tsx':
      case '.js': case '.jsx':
      case '.mjs': case '.cjs': counts.ts++; break;
    }
    if (SOURCE_EXTS.has(ext)) counts.total++;
  }

  return counts;
}

module.exports = { detectModules };
