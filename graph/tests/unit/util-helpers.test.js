'use strict';

const { describe, it, assertEq, assertTrue } = require('../lib/harness');
const { stableSymbolId, formatDocText } = require('../../src/util');

describe('util.stableSymbolId (T1.5)', () => {
  it('produces a 12-char hex digest', () => {
    const id = stableSymbolId({ kind: 'go-func', file: 'foo.go', name: 'Bar' });
    assertEq(id.length, 12);
    assertTrue(/^[0-9a-f]{12}$/.test(id), 'id is hex');
  });

  it('changes when kind/file/name/namespace/class/receiver differ', () => {
    const a = stableSymbolId({ kind: 'go-func', file: 'a.go', name: 'X' });
    const b = stableSymbolId({ kind: 'go-func', file: 'b.go', name: 'X' });
    const c = stableSymbolId({ kind: 'go-type', file: 'a.go', name: 'X' });
    const d = stableSymbolId({ kind: 'go-func', file: 'a.go', name: 'X', receiver: 'T' });
    assertTrue(a !== b, 'file changes id');
    assertTrue(a !== c, 'kind changes id');
    assertTrue(a !== d, 'receiver changes id');
  });

  it('is deterministic for the same input', () => {
    const a = stableSymbolId({ kind: 'c-func', file: 'x.cc', name: 'foo', namespace: 'ns', class_: 'C' });
    const b = stableSymbolId({ kind: 'c-func', file: 'x.cc', name: 'foo', namespace: 'ns', class_: 'C' });
    assertEq(a, b);
  });
});

describe('util.formatDocText (T2.9)', () => {
  it('strips C/C++ block comment markers', () => {
    assertEq(formatDocText('/** First line */'), 'First line');
  });

  it('strips Javadoc-style leading * with the joined block', () => {
    const raw = '/**\n * Marshal returns the JSON encoding of v.\n * Trailing.\n */';
    assertEq(formatDocText(raw), 'Marshal returns the JSON encoding of v.');
  });

  it('strips // line comments', () => {
    assertEq(formatDocText('// hello world'), 'hello world');
  });

  it('skips ASCII-art separator banners', () => {
    const raw = '// ============================================\n// Real description here\n// More';
    assertEq(formatDocText(raw), 'Real description here');
  });

  it('caps long output at 200 chars', () => {
    const long = '// ' + 'a'.repeat(300);
    const out = formatDocText(long);
    assertEq(out.length, 200);
  });

  it('returns null on empty / whitespace-only input', () => {
    assertEq(formatDocText(''), null);
    assertEq(formatDocText('//\n//\n'), null);
  });
});
