'use strict';

const fs = require('fs');
const path = require('path');

/**
 * T1.4: parse go.mod files in the repo to discover the module's import path.
 *
 * Returns `null` if no go.mod is found. Otherwise:
 * {
 * module: "example.com/foo/bar", // value of `module` directive
 * goVersion: "1.21", // optional `go` directive
 * replaces: [{ from, to }], // `replace` directives (best-effort)
 * requires: [{ path, version }], // direct deps (top-level `require` block)
 * file: "go.mod", // repo-relative path
 * }
 *
 * Only the *root* go.mod is used (deepest-first search disabled to keep
 * behaviour predictable in monorepos with vendored sub-modules).
 */
function readGoMod(repo) {
  const candidates = [
    path.join(repo, 'go.mod'),
  ];
  for (const p of candidates) {
    if (fs.existsSync(p)) return parseGoMod(p, repo);
  }
  return null;
}

function parseGoMod(p, repo) {
  let content;
  try { content = fs.readFileSync(p, 'utf8'); }
  catch (_) { return null; }

  const out = {
    module: null,
    goVersion: null,
    replaces: [],
    requires: [],
    file: path.relative(repo, p),
  };

  let inRequireBlock = false;
  let inReplaceBlock = false;
  for (const rawLine of content.split('\n')) {
    const line = rawLine.replace(/\/\/.*$/, '').trim();
    if (!line) continue;

    if (!out.module) {
      const m = line.match(/^module\s+(\S+)/);
      if (m) { out.module = m[1]; continue; }
    }
    if (!out.goVersion) {
      const m = line.match(/^go\s+(\S+)/);
      if (m) { out.goVersion = m[1]; continue; }
    }

    if (line === 'require (') { inRequireBlock = true; continue; }
    if (line === 'replace (') { inReplaceBlock = true; continue; }
    if (line === ')') { inRequireBlock = false; inReplaceBlock = false; continue; }

    if (inRequireBlock) {
      const m = line.match(/^(\S+)\s+(\S+)/);
      if (m) out.requires.push({ path: m[1], version: m[2] });
      continue;
    }
    if (inReplaceBlock) {
      const m = line.match(/^(\S+)(?:\s+\S+)?\s+=>\s+(\S+)(?:\s+\S+)?$/);
      if (m) out.replaces.push({ from: m[1], to: m[2] });
      continue;
    }

    // single-line forms outside blocks
    const reqOne = line.match(/^require\s+(\S+)\s+(\S+)/);
    if (reqOne) { out.requires.push({ path: reqOne[1], version: reqOne[2] }); continue; }
    const repOne = line.match(/^replace\s+(\S+)(?:\s+\S+)?\s+=>\s+(\S+)/);
    if (repOne) { out.replaces.push({ from: repOne[1], to: repOne[2] }); continue; }
  }

  return out.module ? out : null;
}

module.exports = { readGoMod, parseGoMod };
