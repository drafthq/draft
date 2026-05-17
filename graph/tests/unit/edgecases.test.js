'use strict';

// Aggressive edge-case coverage — these are tests designed to expose bugs
// that casual fixture tests wouldn't catch: file system quirks, argument
// boundary conditions, malformed input tolerance, symbol collisions, etc.

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const { describe, it, assertEq, assertTrue, assertFalse, assertContains, assertNotContains } = require('../lib/harness');
const { makeFixtureRepo, makeTempDir } = require('../lib/tempdir');

const util = require('../../src/util');
const modules = require('../../src/modules');
const { parseGoRegex } = require('../../src/extractor-go');
const { parsePythonRegex } = require('../../src/extractor-python');
const { parseTsRegex } = require('../../src/extractor-ts');
const { parseProtoFile } = require('../../src/extractor-proto');
const { looksLikeCpp } = require('../../src/extractor-c');
const { detectCycles } = require('../../src/query');
const { buildIncludeGraph } = require('../../src/extractor-includes');

const GRAPH_CLI = path.resolve(__dirname, '..', '..', 'src', 'index.js');

function runCli(args) {
  return spawnSync(process.execPath, [GRAPH_CLI, ...args], { encoding: 'utf8', timeout: 30000 });
}

// ─────────────────────────────────────────────────────────────────────────────
// Malformed / empty / giant inputs
// ─────────────────────────────────────────────────────────────────────────────

describe('edgecases — malformed proto input', () => {
  it('does not hang or throw on unclosed service braces', () => {
    const services = [], rpcs = [], messages = [], enums = [];
    parseProtoFile(`service Unclosed {\n rpc A (X) returns (Y);\n`,
                   'bad.proto', 'mod', services, rpcs, messages, enums);
    assertEq(services.length, 1);
    assertEq(rpcs.length, 1, 'partial services still contribute their rpcs');
  });

  it('does not consume a file full of block comments', () => {
    const services = [], rpcs = [], messages = [], enums = [];
    parseProtoFile(`/* service Fake { rpc A (X) returns (Y); } */\nmessage Real {}\n`,
                   'x.proto', 'mod', services, rpcs, messages, enums);
    assertEq(services.length, 0);
    assertEq(rpcs.length, 0);
    assertEq(messages.length, 1);
  });

  it('rpcBuffer safety cap — a runaway unterminated rpc does not grow unbounded', () => {
    // 600-char filler inside a service — rpcBuffer resets at 500 chars to
    // guard against memory blowup.
    const junk = 'x'.repeat(600);
    const services = [], rpcs = [], messages = [], enums = [];
    parseProtoFile(
      `service S {\n rpc Broken ${junk}\n}\n`,
      'x.proto', 'mod', services, rpcs, messages, enums
    );
    assertEq(rpcs.length, 0, 'malformed rpc drops without blowing up');
  });
});

describe('edgecases — go regex parser robustness', () => {
  it('ignores func-like strings inside regular strings', () => {
    const functions = [], types = [], imports = [];
    parseGoRegex(`package x
var s = "func Fake() { }"
func Real() {}
`, 'x.go', 'mod', 0, functions, types, imports);
    const names = functions.map(f => f.name);
    assertContains (names, 'Real');
    assertNotContains(names, 'Fake');
  });

  it('handles Windows CRLF line endings', () => {
    const functions = [], types = [], imports = [];
    parseGoRegex(`package x\r\nimport "fmt"\r\nfunc Foo() {}\r\n`,
      'x.go', 'mod', 0, functions, types, imports);
    assertEq(functions.length, 1);
    assertEq(functions[0].name, 'Foo');
  });

  it('parses a function with variadic receiver notation', () => {
    const functions = [], types = [], imports = [];
    parseGoRegex(`package x
func (s *Slice[T]) Add(xs ...T) {}
`, 'x.go', 'mod', 0, functions, types, imports);
    assertEq(functions.length, 1);
    assertEq(functions[0].receiver, 'Slice[T]');
  });
});

describe('edgecases — python indentation', () => {
  it('tab-indented methods are still attributed to class', () => {
    const functions = [], classes = [], imports = [];
    parsePythonRegex(`class T:\n\tdef m(self):\n\t\tpass\n`,
      'x.py', 'mod', 0, functions, classes, imports);
    assertEq(functions.length, 1);
    assertEq(functions[0].receiver, 'T');
  });

  it('decorated methods: the decorator lines do not confuse class detection', () => {
    const functions = [], classes = [], imports = [];
    parsePythonRegex(`class S:
    @staticmethod
    def m():
        pass
    @property
    async def p(self):
        return 1
`, 'x.py', 'mod', 0, functions, classes, imports);
    const names = functions.map(f => f.name);
    assertContains(names, 'm');
    assertContains(names, 'p');
  });
});

describe('edgecases — ts regex parser', () => {
  it('type-only imports recognized via `import type ... from`', () => {
    const functions = [], classes = [], imports = [];
    parseTsRegex(`import type { Foo } from './foo';
import { Bar } from './bar';
`, 'x.ts', 'mod', 0, functions, classes, imports);
    const froms = imports.map(i => i.from);
    assertContains(froms, './foo');
    assertContains(froms, './bar');
  });

  it('arrow-function exports do not crash regex parser', () => {
    const functions = [], classes = [], imports = [];
    parseTsRegex(`export const helper = (x) => x + 1;
export const fn = async (y) => y * 2;
`, 'x.ts', 'mod', 0, functions, classes, imports);
    // regex fallback doesn't necessarily capture arrow fns — just verify no throw
    assertTrue(true);
  });
});

describe('edgecases — looksLikeCpp does not hang on giant strings', () => {
  it('handles 100KB input quickly', () => {
    // Giant /* comment */ that would be catastrophic for a naive regex.
    const huge = '/*' + 'x'.repeat(100_000) + '*/' + '\nstruct c_only { int x; };\n';
    const t0 = Date.now();
    const result = looksLikeCpp(huge);
    const elapsed = Date.now() - t0;
    assertFalse(result, 'only a struct — not C++');
    assertTrue(elapsed < 2000, `looksLikeCpp took ${elapsed}ms, expected <2s`);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// CLI contract / error handling
// ─────────────────────────────────────────────────────────────────────────────

describe('edgecases — CLI behavior', () => {
  it('--help prints usage, exits 0', () => {
    const r = runCli(['--help']);
    assertEq(r.status, 0);
    assertContains(r.stdout, 'graph — knowledge graph builder');
    assertContains(r.stdout, '--repo');
  });

  it('no args → print usage, exit 0', () => {
    const r = runCli([]);
    assertEq(r.status, 0, `expected 0 for usage print; got ${r.status}: ${r.stderr}`);
  });

  it('non-existent --repo → die with useful error', () => {
    const r = runCli(['--repo', '/tmp/does-not-exist-' + Date.now()]);
    assertEq(r.status, 1);
    assertContains(r.stderr, 'Repo path does not exist');
  });

  it('--query without --mode → die', () => {
    const repo = makeFixtureRepo({ 'a/x.go': 'package a\n' });
    const out = path.join(makeTempDir(), 'out');
    runCli(['--repo', repo, '--out', out]); // build first
    const r = runCli(['--repo', repo, '--out', out, '--query']);
    assertEq(r.status, 1);
    assertContains(r.stderr, '--mode required');
  });

  it('--query before build → die with helpful error', () => {
    const out = path.join(makeTempDir(), 'never-built');
    const r = runCli(['--repo', '/tmp', '--out', out, '--query', '--mode', 'modules']);
    assertEq(r.status, 1);
    assertContains(r.stderr, 'Graph not found');
  });

  it('repeated --exclude flags are all honored', () => {
    const repo = makeFixtureRepo({
      'a/keep.go': 'package a\nfunc Keep() {}\n',
      'a/skip1.go': 'package a\nfunc Skip1() {}\n',
      'a/skip2.go': 'package a\nfunc Skip2() {}\n',
    });
    const out = path.join(makeTempDir(), 'out');
    const r = runCli([
      '--repo', repo,
      '--out', out,
      '--exclude', '*skip1*',
      '--exclude', '*skip2*',
    ]);
    assertEq(r.status, 0, `build failed: ${r.stderr}`);
    const modRecords = fs.readFileSync(path.join(out, 'modules', 'a.jsonl'), 'utf8')
      .split('\n').filter(Boolean).map(JSON.parse);
    const goFuncNames = new Set(modRecords.filter(r => r.kind === 'go-func').map(r => r.name));
    assertTrue (goFuncNames.has('Keep'), 'Keep should be indexed');
    assertFalse(goFuncNames.has('Skip1'), '*skip1* exclude should drop skip1.go');
    assertFalse(goFuncNames.has('Skip2'), '*skip2* exclude should drop skip2.go');
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// Filesystem & race edge cases
// ─────────────────────────────────────────────────────────────────────────────

describe('edgecases — filesystem oddities', () => {
  it('handles repo path containing spaces and unicode', () => {
    const repo = makeFixtureRepo(
      { 'a/x.go': 'package a\n' },
      'graph-test with spaces-émoji🚀-'
    );
    const r = runCli(['--repo', repo]);
    assertEq(r.status, 0, `failed: ${r.stderr}`);
  });

  it('tolerates a file that looks like an extension-only name', () => {
    const repo = makeFixtureRepo({
      '.hidden.go': 'package hidden\n', // hidden: skipped (dot prefix)
      'a/.config': 'x', // hidden: skipped inside module
      'a/real.go': 'package a\n',
    });
    const mods = modules.detectModules(repo);
    assertTrue(mods.length >= 1);
    assertEq(mods.find(m => m.name === 'a') != null, true);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// Graph algorithms
// ─────────────────────────────────────────────────────────────────────────────

describe('edgecases — cycle detection on weird graphs', () => {
  it('multiple back-edges hitting same cycle body still dedupes', () => {
    // Build a 3-cycle a→b→c→a, and additional back-edges from c→a and b→a,
    // which would all trigger cycle-detection separately.
    const cycles = detectCycles(
      ['a', 'b', 'c'],
      [
        { source: 'a', target: 'b' },
        { source: 'b', target: 'c' },
        { source: 'c', target: 'a' },
        { source: 'c', target: 'b' }, // duplicate inner cycle
        { source: 'b', target: 'a' }, // another
      ],
    );
    // 3-cycle {a,b,c} + 2-cycle {b,c} + 2-cycle {a,b} = 3 distinct cycles
    assertEq(cycles.length, 3);
  });

  it('sparse DAG with 100k nodes + no back-edges', () => {
    const nodes = [], edges = [];
    for (let i = 0; i < 100_000; i++) {
      nodes.push('n' + i);
      if (i > 0 && i % 10 === 0) edges.push({ source: 'n' + (i - 1), target: 'n' + i });
    }
    const t0 = Date.now();
    const out = detectCycles(nodes, edges);
    const elapsed = Date.now() - t0;
    assertEq(out.length, 0);
    assertTrue(elapsed < 5000, `detectCycles took ${elapsed}ms on 100k-node DAG`);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// Include graph — various quirks
// ─────────────────────────────────────────────────────────────────────────────

describe('edgecases — include graph', () => {
  it('prefers the path-similarity candidate when multiple same-basename files exist', () => {
    const repo = makeFixtureRepo({
      'libA/util.h': '#pragma once\n',
      'libB/util.h': '#pragma once\n',
      'app/main.cc': '#include "libB/util.h"\n', // specific prefix wins
    });
    const mods = modules.detectModules(repo);
    const g = buildIncludeGraph(repo, mods, []);
    const hit = g.edges.find(e => e.source === 'app/main.cc');
    assertEq(hit.target, 'libB/util.h', 'must resolve to libB/util.h (higher similarity)');
  });

  it('treats #include with trailing whitespace / tabs correctly', () => {
    const repo = makeFixtureRepo({
      'mod/a.h': '#pragma once\n',
      'mod/b.cc': '#include\t"mod/a.h" \n',
    });
    const mods = modules.detectModules(repo);
    const g = buildIncludeGraph(repo, mods, []);
    const hit = g.edges.find(e => e.source === 'mod/b.cc');
    assertTrue(hit, 'tab-separated include should still be parsed');
    assertEq(hit.target, 'mod/a.h');
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// Writer — skipModules
// ─────────────────────────────────────────────────────────────────────────────

describe('edgecases — incremental build skipModules', () => {
  it('preserves stale per-module jsonl from existing output for skipped modules', () => {
    const repo = makeFixtureRepo({
      'keep/a.go': 'package keep\nfunc A() {}\n',
      'change/b.go': 'package change\nfunc B() {}\n',
    });
    const out = path.join(makeTempDir(), 'out');

    const r1 = runCli(['--repo', repo, '--out', out, '--incremental']);
    assertEq(r1.status, 0);
    const firstKeep = fs.readFileSync(path.join(out, 'modules', 'keep.jsonl'), 'utf8');

    // Modify only the changed module
    fs.writeFileSync(path.join(repo, 'change', 'b.go'), 'package change\nfunc B() {}\nfunc C() {}\n');

    const r2 = runCli(['--repo', repo, '--out', out, '--incremental']);
    assertEq(r2.status, 0);
    const secondKeep = fs.readFileSync(path.join(out, 'modules', 'keep.jsonl'), 'utf8');
    assertEq(firstKeep, secondKeep, 'keep/ is unchanged → its per-module file must be byte-identical');
  });
});
