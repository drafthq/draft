'use strict';

// Write the install-path marker (~/.cache/draft/plugin-root) so a draft skill can
// locate its bundled scripts/tools/ from the user's project cwd. Skills run with
// cwd = the user's project and ${CLAUDE_PLUGIN_ROOT} is NOT exported into skill Bash,
// so without this marker resolution falls back to globbing the plugin cache. The
// marker is the fast, authoritative path; see core/shared/tool-resolver.md.
//
// Best-effort: any failure is swallowed — graph skills still resolve via the glob
// fallback, so a missing marker is never fatal.

const fs = require('fs');
const os = require('os');
const path = require('path');

// Resolve the installed draft plugin root for a given host, or null if unknown.
function resolvePluginRoot(hostId) {
  const home = os.homedir();

  if (hostId === 'claude-code') {
    // 1. Claude Code's own registry holds the authoritative installPath.
    const reg = path.join(home, '.claude', 'plugins', 'installed_plugins.json');
    try {
      const data = JSON.parse(fs.readFileSync(reg, 'utf8'));
      const key = Object.keys(data.plugins || {}).find((k) => k.startsWith('draft@'));
      const ip = key && data.plugins[key] && data.plugins[key][0] && data.plugins[key][0].installPath;
      if (ip && fs.existsSync(path.join(ip, 'scripts', 'tools'))) return ip;
    } catch {
      /* registry missing or unparseable — fall through to the cache scan */
    }
    // 2. Fallback: newest versioned dir under the plugin cache.
    return newestCacheRoot(path.join(home, '.claude', 'plugins', 'cache'));
  }

  if (hostId === 'cursor') {
    const p = path.join(home, '.cursor', 'plugins', 'local', 'draft');
    return fs.existsSync(path.join(p, 'scripts', 'tools')) ? p : null;
  }

  return null;
}

// Newest <cache>/<marketplace>/draft/<version> dir that carries scripts/tools.
function newestCacheRoot(cacheDir) {
  try {
    const candidates = [];
    for (const mkt of fs.readdirSync(cacheDir)) {
      const draftDir = path.join(cacheDir, mkt, 'draft');
      let versions;
      try {
        versions = fs.readdirSync(draftDir);
      } catch {
        continue;
      }
      for (const v of versions) {
        const root = path.join(draftDir, v);
        if (fs.existsSync(path.join(root, 'scripts', 'tools'))) candidates.push({ v, root });
      }
    }
    if (!candidates.length) return null;
    candidates.sort((a, b) => compareVersions(a.v, b.v));
    return candidates[candidates.length - 1].root;
  } catch {
    return null;
  }
}

// Numeric-aware version compare (no semver dependency).
function compareVersions(a, b) {
  const pa = String(a).split('.').map((n) => parseInt(n, 10) || 0);
  const pb = String(b).split('.').map((n) => parseInt(n, 10) || 0);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const d = (pa[i] || 0) - (pb[i] || 0);
    if (d) return d;
  }
  return 0;
}

// Write ~/.cache/draft/plugin-root for the host. Returns the path written, or null.
function writePluginRootMarker(hostId) {
  try {
    const root = resolvePluginRoot(hostId);
    if (!root) return null;
    const dest = path.join(os.homedir(), '.cache', 'draft', 'plugin-root');
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.writeFileSync(dest, root + '\n');
    return root;
  } catch {
    return null;
  }
}

module.exports = { writePluginRootMarker, resolvePluginRoot };
