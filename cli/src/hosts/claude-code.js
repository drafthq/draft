'use strict';

// Claude Code loads plugins from its own registry (via a marketplace), NOT from
// an arbitrary project directory — so copying files into the cwd never registers
// the /draft:* commands. The correct install is the `claude plugin` CLI:
//   claude plugin marketplace add drafthq/draft
//   claude plugin install draft@draft-plugins --scope <user|project>
// Default scope is `user` (global, available in every project). If the `claude`
// CLI isn't on PATH, we print the equivalent in-session slash commands.
const MARKETPLACE_REPO = 'drafthq/draft';
const PLUGIN_REF = 'draft@draft-plugins'; // name@<marketplace name from marketplace.json>

module.exports = {
  id: 'claude-code',
  label: 'Claude Code',
  aliases: ['claude', 'claudecode'],
  defaultScope: 'global',

  plan(ctx) {
    const scope = ctx.scope === 'project' ? 'project' : 'user'; // --global -> user
    return {
      targetSummary: `Claude Code plugin registry (scope: ${scope})`,
      requires: 'claude',
      actions: [
        {
          kind: 'exec',
          cmd: 'claude',
          args: ['plugin', 'marketplace', 'add', MARKETPLACE_REPO],
          label: `claude plugin marketplace add ${MARKETPLACE_REPO}`,
        },
        {
          kind: 'exec',
          cmd: 'claude',
          args: ['plugin', 'install', PLUGIN_REF, '--scope', scope],
          label: `claude plugin install ${PLUGIN_REF} --scope ${scope}`,
        },
      ],
      graph: true, // fetch the graph engine at install time (/draft:init also fetches on first use as a fallback)
      done: 'Installed draft. Restart Claude Code (or start a new session), then run /draft:init.',
      fallbackTitle: 'Claude Code CLI not found. Run these in Claude Code instead:',
      fallback: [
        '/plugin marketplace add drafthq/draft',
        '/plugin install draft',
      ],
    };
  },
};
