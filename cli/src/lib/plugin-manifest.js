'use strict';

// Read name/version from a plugin manifest JSON (.cursor-plugin/plugin.json or
// .claude-plugin/plugin.json). Fails loud if either required field is missing —
// a manifest without a version would corrupt the registry's install record.
const fs = require('fs');

function readPluginManifest(manifestPath) {
  const raw = fs.readFileSync(manifestPath, 'utf8');
  const data = JSON.parse(raw);
  if (!data.name) throw new Error(`Missing name in ${manifestPath}`);
  if (!data.version) throw new Error(`Missing version in ${manifestPath}`);
  return data;
}

function readPluginVersion(manifestPath) {
  return readPluginManifest(manifestPath).version;
}

module.exports = { readPluginManifest, readPluginVersion };
