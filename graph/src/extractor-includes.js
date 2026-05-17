'use strict';

const fs = require('fs');
const path = require('path');
const { walkFiles, countLines, warn, C_CPP_EXTS_LIST } = require('./util');

/**
 * Build the C++ include graph for a repository.
 *
 * Produces:
 * nodes — one per source file (id, module, path, lines, kind)
 * edges — one per #include relationship between files (source→target)
 * moduleEdges — aggregated inter-module edges with weight (count)
 *
 * Method: read each file line-by-line, parse #include directives.
 * No compiler or tree-sitter needed — purely textual, 100% accurate for
 * include relationships.
 *
 * @param {string} repo
 * @param {Module[]} modules from detectModules()
 * @param {RegExp[]} excludeRes pre-compiled exclude patterns
 * @param {Map<string,string[]>|null} preCollectedFiles pre-collected file map, or null to walk
 */
function buildIncludeGraph(repo, modules, excludeRes = [], preCollectedFiles = null) {
  const repoName = path.basename(repo);

  // Build module lookup: absolute path prefix → module name
  const modulePaths = new Map(); // modPath → modName
  for (const mod of modules) {
    modulePaths.set(mod.path, mod.name);
  }

  // ── Collect all C++ files ─────────────────────────────────────────────────
  const allFiles = preCollectedFiles
    ? C_CPP_EXTS_LIST.flatMap(ext => preCollectedFiles.get(ext) || [])
    : walkFiles(repo, C_CPP_EXTS_LIST, excludeRes);

  // File path → node id (relative to repo root)
  const pathToId = new Map();
  const nodes = [];

  for (const f of allFiles) {
    const rel = path.relative(repo, f);
    const parts = rel.split(path.sep);
    const module = parts.length > 1 ? parts[0] : '__root__';
    const ext = path.extname(f);
    const kind = (ext === '.h' || ext === '.hpp' || ext === '.hxx') ? 'header' : 'source';
    const lines = countLines(f);

    const node = {
      id: rel,
      module,
      path: rel,
      file: path.basename(f),
      kind,
      lines,
      ext: ext.slice(1),
    };

    nodes.push(node);
    pathToId.set(f, rel);
    pathToId.set(rel, rel); // also index by relative path
  }

  // ── Parse #include directives ─────────────────────────────────────────────
  const edges = [];
  const moduleEdgeMap = new Map(); // "src→tgt" → count

  // Build a fast lookup: filename → list of candidate full paths
  // (for resolving quoted includes that don't specify full path)
  const fileIndex = buildFileIndex(allFiles, repo);

  for (const f of allFiles) {
    const rel = path.relative(repo, f);
    const parts = rel.split(path.sep);
    const srcModule = parts.length > 1 ? parts[0] : '__root__';

    let content;
    try { content = fs.readFileSync(f).toString('utf8').replace(/\0/g, ''); }
    catch (_) { continue; }

    const lines = content.split('\n');
    for (const line of lines) {
      const trimmed = line.trimStart();
      if (!trimmed.startsWith('#include')) continue;

      // Match quoted includes: #include "path/to/file.h"
      const quotedMatch = trimmed.match(/^#include\s+"([^"]+)"/);
      if (!quotedMatch) continue;

      const includePath = quotedMatch[1];
      const targetRel = resolveInclude(includePath, f, repo, repoName, fileIndex, pathToId);
      if (!targetRel) continue;

      const targetParts = targetRel.split('/');
      const targetModule = targetParts.length > 1 ? targetParts[0] : '__root__';

      // File-level edge
      edges.push({
        source: rel,
        target: targetRel,
        type: 'INCLUDES',
      });

      // Module-level edge (skip self-references)
      if (srcModule !== targetModule) {
        const key = `${srcModule}→${targetModule}`;
        moduleEdgeMap.set(key, (moduleEdgeMap.get(key) || 0) + 1);
      }
    }
  }

  // ── Convert module edge map → array ──────────────────────────────────────
  const moduleEdges = [];
  for (const [key, weight] of moduleEdgeMap.entries()) {
    const [source, target] = key.split('→');
    moduleEdges.push({ source, target, type: 'INCLUDES', weight });
  }
  moduleEdges.sort((a, b) => b.weight - a.weight);

  return { nodes, edges, moduleEdges };
}

// =============================================================================
// INCLUDE RESOLUTION
// =============================================================================

/**
 * Build a filename → [fullPath, ...] index for fast include resolution.
 * Many C++ codebases use bare filenames in includes (e.g. #include "util.h")
 * without full paths. We resolve them by basename lookup.
 */
function buildFileIndex(files, repo) {
  const index = new Map(); // basename → [relPath, ...]
  for (const f of files) {
    const rel = path.relative(repo, f);
    const base = path.basename(f);
    if (!index.has(base)) index.set(base, []);
    index.get(base).push(rel);
  }
  return index;
}

/**
 * Resolve a quoted include path to a repo-relative path.
 *
 * Resolution order:
 * 1. Exact match: includePath is already a valid repo-relative path
 * e.g. #include "bridge/base/util.h"
 * 2. Repo-name prefixed: #include "bridge/..." → strip prefix
 * 3. Relative to current file's directory
 * 4. Basename fallback: look up by filename in the index
 */
function resolveInclude(includePath, currentFile, repo, repoName, fileIndex, pathToId) {
  // Normalize slashes
  const inc = includePath.replace(/\\/g, '/');

  // 1. Strip repo-name prefix if present (e.g. "bridge/base/..." → "base/...")
  let candidate = inc;
  if (candidate.startsWith(repoName + '/')) {
    candidate = candidate.slice(repoName.length + 1);
  }

  // 2. Check if candidate exists as repo-relative path.
  // pathToId is indexed by both abs-path and rel-path, so a Map lookup is
  // O(1) and avoids a stat syscall per #include directive.
  if (pathToId.has(candidate)) {
    return candidate;
  }

  // 3. Resolve relative to current file's directory.
  const currentDir = path.dirname(currentFile);
  const abs2 = path.resolve(currentDir, inc);
  if (pathToId.has(abs2)) {
    return path.relative(repo, abs2).replace(/\\/g, '/');
  }

  // 4. Basename fallback — useful for flat-ish include structures
  const base = path.basename(inc);
  const candidates = fileIndex.get(base);
  if (candidates && candidates.length === 1) {
    return candidates[0]; // unambiguous
  }
  if (candidates && candidates.length > 1) {
    // Pick the one closest to the include path
    const scored = candidates.map(c => ({
      rel: c,
      score: pathSimilarity(inc, c),
    }));
    scored.sort((a, b) => b.score - a.score);
    return scored[0].rel;
  }

  return null; // external / system header — skip
}

/** Simple path similarity score: count matching path segments from the end */
function pathSimilarity(a, b) {
  const aParts = a.split('/').reverse();
  const bParts = b.split('/').reverse();
  let score = 0;
  for (let i = 0; i < Math.min(aParts.length, bParts.length); i++) {
    if (aParts[i] === bParts[i]) score++;
    else break;
  }
  return score;
}

module.exports = { buildIncludeGraph };
