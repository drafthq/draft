'use strict';

const { describe, it, assertEq, assertTrue, assertContains } = require('../lib/harness');
const { parseTsRegex, buildTsIndex } = require('../../src/extractor-ts');
const { makeFixtureRepo } = require('../lib/tempdir');

function parse(content, ext = '.ts') {
  const functions = [], classes = [], imports = [];
  parseTsRegex(content, 'test' + ext, 'mod', 0, functions, classes, imports);
  return { functions, classes, imports };
}

describe('ts regex — imports', () => {
  it('extracts various import forms', () => {
    const { imports } = parse(`
import React from 'react';
import { useState, useEffect } from 'react';
import * as fs from 'fs';
import type { Config } from './config';
import './side-effect';
`);
    const froms = imports.map(i => i.from);
    assertContains(froms, 'react');
    assertContains(froms, 'fs');
    assertContains(froms, './config');
    assertContains(froms, './side-effect');
  });
});

describe('ts regex — functions and classes', () => {
  it('extracts top-level declarations including export/async', () => {
    const { functions, classes } = parse(`
export async function handleRequest(req) {}
export function helper() {}
function privateFn() {}

export class MyClass {}
export interface MyInterface {}
export type Alias = string;
`);
    const fnNames = functions.map(f => f.name);
    const classNames = classes.map(c => c.name);
    assertContains(fnNames, 'handleRequest');
    assertContains(fnNames, 'helper');
    assertContains(fnNames, 'privateFn');
    assertContains(classNames, 'MyClass');
  });
});

describe('ts — buildTsIndex integration', () => {
  it('derives module attribution from top-level dir', async () => {
    const repo = makeFixtureRepo({
      'web/App.tsx': `
import { foo } from './lib/foo';
export function App() { return null; }
`,
      'web/lib/foo.ts': `
export const foo = 42;
`,
    });
    const idx = await buildTsIndex(repo);
    const app = idx.functions.find(f => f.name === 'App');
    assertTrue(app, 'App should be indexed');
    assertEq(app.module, 'web');
  });
});
