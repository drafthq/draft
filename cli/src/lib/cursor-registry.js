'use strict';

// Cursor reads plugins from the shared Claude plugin registry under ~/.claude/
// on many builds, so a file copy alone never surfaces /draft:* commands. This
// module merges Draft into the three registry files non-destructively:
//   - ~/.claude/plugins/known_marketplaces.json   (marketplace entry)
//   - ~/.claude/plugins/installed_plugins.json     (install record)
//   - ~/.claude/settings.json                       (enabledPlugins flag)
// Every write preserves all other plugins, hooks, and unknown keys. Reads of a
// corrupt JSON file fail loud rather than silently clobbering user data.
const fs = require('fs');
const path = require('path');
const log = require('./log');

const MARKETPLACE_KEY = 'draft-plugins';
const PLUGIN_KEY = `draft@${MARKETPLACE_KEY}`; // name@<marketplace name>

function readJson(filePath, fallback) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch (err) {
    if (err.code === 'ENOENT') return fallback;
    throw new Error(`Cannot parse ${filePath}: ${err.message}`);
  }
}

function writeJsonAtomic(filePath, data) {
  const dir = path.dirname(filePath);
  fs.mkdirSync(dir, { recursive: true });
  const tmp = `${filePath}.tmp.${process.pid}`;
  fs.writeFileSync(tmp, JSON.stringify(data, null, 2) + '\n', 'utf8');
  fs.renameSync(tmp, filePath);
}

function claudeHome(home) {
  return path.join(home, '.claude');
}

function registryPaths(home) {
  const base = path.join(claudeHome(home), 'plugins');
  return {
    kmPath: path.join(base, 'known_marketplaces.json'),
    ipPath: path.join(base, 'installed_plugins.json'),
    settingsPath: path.join(claudeHome(home), 'settings.json'),
  };
}

function registryScope(scope) {
  return scope === 'project' ? 'project' : 'user';
}

// Pure: compute the merged registry objects without touching disk. Callers that
// want to persist them use applyCursorRegistration (which delegates here first).
function registerCursorPlugin(opts) {
  const { home, version, scope } = opts;
  const installPath = path.resolve(opts.installPath);
  const now = new Date().toISOString();
  const paths = registryPaths(home);

  // --- known_marketplaces.json: overwrite only our key. ---
  const km = readJson(paths.kmPath, {});
  km[MARKETPLACE_KEY] = {
    source: { source: 'directory', path: installPath },
    installLocation: installPath,
    lastUpdated: now,
  };

  // --- installed_plugins.json: merge our key, preserve installedAt on upgrade. ---
  const ip = readJson(paths.ipPath, { version: 2, plugins: {} });
  if (typeof ip.version !== 'number') ip.version = 2;
  if (!ip.plugins || typeof ip.plugins !== 'object') ip.plugins = {};
  const existing = Array.isArray(ip.plugins[PLUGIN_KEY]) ? ip.plugins[PLUGIN_KEY][0] : null;
  const installedAt = existing && existing.installedAt ? existing.installedAt : now;
  ip.plugins[PLUGIN_KEY] = [
    {
      scope: registryScope(scope),
      installPath,
      version,
      installedAt,
      lastUpdated: now,
    },
  ];

  // --- settings.json: flip our enabledPlugins flag, preserve everything else. ---
  const settings = readJson(paths.settingsPath, {});
  if (!settings.enabledPlugins || typeof settings.enabledPlugins !== 'object') {
    settings.enabledPlugins = {};
  }
  settings.enabledPlugins[PLUGIN_KEY] = true;

  return {
    kmPath: paths.kmPath,
    km,
    ipPath: paths.ipPath,
    ip,
    settingsPath: paths.settingsPath,
    settings,
  };
}

// Compute the merges and, unless dryRun, persist them atomically. Returns the
// same shape as registerCursorPlugin so the installer can log the paths.
function applyCursorRegistration(opts) {
  const result = registerCursorPlugin(opts);
  if (opts.dryRun) return result;

  log.plan(`writing: ${result.kmPath}`);
  writeJsonAtomic(result.kmPath, result.km);
  log.plan(`writing: ${result.ipPath}`);
  writeJsonAtomic(result.ipPath, result.ip);
  log.plan(`writing: ${result.settingsPath}`);
  writeJsonAtomic(result.settingsPath, result.settings);

  return result;
}

module.exports = {
  PLUGIN_KEY,
  MARKETPLACE_KEY,
  registerCursorPlugin,
  applyCursorRegistration,
};
