'use strict';

const path = require('path');

/**
 * T1.3: cross-file symbol resolution pass.
 *
 * Builds a global symbol table from per-language indexes, then walks every
 * call edge and tries to resolve `to` (and optionally `qualifier`/`toQualified`)
 * to a concrete symbol. Mutates each call record in place by setting:
 * resolved : true | false
 * confidence : 'exact' | 'ambiguous' | 'unresolved'
 * toFile : <repo-relative path> (when resolved exactly)
 * toLine : <number> (when resolved exactly)
 * toId : <stable hash> (when resolved exactly)
 * candidates : [{file,line,id}, ...] (when ambiguous; capped to 5)
 *
 * Resolution policy (deliberately conservative — false matches are worse
 * than missed matches for downstream LLM consumers):
 *
 * GO:
 * - If qualifier matches an aliased import → look up symbol in the
 * imported package's directory.
 * - If qualifier matches a known package name in the repo → same.
 * - Else: same-package lookup (callers and callee in same package).
 * - Receiver methods: if `to` matches a method name and there's exactly
 * one method of that name in scope → resolve.
 *
 * C/C++:
 * - If `toQualified` is fully qualified (`Foo::Bar::baz`) → look up the
 * member by namespace+class chain.
 * - Else: same-namespace lookup; ambiguous if multiple matches.
 *
 * Python / TS:
 * - Same-file first; then same-module; then global by name.
 *
 * @param {{
 * goIndex, cIndex, pythonIndex, tsIndex,
 * goMod, // optional T1.4 result
 * }} indexes
 */
function resolveAllCalls(indexes) {
  const { goIndex, cIndex, pythonIndex, tsIndex, goMod } = indexes;
  const stats = {
    go: { total: 0, exact: 0, ambiguous: 0, unresolved: 0 },
    cpp: { total: 0, exact: 0, ambiguous: 0, unresolved: 0 },
    python: { total: 0, exact: 0, ambiguous: 0, unresolved: 0 },
    ts: { total: 0, exact: 0, ambiguous: 0, unresolved: 0 },
  };

  if (goIndex) {
    resolveGoCalls(goIndex, goMod, stats.go);
  }
  if (cIndex) {
    resolveCppCalls(cIndex, stats.cpp);
  }
  if (pythonIndex) {
    resolveByName(pythonIndex.calls, pythonIndex.functions, stats.python);
  }
  if (tsIndex) {
    resolveByName(tsIndex.calls, tsIndex.functions, stats.ts);
  }

  return { stats };
}

// =============================================================================
// GO RESOLVER
// =============================================================================

function resolveGoCalls(goIndex, goMod, stats) {
  // Build indexes:
  // byPackageName: pkgName → { fns: Map<name,[fn]>, types: Map<name,type>, dir: string|null }
  // byDir: dir → pkgName (deepest match)
  // byFile: file → { pkg, imports: [{path, alias, name}] }
  const byPackageName = new Map();
  const byDir = new Map();
  const byFile = new Map();

  const ensurePkg = (pkg) => {
    if (!byPackageName.has(pkg)) {
      byPackageName.set(pkg, { fns: new Map(), types: new Map(), dirs: new Set() });
    }
    return byPackageName.get(pkg);
  };

  for (const fn of goIndex.functions) {
    const entry = ensurePkg(fn.package);
    if (!entry.fns.has(fn.name)) entry.fns.set(fn.name, []);
    entry.fns.get(fn.name).push(fn);
    const dir = posixDir(fn.file);
    entry.dirs.add(dir);
    byDir.set(dir, fn.package);
    // Make sure every file with at least one function gets a byFile entry,
    // even if it has no imports — the resolver consults `fileInfo` for the
    // same-package fast path on unqualified calls.
    if (!byFile.has(fn.file)) {
      byFile.set(fn.file, { pkg: fn.package, imports: [] });
    }
  }
  for (const t of goIndex.types) {
    const entry = ensurePkg(t.package);
    entry.types.set(t.name, t);
  }
  for (const imp of (goIndex.imports || [])) {
    let info = byFile.get(imp.file);
    if (!info) {
      const fn0 = goIndex.functions.find(f => f.file === imp.file);
      info = { pkg: fn0 ? fn0.package : '__unknown__', imports: [] };
      byFile.set(imp.file, info);
    }
    info.imports.push(imp);
  }

  // Helper: given an import path, return the in-repo package name (if any).
  const moduleRoot = goMod && goMod.module ? goMod.module : null;
  function packageForImport(impPath) {
    // Direct match: import path equals a known dir under module root.
    if (moduleRoot && impPath.startsWith(moduleRoot + '/')) {
      const sub = impPath.slice(moduleRoot.length + 1);
      const pkg = byDir.get(sub);
      if (pkg) return pkg;
    }
    // Suffix match: handles non-modules and vendored layouts.
    const last = impPath.split('/').filter(Boolean).pop();
    if (last && byPackageName.has(last)) return last;
    return null;
  }

  for (const call of (goIndex.calls || [])) {
    stats.total++;
    const fileInfo = byFile.get(call.fromFile);

    // Prefer qualified resolution (pkg.Func or recv.Method).
    if (call.qualifier && fileInfo) {
      // 1) Imported package qualifier
      const imp = fileInfo.imports.find(i => {
        const aliasName = i.alias || lastSegment(i.path);
        return aliasName === call.qualifier;
      });
      if (imp) {
        const targetPkg = packageForImport(imp.path);
        if (targetPkg) {
          const entry = byPackageName.get(targetPkg);
          const cands = entry && entry.fns.get(call.to);
          if (cands && cands.length > 0) {
            applyResolution(call, cands, stats);
            continue;
          }
        }
        // Imported but not in our index (external dep) — leave unresolved
        markUnresolved(call, stats);
        continue;
      }

      // 2) Receiver method: qualifier is a local variable / type. Look for a
      // method with this name across types in the current package.
      const samePkg = byPackageName.get(fileInfo.pkg);
      if (samePkg) {
        const cands = (samePkg.fns.get(call.to) || []).filter(f => !!f.receiver);
        if (cands.length > 0) {
          applyResolution(call, cands, stats);
          continue;
        }
      }
    }

    // Unqualified: same-package lookup
    if (fileInfo) {
      const samePkg = byPackageName.get(fileInfo.pkg);
      if (samePkg) {
        const cands = samePkg.fns.get(call.to);
        if (cands && cands.length > 0) {
          applyResolution(call, cands, stats);
          continue;
        }
      }
    }

    markUnresolved(call, stats);
  }
}

// =============================================================================
// C/C++ RESOLVER
// =============================================================================

function resolveCppCalls(cIndex, stats) {
  // Index functions by name and by namespace::name.
  const byName = new Map(); // name → [func]
  const byFullName = new Map(); // "ns::name" or "Class::name" → [func]
  for (const fn of cIndex.functions) {
    if (!byName.has(fn.name)) byName.set(fn.name, []);
    byName.get(fn.name).push(fn);
    const keys = [];
    if (fn.namespace) keys.push(`${fn.namespace}::${fn.name}`);
    if (fn.class_) keys.push(`${fn.class_}::${fn.name}`);
    if (fn.namespace && fn.class_) keys.push(`${fn.namespace}::${fn.class_}::${fn.name}`);
    for (const k of keys) {
      if (!byFullName.has(k)) byFullName.set(k, []);
      byFullName.get(k).push(fn);
    }
  }

  for (const call of (cIndex.calls || [])) {
    stats.total++;
    // Same-file caller context
    const fromFn = cIndex.functions.find(f => f.file === call.fromFile && f.name === call.from);
    const ctxNs = fromFn && fromFn.namespace;
    const ctxCls = fromFn && fromFn.class_;

    // 1) Fully qualified (Foo::Bar::baz) → exact key lookup
    if (call.toQualified && call.toQualified.includes('::')) {
      const cands = byFullName.get(call.toQualified);
      if (cands && cands.length > 0) {
        applyResolution(call, cands, stats);
        continue;
      }
    }

    // 2) Caller's namespace + name
    if (ctxNs) {
      const cands = byFullName.get(`${ctxNs}::${call.to}`);
      if (cands && cands.length > 0) {
        applyResolution(call, cands, stats);
        continue;
      }
    }

    // 3) Caller's class + name (member call)
    if (ctxCls) {
      const cands = byFullName.get(`${ctxCls}::${call.to}`);
      if (cands && cands.length > 0) {
        applyResolution(call, cands, stats);
        continue;
      }
    }

    // 4) Bare name lookup
    const cands = byName.get(call.to);
    if (cands && cands.length === 1) {
      applyResolution(call, cands, stats);
      continue;
    }
    if (cands && cands.length > 1) {
      // Same-file preference before declaring ambiguous
      const sameFile = cands.filter(c => c.file === call.fromFile);
      if (sameFile.length === 1) { applyResolution(call, sameFile, stats); continue; }
      applyResolution(call, cands, stats);
      continue;
    }

    markUnresolved(call, stats);
  }
}

// =============================================================================
// PYTHON / TS RESOLVER (by-name with same-file → same-module → global tiers)
// =============================================================================

function resolveByName(calls, functions, stats) {
  if (!calls || !functions) return;
  const byName = new Map();
  const byFileName = new Map();
  const byModName = new Map();
  for (const fn of functions) {
    if (!byName.has(fn.name)) byName.set(fn.name, []);
    byName.get(fn.name).push(fn);
    const fk = `${fn.file}::${fn.name}`;
    if (!byFileName.has(fk)) byFileName.set(fk, []);
    byFileName.get(fk).push(fn);
    const mk = `${fn.module}::${fn.name}`;
    if (!byModName.has(mk)) byModName.set(mk, []);
    byModName.get(mk).push(fn);
  }
  for (const call of calls) {
    stats.total++;
    let cands = byFileName.get(`${call.fromFile}::${call.to}`);
    if (!cands || cands.length === 0) cands = byModName.get(`${call.module}::${call.to}`);
    if (!cands || cands.length === 0) cands = byName.get(call.to);
    if (cands && cands.length > 0) {
      applyResolution(call, cands, stats);
    } else {
      markUnresolved(call, stats);
    }
  }
}

// =============================================================================
// HELPERS
// =============================================================================

function applyResolution(call, candidates, stats) {
  if (!candidates || candidates.length === 0) {
    markUnresolved(call, stats);
    return;
  }
  if (candidates.length === 1) {
    const c = candidates[0];
    call.resolved = true;
    call.confidence = 'exact';
    call.toFile = c.file;
    call.toLine = c.line;
    if (c.id) call.toId = c.id;
    stats.exact++;
  } else {
    call.resolved = true;
    call.confidence = 'ambiguous';
    call.candidates = candidates.slice(0, 5).map(c => ({
      file: c.file, line: c.line, id: c.id || null,
    }));
    stats.ambiguous++;
  }
}

function markUnresolved(call, stats) {
  call.resolved = false;
  call.confidence = 'unresolved';
  stats.unresolved++;
}

function posixDir(p) {
  const norm = p.replace(/\\/g, '/');
  const i = norm.lastIndexOf('/');
  return i < 0 ? '' : norm.slice(0, i);
}

function lastSegment(p) {
  const norm = p.replace(/\\/g, '/');
  const segs = norm.split('/').filter(Boolean);
  return segs[segs.length - 1] || '';
}

// =============================================================================
// T2.5: HEURISTIC GO INTERFACE SATISFACTION
// =============================================================================

/**
 * For each Go interface (with `methods` captured by the tree-sitter pass),
 * test every concrete struct in scope by comparing method sets by NAME +
 * ARITY. False positives are real (signatures matter, not just names) — we
 * mark the edge with confidence: 'heuristic' so consumers can decide.
 *
 * Returns array of edges:
 * { kind: 'satisfies', from: '*Buffer', to: 'io.Reader', confidence: 'heuristic',
 * fromFile, toFile }
 */
function inferGoSatisfies(goIndex) {
  if (!goIndex || !goIndex.types) return [];

  // Gather: struct → set of methods (name, arity)
  // arity for a method is the number of its tree-sitter parameter children.
  // We don't have that on the function record yet; approximate via method
  // count and name only — refine when arity is added in a future pass.
  const structMethods = new Map(); // structName → Set<methodName>
  for (const fn of goIndex.functions) {
    if (!fn.receiver) continue;
    let s = structMethods.get(fn.receiver);
    if (!s) { s = new Set(); structMethods.set(fn.receiver, s); }
    s.add(fn.name);
  }

  // Test: does struct method set ⊇ interface method set?
  const edges = [];
  for (const t of goIndex.types) {
    if (t.kind !== 'interface' || !t.methods || t.methods.length === 0) continue;
    const required = t.methods.map(m => m.name);
    if (required.length === 0) continue;
    for (const [structName, methods] of structMethods) {
      if (required.every(n => methods.has(n))) {
        edges.push({
          kind: 'satisfies',
          from: structName,
          to: t.name,
          fromModule: structName, // placeholder; populated below
          toFile: t.file,
          toLine: t.line,
          confidence: 'heuristic',
        });
      }
    }
  }

  // Fill in `fromFile` from any of the struct's methods (deterministic: first by file).
  const structFile = new Map();
  for (const fn of goIndex.functions) {
    if (!fn.receiver) continue;
    if (!structFile.has(fn.receiver)) structFile.set(fn.receiver, fn.file);
  }
  for (const e of edges) {
    e.fromFile = structFile.get(e.from) || null;
    delete e.fromModule;
  }
  return edges;
}

module.exports = { resolveAllCalls, inferGoSatisfies };
