'use strict';

const { describe, it, assertEq, assertTrue, assertContains } = require('../lib/harness');
const { readGoMod, parseGoMod } = require('../../src/extractor-gomod');
const { makeFixtureRepo } = require('../lib/tempdir');

describe('extractor-gomod (T1.4)', () => {
  it('returns null when no go.mod exists', () => {
    const repo = makeFixtureRepo({ 'README.md': '# nothing' });
    assertEq(readGoMod(repo), null);
  });

  it('parses module + go directive + require block', () => {
    const repo = makeFixtureRepo({
      'go.mod': `module example.com/example/proj

go 1.21

require (
    example.com/stretchr/testify v1.8.4
    example.org/x/sync v0.5.0 // indirect
)
`,
    });
    const result = readGoMod(repo);
    assertTrue(result !== null, 'go.mod should be detected');
    assertEq(result.module, 'example.com/example/proj');
    assertEq(result.goVersion, '1.21');
    assertEq(result.requires.length, 2);
    assertContains(result.requires.map(r => r.path), 'example.com/stretchr/testify');
    assertContains(result.requires.map(r => r.path), 'golang.org/x/sync');
  });

  it('parses replace directives in both block and single-line forms', () => {
    const repo = makeFixtureRepo({
      'go.mod': `module example.com/m

replace example.com/old => ./local

replace (
    example.com/x => example.com/y v1.2.3
)
`,
    });
    const r = readGoMod(repo);
    assertEq(r.replaces.length, 2);
    assertContains(r.replaces.map(x => x.from), 'example.com/old');
    assertContains(r.replaces.map(x => x.from), 'example.com/x');
  });
});
