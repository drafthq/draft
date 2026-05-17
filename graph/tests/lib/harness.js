'use strict';

/**
 * Minimal zero-dependency test harness.
 *
 * Why roll our own: the graph tool is a small standalone CLI with only one
 * dependency (web-tree-sitter). Pulling in jest/mocha just to run ~100 unit
 * checks would quadruple the devDependency tree. The API intentionally
 * mirrors the common subset of those frameworks so tests read naturally.
 */

const tests = [];
let _desc = null;

function describe(name, fn) {
  const prev = _desc;
  _desc = prev ? `${prev} > ${name}` : name;
  try { fn(); }
  finally { _desc = prev; }
}

function it(name, fn) {
  tests.push({ name: _desc ? `${_desc} — ${name}` : name, fn });
}

// Alias for conditionally skipped tests.
function xit(name, _fn) {
  tests.push({ name: `[skipped] ${_desc ? _desc + ' — ' : ''}${name}`, fn: () => {}, skipped: true });
}

// ─────────────────────────────────────────────────────────────────────────────
// Assertions — throw with precise actual/expected so the runner can format
// errors uniformly.
// ─────────────────────────────────────────────────────────────────────────────

class AssertionError extends Error {
  constructor(msg, actual, expected) {
    super(msg);
    this.name = 'AssertionError';
    this.actual = actual;
    this.expected = expected;
  }
}

function fmt(v) {
  if (typeof v === 'string') return JSON.stringify(v);
  if (v === undefined) return 'undefined';
  try { return JSON.stringify(v); } catch (_) { return String(v); }
}

function assertEq(actual, expected, msg = '') {
  if (actual !== expected) {
    throw new AssertionError(
      `${msg || 'assertEq'}: expected ${fmt(expected)}, got ${fmt(actual)}`,
      actual, expected
    );
  }
}

function assertDeepEq(actual, expected, msg = '') {
  const a = fmt(actual);
  const e = fmt(expected);
  if (a !== e) {
    throw new AssertionError(
      `${msg || 'assertDeepEq'}:\n expected ${e}\n got ${a}`,
      actual, expected
    );
  }
}

function assertTrue(cond, msg = 'expected true') {
  if (!cond) throw new AssertionError(msg, cond, true);
}

function assertFalse(cond, msg = 'expected false') {
  if (cond) throw new AssertionError(msg, cond, false);
}

function assertContains(haystack, needle, msg = '') {
  if (typeof haystack === 'string') {
    if (!haystack.includes(needle)) {
      throw new AssertionError(`${msg || 'assertContains'}: ${fmt(haystack)} does not contain ${fmt(needle)}`, haystack, needle);
    }
    return;
  }
  if (Array.isArray(haystack)) {
    const matcher = typeof needle === 'function' ? needle : (x) => fmt(x) === fmt(needle);
    if (!haystack.some(matcher)) {
      throw new AssertionError(`${msg || 'assertContains'}: ${fmt(haystack)} does not contain a matching element`, haystack, needle);
    }
    return;
  }
  throw new AssertionError(`assertContains: unsupported haystack type ${typeof haystack}`, haystack, needle);
}

function assertNotContains(haystack, needle, msg = '') {
  if (typeof haystack === 'string') {
    if (haystack.includes(needle)) {
      throw new AssertionError(`${msg || 'assertNotContains'}: ${fmt(haystack)} unexpectedly contains ${fmt(needle)}`, haystack, needle);
    }
    return;
  }
  if (Array.isArray(haystack)) {
    const matcher = typeof needle === 'function' ? needle : (x) => fmt(x) === fmt(needle);
    if (haystack.some(matcher)) {
      throw new AssertionError(`${msg || 'assertNotContains'}: array unexpectedly contains a matching element`, haystack, needle);
    }
    return;
  }
  throw new AssertionError(`assertNotContains: unsupported haystack type ${typeof haystack}`, haystack, needle);
}

function assertThrows(fn, matcher = null, msg = '') {
  let threw = false;
  let err = null;
  try { fn(); } catch (e) { threw = true; err = e; }
  if (!threw) throw new AssertionError(`${msg || 'assertThrows'}: expected function to throw`, 'no throw', 'throw');
  if (matcher) {
    const m = typeof matcher === 'string' ? err.message.includes(matcher) : matcher(err);
    if (!m) throw new AssertionError(`${msg || 'assertThrows'}: thrown error did not match`, err && err.message, matcher);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Runner
// ─────────────────────────────────────────────────────────────────────────────

async function run() {
  const CYAN = '\x1b[36m';
  const GREEN = '\x1b[32m';
  const RED = '\x1b[31m';
  const DIM = '\x1b[2m';
  const NC = '\x1b[0m';

  const filter = process.env.TEST_FILTER || '';
  const only = tests.filter(t => !filter || t.name.includes(filter));

  let pass = 0, fail = 0, skipped = 0;
  const failures = [];
  const started = Date.now();

  for (const t of only) {
    if (t.skipped) { skipped++; console.log(`${DIM}- ${t.name}${NC}`); continue; }
    try {
      const maybePromise = t.fn();
      if (maybePromise && typeof maybePromise.then === 'function') await maybePromise;
      pass++;
      console.log(`${GREEN}✓${NC} ${t.name}`);
    } catch (e) {
      fail++;
      failures.push({ name: t.name, error: e });
      console.log(`${RED}✗${NC} ${t.name}`);
      console.log(` ${RED}${e && e.message ? e.message : e}${NC}`);
      if (e && e.stack) {
        const stackLines = e.stack.split('\n').slice(1, 4);
        for (const line of stackLines) console.log(` ${DIM}${line.trim()}${NC}`);
      }
    }
  }

  const elapsed = ((Date.now() - started) / 1000).toFixed(2);
  console.log('');
  console.log(`${CYAN}Tests:${NC} ${pass} passed, ${fail} failed, ${skipped} skipped (${only.length} total)`);
  console.log(`${CYAN}Time:${NC} ${elapsed}s`);

  if (fail > 0) {
    console.log('');
    console.log(`${RED}Failures:${NC}`);
    for (const f of failures) {
      console.log(` ${RED}✗${NC} ${f.name}`);
      console.log(` ${f.error && f.error.message ? f.error.message : f.error}`);
    }
    process.exit(1);
  }
  process.exit(0);
}

module.exports = {
  describe, it, xit,
  assertEq, assertDeepEq, assertTrue, assertFalse,
  assertContains, assertNotContains, assertThrows,
  run,
  AssertionError,
};
