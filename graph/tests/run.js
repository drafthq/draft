#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

// Silence the CLI's cyan [graph]/[done] logging coming from library functions
// under test so the harness output stays readable. Keep stderr intact for
// actual errors (warn/die still print there).
const origLog = console.log;
console.log = (...args) => {
  const joined = args.join(' ');
  if (/\[(graph|done)\]/.test(joined)) return; // swallow
  origLog(...args);
};

// Load every *.test.js under unit/ + e2e/ so their describe/it() calls register.
const testDirs = ['unit', 'e2e'];
for (const dir of testDirs) {
  const full = path.join(__dirname, dir);
  if (!fs.existsSync(full)) continue;
  for (const f of fs.readdirSync(full).sort()) {
    if (f.endsWith('.test.js')) require(path.join(full, f));
  }
}

const { run } = require('./lib/harness');
run();
