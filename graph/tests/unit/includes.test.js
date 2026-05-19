'use strict';

const path = require('path');
const { describe, it, assertEq, assertTrue, assertContains } = require('../lib/harness');
const { buildIncludeGraph } = require('../../src/extractor-includes');
const { detectModules } = require('../../src/modules');
const { makeFixtureRepo } = require('../lib/tempdir');

describe('extractor-includes.buildIncludeGraph', () => {
  it('creates file nodes and include edges', () => {
    const repo = makeFixtureRepo({
      'base/util.h': `#pragma once\nvoid helper();\n`,
      'base/util.cc': `#include "base/util.h"\nvoid helper() {}\n`,
      'api/service.h': `#pragma once\n#include "base/util.h"\nvoid svc();\n`,
      'api/service.cc': `#include "api/service.h"\nvoid svc() { helper(); }\n`,
    });
    const mods = detectModules(repo);
    const graph = buildIncludeGraph(repo, mods, []);

    assertEq(graph.nodes.length, 4, 'one node per C/C++ file');

    const edgeSrcs = graph.edges.map(e => `${e.source}→${e.target}`);
    assertContains(edgeSrcs, 'base/util.cc→base/util.h');
    assertContains(edgeSrcs, 'api/service.h→base/util.h');
    assertContains(edgeSrcs, 'api/service.cc→api/service.h');

    // Module edge: api → base
    const apiToBase = graph.moduleEdges.find(e => e.source === 'api' && e.target === 'base');
    assertTrue(apiToBase, 'expected module edge api → base');
    assertEq(apiToBase.weight, 1);
  });

  it('resolves bare-basename includes via index', () => {
    const repo = makeFixtureRepo({
      'base/util.h': `#pragma once\n`,
      'api/service.cc': `#include "util.h"\n`,
    });
    const mods = detectModules(repo);
    const graph = buildIncludeGraph(repo, mods, []);
    const hasEdge = graph.edges.some(e => e.source === 'api/service.cc' && e.target === 'base/util.h');
    assertTrue(hasEdge, 'bare include "util.h" should resolve to base/util.h');
  });

  it('classifies .hpp as header', () => {
    const repo = makeFixtureRepo({ 'mod/x.hpp': '#pragma once\n' });
    const mods = detectModules(repo);
    const graph = buildIncludeGraph(repo, mods, []);
    assertEq(graph.nodes.length, 1);
    assertEq(graph.nodes[0].kind, 'header');
  });

  it('treats external / system includes as unresolved (no edge)', () => {
    const repo = makeFixtureRepo({
      'mod/a.cc': `#include <stdio.h>\n#include "does_not_exist.h"\n`,
    });
    const mods = detectModules(repo);
    const graph = buildIncludeGraph(repo, mods, []);
    assertEq(graph.edges.length, 0, 'unresolved includes should produce no edges');
    // T2.3: angle-bracket and unresolved quoted includes should appear in externalDeps.
    const headers = graph.externalDeps.map(d => d.header);
    assertContains(headers, 'stdio.h');
    assertContains(headers, 'does_not_exist.h');
  });

  it('T2.3: aggregates angle-bracket external deps with importer counts', () => {
    const repo = makeFixtureRepo({
      'mod/a.cc': `#include <absl/strings/str_cat.h>\n#include <openssl/sha.h>\n`,
      'mod/b.cc': `#include <absl/strings/str_cat.h>\n`,
    });
    const mods = detectModules(repo);
    const g = buildIncludeGraph(repo, mods, []);
    const absl = g.externalDeps.find(d => d.header === 'absl/strings/str_cat.h');
    assertTrue(absl, 'absl header should be tracked');
    assertEq(absl.count, 2, 'imported by 2 files');
    assertEq(absl.bucket, 'absl', 'first path segment exposed as bucket');
    assertEq(absl.importers.length, 2);
  });

  it('T3.1: resolves angle-bracket include against extra search paths', () => {
    // Two headers share the basename `lib.h`; the basename fallback can't
    // disambiguate. Only an explicit -I search path nails the right one.
    const repo = makeFixtureRepo({
      'third_party/zlib/lib.h': '#pragma once\n// the one we want\n',
      'third_party/other/lib.h': '#pragma once\n',
      'mod/a.cc': '#include <lib.h>\n',
    });
    const mods = detectModules(repo);
    const g = buildIncludeGraph(repo, mods, [], null, { searchPaths: ['third_party/zlib'] });
    assertContains(g.edges.map(e => e.target), 'third_party/zlib/lib.h');
  });
});
