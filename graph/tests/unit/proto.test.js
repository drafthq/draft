'use strict';

const { describe, it, assertEq, assertTrue, assertContains } = require('../lib/harness');
const { parseProtoFile, buildProtoIndex } = require('../../src/extractor-proto');
const { makeFixtureRepo } = require('../lib/tempdir');

function parse(content) {
  const services = [], rpcs = [], messages = [], enums = [];
  parseProtoFile(content, 'test.proto', 'mod', services, rpcs, messages, enums);
  return { services, rpcs, messages, enums };
}

describe('proto parser — C1 (brace depth)', () => {
  it('closes service block correctly so messages after it are NOT attributed to it', () => {
    const out = parse(`
syntax = "proto3";

service Foo {
  rpc Bar (Req) returns (Resp);
}

message ShouldNotLeakIntoFoo {
  int32 x = 1;
}

service Baz {
  rpc Qux (A) returns (B);
}
`);
    // The bug: blockDepth=1 at service line + opens=1 on same line → 2; closing '}' drops to 1,
    // so inService never resets, and Baz's RPC would be attributed to Foo.
    const fooRpcs = out.rpcs.filter(r => r.service === 'Foo');
    const bazRpcs = out.rpcs.filter(r => r.service === 'Baz');
    assertEq(fooRpcs.length, 1, 'Foo should own exactly 1 RPC (Bar)');
    assertEq(bazRpcs.length, 1, 'Baz should own exactly 1 RPC (Qux)');
    assertContains(out.messages.map(m => m.name), 'ShouldNotLeakIntoFoo');
  });

  it('handles services with separate-line RPCs after inline empty services', () => {
    // Parser is line-oriented: an RPC on the same line as `service X {` is a
    // known limitation (rare in real .proto files). Use idiomatic one-rpc-per-line.
    const out = parse(`service Empty {}
service Real {
  rpc M (X) returns (Y);
}
`);
    const real = out.rpcs.find(r => r.service === 'Real');
    assertTrue(real != null, 'Real.M should be extracted');
    assertEq(real.name, 'M');
  });

  it('extracts streaming flags', () => {
    const out = parse(`
service S {
  rpc UploadAndStream (stream Req) returns (stream Resp);
  rpc OneShot (Req) returns (Resp);
}
`);
    const up = out.rpcs.find(r => r.name === 'UploadAndStream');
    const os = out.rpcs.find(r => r.name === 'OneShot');
    assertEq(up.streaming_request, true);
    assertEq(up.streaming_response, true);
    assertEq(os.streaming_request, false);
    assertEq(os.streaming_response, false);
  });

  it('handles multi-line RPC declarations', () => {
    const out = parse(`
service S {
  rpc DoIt (
    VeryLongRequestType
  ) returns (
    VeryLongResponseType
  );
}
`);
    assertEq(out.rpcs.length, 1);
    assertEq(out.rpcs[0].name, 'DoIt');
    assertEq(out.rpcs[0].request, 'VeryLongRequestType');
    assertEq(out.rpcs[0].response, 'VeryLongResponseType');
  });

  it('L4: strips /* ... */ block comments before brace counting', () => {
    const out = parse(`
service S {
  /* This comment contains { and } and rpc Fake (A) returns (B); */
  rpc Real (Req) returns (Resp);
}
`);
    assertEq(out.rpcs.length, 1, 'Only Real RPC should be extracted; fake one in comment must be ignored');
    assertEq(out.rpcs[0].name, 'Real');
  });

  it('does not confuse string literals containing braces', () => {
    const out = parse(`
service S {
  option (custom) = "not a {brace} but a string";
  rpc Ping (P) returns (P);
}
`);
    assertEq(out.rpcs.length, 1);
  });

  it('parses nested messages and enums', () => {
    const out = parse(`
message Outer {
  enum Status { ACTIVE = 0; INACTIVE = 1; }
  message Inner { int32 x = 1; }
}
`);
    assertContains(out.messages.map(m => m.name), 'Outer');
    assertContains(out.messages.map(m => m.name), 'Inner');
    assertContains(out.enums.map(e => e.name), 'Status');
  });

  it('buildProtoIndex integrates filesystem walk', () => {
    const repo = makeFixtureRepo({
      'api/v1/svc.proto': `
syntax = "proto3";
service A {
  rpc X (R) returns (S);
}
`,
      'api/v1/types.proto': `
syntax = "proto3";
message M {}
enum E { ZERO = 0; }
`,
    });
    const idx = buildProtoIndex(repo, []);
    assertEq(idx.services.length, 1);
    assertEq(idx.rpcs.length, 1);
    assertEq(idx.messages.length, 1);
    assertEq(idx.enums.length, 1);
    assertEq(idx.services[0].module, 'api', 'top-level dir determines module name');
  });
});
