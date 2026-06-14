'use strict';

// Claude Code loads plugins from its own registry (via a marketplace), NOT from
// an arbitrary project directory — so copying files into the cwd never registers
// the /draft:* commands. The correct install is the `claude plugin` CLI.
//
// We run four idempotent steps so a re-run UPGRADES an existing install rather
// than no-op'ing on "already installed":
//   1. marketplace add  <repo>   — register the marketplace (no-op if present)
//   2. marketplace update <name> — re-fetch manifest from GitHub (the upgrade key)
//   3. plugin install   <ref>    — install (no-op if already installed)
//   4. plugin update    <ref>    — bump an existing install to the new version
// Steps 2 and 4 exit 0 when there's nothing to do, so they're safe on a fresh
// install too. Default scope is `user` (global). If the `claude` CLI isn't on
// PATH, we print the equivalent in-session slash commands.
const MARKETPLACE_REPO = 'drafthq/draft';
const MARKETPLACE_NAME = 'draft-plugins'; // the `name` field in .claude-plugin/marketplace.json
const PLUGIN_REF = `draft@${MARKETPLACE_NAME}`; // name@<marketplace name>

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
          args: ['plugin', 'marketplace', 'update', MARKETPLACE_NAME],
          label: `claude plugin marketplace update ${MARKETPLACE_NAME}`,
        },
        {
          kind: 'exec',
          cmd: 'claude',
          args: ['plugin', 'install', PLUGIN_REF, '--scope', scope],
          label: `claude plugin install ${PLUGIN_REF} --scope ${scope}`,
        },
        {
          kind: 'exec',
          cmd: 'claude',
          args: ['plugin', 'update', PLUGIN_REF, '--scope', scope],
          label: `claude plugin update ${PLUGIN_REF} --scope ${scope}`,
        },
      ],
      graph: true, // fetch the graph engine at install time (/draft:init also fetches on first use as a fallback)
      done: 'Installed/updated draft. Restart Claude Code (or start a new session), then run /draft:init.',
      fallbackTitle: 'Claude Code CLI not found. Run these in Claude Code instead:',
      fallback: [
        '/plugin marketplace add drafthq/draft',
        '/plugin marketplace update draft-plugins',
        '/plugin install draft',
        '/plugin update draft',
      ],
    };
  },
};
