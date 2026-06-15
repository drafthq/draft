'use strict';

const { spawnSync } = require('child_process');
const fsx = require('./lib/fsx');
const log = require('./lib/log');
const { fetchGraph } = require('./lib/graph');

// A short ceiling so a wedged `claude --version` can't hang the installer
// before we even reach the real (separately-timed) install steps.
const CHECK_TIMEOUT_MS = 10000;

function hasBinary(name) {
  // ENOENT on the error means the binary is not on PATH.
  const r = spawnSync(name, ['--version'], { stdio: 'ignore', timeout: CHECK_TIMEOUT_MS });
  return !(r.error && r.error.code === 'ENOENT');
}

// Per-step ceiling so a stalled network op (e.g. the `git clone` behind
// `claude plugin marketplace add`) fails loudly with the manual fallback
// instead of hanging the installer forever. Override with DRAFT_INSTALL_TIMEOUT_MS.
const STEP_TIMEOUT_MS = Number(process.env.DRAFT_INSTALL_TIMEOUT_MS) || 300000;

function execAction(act, ctx) {
  const printable = `${act.cmd} ${act.args.join(' ')}`;
  log.plan(`${ctx.dryRun ? 'would run' : 'running'}: ${printable}`);
  if (ctx.dryRun) return 0;
  const r = spawnSync(act.cmd, act.args, { stdio: 'inherit', timeout: STEP_TIMEOUT_MS });
  if (r.error) {
    if (r.error.code === 'ETIMEDOUT') {
      log.error(`timed out after ${Math.round(STEP_TIMEOUT_MS / 1000)}s: ${printable}`);
    } else {
      log.error(`failed to run ${act.cmd}: ${r.error.message}`);
    }
    return 1;
  }
  return r.status == null ? 1 : r.status;
}

function fsAction(act, ctx) {
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

function printFallback(plan) {
  if (plan.fallbackTitle) log.warn(plan.fallbackTitle);
  (plan.fallback || []).forEach((line) => log.info('    ' + line));
}

function install(host, ctx) {
  const plan = host.plan(ctx);
  log.step(`Installing Draft -> ${host.label}  [${plan.targetSummary}]${ctx.dryRun ? '  (dry run)' : ''}`);

  // A plan may require an external CLI (e.g. claude). If it's missing, say so
  // loudly, print the manual fallback, and exit non-zero — a no-op must never
  // read as success. Only enforced on a real install; a dry run still shows the
  // planned commands.
  if (plan.requires && !ctx.dryRun && !hasBinary(plan.requires)) {
    log.error(`Cannot auto-install: the "${plan.requires}" CLI is not on your PATH. Nothing was installed.`);
    printFallback(plan);
    return 1;
  }

  // Pre-flight: for file copies, every bundled source must exist and guarded
  // targets must not already exist unless --force. Checked up front so a
  // failure writes nothing.
  for (const act of plan.actions) {
    if (act.kind === 'exec') continue;
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
    if (act.kind === 'exec') {
      const code = execAction(act, ctx);
      if (code !== 0) {
        log.error(`Step failed (exit ${code}): ${act.label || act.cmd}`);
        if (plan.onFailHint) log.error(plan.onFailHint);
        if (plan.fallback) printFallback(plan);
        return code;
      }
    } else {
      fsAction(act, ctx);
    }
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

module.exports = { install, hasBinary };
