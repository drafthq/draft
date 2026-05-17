'use strict';

const path = require('path');
const { describe, it, assertEq, assertTrue, assertContains, assertNotContains } = require('../lib/harness');
const { makeFixtureRepo } = require('../lib/tempdir');
const { detectModules } = require('../../src/modules');

describe('modules.detectModules', () => {
  it('detects top-level dirs containing source files', () => {
    const repo = makeFixtureRepo({
      'api/handler.go': 'package api\n',
      'proto/svc.proto': 'syntax = "proto3";\nservice S {}\n',
      'docs/README.md': '# docs — no source files\n',
    });
    const mods = detectModules(repo);
    const names = mods.map(m => m.name);
    assertContains (names, 'api');
    assertContains (names, 'proto');
    assertNotContains(names, 'docs', 'docs has no source files, must be skipped');
  });

  it('creates a __root__ entry when there are top-level source files', () => {
    const repo = makeFixtureRepo({
      'main.go': 'package main\n',
      'pkg/helper.go': 'package pkg\n',
    });
    const mods = detectModules(repo);
    const names = mods.map(m => m.name);
    assertContains(names, '__root__');
    assertContains(names, 'pkg');
    const root = mods.find(m => m.name === '__root__');
    assertEq(root.rootOnly, true);
    assertEq(root.files.go, 1, 'should only count root-level .go files, not subdirectories');
  });

  it('H3: detects modules made of only ctags-handled languages (Ruby/Swift/...)', () => {
    const repo = makeFixtureRepo({
      'rubysvc/foo.rb': 'class Foo; end\n',
      'swiftsvc/bar.swift': 'class Bar {}\n',
      'scala/baz.scala': 'object Baz {}\n',
    });
    const mods = detectModules(repo);
    const names = mods.map(m => m.name);
    assertContains(names, 'rubysvc', 'Ruby-only module must be detected (H3 regression)');
    assertContains(names, 'swiftsvc', 'Swift-only module must be detected');
    assertContains(names, 'scala', 'Scala-only module must be detected');
    const rubyMod = mods.find(m => m.name === 'rubysvc');
    assertEq(rubyMod.files.total, 1);
    assertEq(rubyMod.files.other, 1, 'ctags-only languages should land in the `other` bucket');
  });

  it('honors exclude patterns passed as raw strings', () => {
    const repo = makeFixtureRepo({
      'api/handler.go': 'package api\n',
      'api/handler.pb.go': '// generated, should be excluded if the pattern matched .go filenames\n',
      'api/vendor/pkg/x.go': 'package pkg\n',
    });
    const mods = detectModules(repo, ['*/vendor/*']);
    const api = mods.find(m => m.name === 'api');
    assertTrue(api != null, 'api module must exist');
    assertEq(api.files.go, 2, 'expected 2 .go files after excluding api/vendor/*');
  });

  it('returns empty list for repos with no source files', () => {
    const repo = makeFixtureRepo({ 'README.md': '# empty\n' });
    const mods = detectModules(repo);
    assertEq(mods.length, 0);
  });

  it('tolerates missing repo gracefully', () => {
    const mods = detectModules(path.join('/tmp', 'does-not-exist-' + Date.now()));
    assertEq(mods.length, 0);
  });

  it('counts .h/.cc together under cc/h buckets', () => {
    const repo = makeFixtureRepo({
      'cc/foo.cc': 'int foo();\n',
      'cc/foo.h': '#pragma once\n',
      'cc/bar.hpp': '#pragma once\n',
    });
    const mods = detectModules(repo);
    const cc = mods.find(m => m.name === 'cc');
    assertEq(cc.files.cc, 1);
    assertEq(cc.files.h, 2, '.h + .hpp should both land in the h bucket');
  });
});
