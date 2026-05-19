'use strict';

const fs = require('fs');
const path = require('path');
const { writeJsonl, dirSizeKB } = require('./util');
const { generateModuleDeps, generateProtoMap } = require('./mermaid');

/**
 * Write all graph output files.
 *
 * Output structure:
 * graph/
 * ├── schema.yaml — metadata + config
 * ├── module-graph.jsonl — inter-module dependency edges (always load)
 * ├── proto-index.jsonl — all proto services/rpcs/messages (always load)
 * ├── hotspots.jsonl — top 50 files by complexity (always load)
 * ├── go-index.jsonl — Go symbols + call edges
 * ├── python-index.jsonl — Python symbols + call edges
 * ├── ts-index.jsonl — TypeScript/JS symbols + call edges
 * ├── c-index.jsonl — C/C++ symbols + call edges
 * ├── call-index.jsonl — all intra-file call edges across all languages
 * └── modules/
 * ├── <name>.jsonl — per-module file graph (load on demand)
 * └── ...
 *
 * @param {{ out, repo, modules, includeGraph, protoIndex, goIndex, pythonIndex,
 * tsIndex, cIndex, ctagsIndex, skipModules }} opts
 * @returns {{ moduleEdges, rpcs, hotspots, moduleFiles, totalSizeKB,
 * tsFunctions, tsClasses, cFunctions, cTypes, ctagsSymbols }}
 */
function writeGraph({ out, existingOut = out, repo, modules, includeGraph, protoIndex,
                      goIndex = { functions: [], types: [], imports: [], calls: [] },
                      pythonIndex = { functions: [], classes: [], imports: [], calls: [] },
                      tsIndex = { functions: [], classes: [], imports: [], calls: [] },
                      cIndex = { functions: [], types: [], calls: [] },
                      ctagsIndex = { symbols: [] },
                      skipModules = new Set() }) {
  const modulesDir = path.join(out, 'modules');
  fs.mkdirSync(modulesDir, { recursive: true });

  // ── 1. module-graph.jsonl ─────────────────────────────────────────────────
  const moduleNodes = modules.map(m => ({
    id: m.name,
    type: 'module',
    sizeKB: m.sizeKB,
    files: m.files,
  }));

  const moduleNames = new Set(modules.map(m => m.name));
  const goModuleEdgeMap = new Map();

  for (const imp of goIndex.imports) {
    const srcModule = imp.module;
    if (!srcModule) continue;
    const segments = imp.path.split('/');
    let matched = null;
    for (let len = segments.length; len >= 1; len--) {
      const candidate = segments.slice(segments.length - len).join('/');
      if (moduleNames.has(candidate)) { matched = candidate; break; }
    }
    if (!matched || matched === srcModule) continue;
    const key = `${srcModule}->${matched}`;
    goModuleEdgeMap.set(key, (goModuleEdgeMap.get(key) || 0) + 1);
  }

  // Also derive TS module edges from imports
  const tsModuleEdgeMap = new Map();
  for (const imp of (tsIndex.imports || [])) {
    const srcModule = imp.module;
    if (!srcModule || !imp.from) continue;
    const segments = imp.from.replace(/^\.\.?\//, '').split('/');
    let matched = null;
    for (let len = segments.length; len >= 1; len--) {
      const candidate = segments.slice(0, len).join('/');
      if (moduleNames.has(candidate)) { matched = candidate; break; }
    }
    if (!matched || matched === srcModule) continue;
    const key = `${srcModule}->${matched}`;
    tsModuleEdgeMap.set(key, (tsModuleEdgeMap.get(key) || 0) + 1);
  }

  const mergedEdgeMap = new Map();
  for (const e of includeGraph.moduleEdges) {
    const key = `${e.source}->${e.target}`;
    mergedEdgeMap.set(key, { source: e.source, target: e.target, weight: (mergedEdgeMap.get(key)?.weight || 0) + e.weight });
  }
  for (const [key, weight] of goModuleEdgeMap) {
    const [source, target] = key.split('->');
    if (mergedEdgeMap.has(key)) {
      mergedEdgeMap.get(key).weight += weight;
    } else {
      mergedEdgeMap.set(key, { source, target, weight });
    }
  }
  for (const [key, weight] of tsModuleEdgeMap) {
    const [source, target] = key.split('->');
    if (mergedEdgeMap.has(key)) {
      mergedEdgeMap.get(key).weight += weight;
    } else {
      mergedEdgeMap.set(key, { source, target, weight });
    }
  }
  const allModuleEdges = Array.from(mergedEdgeMap.values());

  const moduleGraphRecords = [
    ...moduleNodes.map(n => ({ kind: 'node', ...n })),
    ...allModuleEdges.map(e => ({ kind: 'edge', ...e })),
  ];
  writeJsonl(path.join(out, 'module-graph.jsonl'), moduleGraphRecords);

  // ── 2. proto-index.jsonl ──────────────────────────────────────────────────
  const protoRecords = [
    ...protoIndex.services.map(s => ({ kind: 'service', ...s })),
    ...protoIndex.rpcs.map(r => ({ kind: 'rpc', ...r })),
    ...protoIndex.messages.map(m => ({ kind: 'message', ...m })),
    ...protoIndex.enums.map(e => ({ kind: 'enum', ...e })),
  ];
  writeJsonl(path.join(out, 'proto-index.jsonl'), protoRecords);

  // ── 3. hotspots.jsonl ─────────────────────────────────────────────────────
  const fanInMap = buildFanInMap(includeGraph.edges);

  const goFileMap = new Map();
  for (const fn of goIndex.functions) {
    const entry = goFileMap.get(fn.file) || { lines: 0, module: fn.module };
    entry.lines = Math.max(entry.lines, fn.lines || 0);
    goFileMap.set(fn.file, entry);
  }

  const pyFileMap = new Map();
  for (const fn of pythonIndex.functions) {
    const entry = pyFileMap.get(fn.file) || { lines: 0, module: fn.module };
    entry.lines = Math.max(entry.lines, fn.lines || 0);
    pyFileMap.set(fn.file, entry);
  }
  for (const cls of pythonIndex.classes) {
    if (!pyFileMap.has(cls.file)) pyFileMap.set(cls.file, { lines: 0, module: cls.module });
  }

  const tsFileMap = new Map();
  for (const fn of tsIndex.functions) {
    const entry = tsFileMap.get(fn.file) || { lines: 0, module: fn.module };
    entry.lines = Math.max(entry.lines, fn.lines || 0);
    tsFileMap.set(fn.file, entry);
  }
  for (const cls of tsIndex.classes) {
    if (!tsFileMap.has(cls.file)) tsFileMap.set(cls.file, { lines: 0, module: cls.module });
  }

  const cFileMap = new Map();
  for (const fn of cIndex.functions) {
    const entry = cFileMap.get(fn.file) || { lines: 0, module: fn.module };
    entry.lines = Math.max(entry.lines, fn.lines || 0);
    cFileMap.set(fn.file, entry);
  }
  for (const t of cIndex.types) {
    if (!cFileMap.has(t.file)) cFileMap.set(t.file, { lines: 0, module: t.module });
  }

  const syntheticGoNodes = Array.from(goFileMap.entries())
    .map(([file, { lines, module }]) => ({ id: file, lines, module, fanIn: 0 }));
  const syntheticPyNodes = Array.from(pyFileMap.entries())
    .map(([file, { lines, module }]) => ({ id: file, lines, module, fanIn: 0 }));
  const syntheticTsNodes = Array.from(tsFileMap.entries())
    .map(([file, { lines, module }]) => ({ id: file, lines, module, fanIn: 0 }));
  const syntheticCNodes = Array.from(cFileMap.entries())
    .map(([file, { lines, module }]) => ({ id: file, lines, module, fanIn: 0 }));

  const allFileNodes = [
    ...includeGraph.nodes,
    ...syntheticGoNodes,
    ...syntheticPyNodes,
    ...syntheticTsNodes,
    ...syntheticCNodes,
  ];

  const hotspots = allFileNodes
    .map(n => ({
      ...n,
      fanIn: fanInMap.get(n.id) || 0,
      score: n.lines + (fanInMap.get(n.id) || 0) * 50,
    }))
    .sort((a, b) => b.score - a.score)
    .slice(0, 50)
    .map(({ score, ...rest }) => ({ kind: 'hotspot', ...rest }));

  writeJsonl(path.join(out, 'hotspots.jsonl'), hotspots);

  // ── 4. go-index.jsonl ─────────────────────────────────────────────────────
  if (goIndex.functions.length > 0 || goIndex.types.length > 0) {
    const goRecords = [
      ...goIndex.functions.map(f => ({ kind: 'func', ...f })),
      ...goIndex.types.map(t => ({ kind: 'type', ...t })),
      ...goIndex.imports.map(i => ({ kind: 'import', ...i })),
      ...goIndex.calls.map(c => ({ ...c })),
    ];
    writeJsonl(path.join(out, 'go-index.jsonl'), goRecords);
  }

  // ── 5. python-index.jsonl ──────────────────────────────────────────────────
  if (pythonIndex.functions.length > 0 || pythonIndex.classes.length > 0) {
    const pyRecords = [
      ...pythonIndex.functions.map(f => ({ kind: 'func', ...f })),
      ...pythonIndex.classes.map(c => ({ kind: 'class', ...c })),
      ...pythonIndex.imports.map(i => ({ kind: 'import', ...i })),
      ...pythonIndex.calls.map(c => ({ ...c })),
    ];
    writeJsonl(path.join(out, 'python-index.jsonl'), pyRecords);
  }

  // ── 6. ts-index.jsonl ─────────────────────────────────────────────────────
  if (tsIndex.functions.length > 0 || tsIndex.classes.length > 0) {
    const tsRecords = [
      ...tsIndex.functions.map(f => ({ kind: 'ts-func', ...f })),
      ...tsIndex.classes.map(c => ({ kind: 'ts-class', ...c })),
      ...(tsIndex.imports || []).map(i => ({ kind: 'ts-import', ...i })),
      ...tsIndex.calls.map(c => ({ ...c })),
    ];
    writeJsonl(path.join(out, 'ts-index.jsonl'), tsRecords);
  }

  // ── 7. c-index.jsonl ──────────────────────────────────────────────────────
  if (cIndex.functions.length > 0 || cIndex.types.length > 0) {
    const cRecords = [
      ...cIndex.functions.map(f => ({ kind: 'c-func', ...f })),
      ...cIndex.types.map(t => ({ kind: 'c-type', ...t })),
      ...cIndex.calls.map(c => ({ ...c })),
    ];
    writeJsonl(path.join(out, 'c-index.jsonl'), cRecords);
  }

  // ── 8. call-index.jsonl — all intra-file call edges ───────────────────────
  const allCalls = [
    ...goIndex.calls,
    ...pythonIndex.calls,
    ...tsIndex.calls,
    ...cIndex.calls,
  ];
  if (allCalls.length > 0) {
    writeJsonl(path.join(out, 'call-index.jsonl'), allCalls);
  }

  // ── 9. modules/<name>.jsonl ───────────────────────────────────────────────
  const edgesByModule = new Map();
  for (const edge of includeGraph.edges) {
    const srcParts = edge.source.split('/');
    const mod = srcParts.length > 1 ? srcParts[0] : '__root__';
    if (!edgesByModule.has(mod)) edgesByModule.set(mod, []);
    edgesByModule.get(mod).push(edge);
  }

  const goByModule = new Map();
  for (const fn of goIndex.functions) {
    if (!goByModule.has(fn.module)) goByModule.set(fn.module, { functions: [], types: [], calls: [] });
    goByModule.get(fn.module).functions.push(fn);
  }
  for (const t of goIndex.types) {
    if (!goByModule.has(t.module)) goByModule.set(t.module, { functions: [], types: [], calls: [] });
    goByModule.get(t.module).types.push(t);
  }
  for (const c of goIndex.calls) {
    if (!goByModule.has(c.module)) goByModule.set(c.module, { functions: [], types: [], calls: [] });
    goByModule.get(c.module).calls.push(c);
  }

  const pyByModule = new Map();
  for (const fn of pythonIndex.functions) {
    if (!pyByModule.has(fn.module)) pyByModule.set(fn.module, { functions: [], classes: [], calls: [] });
    pyByModule.get(fn.module).functions.push(fn);
  }
  for (const c of pythonIndex.classes) {
    if (!pyByModule.has(c.module)) pyByModule.set(c.module, { functions: [], classes: [], calls: [] });
    pyByModule.get(c.module).classes.push(c);
  }
  for (const c of pythonIndex.calls) {
    if (!pyByModule.has(c.module)) pyByModule.set(c.module, { functions: [], classes: [], calls: [] });
    pyByModule.get(c.module).calls.push(c);
  }

  const tsByModule = new Map();
  for (const fn of tsIndex.functions) {
    if (!tsByModule.has(fn.module)) tsByModule.set(fn.module, { functions: [], classes: [], calls: [] });
    tsByModule.get(fn.module).functions.push(fn);
  }
  for (const c of tsIndex.classes) {
    if (!tsByModule.has(c.module)) tsByModule.set(c.module, { functions: [], classes: [], calls: [] });
    tsByModule.get(c.module).classes.push(c);
  }
  for (const c of tsIndex.calls) {
    if (!tsByModule.has(c.module)) tsByModule.set(c.module, { functions: [], classes: [], calls: [] });
    tsByModule.get(c.module).calls.push(c);
  }

  const cByModule = new Map();
  for (const fn of cIndex.functions) {
    if (!cByModule.has(fn.module)) cByModule.set(fn.module, { functions: [], types: [], calls: [] });
    cByModule.get(fn.module).functions.push(fn);
  }
  for (const t of cIndex.types) {
    if (!cByModule.has(t.module)) cByModule.set(t.module, { functions: [], types: [], calls: [] });
    cByModule.get(t.module).types.push(t);
  }
  for (const c of cIndex.calls) {
    if (!cByModule.has(c.module)) cByModule.set(c.module, { functions: [], types: [], calls: [] });
    cByModule.get(c.module).calls.push(c);
  }

  const ctagsByModule = new Map();
  for (const sym of ctagsIndex.symbols) {
    if (!ctagsByModule.has(sym.module)) ctagsByModule.set(sym.module, []);
    ctagsByModule.get(sym.module).push(sym);
  }

  let moduleFilesCount = 0;

  for (const mod of modules) {
    // Incremental: skip unchanged modules' per-module files
    if (skipModules.has(mod.name)) {
      // Copy unchanged module file from the committed output dir (existingOut) into the
      // temp write dir (out). Without this, incremental builds would miss unchanged modules.
      const srcPath = path.join(existingOut, 'modules', `${mod.name}.jsonl`);
      const destPath = path.join(modulesDir, `${mod.name}.jsonl`);
      if (fs.existsSync(srcPath)) {
        fs.copyFileSync(srcPath, destPath);
        moduleFilesCount++;
        continue;
      }
    }

    const modNodes = includeGraph.nodes.filter(n => n.module === mod.name);
    const modEdges = edgesByModule.get(mod.name) || [];
    const goData = goByModule.get(mod.name) || { functions: [], types: [], calls: [] };
    const pyData = pyByModule.get(mod.name) || { functions: [], classes: [], calls: [] };
    const tsData = tsByModule.get(mod.name) || { functions: [], classes: [], calls: [] };
    const cData = cByModule.get(mod.name) || { functions: [], types: [], calls: [] };
    const ctagsSym = ctagsByModule.get(mod.name) || [];

    const modNodeIds = new Set(modNodes.map(n => n.id));
    const intraEdges = modEdges.filter(e => modNodeIds.has(e.target));
    const crossEdges = modEdges.filter(e => !modNodeIds.has(e.target));

    const records = [
      { kind: 'module', name: mod.name, sizeKB: mod.sizeKB, files: mod.files },
      ...modNodes.map(n => ({ kind: 'file', ...n })),
      ...intraEdges.map(e => ({ kind: 'include', ...e })),
      ...crossEdges.map(e => ({ kind: 'cross-include', ...e })),
      // Go
      ...goData.functions.map(f => ({ kind: 'go-func', ...f })),
      ...goData.types.map(t => ({ kind: 'go-type', ...t })),
      ...goData.calls.map(c => ({ ...c })),
      // Python
      ...pyData.functions.map(f => ({ kind: 'py-func', ...f })),
      ...pyData.classes.map(c => ({ kind: 'py-class', ...c })),
      ...pyData.calls.map(c => ({ ...c })),
      // TypeScript/JS
      ...tsData.functions.map(f => ({ kind: 'ts-func', ...f })),
      ...tsData.classes.map(c => ({ kind: 'ts-class', ...c })),
      ...tsData.calls.map(c => ({ ...c })),
      // C/C++
      ...cData.functions.map(f => ({ kind: 'c-func', ...f })),
      ...cData.types.map(t => ({ kind: 'c-type', ...t })),
      ...cData.calls.map(c => ({ ...c })),
      // ctags fallback (Java, Rust, etc.)
      ...ctagsSym.map(s => ({ kind: 'ctags-sym', ...s })),
    ];

    if (records.length > 1) {
      writeJsonl(path.join(modulesDir, `${mod.name}.jsonl`), records);
      moduleFilesCount++;
    }
  }

  // ── 10. Mermaid diagrams ───────────────────────────────────────────────────
  const depsDiagram = generateModuleDeps(out, { records: moduleGraphRecords });
  const protoDiagram = generateProtoMap(out, { records: protoRecords });

  if (depsDiagram.mermaid) {
    fs.writeFileSync(path.join(out, 'module-deps.mermaid'), depsDiagram.mermaid, 'utf8');
  }
  if (protoDiagram.mermaid) {
    fs.writeFileSync(path.join(out, 'proto-map.mermaid'), protoDiagram.mermaid, 'utf8');
  }

  // ── 11. schema.yaml ───────────────────────────────────────────────────────
  const schema = generateSchema(repo, modules, includeGraph, allModuleEdges, protoIndex,
                                goIndex, pythonIndex, tsIndex, cIndex, ctagsIndex, allCalls);
  fs.writeFileSync(path.join(out, 'schema.yaml'), schema);

  // ── Compute stats ─────────────────────────────────────────────────────────
  const totalSizeKB = dirSizeKB(out);

  return {
    moduleEdges: allModuleEdges.length,
    rpcs: protoIndex.rpcs.length,
    hotspots: hotspots.length,
    moduleFiles: moduleFilesCount,
    totalSizeKB,
    tsFunctions: tsIndex.functions.length,
    tsClasses: tsIndex.classes.length,
    cFunctions: cIndex.functions.length,
    cTypes: cIndex.types.length,
    ctagsSymbols: ctagsIndex.symbols.length,
  };
}

// =============================================================================
// HELPERS
// =============================================================================

function buildFanInMap(edges) {
  const map = new Map();
  for (const e of edges) {
    map.set(e.target, (map.get(e.target) || 0) + 1);
  }
  return map;
}

function generateSchema(repo, modules, includeGraph, allModuleEdges, protoIndex,
                        goIndex, pythonIndex, tsIndex, cIndex, ctagsIndex, allCalls) {
  const repoName = path.basename(repo);
  const now = new Date().toISOString().replace('T', ' ').slice(0, 19);

  const modList = modules
    .map(m => ` ${m.name}: # ${m.sizeKB}KB, ${m.files.cc}cc ${m.files.h}h ${m.files.go}go ${m.files.ts}ts ${m.files.py}py`)
    .join('\n');

  const tsFuncs = tsIndex.functions.length;
  const tsClasses = tsIndex.classes.length;
  const cFuncs = cIndex.functions.length;
  const cTypes = cIndex.types.length;
  const totalCalls = allCalls.length;

  return `# draft/graph/schema.yaml
# Auto-generated by graph — do not edit manually
# Re-generate with: graph --repo <path>

repo: ${repoName}
generated: ${now}
version: 2

stats:
  modules: ${modules.length}
  file_nodes: ${includeGraph.nodes.length}
  include_edges: ${includeGraph.edges.length}
  module_edges: ${allModuleEdges.length}
  proto_services: ${protoIndex.services.length}
  proto_rpcs: ${protoIndex.rpcs.length}
  proto_enums: ${protoIndex.enums.length}
  go_functions: ${goIndex.functions.length}
  go_types: ${goIndex.types.length}
  py_functions: ${pythonIndex.functions.length}
  py_classes: ${pythonIndex.classes.length}
  ts_functions: ${tsFuncs}
  ts_classes: ${tsClasses}
  c_functions: ${cFuncs}
  c_types: ${cTypes}
  ctags_symbols: ${ctagsIndex.symbols.length}
  call_edges: ${totalCalls}

indexers:
  cpp:
    method: include-graph
    accuracy: "~95% (quoted includes only; angle-bracket system headers excluded)"
    excludes: ["*.pb.cc", "*.pb.h", "*_generated*", "*/test/*"]
  c_symbols:
    method: ${cFuncs > 0 ? 'tree-sitter (with ctags fallback)' : 'skipped (no C/C++ files)'}
    accuracy: "~95%"
  go:
    method: ${goIndex.functions.length > 0 ? 'tree-sitter (with regex fallback)' : 'skipped (no Go files)'}
    accuracy: "~95%"
  python:
    method: ${pythonIndex.functions.length > 0 ? 'tree-sitter (with regex fallback)' : 'skipped (no Python files)'}
    accuracy: "~98%"
  typescript:
    method: ${tsFuncs > 0 ? 'tree-sitter (with regex fallback)' : 'skipped (no TS/JS files)'}
    accuracy: "~95%"
  proto:
    method: line-parser
    accuracy: "100%"
  other_languages:
    method: ${ctagsIndex.symbols.length > 0 ? 'universal-ctags' : 'skipped (ctags not found or no supported files)'}

graph_levels:
  module_graph:
    file: module-graph.jsonl
    load: always
    nodes: ${modules.length}
    edges: ${allModuleEdges.length}
  proto_index:
    file: proto-index.jsonl
    load: always
    rpcs: ${protoIndex.rpcs.length}
  hotspots:
    file: hotspots.jsonl
    load: always
    entries: 50
  go_index:
    file: go-index.jsonl
    load: when-working-in-go-modules
    functions: ${goIndex.functions.length}
  python_index:
    file: python-index.jsonl
    load: when-working-in-python-modules
    functions: ${pythonIndex.functions.length}
  ts_index:
    file: ts-index.jsonl
    load: when-working-in-ts-js-modules
    functions: ${tsFuncs}
  c_index:
    file: c-index.jsonl
    load: when-working-in-c-cpp-modules
    functions: ${cFuncs}
  call_index:
    file: call-index.jsonl
    load: when-tracing-call-paths
    edges: ${totalCalls}
  per_module:
    dir: modules/
    load: on-demand
    files: ${modules.length}

modules:
${modList}
`;
}

module.exports = { writeGraph };
