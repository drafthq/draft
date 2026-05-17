'use strict';

const { describe, it, assertEq, assertTrue, assertContains, assertNotContains } = require('../lib/harness');
const { readCompileCommands } = require('../../src/extractor-compdb');
const { makeFixtureRepo } = require('../lib/tempdir');

describe('extractor-compdb (T3.1)', () => {
  it('returns null when no compile_commands.json exists', () => {
    const repo = makeFixtureRepo({ 'README.md': 'x' });
    assertEq(readCompileCommands(repo), null);
  });

  it('extracts repo-relative -I/-iquote/-isystem search paths from arguments form', () => {
    // Empty repo first; we then write compile_commands.json with `directory`
    // pointing at the repo so include paths resolve inside it.
    const repo = makeFixtureRepo({ '.placeholder': '' });
    require('fs').writeFileSync(require('path').join(repo, 'compile_commands.json'), JSON.stringify([
      {
        directory: repo,
        file: 'src/foo.cc',
        arguments: ['clang++', '-c', '-I', 'include', '-Ithird_party/abseil', '-isystem', 'vendor', '-DFOO=1', 'src/foo.cc'],
      },
    ]));
    const r = readCompileCommands(repo);
    assertTrue(r !== null);
    assertContains(r.searchPaths, 'include');
    assertContains(r.searchPaths, 'third_party/abseil');
    assertContains(r.searchPaths, 'vendor');
    assertContains(r.defines, '-DFOO=1');
  });

  it('parses the `command` string form via shell-like tokenization', () => {
    const repo = makeFixtureRepo({ '.placeholder': '' });
    require('fs').writeFileSync(require('path').join(repo, 'compile_commands.json'), JSON.stringify([
      { directory: repo, file: 'a.c', command: 'gcc -c -I include "-Ipath/with space" -Iabsl a.c' },
    ]));
    const r = readCompileCommands(repo);
    assertContains(r.searchPaths, 'include');
    assertContains(r.searchPaths, 'absl');
    assertContains(r.searchPaths, 'path/with space');
  });

  it('drops absolute paths outside the repo (e.g. /usr/include)', () => {
    const repo = makeFixtureRepo({ '.placeholder': '' });
    require('fs').writeFileSync(require('path').join(repo, 'compile_commands.json'), JSON.stringify([
      { directory: repo, file: 'a.cc', arguments: ['c++', '-c', '-I/usr/include', '-Iinclude', 'a.cc'] },
    ]));
    const r = readCompileCommands(repo);
    assertContains(r.searchPaths, 'include');
    assertNotContains(r.searchPaths, '/usr/include');
  });
});
