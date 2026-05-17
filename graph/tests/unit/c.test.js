'use strict';

const { describe, it, assertTrue, assertFalse } = require('../lib/harness');
const { looksLikeCpp } = require('../../src/extractor-c');

describe('extractor-c.looksLikeCpp (L3)', () => {
  it('detects class-based C++ headers', () => {
    assertTrue(looksLikeCpp('class Foo { public: void bar(); };'));
  });

  it('detects namespace blocks', () => {
    assertTrue(looksLikeCpp('namespace foo { int x; }'));
    assertTrue(looksLikeCpp('namespace {\n int anon;\n}'));
  });

  it('detects template declarations', () => {
    assertTrue(looksLikeCpp('template<typename T> T add(T a, T b);'));
  });

  it('detects :: scope resolution', () => {
    assertTrue(looksLikeCpp('void Foo::bar() {}'));
  });

  it('detects extern "C" blocks', () => {
    assertTrue(looksLikeCpp('extern "C" { void c_func(); }'));
  });

  it('does NOT trigger on comments or strings mentioning "class"', () => {
    assertFalse(looksLikeCpp('// a comment about class Foo\nint x;\n'));
    assertFalse(looksLikeCpp('/* class Bar appears only in a block comment */\nvoid c_fn();\n'));
    assertFalse(looksLikeCpp('const char *s = "class Baz";\nvoid c_fn();\n'));
  });

  it('returns false for plain C headers', () => {
    assertFalse(looksLikeCpp(`
#ifndef FOO_H
#define FOO_H
struct foo { int x; };
int foo_init(struct foo *f);
#endif
`));
  });
});
