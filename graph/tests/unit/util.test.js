'use strict';

const fs = require('fs');
const path = require('path');
const {
  describe, it, assertEq, assertDeepEq, assertTrue, assertFalse, assertContains,
  assertNotContains,
} = require('../lib/harness');
const { makeFixtureRepo, makeTempDir } = require('../lib/tempdir');

const util = require('../../src/util');

describe('util.parseArgs', () => {
  it('parses --key value pairs', () => {
    const a = util.parseArgs(['--repo', '/tmp/x', '--out', '/tmp/y']);
    assertEq(a.repo, '/tmp/x');
    assertEq(a.out, '/tmp/y');
  });

  it('treats flag without value as boolean true', () => {
    const a = util.parseArgs(['--help']);
    assertEq(a.help, true);
  });

  it('collects positional arguments under _', () => {
    const a = util.parseArgs(['positional', '--flag']);
    assertDeepEq(a._, ['positional']);
    assertEq(a.flag, true);
  });

  it('collects repeated flags into arrays', () => {
    const a = util.parseArgs(['--exclude', 'a', '--exclude', 'b']);
    assertDeepEq(a.exclude, ['a', 'b']);
  });

  it('handles --flag followed by --next as boolean', () => {
    const a = util.parseArgs(['--verbose', '--mode', 'callers']);
    assertEq(a.verbose, true);
    assertEq(a.mode, 'callers');
  });
});

describe('util.compileExcludes', () => {
  const match = (pattern, p) => util.compileExcludes([pattern])[0].test(p);

  it('matches basename globs as path segments (not substrings)', () => {
    assertTrue (match('*.pb.cc', 'foo/bar.pb.cc'), 'should match nested file with matching basename');
    assertTrue (match('*.pb.cc', 'bar.pb.cc'), 'should match top-level file');
    assertFalse(match('*.pb.cc', 'foo.pb.cc.txt'), 'should NOT match substring match');
    assertFalse(match('*.pb.cc', 'fooPBpbcc'), 'should NOT match unrelated name');
  });

  it('*.key does not match foo.keyword.go (the original M1 bug)', () => {
    assertFalse(match('*.key', 'foo.keyword.go'));
    assertTrue (match('*.key', 'secret.key'));
    assertTrue (match('*.key', 'a/b/secret.key'));
  });

  it('path pattern */vendor/* matches nested descendants', () => {
    assertTrue (match('*/vendor/*', 'foo/vendor/pkg/bar.go'));
    assertTrue (match('*/vendor/*', 'foo/vendor/bar.go'));
    assertFalse(match('*/vendor/*', 'vendor/bar.go'), 'top-level vendor without parent must not match');
  });

  it('path pattern */test/* preserves top-level test module', () => {
    assertTrue (match('*/test/*', 'api/test/foo.go'));
    assertTrue (match('*/test/*', 'api/test/sub/foo.go'));
    assertFalse(match('*/test/*', 'test/foo.go'), 'top-level test/ is not excluded');
  });

  it('supports ** globstar across path separators', () => {
    assertTrue(match('**/foo/bar.go', 'a/b/c/foo/bar.go'));
    assertTrue(match('**/foo/bar.go', 'foo/bar.go'), '**/ at start should also match zero segments (gitignore)');
    assertTrue(match('**/foo/bar.go', 'x/foo/bar.go'));
  });

  it('escapes regex metachars in literal parts of the pattern', () => {
    // A literal `.` in a glob must not also match `x` — would happen if we
    // forgot to escape.
    assertFalse(match('*.cc', 'fooxcc'));
    assertTrue (match('*.cc', 'foo.cc'));
  });
});

describe('util.shouldExclude', () => {
  it('normalizes backslashes (windows paths) to forward slashes', () => {
    const res = util.compileExcludes(['*/vendor/*']);
    assertTrue(util.shouldExclude('foo\\vendor\\bar.go', res));
  });
});

describe('util.walkFiles', () => {
  it('skips hidden directories and node_modules/dist/build/out', () => {
    const repo = makeFixtureRepo({
      'keep/a.go': 'package a\n',
      '.hidden/should-skip.go': 'package x\n',
      'node_modules/lib/index.js': 'exports.x = 1\n',
      'dist/build-artifact.js': 'console.log(1)\n',
      'build/build-artifact.cpp': 'int main(){}\n',
      'out/artifact.go': 'package a\n',
    });
    const files = util.walkFiles(repo, ['.go', '.js', '.cpp']);
    const rels = files.map(f => path.relative(repo, f));
    assertContains(rels, 'keep/a.go');
    assertNotContains(rels, '.hidden/should-skip.go');
    assertNotContains(rels, 'node_modules/lib/index.js');
    assertNotContains(rels, 'dist/build-artifact.js');
    assertNotContains(rels, 'build/build-artifact.cpp');
    assertNotContains(rels, 'out/artifact.go');
  });

  it('honors excludeRes against repo-relative path', () => {
    const repo = makeFixtureRepo({
      'api/service.go': 'package api\n',
      'api/vendor/lib/pkg.go': 'package lib\n',
      'vendor/toplevel.go': 'package tl\n',
    });
    const res = util.compileExcludes(['*/vendor/*']);
    const files = util.walkFiles(repo, ['.go'], res, repo);
    const rels = files.map(f => path.relative(repo, f));
    assertContains (rels, 'api/service.go');
    assertContains (rels, 'vendor/toplevel.go', 'top-level vendor kept');
    assertNotContains(rels, 'api/vendor/lib/pkg.go');
  });

  it('returns all files when extensions list is empty', () => {
    const repo = makeFixtureRepo({ 'a.txt': '1', 'b.md': '2', 'c.go': '3' });
    const files = util.walkFiles(repo, []);
    assertEq(files.length, 3);
  });

  it('does not follow symlinks', () => {
    const repo = makeFixtureRepo({ 'src/a.go': 'package a\n' });
    const target = path.join(repo, 'src');
    const link = path.join(repo, 'link');
    try { fs.symlinkSync(target, link, 'dir'); } catch (_) { return; /* skip if no symlink support */ }
    const files = util.walkFiles(repo, ['.go']);
    const rels = files.map(f => path.relative(repo, f));
    assertContains (rels, 'src/a.go');
    assertNotContains(rels, 'link/a.go');
  });
});

describe('util.collectAllFiles', () => {
  it('partitions files by extension', () => {
    const repo = makeFixtureRepo({
      'svc/a.go': 'package a\n',
      'svc/b.py': '\n',
      'svc/c.proto': '\n',
      'svc/unknown.x': 'x',
    });
    const map = util.collectAllFiles(repo);
    assertEq((map.get('.go') || []).length, 1);
    assertEq((map.get('.py') || []).length, 1);
    assertEq((map.get('.proto') || []).length, 1);
    assertEq(map.has('.x'), false, '.x is not a known source extension');
  });
});

describe('util.dirSizeKB', () => {
  it('sums file sizes under a directory', () => {
    const repo = makeFixtureRepo({
      'mod/a.go': Buffer.alloc(2048, 'a').toString(), // 2KB
      'mod/b.go': Buffer.alloc(1024, 'b').toString(), // 1KB
    });
    const kb = util.dirSizeKB(path.join(repo, 'mod'));
    assertTrue(kb >= 3 && kb <= 4, `expected ~3KB, got ${kb}`);
  });

  it('honors excludeRes when provided (L6 fix)', () => {
    const repo = makeFixtureRepo({
      'mod/a.go': Buffer.alloc(4096, 'a').toString(), // 4KB
      'mod/gen/big.pb.cc': Buffer.alloc(8192, 'b').toString(), // 8KB — excluded
    });
    const withExcludes = util.dirSizeKB(path.join(repo, 'mod'), util.compileExcludes(['*.pb.cc']), repo);
    const withoutExcludes = util.dirSizeKB(path.join(repo, 'mod'));
    assertTrue(withExcludes < withoutExcludes,
      `expected ${withExcludes} < ${withoutExcludes} (excluded pb.cc should trim total)`);
    assertTrue(withExcludes <= 5, `expected ~4KB with excludes, got ${withExcludes}`);
  });
});

describe('util.writeJsonl', () => {
  it('writes one JSON object per line, skips unserializable records', () => {
    const tmp = makeTempDir();
    const file = path.join(tmp, 'out.jsonl');
    const circ = {}; circ.self = circ;
    const n = util.writeJsonl(file, [
      { a: 1 },
      { b: 'hello' },
      circ, // circular — should be skipped or sanitized (both fail → skip)
      { c: [1, 2, 3] },
    ]);
    const lines = fs.readFileSync(file, 'utf8').trim().split('\n');
    // circular fails both JSON.stringify and sanitize, so should be skipped
    assertEq(lines.length, 3);
    assertEq(n, 3);
    assertDeepEq(JSON.parse(lines[0]), { a: 1 });
    assertDeepEq(JSON.parse(lines[2]), { c: [1, 2, 3] });
  });

  it('sanitizes non-UTF8 / NUL / control chars when stringify fails', () => {
    const tmp = makeTempDir();
    const file = path.join(tmp, 'out.jsonl');
    // Lone surrogate — valid JS string but produces invalid JSON. JSON.stringify
    // historically emitted literal \uD800, which later JSON.parse rejected.
    const lone = '\uD800';
    util.writeJsonl(file, [{ bad: lone, ok: 'hi' }]);
    const lines = fs.readFileSync(file, 'utf8').trim().split('\n');
    // either sanitized (no lone surrogate) or present — either way it must be valid JSON now
    for (const line of lines) {
      JSON.parse(line); // must not throw
    }
  });
});

describe('util.initTreeSitter', () => {
  it('caches the promise across concurrent callers (M4 fix)', async () => {
    // Same promise identity for concurrent calls
    const [p1, p2] = [util.initTreeSitter(), util.initTreeSitter()];
    assertEq(p1, p2, 'initTreeSitter should return the same promise for concurrent calls');
    const [r1, r2] = await Promise.all([p1, p2]);
    assertEq(r1, r2, 'resolved Parser class identity must match');
  });
});

describe('util.countLines / countLinesFromContent', () => {
  it('counts \\n in content', () => {
    assertEq(util.countLinesFromContent('a\nb\nc\n'), 3);
    assertEq(util.countLinesFromContent(''), 0);
    assertEq(util.countLinesFromContent('single'), 0, 'no trailing newline');
  });
});
