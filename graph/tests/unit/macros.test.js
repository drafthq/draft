'use strict';

const { describe, it, assertEq, assertTrue, assertContains, assertNotContains } = require('../lib/harness');
const { buildMacroIndex, looksLikeHeaderGuard } = require('../../src/extractor-macros');
const { makeFixtureRepo } = require('../lib/tempdir');

describe('extractor-macros.looksLikeHeaderGuard (T3.4)', () => {
  it('rejects header guards that match the file basename', () => {
    assertTrue(looksLikeHeaderGuard('FOO_H', 'FOO_H'));
    assertTrue(looksLikeHeaderGuard('__FOO_H__', 'FOO_H'));
    assertTrue(looksLikeHeaderGuard('FOO_HPP', 'FOO_HPP'));
  });

  it('returns false for genuine macros with no _H suffix', () => {
    assertEq(looksLikeHeaderGuard('MAX', 'FOO_H'), false);
    assertEq(looksLikeHeaderGuard('RETURN_IF', 'FOO_H'), false);
  });
});

describe('extractor-macros.buildMacroIndex (T3.4)', () => {
  it('captures function-like macros with their parameter names', () => {
    const repo = makeFixtureRepo({
      'mod/m.h': `#ifndef MOD_M_H_
#define MOD_M_H_

#define MAX(a, b) ((a) > (b) ? (a) : (b))
#define RETURN_IF_ERROR(expr) do { auto s = (expr); if (!s.ok()) return s; } while(0)
#define VERSION 42

#endif
`,
    });
    const { macros } = buildMacroIndex(repo);
    const max = macros.find(m => m.name === 'MAX');
    assertTrue(max, 'MAX should be indexed');
    assertEq(max.params.length, 2);
    assertContains(max.params, 'a');
    assertContains(max.params, 'b');
    assertContains(macros.map(m => m.name), 'RETURN_IF_ERROR');
    assertContains(macros.map(m => m.name), 'VERSION');
    assertNotContains(macros.map(m => m.name), 'MOD_M_H_'); // header guard skipped
  });

  it('attaches a stable id to each macro record', () => {
    const repo = makeFixtureRepo({ 'lib/x.h': '#define WANT 1' });
    const { macros } = buildMacroIndex(repo);
    assertEq(macros.length, 1);
    assertTrue(/^[0-9a-f]{12}$/.test(macros[0].id), 'id is 12-char hex');
  });
});
