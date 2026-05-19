'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');

/**
 * Create a fresh temp directory that's cleaned up on process exit.
 * Returns the absolute path.
 */
function makeTempDir(prefix = 'graph-test-') {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), prefix));
  process.on('exit', () => {
    try { fs.rmSync(dir, { recursive: true, force: true }); } catch (_) {}
  });
  return dir;
}

/**
 * Populate a directory from a { relPath: string, ... } spec.
 * Any missing parent directories are created automatically.
 */
function writeTree(root, tree) {
  for (const [rel, contents] of Object.entries(tree)) {
    const full = path.join(root, rel);
    fs.mkdirSync(path.dirname(full), { recursive: true });
    fs.writeFileSync(full, contents);
  }
}

/** Shorthand: create temp dir and populate with tree in one call. */
function makeFixtureRepo(tree, prefix) {
  const dir = makeTempDir(prefix);
  writeTree(dir, tree);
  return dir;
}

module.exports = { makeTempDir, writeTree, makeFixtureRepo };
