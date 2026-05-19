'use strict';

const { describe, it, assertEq, assertTrue } = require('../lib/harness');
const { detectCycles } = require('../../src/query');

describe('query.detectCycles — M2 (dedup)', () => {
  it('returns empty list for a DAG', () => {
    const cycles = detectCycles(
      ['a', 'b', 'c'],
      [{ source: 'a', target: 'b' }, { source: 'b', target: 'c' }],
    );
    assertEq(cycles.length, 0);
  });

  it('detects a simple 2-node cycle once', () => {
    const cycles = detectCycles(
      ['a', 'b'],
      [{ source: 'a', target: 'b' }, { source: 'b', target: 'a' }],
    );
    assertEq(cycles.length, 1, 'a↔b should be a single cycle');
  });

  it('dedupes rotations of the same 3-node cycle', () => {
    // a → b → c → a, with multiple entry points producing rotations
    const cycles = detectCycles(
      ['a', 'b', 'c', 'x'],
      [
        { source: 'x', target: 'a' },
        { source: 'a', target: 'b' },
        { source: 'b', target: 'c' },
        { source: 'c', target: 'a' },
      ],
    );
    assertEq(cycles.length, 1, '(a,b,c) / (b,c,a) / (c,a,b) should be a single cycle');
  });

  it('distinguishes two independent cycles', () => {
    const cycles = detectCycles(
      ['a', 'b', 'c', 'd'],
      [
        { source: 'a', target: 'b' }, { source: 'b', target: 'a' },
        { source: 'c', target: 'd' }, { source: 'd', target: 'c' },
      ],
    );
    assertEq(cycles.length, 2);
  });

  it('handles self-loops (source === target) as a cycle without crash', () => {
    const cycles = detectCycles(
      ['a'],
      [{ source: 'a', target: 'a' }],
    );
    // self-loop produces cycle [a, a] — canonicalKey body is [a], key "a"
    assertEq(cycles.length, 1);
  });

  it('ignores edges to unknown nodes (not in node list)', () => {
    const cycles = detectCycles(
      ['a'],
      [{ source: 'a', target: 'ghost' }],
    );
    assertEq(cycles.length, 0);
  });

  it('tolerates larger graphs without stack-overflow (iterative DFS)', () => {
    // 5000-node linear chain + one back-edge → single cycle
    const nodes = [];
    const edges = [];
    for (let i = 0; i < 5000; i++) {
      nodes.push('n' + i);
      if (i > 0) edges.push({ source: 'n' + (i - 1), target: 'n' + i });
    }
    edges.push({ source: 'n4999', target: 'n0' }); // close the loop
    const cycles = detectCycles(nodes, edges);
    assertEq(cycles.length, 1);
  });
});
