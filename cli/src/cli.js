'use strict';

const os = require('os');
const { hosts, getHost } = require('./hosts');
const { install } = require('./installer');
const log = require('./lib/log');
const pkg = require('../../package.json');

function parseFlags(args) {
  const flags = { scope: null, dryRun: false, graph: true, force: false };
  const positionals = [];
  for (const a of args) {
    switch (a) {
      case '--global': flags.scope = 'global'; break;
      case '--project':
      case '--local': flags.scope = 'project'; break;
      case '--dry-run': flags.dryRun = true; break;
      case '--no-graph': flags.graph = false; break;
      case '--force': flags.force = true; break;
      default:
        if (a.startsWith('-')) {
          throw new Error(`Unknown flag: ${a}`);
        }
        positionals.push(a);
    }
  }
  return { flags, positionals };
}

function printHosts() {
  log.info('\nSupported hosts:');
  for (const h of hosts) {
    log.info(`  ${h.id.padEnd(12)} ${h.label}  (${h.defaultScope} install)`);
  }
  log.info('\nUsage: draft install <host> [--global|--project] [--dry-run] [--no-graph] [--force]');
}

function printHelp() {
  log.info(`draft — install the Draft Context-Driven Development methodology into your AI coding agent

Usage:
  draft install <host> [flags]   Install Draft for a host
  draft list                     List supported hosts
  draft --version                Print version
  draft --help                   Show this help

Hosts: ${hosts.map((h) => h.id).join(', ')}

Flags:
  --global        Install to the user-level location (default for cursor)
  --project       Install into the current project (default for claude-code, codex, opencode)
  --dry-run       Print planned writes without touching disk
  --no-graph      Skip the knowledge-graph engine fetch
  --force         Overwrite an existing target

GitHub Copilot / Gemini are not hosts — copy the committed instructions file directly:
  .github/copilot-instructions.md   or   .gemini.md   from github.com/drafthq/draft`);
}

function cmdInstall(args) {
  const { flags, positionals } = parseFlags(args);
  const hostId = positionals[0];
  if (!hostId) {
    log.error('Missing host. Usage: draft install <host>');
    printHosts();
    return 1;
  }
  const host = getHost(hostId);
  if (!host) {
    log.error(`Unknown host: ${hostId}`);
    printHosts();
    return 1;
  }
  const ctx = {
    cwd: process.cwd(),
    home: os.homedir(),
    env: process.env,
    scope: flags.scope || host.defaultScope,
    dryRun: flags.dryRun,
    force: flags.force,
    graph: flags.graph,
  };
  return install(host, ctx);
}

async function run(argv) {
  const [cmd, ...rest] = argv;
  switch (cmd) {
    case undefined:
    case 'help':
    case '--help':
    case '-h':
      printHelp();
      return 0;
    case 'version':
    case '--version':
    case '-v':
      log.info(pkg.version);
      return 0;
    case 'list':
    case 'hosts':
      printHosts();
      return 0;
    case 'install':
      return cmdInstall(rest);
    default:
      log.error(`Unknown command: ${cmd}`);
      printHelp();
      return 1;
  }
}

module.exports = { run, parseFlags };
