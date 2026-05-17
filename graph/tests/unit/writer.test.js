'use strict';

const fs = require('fs');
const path = require('path');
const { describe, it, assertEq, assertTrue, assertContains, assertNotContains } = require('../lib/harness');
const { writeGraph } = require('../../src/writer');
const { makeTempDir } = require('../lib/tempdir');

function loadJsonl(file) {
  return fs.readFileSync(file, 'utf8')
    .split('\n')
    .filter(l => l.trim().length > 0)
    .map(l => JSON.parse(l));
}

function emptyIndexes() {
  return {
    goIndex: { functions: [], types: [], imports: [], calls: [] },
    pythonIndex: { functions: [], classes: [], imports: [], calls: [] },
    tsIndex: { functions: [], classes: [], imports: [], calls: [] },
    cIndex: { functions: [], types: [], calls: [] },
    ctagsIndex: { symbols: [] },
    includeGraph:{ nodes: [], edges: [], moduleEdges: [] },
    protoIndex: { services: [], rpcs: [], messages: [], enums: [] },
  };
}

describe('writer.writeGraph — TS relative-import module edges (M3)', () => {
  it('resolves deep-nested relative imports to correct target module', () => {
    const out = makeTempDir();
    const repo = '/fake/repo';
    const modules = [
      { name: 'api', path: repo + '/api', sizeKB: 0, files: { cc:0,h:0,go:0,proto:0,py:0,java:0,rs:0,ts:1,other:0,total:1 } },
      { name: 'shared', path: repo + '/shared', sizeKB: 0, files: { cc:0,h:0,go:0,proto:0,py:0,java:0,rs:0,ts:1,other:0,total:1 } },
    ];
    const idx = emptyIndexes();
    idx.tsIndex.imports = [
      // api/routes/v1/handler.ts is 3 dirs deep — needs ../../../ to escape `api`
      { from: '../../../shared/auth', file: 'api/routes/v1/handler.ts', module: 'api' },
      // api/foo.ts imports from ./bar → same module, must not produce an edge
      { from: './bar', file: 'api/foo.ts', module: 'api' },
      // api/foo.ts imports from "react" → bare package, skip
      { from: 'react', file: 'api/foo.ts', module: 'api' },
      // shared/index.ts imports from "../api/types" → api (cross-module, reverse direction)
      { from: '../api/types', file: 'shared/index.ts', module: 'shared' },
      // api/deep.ts imports from '../../../../escape' → escapes repo root, skip
      { from: '../../../../escape', file: 'api/deep.ts', module: 'api' },
    ];
    writeGraph({ out, repo, modules, ...idx });

    const records = loadJsonl(path.join(out, 'module-graph.jsonl'));
    const edges = records.filter(r => r.kind === 'edge');
    const edgeKeys = edges.map(e => `${e.source}->${e.target}`);

    assertContains (edgeKeys, 'api->shared', 'api → shared edge via ../../shared/auth');
    assertContains (edgeKeys, 'shared->api', 'shared → api edge via ../api/types');
    assertNotContains(edgeKeys, 'api->api', 'self-edges must be skipped');
    assertNotContains(edgeKeys, 'api->react', 'bare package specifiers must not produce edges');
  });
});

describe('writer.writeGraph — per-module file has kind field (L7)', () => {
  it('tags per-module call records with language-specific kind', () => {
    const out = makeTempDir();
    const repo = '/fake/repo';
    const modules = [
      { name: 'svc', path: repo + '/svc', sizeKB: 0, files: { cc:0,h:0,go:1,proto:0,py:0,java:0,rs:0,ts:0,other:0,total:1 } },
    ];
    const idx = emptyIndexes();
    idx.goIndex.functions = [
      { name: 'Handle', receiver: null, qualified: 'Handle', file: 'svc/app.go', module: 'svc', package: 'svc', line: 5, lines: 10 },
    ];
    idx.goIndex.calls = [
      { from: 'Handle', to: 'json.Marshal', fromFile: 'svc/app.go', module: 'svc', line: 7, resolved: 'json.Marshal' },
    ];
    writeGraph({ out, repo, modules, ...idx });

    const svcRecords = loadJsonl(path.join(out, 'modules', 'svc.jsonl'));
    const calls = svcRecords.filter(r => r.kind === 'go-call');
    assertEq(calls.length, 1, 'go-call record must be present in per-module file');
    assertEq(calls[0].to, 'json.Marshal');
  });
});

describe('writer.writeGraph — basic outputs', () => {
  it('writes schema + module-graph + hotspots + proto-index', () => {
    const out = makeTempDir();
    const repo = '/fake/repo';
    const modules = [
      { name: 'a', path: repo + '/a', sizeKB: 0, files: { cc:0,h:0,go:1,proto:0,py:0,java:0,rs:0,ts:0,other:0,total:1 } },
    ];
    const idx = emptyIndexes();
    writeGraph({ out, repo, modules, ...idx });

    assertTrue(fs.existsSync(path.join(out, 'module-graph.jsonl')));
    assertTrue(fs.existsSync(path.join(out, 'proto-index.jsonl')));
    assertTrue(fs.existsSync(path.join(out, 'hotspots.jsonl')));
    assertTrue(fs.existsSync(path.join(out, 'modules')));
  });
});

describe('writer.writeGraph — new artifact emission (T2.3 / T2.5 / T3.2-T3.4)', () => {
  it('writes external-deps.jsonl, macros.jsonl, satisfies.jsonl, build-hints.jsonl, manifests.jsonl when data present', () => {
    const out = makeTempDir();
    const repo = '/fake/repo';
    const modules = [{ name: 'a', path: repo + '/a', sizeKB: 0, files: { cc:1,h:0,go:0,proto:0,py:0,java:0,rs:0,ts:0,other:0,total:1 } }];
    const idx = emptyIndexes();
    idx.includeGraph.externalDeps = [
      { header: 'absl/strings/str_cat.h', bucket: 'absl', count: 3, importers: ['a/x.cc', 'a/y.cc', 'a/z.cc'] },
    ];
    writeGraph({
      out, repo, modules,
      ...idx,
      macroIndex: { macros: [{ name: 'MAX', file: 'a/util.h', module: 'a', line: 4, params: ['a','b'], id: 'aa11bb22cc33' }] },
      satisfies: [{ from: '*Buffer', to: 'io.Reader', confidence: 'heuristic', fromFile: 'a/buf.go', toFile: 'a/io.go' }],
      buildHints: { libraries: [{ name: 'lib', kind: 'cc_library', srcs: ['a.cc'], deps: [], visibility: [], file: 'a/BUILD' }], edges: [] },
      manifests: [{ kind: 'package.json', file: 'package.json', deps: [{ name: 'react', version: '18' }] }],
    });

    assertTrue(fs.existsSync(path.join(out, 'external-deps.jsonl')), 'external-deps.jsonl');
    assertTrue(fs.existsSync(path.join(out, 'macros.jsonl')), 'macros.jsonl');
    assertTrue(fs.existsSync(path.join(out, 'satisfies.jsonl')), 'satisfies.jsonl');
    assertTrue(fs.existsSync(path.join(out, 'build-hints.jsonl')), 'build-hints.jsonl');
    assertTrue(fs.existsSync(path.join(out, 'manifests.jsonl')), 'manifests.jsonl');

    const ext = loadJsonl(path.join(out, 'external-deps.jsonl'));
    assertEq(ext.length, 1);
    assertEq(ext[0].kind, 'external-dep');
    assertEq(ext[0].header, 'absl/strings/str_cat.h');

    const sat = loadJsonl(path.join(out, 'satisfies.jsonl'));
    assertEq(sat[0].confidence, 'heuristic');

    const manifestRecords = loadJsonl(path.join(out, 'manifests.jsonl'));
    const summary = manifestRecords.find(r => r.kind === 'manifest');
    const dep = manifestRecords.find(r => r.kind === 'external-pkg');
    assertEq(summary.dep_count, 1);
    assertEq(dep.name, 'react');
  });

  it('writer.schema.yaml: includes resolution + opt_in blocks when provided', () => {
    const out = makeTempDir();
    const repo = '/fake/repo';
    const modules = [{ name: 'a', path: repo + '/a', sizeKB: 0, files: { cc:0,h:0,go:1,proto:0,py:0,java:0,rs:0,ts:0,other:0,total:1 } }];
    const idx = emptyIndexes();
    writeGraph({
      out, repo, modules,
      ...idx,
      goMod: { module: 'example.com/example/proj' },
      compileDb: { entries: 5, searchPaths: ['include'], defines: [] },
      manifests: [{ kind: 'package.json', file: 'package.json', deps: [] }],
      buildHints: { libraries: [{ name: 'lib', kind: 'cc_library' }], edges: [] },
      resolveStats: { go: { total:1, exact:1, ambiguous:0, unresolved:0 },
                      cpp:{ total:0, exact:0, ambiguous:0, unresolved:0 },
                      python:{ total:0, exact:0, ambiguous:0, unresolved:0 },
                      ts: { total:0, exact:0, ambiguous:0, unresolved:0 } },
    });
    const schema = fs.readFileSync(path.join(out, 'schema.yaml'), 'utf8');
    assertContains(schema, 'resolution:');
    assertContains(schema, 'opt_in:');
    assertContains(schema, 'go_mod_module: example.com/example/proj');
  });
});
