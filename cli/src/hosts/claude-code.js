'use strict';

const path = require('path');
const { asset } = require('../lib/paths');

// Draft's native plugin shape: the .claude-plugin manifest + skills/core/bin and
// the deterministic shell helpers the skills invoke. Copied into the project root
// so Claude Code (and Cursor, which shares the format) discovers it locally.
const ITEMS = [
  { p: '.claude-plugin', kind: 'copyTree' },
  { p: 'skills', kind: 'copyTree' },
  { p: 'core', kind: 'copyTree' },
  { p: 'bin', kind: 'copyTree' },
  { p: 'scripts/tools', kind: 'copyTree' },
  { p: 'scripts/fetch-memory-engine.sh', kind: 'copyFile' },
  { p: 'scripts/lib.sh', kind: 'copyFile' },
];

module.exports = {
  id: 'claude-code',
  label: 'Claude Code',
  aliases: ['claude', 'claudecode'],
  defaultScope: 'project',

  plan(ctx) {
    const root = ctx.cwd;
    const actions = ITEMS.map((it) => ({
      kind: it.kind,
      src: asset(it.p),
      dest: path.join(root, it.p),
      label: it.p,
      // Guard on the manifest dir: its presence marks a prior Draft install.
      guard: it.p === '.claude-plugin',
    }));

    return {
      targetSummary: `${root} (project)`,
      actions,
      graph: true,
      done: 'Draft plugin copied into the project. Run /draft in Claude Code to see the commands.',
      notes: [
        'Alternative (no npm): /plugin marketplace add drafthq/draft  then  /plugin install draft',
      ],
    };
  },
};
