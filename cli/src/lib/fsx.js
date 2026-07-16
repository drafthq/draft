'use strict';

const fs = require('fs');
const path = require('path');

function exists(p) {
  try {
    fs.accessSync(p);
    return true;
  } catch {
    return false;
  }
}

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function copyTree(src, dest) {
  ensureDir(path.dirname(dest));
  // Mirror, don't merge: dests are fully draft-owned bundled dirs, and a
  // merge-copy would keep files deleted by newer releases around forever.
  fs.rmSync(dest, { recursive: true, force: true });
  fs.cpSync(src, dest, { recursive: true });
}

function copyFile(src, dest) {
  ensureDir(path.dirname(dest));
  fs.copyFileSync(src, dest);
}

function writeFile(dest, content) {
  ensureDir(path.dirname(dest));
  fs.writeFileSync(dest, content);
}

module.exports = { exists, ensureDir, copyTree, copyFile, writeFile };
