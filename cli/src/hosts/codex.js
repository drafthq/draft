'use strict';

const path = require('path');
const { asset } = require('../lib/paths');

// Codex reads an AGENTS.md from the repo root. Draft ships a generated AGENTS.md
// (the full inlined methodology) — drop it in place. Guarded so we never clobber
// an existing AGENTS.md without --force.
module.exports = {
  id: 'codex',
  label: 'OpenAI Codex',
  aliases: ['codex-cli'],
  defaultScope: 'project',

  plan(ctx) {
    const dest = path.join(ctx.cwd, 'AGENTS.md');
    return {
      targetSummary: `${dest} (project)`,
      actions: [
        {
          kind: 'copyFile',
          src: asset('integrations', 'agents', 'AGENTS.md'),
          dest,
          label: 'AGENTS.md',
          guard: true,
        },
      ],
      graph: false,
      done: 'Wrote AGENTS.md — Codex reads it automatically from the repo root.',
      notes: ['Commit AGENTS.md so your whole team shares the Draft methodology.'],
    };
  },
};
