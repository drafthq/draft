'use strict';

const path = require('path');
const { asset } = require('../lib/paths');
const { readPluginVersion } = require('../lib/plugin-manifest');
const { applyCursorRegistration } = require('../lib/cursor-registry');

// Cursor discovers Draft through two layers, both shipped here: the native
// .cursor-plugin/plugin.json manifest, and the shared Claude plugin registry
// under ~/.claude/ (written in postInstall). A file copy alone is not enough —
// current Cursor builds never surface /draft:* commands without registration.
const ITEMS = [
  { p: '.cursor-plugin', kind: 'copyTree' },
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
    // Guard the whole install dir on the .cursor-plugin manifest's presence.
    actions[0].guard = true;

    return {
      targetSummary: `${base} (${ctx.scope})`,
      actions,
      graph: true,
      // Runs after the file copies: register + enable the plugin in the shared
      // Claude registry. On a dry run it computes the merges and writes nothing.
      postInstall(c) {
        const installedManifest = path.join(base, '.cursor-plugin', 'plugin.json');
        const version = readPluginVersion(
          c.dryRun ? asset('.cursor-plugin', 'plugin.json') : installedManifest
        );
        return applyCursorRegistration({
          home: c.home,
          installPath: base,
          version,
          scope: c.scope,
          dryRun: c.dryRun,
        });
      },
      done: [
        `Draft installed to ${base}.`,
        'Plugin registered and enabled in ~/.claude/plugins/.',
        'Restart Cursor (Developer: Reload Window) to load /draft:* commands.',
      ].join(' '),
      fallbackTitle: 'If /draft commands do not appear after restart:',
      fallback: [
        `Confirm ${base}/.cursor-plugin/plugin.json exists`,
        'Confirm ~/.claude/plugins/installed_plugins.json contains "draft@draft-plugins"',
        'Confirm ~/.claude/settings.json has "draft@draft-plugins": true',
        'Run Developer: Reload Window in Cursor',
      ],
    };
  },
};
