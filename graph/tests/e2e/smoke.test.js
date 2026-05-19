'use strict';

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const { describe, it, assertEq, assertTrue, assertContains } = require('../lib/harness');
const { makeFixtureRepo, makeTempDir } = require('../lib/tempdir');

const GRAPH_CLI = path.resolve(__dirname, '..', '..', 'src', 'index.js');

function runGraph(args, opts = {}) {
  const res = spawnSync(process.execPath, [GRAPH_CLI, ...args], {
    encoding: 'utf8',
    timeout: 60000,
    ...opts,
  });
  return res;
}

function buildFixtureRepo() {
  return makeFixtureRepo({
    // ── proto module ──────────────────────────────────────────────────────
    'proto/greeter.proto': `
syntax = "proto3";
service Greeter {
  rpc Hello (HelloReq) returns (HelloResp);
  rpc Stream (stream HelloReq) returns (stream HelloResp);
}
message HelloReq { string name = 1; }
message HelloResp { string msg = 1; }
/* block comment with { fake } rpc Ghost (A) returns (B); */
`,
    // ── go service module ────────────────────────────────────────────────
    'service/server.go': `package service

import (
  "fmt"
  "strings"
)

type Server struct { name string }

func (s *Server) Handle(req string) string {
  return fmt.Sprintf("hi %s", strings.TrimSpace(req))
}

func Free() int { return 42 }

func Max[T int | float64](a, b T) T { if a > b { return a }; return b }
`,
    // ── go util module referenced by service via package path ────────────
    'util/util.go': `package util

func Upper(s string) string { return s }
`,
    // ── python worker module ─────────────────────────────────────────────
    'worker/worker.py': `
import json

class Worker:
    async def run(self, msg):
        return json.dumps({"msg": msg})

    def helper(self):
        return 1
`,
    // ── ts web module with deep relative import ──────────────────────────
    'web/src/app.ts': `
import { format } from '../../shared/lib/fmt';
export function main() { return format('hi'); }
`,
    'shared/lib/fmt.ts': `
export function format(s: string) { return '[' + s + ']'; }
`,
    // ── c++ include graph ────────────────────────────────────────────────
    'base/util.h': `#pragma once\nvoid helper();\n`,
    'base/util.cc': `#include "base/util.h"\nvoid helper() {}\n`,
    'api/svc.h': `#pragma once\n#include "base/util.h"\nclass Svc { void go(); };\n`,
    'api/svc.cc': `#include "api/svc.h"\nvoid Svc::go() { helper(); }\n`,
    // ── generated file that must be excluded ─────────────────────────────
    'api/svc.pb.cc': `// GENERATED — should be skipped\nint main(){ return 0; }\n`,
    // ── ruby (ctags-only) module ─────────────────────────────────────────
    'rb/app.rb': `class App\n def run; end\nend\n`,
  });
}

describe('e2e — build + query cycle', () => {
  it('builds graph, produces expected artifacts', () => {
    const repo = buildFixtureRepo();
    const out = path.join(makeTempDir(), 'graph-out');

    const res = runGraph(['--repo', repo, '--out', out]);
    assertEq(res.status, 0, `graph build failed:\nSTDOUT:\n${res.stdout}\nSTDERR:\n${res.stderr}`);

    // Artifacts
    assertTrue(fs.existsSync(path.join(out, 'module-graph.jsonl')));
    assertTrue(fs.existsSync(path.join(out, 'proto-index.jsonl')));
    assertTrue(fs.existsSync(path.join(out, 'hotspots.jsonl')));
    assertTrue(fs.existsSync(path.join(out, 'modules')));

    // Proto: 1 service, 2 RPCs, no ghost RPC from block comment (L4)
    const proto = fs.readFileSync(path.join(out, 'proto-index.jsonl'), 'utf8')
      .split('\n').filter(Boolean).map(JSON.parse);
    const rpcs = proto.filter(r => r.kind === 'rpc');
    assertEq(rpcs.length, 2, 'should have 2 real RPCs, not 3 (Ghost is in block comment)');
    const rpcNames = rpcs.map(r => r.name);
    assertContains(rpcNames, 'Hello');
    assertContains(rpcNames, 'Stream');

    // Module-graph
    const modGraph = fs.readFileSync(path.join(out, 'module-graph.jsonl'), 'utf8')
      .split('\n').filter(Boolean).map(JSON.parse);
    const moduleNames = modGraph.filter(r => r.kind === 'node').map(r => r.id);
    assertContains(moduleNames, 'service');
    assertContains(moduleNames, 'util');
    assertContains(moduleNames, 'proto');
    assertContains(moduleNames, 'worker');
    assertContains(moduleNames, 'web');
    assertContains(moduleNames, 'shared');
    assertContains(moduleNames, 'base');
    assertContains(moduleNames, 'api');
    assertContains(moduleNames, 'rb', 'Ruby-only module must be detected (H3)');

    const edges = modGraph.filter(r => r.kind === 'edge');
    const edgeKeys = edges.map(e => `${e.source}->${e.target}`);
    assertContains(edgeKeys, 'api->base', 'api includes base/util.h');
    assertContains(edgeKeys, 'web->shared', 'web imports ../../shared/lib/fmt (M3 fix)');

    // Per-module files: only modules with actual indexed records get a file.
    // `rb/` (Ruby) only materializes when universal-ctags is installed — we
    // don't assume ctags is on the test machine.
    assertTrue(fs.existsSync(path.join(out, 'modules', 'service.jsonl')));
    assertTrue(fs.existsSync(path.join(out, 'modules', 'api.jsonl')));
    assertTrue(fs.existsSync(path.join(out, 'modules', 'web.jsonl')));
  });

  it('query modules lists cycles (none in fixture)', () => {
    const repo = buildFixtureRepo();
    const out = path.join(makeTempDir(), 'graph-out');
    assertEq(runGraph(['--repo', repo, '--out', out]).status, 0);

    const q = runGraph(['--repo', repo, '--out', out, '--query', '--mode', 'modules']);
    assertEq(q.status, 0, `query failed: ${q.stderr}`);
    const parsed = JSON.parse(q.stdout);
    assertTrue(Array.isArray(parsed.modules));
    assertTrue(Array.isArray(parsed.dependencies));
    assertEq(parsed.cycles.length, 0, 'fixture has no cycles');
  });

  it('query callers with --symbol routes to function-callers (M6)', () => {
    const repo = buildFixtureRepo();
    const out = path.join(makeTempDir(), 'graph-out');
    assertEq(runGraph(['--repo', repo, '--out', out]).status, 0);

    // `fmt.Sprintf` would have been misrouted to file-callers by the old
    // `looksLikeFile` heuristic (the dot). With M6 it routes to
    // queryFunctionCallers, which returns a { target, callers, by_module, ... }
    // shape regardless of whether the call graph is empty.
    const q = runGraph(['--repo', repo, '--out', out, '--query', '--symbol', 'fmt.Sprintf', '--mode', 'callers']);
    assertEq(q.status, 0, `query failed: ${q.stderr}`);
    const parsed = JSON.parse(q.stdout);
    assertTrue('target' in parsed,
      `expected function-callers shape. stdout was:\n${q.stdout}`);
    assertTrue('callers' in parsed, 'should return function-callers shape, not file-callers shape');
    assertTrue(Array.isArray(parsed.callers), 'callers must be an array');
  });

  it('mermaid mode outputs markdown text', () => {
    const repo = buildFixtureRepo();
    const out = path.join(makeTempDir(), 'graph-out');
    assertEq(runGraph(['--repo', repo, '--out', out]).status, 0);

    const q = runGraph(['--repo', repo, '--out', out, '--query', '--mode', 'mermaid']);
    assertEq(q.status, 0, `mermaid query failed: ${q.stderr}`);
    assertTrue(q.stdout.includes('graph') || q.stdout.includes('flowchart'),
      'mermaid output should contain a diagram declaration');
  });

  it('atomic commit: second run replaces first cleanly, no .tmp/.old leftovers', () => {
    const repo = buildFixtureRepo();
    const out = path.join(makeTempDir(), 'graph-out');

    assertEq(runGraph(['--repo', repo, '--out', out]).status, 0);
    const firstMtime = fs.statSync(out).mtimeMs;

    // Second run — should replace atomically.
    assertEq(runGraph(['--repo', repo, '--out', out]).status, 0);

    const parentDir = path.dirname(out);
    const baseName = path.basename(out);
    const leftovers = fs.readdirSync(parentDir).filter(n =>
      n !== baseName &&
      (n.startsWith(baseName + '.tmp-') || n.startsWith(baseName + '.old-'))
    );
    assertEq(leftovers.length, 0, `expected no .tmp/.old leftovers, got: ${leftovers.join(', ')}`);
  });

  it('incremental build writes hashes.json, second run reuses it', () => {
    const repo = buildFixtureRepo();
    const out = path.join(makeTempDir(), 'graph-out');

    const r1 = runGraph(['--repo', repo, '--out', out, '--incremental']);
    assertEq(r1.status, 0);
    assertTrue(fs.existsSync(path.join(out, 'hashes.json')));

    const r2 = runGraph(['--repo', repo, '--out', out, '--incremental']);
    assertEq(r2.status, 0);
    assertTrue(r2.stdout.includes('Incremental: skipping') || r2.stdout.includes('skipping'),
      `second run should skip unchanged modules, stdout was:\n${r2.stdout}`);
  });
});

describe('e2e — new artifacts (T1.3 / T1.4 / T2.3 / T2.5 / T3.1-T3.4)', () => {
  it('emits all new opt-in artifacts and resolves cross-package Go calls via go.mod', () => {
    const repo = makeFixtureRepo({
      'go.mod': `module example.com/proj
go 1.21
`,
      // Two packages with cross-package call resolved via module path.
      'svc/handler.go': `package svc
import "example.com/proj/util"

type Server struct{}

func (s *Server) Handle() string { return util.Upper("hi") }

func Caller() { _ = util.Upper("x") }
`,
      'util/util.go': `package util

// Upper uppercases s.
func Upper(s string) string { return s }
`,
      // C++ with angle-bracket external dep + macro
      'lib/m.h': `#ifndef LIB_M_H_
#define LIB_M_H_

#include <absl/strings/str_cat.h>

#define MAX(a, b) ((a) > (b) ? (a) : (b))

#endif
`,
      // package.json so manifests.jsonl is emitted
      'package.json': JSON.stringify({ dependencies: { react: '^18.0.0' } }),
      // BUILD file so build-hints.jsonl is emitted
      'svc/BUILD': `go_library(name = "svc", srcs = ["handler.go"], deps = ["//util"])`,
    });
    const out = path.join(makeTempDir(), 'graph-out');
    const res = runGraph(['--repo', repo, '--out', out]);
    assertEq(res.status, 0, `graph build failed:\nSTDOUT:\n${res.stdout}\nSTDERR:\n${res.stderr}`);

    // External deps file should mention absl
    assertTrue(fs.existsSync(path.join(out, 'external-deps.jsonl')),
      'external-deps.jsonl should be emitted when angle-bracket includes are present');
    const ext = fs.readFileSync(path.join(out, 'external-deps.jsonl'), 'utf8')
      .split('\n').filter(Boolean).map(JSON.parse);
    assertContains(ext.map(e => e.bucket), 'absl');

    // Macros file should contain MAX, not the header guard
    assertTrue(fs.existsSync(path.join(out, 'macros.jsonl')));
    const macros = fs.readFileSync(path.join(out, 'macros.jsonl'), 'utf8')
      .split('\n').filter(Boolean).map(JSON.parse);
    assertContains(macros.map(m => m.name), 'MAX');

    // Manifests file should contain react
    assertTrue(fs.existsSync(path.join(out, 'manifests.jsonl')));
    const manifestRecords = fs.readFileSync(path.join(out, 'manifests.jsonl'), 'utf8')
      .split('\n').filter(Boolean).map(JSON.parse);
    assertContains(manifestRecords.filter(r => r.kind === 'external-pkg').map(r => r.name), 'react');

    // Build-hints
    assertTrue(fs.existsSync(path.join(out, 'build-hints.jsonl')));

    // Schema mentions resolution + opt_in.
    const schema = fs.readFileSync(path.join(out, 'schema.yaml'), 'utf8');
    assertContains(schema, 'resolution:');
    assertContains(schema, 'opt_in:');
    assertContains(schema, 'go_mod_module: example.com/proj');

    // Go calls were resolved cross-package via go.mod.
    const callIndex = fs.readFileSync(path.join(out, 'call-index.jsonl'), 'utf8')
      .split('\n').filter(Boolean).map(JSON.parse);
    const upperCall = callIndex.find(c => c.to === 'Upper' && c.qualifier === 'util');
    assertTrue(upperCall, 'expected a call to util.Upper to be present');
    assertEq(upperCall.confidence, 'exact');
    assertEq(upperCall.toFile, 'util/util.go');

    // Symbol records carry id, endLine, doc.
    const goIndex = fs.readFileSync(path.join(out, 'go-index.jsonl'), 'utf8')
      .split('\n').filter(Boolean).map(JSON.parse);
    const upperFn = goIndex.find(r => r.kind === 'func' && r.name === 'Upper');
    assertTrue(upperFn, 'Upper function should be in go-index');
    assertTrue(/^[0-9a-f]{12}$/.test(upperFn.id), 'stable id present');
    assertTrue(typeof upperFn.endLine === 'number', 'endLine present');
    assertContains(upperFn.doc || '', 'Upper');
  });

  it('--go-tags filters files by //go:build directive (T3.5)', () => {
    const repo = makeFixtureRepo({
      'mod/linux.go': `//go:build linux

package mod
func L() {}
`,
      'mod/windows.go': `//go:build windows

package mod
func W() {}
`,
    });
    const out = path.join(makeTempDir(), 'graph-out');
    const res = runGraph(['--repo', repo, '--out', out, '--go-tags', 'linux']);
    assertEq(res.status, 0, res.stderr);

    const goIndex = fs.readFileSync(path.join(out, 'go-index.jsonl'), 'utf8')
      .split('\n').filter(Boolean).map(JSON.parse);
    const fnNames = goIndex.filter(r => r.kind === 'func').map(r => r.name);
    assertContains(fnNames, 'L');
    assertEq(fnNames.includes('W'), false, 'windows-only file should be skipped under linux tag');
  });
});

describe('e2e — excludes honor gitignore-like semantics', () => {
  it('does not exclude a top-level test/ directory', () => {
    const repo = makeFixtureRepo({
      'test/foo.go': 'package test\n',
      'lib/foo.go': 'package lib\n',
      'lib/test/bar.go': 'package test\n', // nested should be excluded via default */test/*
    });
    const out = path.join(makeTempDir(), 'graph-out');
    assertEq(runGraph(['--repo', repo, '--out', out]).status, 0);

    const modNames = fs.readFileSync(path.join(out, 'module-graph.jsonl'), 'utf8')
      .split('\n').filter(Boolean).map(JSON.parse)
      .filter(r => r.kind === 'node').map(r => r.id);
    assertContains(modNames, 'test', 'top-level test/ should be a module');
    assertContains(modNames, 'lib');
  });
});
