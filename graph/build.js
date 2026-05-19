'use strict';

/**
 * Build script — bundles graph into a single CJS file,
 * then creates a Linux x64 SEA binary with WASM grammars embedded.
 *
 * Usage:
 * node build.js — bundle only (for dev/testing)
 * node build.js --binary — full binary (requires Node 20+)
 */

const { build } = require('esbuild');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const BINARY_FLAG = process.argv.includes('--binary');
const OUT_DIR = path.join(__dirname, 'dist');
const BUNDLE_PATH = path.join(OUT_DIR, 'bundle.cjs');
const BLOB_PATH = path.join(OUT_DIR, 'graph.blob');
const BIN_PATH = path.join(__dirname, 'bin', 'graph');

// WASM files to embed as SEA assets
// Sourced from node_modules after npm install
const WASM_ASSETS = {
  'tree-sitter.wasm': 'node_modules/web-tree-sitter/tree-sitter.wasm',
  'tree-sitter-go.wasm': 'node_modules/tree-sitter-wasms/out/tree-sitter-go.wasm',
  'tree-sitter-python.wasm': 'node_modules/tree-sitter-wasms/out/tree-sitter-python.wasm',
  'tree-sitter-typescript.wasm': 'node_modules/tree-sitter-wasms/out/tree-sitter-typescript.wasm',
  'tree-sitter-tsx.wasm': 'node_modules/tree-sitter-wasms/out/tree-sitter-tsx.wasm',
  'tree-sitter-c.wasm': 'node_modules/tree-sitter-wasms/out/tree-sitter-c.wasm',
  'tree-sitter-cpp.wasm': 'node_modules/tree-sitter-wasms/out/tree-sitter-cpp.wasm',
};

// =============================================================================
// STEP 1: esbuild bundle
// =============================================================================
async function bundle() {
  console.log('[1/3] Bundling with esbuild...');
  fs.mkdirSync(OUT_DIR, { recursive: true });

  await build({
    entryPoints: [path.join(__dirname, 'src', 'index.js')],
    bundle: true,
    platform: 'node',
    target: 'node20',
    format: 'cjs',
    outfile: BUNDLE_PATH,

    // Keep node: builtins external (they're in the Node runtime)
    packages: 'bundle',
    external: [
      'node:sea', // SEA API — only available in the compiled binary
      'web-tree-sitter', // loaded via SEA asset in binary, via require in dev
      'tree-sitter-wasms',
    ],

    sourcemap: false,
    minify: false, // keep readable for debugging
    logLevel: 'info',

    define: {
      'process.env.NODE_ENV': '"production"',
    },
  });

  const sizeKB = Math.round(fs.statSync(BUNDLE_PATH).size / 1024);
  console.log(` Bundle: ${BUNDLE_PATH} (${sizeKB}KB)`);
}

// =============================================================================
// STEP 2: SEA config + blob (Node 20+ only)
// =============================================================================
function generateBlob() {
  console.log('[2/3] Generating SEA blob...');

  // Validate WASM assets exist
  const assets = {};
  let hasWasm = false;

  for (const [name, src] of Object.entries(WASM_ASSETS)) {
    const full = path.join(__dirname, src);
    if (fs.existsSync(full)) {
      assets[name] = full;
      hasWasm = true;
      console.log(` Asset: ${name}`);
    } else {
      console.warn(` WARN: WASM not found: ${full} (tree-sitter will use regex fallback)`);
    }
  }

  const seaConfig = {
    main: BUNDLE_PATH,
    output: BLOB_PATH,
    assets: hasWasm ? assets : undefined,
    disableExperimentalSEAWarning: true,
  };

  const configPath = path.join(OUT_DIR, 'sea-config.json');
  fs.writeFileSync(configPath, JSON.stringify(seaConfig, null, 2));

  execSync(`node --experimental-sea-config ${configPath}`, { stdio: 'inherit' });
  console.log(` Blob: ${BLOB_PATH}`);
}

// =============================================================================
// STEP 3: Inject blob into Node binary (Node 20+ only)
// =============================================================================
function injectBinary() {
  console.log('[3/3] Building Linux binary...');

  fs.mkdirSync(path.dirname(BIN_PATH), { recursive: true });

  // Copy current Node binary
  const nodeBin = process.execPath;
  fs.copyFileSync(nodeBin, BIN_PATH);
  console.log(` Copied Node from: ${nodeBin}`);

  // Inject SEA blob
  execSync(
    `npx postject ${BIN_PATH} NODE_SEA_BLOB ${BLOB_PATH} ` +
    `--sentinel-fuse NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2`,
    { stdio: 'inherit' }
  );

  // Strip debug symbols (~15-20MB savings)
  try {
    execSync(`strip ${BIN_PATH}`, { stdio: 'inherit' });
    console.log(' Stripped debug symbols');
  } catch (_) {
    console.warn(' WARN: strip not available, binary may be larger');
  }

  // Make executable
  fs.chmodSync(BIN_PATH, 0o755);

  const sizeKB = Math.round(fs.statSync(BIN_PATH).size / 1024);
  console.log(` Binary: ${BIN_PATH} (${Math.round(sizeKB / 1024)}MB)`);
}

// =============================================================================
// STEP 2-ALT: Shell launcher (works with any Node version)
// =============================================================================
function buildShellLauncher() {
  console.log('[2/2] Creating shell launcher...');

  fs.mkdirSync(path.dirname(BIN_PATH), { recursive: true });

  // Use relative path so the launcher works after packaging/relocation
  const relBundle = path.relative(path.dirname(BIN_PATH), BUNDLE_PATH);
  const launcher = `#!/usr/bin/env node
require(require('path').join(__dirname, ${JSON.stringify(relBundle)}));
`;
  fs.writeFileSync(BIN_PATH, launcher);
  fs.chmodSync(BIN_PATH, 0o755);

  const bundleKB = Math.round(fs.statSync(BUNDLE_PATH).size / 1024);
  console.log(` Launcher: ${BIN_PATH}`);
  console.log(` Bundle: ${BUNDLE_PATH} (${bundleKB}KB)`);
}

// =============================================================================
// MAIN
// =============================================================================
async function main() {
  console.log('graph build\n');

  await bundle();

  if (BINARY_FLAG) {
    // Check Node version for SEA support
    const major = parseInt(process.versions.node.split('.')[0], 10);
    if (major >= 20) {
      generateBlob();
      injectBinary();
      console.log('\nBuild complete (SEA binary).');
    } else {
      console.warn(` Node ${process.versions.node} — SEA requires Node 20+, using shell launcher`);
      buildShellLauncher();
      console.log('\nBuild complete (shell launcher).');
    }
    console.log(`Run: ${BIN_PATH} --repo <path> --out <dir>`);
  } else {
    console.log('\nBundle complete (dev mode).');
    console.log(`Run: node ${BUNDLE_PATH} --repo <path>`);
    console.log('For full binary: node build.js --binary');
  }
}

main().catch(e => { console.error(e); process.exit(1); });
