'use strict';

const path = require('path');
const { asset } = require('../lib/paths');

// Cursor natively understands the .claude-plugin structure. Install the same
// native plugin tree, by default to the user-level plugin directory so it is
// available across all projects.
const ITEMS = [
  { p: '.claude-plugin', kind: 'copyTree' },
  { p: 'skills', kind: 'copyTree' },
  { p: 'core', kind: 'copyTree' },
  { p: 'bin', kind: 'copyTree' },
  { p: 'scripts/tools', kind: 'copyTree' },
  { p: 'scripts/fetch-memory-engine.sh', kind: 'copyFile' },
  { p: 'scripts/lib.sh', kind: 'copyFile' },
];

function cursorHome(ctx) {
  return ctx.env.CURSOR_HOME || path.join(ctx.home, '.cursor');
}

module.exports = {
  id: 'cursor',
  label: 'Cursor',
  aliases: [],
  defaultScope: 'global',

  plan(ctx) {
    const base = ctx.scope === 'project'
      ? path.join(ctx.cwd, '.cursor', 'plugins', 'local', 'draft')
      : path.join(cursorHome(ctx), 'plugins', 'local', 'draft');

    const actions = ITEMS.map((it) => ({
      kind: it.kind,
      src: asset(it.p),
      dest: path.join(base, it.p),
      label: it.p,
    }));
    // Guard the whole install dir on the manifest's presence.
    actions[0].guard = true;

    return {
      targetSummary: `${base} (${ctx.scope})`,
      actions,
      graph: true,
      done: `Draft installed to ${base}. Restart Cursor to detect the plugin.`,
    };
  },
};
