'use strict';

const { describe, it, assertEq, assertContains } = require('../lib/harness');
const {
  readManifests, parsePackageJson, parseRequirements, parseCargoToml, parseGoSum,
} = require('../../src/extractor-manifest');
const { makeFixtureRepo } = require('../lib/tempdir');

describe('extractor-manifest (T3.3) — parsers', () => {
  it('parses package.json deps + devDeps + peerDeps', () => {
    const out = parsePackageJson(JSON.stringify({
      dependencies: { react: '^18.0.0', lodash: '4.17.21' },
      devDependencies: { jest: '29' },
      peerDependencies:{ react: '*' },
    }));
    const names = out.map(d => d.name);
    assertContains(names, 'react');
    assertContains(names, 'lodash');
    assertContains(names, 'jest');
    assertEq(out.length, 4); // react appears in deps + peer
  });

  it('parses requirements.txt skipping flags and capturing version specifiers', () => {
    const out = parseRequirements(`
# header
flask==2.3.0
requests>=2.28
-e git+https://example.com/x/y@main
numpy~=1.26
`);
    assertEq(out.find(d => d.name === 'flask').version, '==2.3.0');
    assertEq(out.find(d => d.name === 'requests').version, '>=2.28');
    assertEq(out.length, 3, 'editable/-e line is skipped');
  });

  it('parses Cargo.toml [dependencies] section, both inline and table forms', () => {
    const out = parseCargoToml(`
[package]
name = "x"

[dependencies]
serde = "1.0"
tokio = { version = "1.32", features = ["full"] }

[dev-dependencies]
mockall = "0.11"
`);
    const names = out.map(d => d.name);
    assertContains(names, 'serde');
    assertContains(names, 'tokio');
    assertContains(names, 'mockall');
    assertEq(out.find(d => d.name === 'tokio').version, '1.32');
  });

  it('parses go.sum and dedupes module/version pairs', () => {
    const out = parseGoSum(`
example.com/stretchr/testify v1.8.4 h1:abc
example.com/stretchr/testify v1.8.4/go.mod h1:def
example.org/x/sync v0.5.0 h1:ghi
`);
    assertEq(out.length, 2);
    const names = out.map(d => d.name);
    assertContains(names, 'example.com/stretchr/testify');
    assertContains(names, 'golang.org/x/sync');
  });
});

describe('extractor-manifest (T3.3) — readManifests integration', () => {
  it('discovers and aggregates manifests at root + one level deep', () => {
    const repo = makeFixtureRepo({
      'package.json': JSON.stringify({ dependencies: { foo: '1' } }),
      'frontend/package.json': JSON.stringify({ dependencies: { bar: '2' } }),
      'requirements.txt': 'flask==2',
      'go.sum': 'mod v0.1.0 h1:zzz\n',
    });
    const { manifests } = readManifests(repo);
    const kinds = manifests.map(m => m.kind);
    assertContains(kinds, 'package.json');
    assertContains(kinds, 'requirements.txt');
    assertContains(kinds, 'go.sum');
  });
});
