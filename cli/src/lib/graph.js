'use strict';

const { spawnSync } = require('child_process');
const { asset } = require('./paths');
const fsx = require('./fsx');
const log = require('./log');

// Best-effort fetch of the knowledge-graph engine (codebase-memory-mcp) into the
// Draft-managed cache (~/.cache/draft/bin). Network-gated; failures are non-fatal
// because graph features degrade gracefully when the engine is absent.
function fetchGraph() {
  const script = asset('scripts', 'fetch-memory-engine.sh');
  if (!fsx.exists(script)) {
    return;
  }
  log.note('Fetching knowledge-graph engine (best-effort)...');
  const result = spawnSync('bash', [script], { stdio: 'inherit' });
  if (result.status !== 0) {
    log.warn('Graph engine fetch skipped (offline or unsupported platform) — features degrade gracefully.');
  }
}

module.exports = { fetchGraph };
