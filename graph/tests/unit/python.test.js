'use strict';

const { describe, it, assertEq, assertTrue, assertContains } = require('../lib/harness');
const { parsePythonRegex, buildPythonIndex } = require('../../src/extractor-python');
const { makeFixtureRepo } = require('../lib/tempdir');

function parse(content) {
  const functions = [], classes = [], imports = [];
  parsePythonRegex(content, 'test.py', 'mod', 0, functions, classes, imports);
  return { functions, classes, imports };
}

describe('python regex — H2 (async def)', () => {
  it('extracts both sync and async function declarations', () => {
    const { functions } = parse(`
def plain():
    pass

async def async_fn():
    await something()

class Svc:
    def method(self):
        pass
    async def async_method(self):
        await x()
`);
    const names = functions.map(f => f.name);
    assertContains(names, 'plain', 'sync def still works');
    assertContains(names, 'async_fn', 'top-level async def extracted');
    assertContains(names, 'method', 'sync method extracted');
    assertContains(names, 'async_method', 'async method extracted (H2 fix)');
    const asyncM = functions.find(f => f.name === 'async_method');
    assertEq(asyncM.receiver, 'Svc', 'async method should be attributed to its class');
  });
});

describe('python regex — classes and inheritance', () => {
  it('captures base classes', () => {
    const { classes } = parse(`
class Base:
    pass

class Mid(Base):
    pass

class Combined(Base, Mixin):
    pass
`);
    const byName = Object.fromEntries(classes.map(c => [c.name, c.bases]));
    assertEq(byName.Base.length, 0);
    assertEq(byName.Mid.length, 1);
    assertEq(byName.Mid[0], 'Base');
    assertEq(byName.Combined.length, 2);
    assertContains(byName.Combined, 'Base');
    assertContains(byName.Combined, 'Mixin');
  });

  it('distinguishes nested vs top-level methods via indent', () => {
    const { functions } = parse(`
def top_level():
    def nested():
        pass

class A:
    def m(self):
        def inner():
            pass
`);
    const top = functions.find(f => f.name === 'top_level');
    const m = functions.find(f => f.name === 'm');
    assertEq(top.receiver, null);
    assertEq(m.receiver, 'A');
  });
});

describe('python regex — imports', () => {
  it('captures both import X and from Y import ... forms', () => {
    const { imports } = parse(`
import os
import os.path as op
from typing import Any, List
from . import sibling
from ..parent import thing
`);
    const paths = imports.map(i => i.path);
    assertContains(paths, 'os');
    assertContains(paths, 'os.path');
    assertContains(paths, 'typing');
  });
});

describe('python — buildPythonIndex integration', () => {
  it('indexes fixture repo', async () => {
    const repo = makeFixtureRepo({
      'svc/app.py': `
import json

class Server:
    async def handle(self, req):
        return json.dumps({"ok": True})
`,
      'util/helpers.py': `
def max2(a, b):
    return a if a > b else b
`,
    });
    const idx = await buildPythonIndex(repo);
    const handle = idx.functions.find(f => f.name === 'handle');
    assertTrue(handle, 'async method handle must be indexed');
    assertEq(handle.receiver, 'Server');
    assertEq(handle.module, 'svc');
  });
});
