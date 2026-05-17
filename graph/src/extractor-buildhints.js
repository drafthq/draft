'use strict';

const fs = require('fs');
const path = require('path');
const { walkFiles } = require('./util');

/**
 * T3.2: regex-parse Bazel BUILD files and CMakeLists.txt to harvest
 * declared library boundaries and dependency lists.
 *
 * Output:
 * {
 * libraries: [{ name, kind, srcs[], deps[], visibility, file }, ...],
 * edges: [{ from, to, file, kind: 'declared-dep' }, ...],
 * }
 *
 * Only top-level fields are extracted with regex; we don't run Starlark or
 * CMake. Silent failure on malformed files. The data is intended as a
 * supplement to include-graph derived edges, not a replacement.
 */
function readBuildHints(repo, excludeRes = []) {
  const libraries = [];
  const edges = [];

  // Bazel BUILD / BUILD.bazel
  const bazelFiles = walkFiles(repo, [], excludeRes).filter(f => {
    const b = path.basename(f);
    return b === 'BUILD' || b === 'BUILD.bazel';
  });
  for (const f of bazelFiles) {
    let content;
    try { content = fs.readFileSync(f, 'utf8'); }
    catch (_) { continue; }
    const rel = path.relative(repo, f);
    parseBazel(content, rel, libraries, edges);
  }

  // CMakeLists.txt
  const cmakeFiles = walkFiles(repo, [], excludeRes).filter(f =>
    path.basename(f) === 'CMakeLists.txt'
  );
  for (const f of cmakeFiles) {
    let content;
    try { content = fs.readFileSync(f, 'utf8'); }
    catch (_) { continue; }
    const rel = path.relative(repo, f);
    parseCMake(content, rel, libraries, edges);
  }

  return { libraries, edges };
}

// =============================================================================
// BAZEL — match common rule kinds. We don't try to be exhaustive; the goal is
// useful structural hints, not a full Starlark interpreter.
// =============================================================================
const BAZEL_RULE_KINDS = new Set([
  'cc_library', 'cc_binary', 'cc_test',
  'go_library', 'go_binary', 'go_test',
  'py_library', 'py_binary', 'py_test',
  'java_library', 'java_binary',
  'rust_library', 'rust_binary',
  'ts_library', 'ts_project',
  'proto_library',
]);

function parseBazel(content, file, libraries, edges) {
  // Match `rule_kind(\n name = "foo",\n srcs = [...],\n deps = [...] )`
  // Using a non-greedy `[\s\S]*?` between rule_kind( and the matching ) and a
  // simple paren-balance count. Greedy bracket grouping below.
  const rules = splitRuleCalls(content);
  for (const { kind, body } of rules) {
    if (!BAZEL_RULE_KINDS.has(kind)) continue;
    const name = matchString(body, /\bname\s*=\s*"([^"]+)"/);
    if (!name) continue;
    const srcs = matchList(body, /\bsrcs\s*=\s*\[([\s\S]*?)\]/);
    const deps = matchList(body, /\bdeps\s*=\s*\[([\s\S]*?)\]/);
    const visibility = matchList(body, /\bvisibility\s*=\s*\[([\s\S]*?)\]/);

    libraries.push({
      name,
      kind,
      srcs: srcs || [],
      deps: deps || [],
      visibility: visibility || [],
      file,
    });
    for (const d of (deps || [])) {
      edges.push({ from: name, to: d, file, kind: 'declared-dep' });
    }
  }
}

// Split a Bazel BUILD file by top-level rule calls.
// Returns [{ kind, body }, ...] where `body` is the content inside the (...).
function splitRuleCalls(content) {
  const out = [];
  const re = /\b(\w+)\s*\(/g;
  let m;
  while ((m = re.exec(content)) !== null) {
    const kind = m[1];
    if (!BAZEL_RULE_KINDS.has(kind)) continue;
    const start = m.index + m[0].length;
    let depth = 1;
    let i = start;
    let inString = null;
    while (i < content.length && depth > 0) {
      const c = content[i];
      if (inString) {
        if (c === '\\') { i += 2; continue; }
        if (c === inString) inString = null;
      } else {
        if (c === '"' || c === "'") inString = c;
        else if (c === '(') depth++;
        else if (c === ')') depth--;
      }
      i++;
    }
    if (depth === 0) {
      out.push({ kind, body: content.slice(start, i - 1) });
      re.lastIndex = i;
    }
  }
  return out;
}

function matchString(body, re) {
  const m = body.match(re);
  return m ? m[1] : null;
}

function matchList(body, re) {
  const m = body.match(re);
  if (!m) return null;
  const out = [];
  const inner = m[1];
  const sre = /"([^"]+)"/g;
  let sm;
  while ((sm = sre.exec(inner)) !== null) out.push(sm[1]);
  return out;
}

// =============================================================================
// CMAKE — handle add_library / add_executable / target_link_libraries.
// =============================================================================
function parseCMake(content, file, libraries, edges) {
  // add_library(<name> [STATIC|SHARED|...] src1 src2 ...)
  // add_executable(<name> src1 src2 ...)
  const declRe = /\b(add_library|add_executable)\s*\(\s*([^\s)]+)([^)]*)\)/g;
  let m;
  while ((m = declRe.exec(content)) !== null) {
    const kind = m[1];
    const name = m[2];
    const rest = m[3].trim();
    const tokens = rest.split(/\s+/).filter(Boolean);
    // Drop common type keywords that aren't sources.
    const srcs = tokens.filter(t => !/^(STATIC|SHARED|MODULE|INTERFACE|OBJECT|ALIAS|IMPORTED|EXCLUDE_FROM_ALL|WIN32|MACOSX_BUNDLE)$/i.test(t));
    libraries.push({ name, kind, srcs, deps: [], visibility: [], file });
  }
  // target_link_libraries(<name> ... deps ...)
  const linkRe = /\btarget_link_libraries\s*\(\s*([^\s)]+)([^)]*)\)/g;
  while ((m = linkRe.exec(content)) !== null) {
    const name = m[1];
    const rest = m[2].trim();
    const tokens = rest.split(/\s+/).filter(Boolean)
      .filter(t => !/^(PUBLIC|PRIVATE|INTERFACE)$/i.test(t));
    const lib = libraries.find(l => l.name === name && l.file === file);
    if (lib) lib.deps.push(...tokens);
    for (const d of tokens) edges.push({ from: name, to: d, file, kind: 'declared-dep' });
  }
}

module.exports = { readBuildHints, parseBazel, parseCMake };
