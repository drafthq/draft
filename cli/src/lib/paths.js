'use strict';

const path = require('path');

// The package root holds the bundled assets (skills/, core/, integrations/, …).
// cli/src/lib/paths.js → ../../.. === package root, identical for global installs
// and `npx` (both unpack the published tarball with this layout).
const PACKAGE_ROOT = path.resolve(__dirname, '..', '..', '..');

function asset(...parts) {
  return path.join(PACKAGE_ROOT, ...parts);
}

module.exports = { PACKAGE_ROOT, asset };
