'use strict';

const { describe, it, assertEq, assertTrue, assertContains } = require('../lib/harness');
const { resolveAllCalls, inferGoSatisfies } = require('../../src/resolver');

function goFn(name, file, opts = {}) {
  return { name, file, line: 10, package: opts.package || 'pkg', module: opts.module || 'pkg',
           receiver: opts.receiver || null, id: opts.id || `id_${file}_${name}`,
           qualified: opts.receiver ? `${opts.receiver}.${name}` : name };
}

describe('resolver.resolveAllCalls — Go (T1.3 / T1.4)', () => {
  it('resolves unqualified same-package call exactly', () => {
    const goIndex = {
      functions: [goFn('Foo', 'a/x.go'), goFn('Bar', 'a/y.go')],
      types: [], imports: [],
      calls: [
        { from: 'Bar', to: 'Foo', fromFile: 'a/y.go', module: 'a', resolved: false },
      ],
    };
    const r = resolveAllCalls({ goIndex });
    assertEq(r.stats.go.exact, 1);
    assertEq(goIndex.calls[0].resolved, true);
    assertEq(goIndex.calls[0].confidence, 'exact');
    assertEq(goIndex.calls[0].toFile, 'a/x.go');
  });

  it('resolves qualified pkg.Foo via go.mod module path', () => {
    const goIndex = {
      functions: [
        goFn('Println', 'logger/log.go', { package: 'logger', module: 'logger' }),
        goFn('Handle', 'svc/h.go', { package: 'svc', module: 'svc' }),
      ],
      types: [],
      imports: [
        { path: 'example.com/example/proj/logger', alias: null, file: 'svc/h.go', module: 'svc' },
      ],
      calls: [
        { from: 'Handle', to: 'Println', qualifier: 'logger', toQualified: 'logger.Println',
          fromFile: 'svc/h.go', module: 'svc', resolved: false },
      ],
    };
    const goMod = { module: 'example.com/example/proj' };
    const r = resolveAllCalls({ goIndex, goMod });
    assertEq(r.stats.go.exact, 1);
    assertEq(goIndex.calls[0].toFile, 'logger/log.go');
  });

  it('respects aliased Go imports (T2.6)', () => {
    const goIndex = {
      functions: [
        goFn('Sprintf', 'fmt/fmt.go', { package: 'fmt', module: 'fmt' }),
        goFn('Caller', 'svc/h.go', { package: 'svc', module: 'svc' }),
      ],
      types: [],
      imports: [
        // Aliased: import f "fmt"
        { path: 'fmt', alias: 'f', file: 'svc/h.go', module: 'svc' },
      ],
      calls: [
        { from: 'Caller', to: 'Sprintf', qualifier: 'f', toQualified: 'f.Sprintf',
          fromFile: 'svc/h.go', module: 'svc', resolved: false },
      ],
    };
    const r = resolveAllCalls({ goIndex });
    assertEq(r.stats.go.exact, 1);
    assertEq(goIndex.calls[0].toFile, 'fmt/fmt.go');
  });

  it('marks unresolved when target is not in the repo', () => {
    const goIndex = {
      functions: [goFn('Caller', 'svc/h.go', { package: 'svc' })],
      types: [], imports: [],
      calls: [
        { from: 'Caller', to: 'Marshal', qualifier: 'json', toQualified: 'json.Marshal',
          fromFile: 'svc/h.go', module: 'svc', resolved: false },
      ],
    };
    const r = resolveAllCalls({ goIndex });
    assertEq(r.stats.go.unresolved, 1);
    assertEq(goIndex.calls[0].confidence, 'unresolved');
  });
});

describe('resolver.resolveAllCalls — C/C++ (T1.3)', () => {
  it('resolves a fully qualified Foo::Bar::baz call', () => {
    const cIndex = {
      functions: [
        { name: 'baz', file: 'a.cc', module: 'a', line: 5, namespace: 'Foo::Bar', class_: null, id: 'idbaz' },
        { name: 'caller', file: 'a.cc', module: 'a', line: 1, namespace: null, class_: null, id: 'idcall' },
      ],
      types: [], inherits: [],
      calls: [
        { from: 'caller', to: 'baz', toQualified: 'Foo::Bar::baz', fromFile: 'a.cc', module: 'a', resolved: false },
      ],
    };
    const r = resolveAllCalls({ cIndex });
    assertEq(r.stats.cpp.exact, 1);
    assertEq(cIndex.calls[0].toLine, 5);
  });

  it('marks ambiguous when multiple bare-name candidates exist across files', () => {
    const cIndex = {
      functions: [
        { name: 'foo', file: 'a.cc', module: 'a', line: 1, namespace: null, class_: null, id: 'i1' },
        { name: 'foo', file: 'b.cc', module: 'b', line: 2, namespace: null, class_: null, id: 'i2' },
        { name: 'caller', file: 'c.cc', module: 'c', line: 1, namespace: null, class_: null, id: 'i3' },
      ],
      types: [], inherits: [],
      calls: [
        { from: 'caller', to: 'foo', fromFile: 'c.cc', module: 'c', resolved: false },
      ],
    };
    const r = resolveAllCalls({ cIndex });
    assertEq(r.stats.cpp.ambiguous, 1);
    assertEq(cIndex.calls[0].confidence, 'ambiguous');
    assertEq(cIndex.calls[0].candidates.length, 2);
  });
});

describe('resolver.inferGoSatisfies (T2.5)', () => {
  it('emits satisfies edges where struct method set covers an interface', () => {
    const goIndex = {
      functions: [
        { name: 'Read', receiver: 'Buffer', file: 'b.go', line: 1, module: 'm', package: 'm' },
        { name: 'Close', receiver: 'Buffer', file: 'b.go', line: 5, module: 'm', package: 'm' },
        // Different struct without Close — should NOT satisfy
        { name: 'Read', receiver: 'Reader', file: 'r.go', line: 1, module: 'm', package: 'm' },
      ],
      types: [
        { name: 'Closer', kind: 'interface', file: 'i.go', line: 1, module: 'm', package: 'm',
          methods: [{ name: 'Read', arity: 1 }, { name: 'Close', arity: 0 }] },
      ],
    };
    const edges = inferGoSatisfies(goIndex);
    const keys = edges.map(e => `${e.from}->${e.to}`);
    assertContains(keys, 'Buffer->Closer');
    assertEq(keys.includes('Reader->Closer'), false, 'Reader missing Close — should not satisfy');
    assertEq(edges.find(e => e.from === 'Buffer').confidence, 'heuristic');
  });
});
