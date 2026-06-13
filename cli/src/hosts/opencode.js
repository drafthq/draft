'use strict';

const path = require('path');
const { asset } = require('../lib/paths');

// opencode reads AGENTS.md from the repo root and auto-discovers skills under the
// cross-host ~/.agents/skills/ convention. Write the generated AGENTS.md (the
// working integration) and bundle Draft's skills under ~/.agents/skills/draft/.
module.exports = {
  id: 'opencode',
  label: 'opencode',
  aliases: ['open-code'],
  defaultScope: 'project',

  plan(ctx) {
    const agentsDest = path.join(ctx.cwd, 'AGENTS.md');
    const skillsDest = path.join(ctx.home, '.agents', 'skills', 'draft');
    return {
      targetSummary: `${agentsDest} + ${skillsDest}`,
      actions: [
        {
          kind: 'copyFile',
          src: asset('integrations', 'agents', 'AGENTS.md'),
          dest: agentsDest,
          label: 'AGENTS.md',
          guard: true,
        },
        {
          kind: 'copyTree',
          src: asset('skills'),
          dest: skillsDest,
          label: '~/.agents/skills/draft/',
        },
      ],
      graph: false,
      done: 'opencode reads AGENTS.md from the repo root; Draft skills bundled under ~/.agents/skills/draft/.',
    };
  },
};
