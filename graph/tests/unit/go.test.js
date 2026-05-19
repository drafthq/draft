'use strict';

const { describe, it, assertEq, assertTrue, assertContains } = require('../lib/harness');
const { parseGoRegex, evalGoBuildExpr, evaluateBuildTags, buildGoIndex } = require('../../src/extractor-go');
const { makeFixtureRepo } = require('../lib/tempdir');

function parse(content) {
  const functions = [], types = [], imports = [];
  parseGoRegex(content, 'test.go', 'mod', 0, functions, types, imports);
  return { functions, types, imports };
}

describe('go regex — H1 (pointer-receiver *)', () => {
  it('strips leading * from the receiver type token', () => {
    const { functions } = parse(`
package x

func (r *MyType) Method1() {}
func (x *Other) Method2() {}
func (p Plain) Method3() {}
func (*Anon) Method4() {}
func Free() {}
`);
    const methodsByName = Object.fromEntries(functions.map(f => [f.name, f]));
    assertEq(methodsByName.Method1.receiver, 'MyType', 'pointer receiver with name must strip *');
    assertEq(methodsByName.Method2.receiver, 'Other');
    assertEq(methodsByName.Method3.receiver, 'Plain');
    assertEq(methodsByName.Method4.receiver, 'Anon', 'anonymous pointer receiver must strip *');
    assertEq(methodsByName.Free.receiver, null, 'free function has no receiver');
    assertEq(methodsByName.Method1.qualified, 'MyType.Method1', 'qualified uses stripped receiver');
  });
});

describe('go regex — L2 (generics)', () => {
  it('captures generic function declarations with type parameter list', () => {
    const { functions } = parse(`
package x

func Map[T any, R any](xs []T, fn func(T) R) []R { return nil }
func Filter[T any](xs []T, pred func(T) bool) []T { return nil }
func (s *Stack[T]) Push(v T) {}
`);
    assertContains(functions.map(f => f.name), 'Map');
    assertContains(functions.map(f => f.name), 'Filter');
    assertContains(functions.map(f => f.name), 'Push');
    const push = functions.find(f => f.name === 'Push');
    assertEq(push.receiver, 'Stack[T]', 'generic receiver type is preserved verbatim (minus *)');
  });
});

describe('go regex — L9 (import block end)', () => {
  it('handles trailing whitespace and comments on import start/end', () => {
    const { imports } = parse(`
package x

import ( // grouped
  "fmt"
  "strings"
) // end of imports

import "errors"
`);
    const paths = imports.map(i => i.path);
    assertContains(paths, 'fmt');
    assertContains(paths, 'strings');
    assertContains(paths, 'errors');
  });

  it('parses aliased imports: _ "pkg", alias "pkg"', () => {
    const { imports } = parse(`
package x

import (
  _ "net/http/pprof"
  fm "fmt"
)
`);
    const paths = imports.map(i => i.path);
    assertContains(paths, 'net/http/pprof');
    assertContains(paths, 'fmt');
  });
});

describe('go regex — types', () => {
  it('extracts struct / interface / alias kinds', () => {
    const { types } = parse(`
package x

type Foo struct { x int }
type Bar interface { M() }
type Baz = Foo
type Qux int
`);
    const byName = Object.fromEntries(types.map(t => [t.name, t.kind]));
    assertEq(byName.Foo, 'struct');
    assertEq(byName.Bar, 'interface');
    assertEq(byName.Baz, 'alias');
    assertEq(byName.Qux, 'type');
  });
});

describe('go regex — T2.6 aliased imports', () => {
  it('captures alias on imports (single + grouped forms)', () => {
    const { imports } = parse(`
package x

import f "fmt"

import (
  _ "net/http/pprof"
  . "errors"
  "strings"
)
`);
    const byPath = Object.fromEntries(imports.map(i => [i.path, i.alias]));
    assertEq(byPath['fmt'], 'f', 'single-line import alias');
    assertEq(byPath['net/http/pprof'], '_');
    assertEq(byPath['errors'], '.');
    assertEq(byPath['strings'], null, 'unaliased import has alias=null');
  });
});

describe('go — T2.4 generics: type_params', () => {
  it('regex parser extracts type-parameter names from func[T any, U comparable]', () => {
    const { functions } = parse(`
package x

func Map[T any, U comparable](xs []T, f func(T) U) []U { return nil }
func Plain() {}
`);
    const map = functions.find(f => f.name === 'Map');
    const pln = functions.find(f => f.name === 'Plain');
    assertContains(map.type_params, 'T');
    assertContains(map.type_params, 'U');
    assertEq(pln.type_params, undefined, 'non-generic functions have no type_params');
  });
});

describe('go — T1.5 stable id + T2.7 endLine', () => {
  it('attaches a 12-char hex id to each function and type record', () => {
    const { functions, types } = parse(`
package x

func Foo() {}
type Bar struct{}
`);
    const foo = functions.find(f => f.name === 'Foo');
    const bar = types.find(t => t.name === 'Bar');
    assertTrue(/^[0-9a-f]{12}$/.test(foo.id), 'func id is 12 hex chars');
    assertTrue(/^[0-9a-f]{12}$/.test(bar.id), 'type id is 12 hex chars');
    assertTrue(typeof foo.endLine === 'number', 'endLine present on function record');
  });
});

describe('go — T3.5 build tag evaluation', () => {
  it('evalGoBuildExpr: AND/OR/NOT/parens', () => {
    const tags = new Set(['linux', 'amd64']);
    assertEq(evalGoBuildExpr('linux', tags), true);
    assertEq(evalGoBuildExpr('windows', tags), false);
    assertEq(evalGoBuildExpr('linux && amd64', tags), true);
    assertEq(evalGoBuildExpr('linux && arm64', tags), false);
    assertEq(evalGoBuildExpr('linux || windows',tags), true);
    assertEq(evalGoBuildExpr('!windows', tags), true);
    assertEq(evalGoBuildExpr('(linux || windows) && amd64', tags), true);
  });

  it('evaluateBuildTags reads //go:build line in file prologue', () => {
    const src = `//go:build linux && amd64

package x
`;
    const linuxOnly = evaluateBuildTags(src, new Set(['linux', 'amd64']));
    const winOnly = evaluateBuildTags(src, new Set(['windows']));
    assertEq(linuxOnly.skip, false);
    assertEq(winOnly.skip, true);
  });

  it('files lacking //go:build are never skipped', () => {
    const src = 'package x\nfunc F() {}\n';
    const v = evaluateBuildTags(src, new Set(['windows']));
    assertEq(v.skip, false);
  });
});

describe('go — buildGoIndex integration (regex path)', () => {
  it('indexes files and reports correct module attribution', async () => {
    const repo = makeFixtureRepo({
      'svc/handler.go': `package svc

import "fmt"
func (s *Server) Handle() { fmt.Println("hi") }
`,
      'util/util.go': `package util

func Max(a, b int) int { if a > b { return a } ; return b }
`,
    });
    const idx = await buildGoIndex(repo);
    const svcHandle = idx.functions.find(f => f.name === 'Handle');
    const util = idx.functions.find(f => f.name === 'Max');
    assertTrue(svcHandle, 'Handle should be indexed');
    assertTrue(util, 'Max should be indexed');
    assertEq(svcHandle.module, 'svc');
    assertEq(svcHandle.receiver, 'Server');
    assertEq(util.module, 'util');
  });
});
