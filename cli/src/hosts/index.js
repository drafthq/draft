'use strict';

// Host registry. Order here is the order shown by `draft list`.
const hosts = [
  require('./claude-code'),
  require('./cursor'),
  require('./codex'),
  require('./opencode'),
];

const byId = new Map();
for (const host of hosts) {
  byId.set(host.id, host);
  for (const alias of host.aliases || []) {
    byId.set(alias, host);
  }
}

function getHost(id) {
  if (!id) return null;
  return byId.get(String(id).toLowerCase()) || null;
}

module.exports = { hosts, getHost };
