'use strict';

const fsx = require('./lib/fsx');
const log = require('./lib/log');
const { fetchGraph } = require('./lib/graph');

function execAction(act, ctx) {
  log.plan(`${ctx.dryRun ? 'would write' : 'writing'}: ${act.dest}`);
  if (ctx.dryRun) return;
  switch (act.kind) {
    case 'copyTree':
      fsx.copyTree(act.src, act.dest);
      break;
    case 'copyFile':
      fsx.copyFile(act.src, act.dest);
      break;
    case 'writeFile':
      fsx.writeFile(act.dest, act.content);
      break;
    default:
      throw new Error(`Unknown action kind: ${act.kind}`);
  }
}

function install(host, ctx) {
  const plan = host.plan(ctx);
  log.step(`Installing Draft -> ${host.label}  [${plan.targetSummary}]${ctx.dryRun ? '  (dry run)' : ''}`);

  // Pre-flight: every bundled source must exist, and guarded targets must not
  // already exist unless --force. Checked up front so a failure writes nothing.
  for (const act of plan.actions) {
    if (!fsx.exists(act.src)) {
      log.error(`Bundled asset missing: ${act.src}`);
      log.error('Reinstall @drafthq/draft — the package looks incomplete.');
      return 1;
    }
    if (act.guard && fsx.exists(act.dest) && !ctx.force) {
      log.error(`${act.dest} already exists. Re-run with --force to overwrite.`);
      return 1;
    }
  }

  for (const act of plan.actions) {
    execAction(act, ctx);
  }

  if (plan.graph && ctx.graph && !ctx.dryRun) {
    fetchGraph(ctx);
  }

  (plan.notes || []).forEach((n) => log.note(n));

  if (ctx.dryRun) {
    log.success('Dry run complete — no files written.');
  } else {
    log.success(plan.done || 'Done.');
  }
  return 0;
}

module.exports = { install };
