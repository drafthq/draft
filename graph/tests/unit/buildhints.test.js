'use strict';

const { describe, it, assertEq, assertTrue, assertContains } = require('../lib/harness');
const { readBuildHints, parseBazel, parseCMake } = require('../../src/extractor-buildhints');
const { makeFixtureRepo } = require('../lib/tempdir');

describe('extractor-buildhints.parseBazel (T3.2)', () => {
  it('extracts cc_library + go_library + their deps', () => {
    const libs = []; const edges = [];
    parseBazel(`
cc_library(
    name = "foo",
    srcs = ["foo.cc", "bar.cc"],
    deps = ["//other:baz", "@absl//strings"],
    visibility = ["//visibility:public"],
)

go_library(
    name = "svc",
    srcs = ["server.go"],
    deps = [":models"],
)
`, 'sub/BUILD', libs, edges);
    assertEq(libs.length, 2);
    const foo = libs.find(l => l.name === 'foo');
    assertTrue(foo, 'foo library captured');
    assertEq(foo.kind, 'cc_library');
    assertContains(foo.srcs, 'foo.cc');
    assertContains(foo.deps, '//other:baz');
    assertContains(foo.visibility, '//visibility:public');

    const edgeKeys = edges.map(e => `${e.from}->${e.to}`);
    assertContains(edgeKeys, 'foo->//other:baz');
    assertContains(edgeKeys, 'svc->:models');
  });

  it('skips unknown rule kinds (e.g. macros, custom rules)', () => {
    const libs = []; const edges = [];
    parseBazel(`
my_custom_macro(name = "x", srcs = ["a.cc"])
`, 'BUILD', libs, edges);
    assertEq(libs.length, 0);
  });
});

describe('extractor-buildhints.parseCMake (T3.2)', () => {
  it('extracts add_library + target_link_libraries deps', () => {
    const libs = []; const edges = [];
    parseCMake(`
add_library(foo STATIC src1.cc src2.cc)
target_link_libraries(foo PUBLIC absl::strings PRIVATE bar)
add_executable(app main.cc)
target_link_libraries(app foo)
`, 'CMakeLists.txt', libs, edges);

    const foo = libs.find(l => l.name === 'foo');
    assertTrue(foo, 'foo library captured');
    assertEq(foo.kind, 'add_library');
    assertContains(foo.srcs, 'src1.cc');
    assertContains(foo.deps, 'absl::strings');
    assertContains(foo.deps, 'bar');

    const edgeKeys = edges.map(e => `${e.from}->${e.to}`);
    assertContains(edgeKeys, 'app->foo');
  });
});

describe('extractor-buildhints.readBuildHints integration', () => {
  it('finds BUILD and CMakeLists files in nested dirs', () => {
    const repo = makeFixtureRepo({
      'svc/BUILD': 'cc_library(name = "svc", srcs = ["svc.cc"])',
      'CMakeLists.txt': 'add_library(top STATIC top.cc)',
    });
    const r = readBuildHints(repo);
    const names = r.libraries.map(l => l.name);
    assertContains(names, 'svc');
    assertContains(names, 'top');
  });
});
