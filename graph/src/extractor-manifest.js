'use strict';

const fs = require('fs');
const path = require('path');

/**
 * T3.3: harvest declared external dependencies from common manifest files.
 *
 * We don't index the dependencies themselves — we just record what the repo
 * *claims* to depend on, so an agent can answer "does this project use X?"
 * without scanning vendor directories.
 *
 * Returns:
 * {
 * manifests: [
 * { kind: 'package.json'|'go.sum'|'go.mod-require'|'requirements.txt'|'Cargo.toml',
 * file: <repo-rel>,
 * deps: [{ name, version }] },
 * ...
 * ]
 * }
 *
 * Files lower in the directory tree (e.g. nested package.jsons in monorepos)
 * are included with their relative path so consumers can group by workspace.
 */
function readManifests(repo) {
  const manifests = [];

  collectByName(repo, 'package.json', manifests, parsePackageJson);
  collectByName(repo, 'requirements.txt', manifests, parseRequirements);
  collectByName(repo, 'Cargo.toml', manifests, parseCargoToml);
  collectByName(repo, 'go.sum', manifests, parseGoSum);

  return { manifests };
}

function collectByName(repo, basename, out, parser) {
  // Scan two levels deep — typical for monorepos. Going deeper would
  // re-walk the tree we already walked in collectAllFiles, defeating the
  // "lightweight" goal. Two levels covers ~95% of real-world layouts.
  const candidates = [];
  try {
    for (const e of fs.readdirSync(repo, { withFileTypes: true })) {
      if (e.name.startsWith('.')) continue;
      const p = path.join(repo, e.name);
      if (e.isDirectory()) {
        try {
          for (const f of fs.readdirSync(p, { withFileTypes: true })) {
            if (f.name === basename) candidates.push(path.join(p, f.name));
          }
        } catch (_) {}
      } else if (e.name === basename) {
        candidates.push(p);
      }
    }
  } catch (_) {}

  for (const c of candidates) {
    try {
      const content = fs.readFileSync(c, 'utf8');
      const deps = parser(content);
      if (!deps) continue;
      out.push({
        kind: basename,
        file: path.relative(repo, c),
        deps,
      });
    } catch (_) { /* skip unreadable */ }
  }
}

// =============================================================================
// PARSERS — best-effort, tolerant of malformed content.
// =============================================================================

function parsePackageJson(content) {
  let json;
  try { json = JSON.parse(content); }
  catch (_) { return null; }
  const out = [];
  for (const section of ['dependencies', 'devDependencies', 'peerDependencies', 'optionalDependencies']) {
    const obj = json && json[section];
    if (obj && typeof obj === 'object') {
      for (const [name, version] of Object.entries(obj)) {
        out.push({ name, version: String(version), section });
      }
    }
  }
  return out;
}

function parseRequirements(content) {
  const out = [];
  for (const rawLine of content.split('\n')) {
    const line = rawLine.replace(/#.*$/, '').trim();
    if (!line || line.startsWith('-')) continue; // skip flags like -r, -e
    // pkg, pkg==1.2, pkg>=1, pkg~=1, pkg[extra]==1
    const m = line.match(/^([A-Za-z0-9_.\-\[\]]+)\s*([<>=!~][^;]*)?/);
    if (m) out.push({ name: m[1].trim(), version: (m[2] || '').trim() || null });
  }
  return out;
}

function parseCargoToml(content) {
  // Tiny TOML subset: we only parse [dependencies] / [dev-dependencies] /
  // [build-dependencies] sections with simple `name = "version"` or
  // `name = { version = "x", ... }` lines. Anything else is ignored.
  const out = [];
  let section = null;
  for (const rawLine of content.split('\n')) {
    const line = rawLine.replace(/#.*$/, '').trim();
    if (!line) continue;
    const sec = line.match(/^\[([^\]]+)\]/);
    if (sec) { section = sec[1].trim(); continue; }
    if (section && /dependencies/i.test(section)) {
      const eqIdx = line.indexOf('=');
      if (eqIdx <= 0) continue;
      const name = line.slice(0, eqIdx).trim();
      const rhs = line.slice(eqIdx + 1).trim();
      let version = null;
      const sm = rhs.match(/^"([^"]+)"/);
      if (sm) version = sm[1];
      else {
        const im = rhs.match(/version\s*=\s*"([^"]+)"/);
        if (im) version = im[1];
      }
      if (name) out.push({ name, version, section });
    }
  }
  return out;
}

function parseGoSum(content) {
  // Each line: `<module> <version>[/go.mod] <hash>`
  // We dedupe by (module, version) since each module appears with both forms.
  const seen = new Set();
  const out = [];
  for (const rawLine of content.split('\n')) {
    const line = rawLine.trim();
    if (!line) continue;
    const m = line.match(/^(\S+)\s+(v\S+?)(?:\/go\.mod)?\s+\S+/);
    if (!m) continue;
    const key = `${m[1]}@${m[2]}`;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push({ name: m[1], version: m[2] });
  }
  return out;
}

module.exports = { readManifests, parsePackageJson, parseRequirements, parseCargoToml, parseGoSum };
