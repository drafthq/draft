#!/usr/bin/env node
'use strict';

// Entry point for the `draft` CLI. Keeps argv parsing and dispatch in src/cli.js
// so this stays a thin, dependency-free launcher.
const { run } = require('../src/cli');

run(process.argv.slice(2))
  .then((code) => process.exit(code))
  .catch((err) => {
    console.error(err && err.message ? err.message : String(err));
    process.exit(1);
  });
