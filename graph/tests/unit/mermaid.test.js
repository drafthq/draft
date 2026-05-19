'use strict';

const { describe, it, assertEq, assertContains, assertNotContains } = require('../lib/harness');
const { escapeMermaidLabel } = require('../../src/mermaid');

describe('mermaid.escapeMermaidLabel (L8)', () => {
  it('escapes Mermaid-breaking characters', () => {
    assertEq(escapeMermaidLabel('foo'), 'foo');
    assertEq(escapeMermaidLabel('a&b'), 'a&amp;b');
    assertEq(escapeMermaidLabel('a<b>c'), 'a&lt;b&gt;c');
    assertEq(escapeMermaidLabel('a"b'), 'a&quot;b');
    assertEq(escapeMermaidLabel('a|b'), 'a&#124;b');
    assertEq(escapeMermaidLabel('foo[bar]'), 'foo&#91;bar&#93;');
  });

  it('handles names that look like HTML / mermaid syntax', () => {
    const out = escapeMermaidLabel('<svg onerror="pwn()">|[injected]');
    assertNotContains(out, '<');
    assertNotContains(out, '>');
    assertNotContains(out, '|');
    assertNotContains(out, '[');
    assertNotContains(out, ']');
    assertNotContains(out, '"');
    assertContains (out, '&lt;');
    assertContains (out, '&quot;');
    assertContains (out, '&#124;');
  });

  it('coerces non-string inputs via String()', () => {
    assertEq(escapeMermaidLabel(42), '42');
    assertEq(escapeMermaidLabel(null), 'null');
  });
});
