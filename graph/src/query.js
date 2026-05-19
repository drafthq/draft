'use strict';

const fs = require('fs');
const path = require('path');
const { die, warn } = require('./util');
const { generateModuleDeps, generateProtoMap, generateAllMermaid } = require('./mermaid');

/**
 * Query the graph without rebuilding.
 * Reads JSONL files directly — no database needed.
 *
 * Modes:
 * callers — what files/modules include the given symbol/file
 * impact — transitive blast radius of changing a file
 * hotspots — top complexity files (optionally filtered to a module)
 * modules — show the inter-module dependency graph
 * mermaid — generate Mermaid diagram text (module deps + proto map)
 *
 * Output: JSON to stdout — consumed by draft:implement, draft:bughunt etc.
 */
function query({ out, symbol, file, mode }) {
  if (!mode) die('--mode required for query. Options: callers|impact|hotspots|modules|mermaid');
  if (!fs.existsSync(out)) die(`Graph not found at ${out}. Run graph --repo <path> first.`);

  switch (mode) {
    case 'callers': return queryCallers(out, symbol || file);
    case 'impact': return queryImpact(out, symbol || file);
    case 'hotspots': return queryHotspots(out, symbol);
    case 'modules': return queryModules(out);
    case 'cycles': return queryCycles(out);
    case 'mermaid': return queryMermaid(out, symbol);
    default: die(`Unknown mode: ${mode}. Options: callers|impact|hotspots|modules|cycles|mermaid`);
  }
}

// =============================================================================
// LOADERS
// =============================================================================

function loadJsonl(filePath) {
  if (!fs.existsSync(filePath)) return [];
  const buf = fs.readFileSync(filePath);
  const results = [];
  let start = 0;
  for (let i = 0; i <= buf.length; i++) {
    if (i === buf.length || buf[i] === 10) { // 10 = '\n'
      if (i > start) {
        const line = buf.toString('utf8', start, i).trimEnd();
        if (line) {
          try {
            const r = JSON.parse(line);
            if (r !== null) results.push(r);
          } catch (_) {}
        }
      }
      start = i + 1;
    }
  }
  return results;
}

function loadModuleGraph(out) {
  return loadJsonl(path.join(out, 'module-graph.jsonl'));
}

function loadModuleFile(out, moduleName) {
  return loadJsonl(path.join(out, 'modules', `${moduleName}.jsonl`));
}

function loadHotspots(out) {
  return loadJsonl(path.join(out, 'hotspots.jsonl'));
}

// =============================================================================
// QUERY: CALLERS
// Two modes:
// 1. File target (contains '/' or has a file extension): include-edge callers
// 2. Symbol name (bare identifier): function-level callers from call-index.jsonl
// =============================================================================

function queryCallers(out, target) {
  if (!target) die('--symbol or --file required for callers mode');

  // Dispatch: if target looks like a file path use include-edge logic,
  // otherwise use the call index for function-level callers.
  const looksLikeFile = target.includes('/') || /\.\w{1,6}$/.test(target);
  if (looksLikeFile) {
    return queryFileCallers(out, target);
  } else {
    return queryFunctionCallers(out, target);
  }
}

/**
 * Include-edge callers: what files #include / import the given file?
 */
function queryFileCallers(out, target) {
  const targetModule = target.includes('/') ? target.split('/')[0] : '__root__';

  const modFileCache = new Map();
  const getCachedModFile = (moduleName) => {
    if (!modFileCache.has(moduleName)) {
      modFileCache.set(moduleName, loadModuleFile(out, moduleName));
    }
    return modFileCache.get(moduleName);
  };

  const moduleRecords = getCachedModFile(targetModule);

  const intraCallers = moduleRecords
    .filter(r => r.kind === 'include' && r.target === target)
    .map(r => ({ file: r.source, module: targetModule, type: 'intra-module' }));

  const moduleGraph = loadModuleGraph(out);
  const moduleNodes = moduleGraph.filter(r => r.kind === 'node').map(r => r.id);
  const crossCallers = [];

  for (const mod of moduleNodes) {
    if (mod === targetModule) continue;
    const recs = getCachedModFile(mod);
    for (const r of recs) {
      if (r.kind === 'cross-include' && r.target === target) {
        crossCallers.push({ file: r.source, module: mod, type: 'cross-module' });
      }
    }
  }

  const result = {
    target,
    callers: [...intraCallers, ...crossCallers],
    summary: {
      intra: intraCallers.length,
      cross: crossCallers.length,
      total: intraCallers.length + crossCallers.length,
    },
  };

  console.log(JSON.stringify(result, null, 2));
}

/**
 * Function-level callers: which functions call the given symbol?
 * Reads call-index.jsonl — intra-file call edges from all language extractors.
 */
function queryFunctionCallers(out, target) {
  const callIndexPath = path.join(out, 'call-index.jsonl');
  if (!fs.existsSync(callIndexPath)) {
    console.log(JSON.stringify({
      error: 'no call index — rebuild graph to generate call edges',
      hint: 'Run: graph --repo <path> --out ' + out,
    }, null, 2));
    return;
  }

  const allCalls = loadJsonl(callIndexPath);
  const callers = allCalls
    .filter(r => r.to === target)
    .map(r => ({
      func: r.from,
      file: r.fromFile,
      module: r.module,
      line: r.line,
      kind: r.kind,
      resolved: r.resolved,
    }));

  // Deduplicate by (func, file) — same function calling same target multiple times
  const seen = new Set();
  const unique = callers.filter(c => {
    const key = `${c.func}::${c.file}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });

  // Group by module for summary
  const byModule = {};
  for (const c of unique) {
    byModule[c.module] = (byModule[c.module] || 0) + 1;
  }

  const result = {
    target,
    callers: unique,
    total: unique.length,
    by_module: byModule,
    note: 'intra-file call edges only; cross-file resolution requires type information',
  };

  console.log(JSON.stringify(result, null, 2));
}

// =============================================================================
// QUERY: IMPACT (transitive blast radius)
// What would break if this file changes? BFS over the include graph.
// Each impacted file is classified as code|test|doc|config so callers can
// reason about which kinds of follow-up work the change implies.
// =============================================================================

/**
 * Classify a file path into a coarse category. Pattern set mirrors
 * scripts/tools/classify-files.sh; kept in JS to avoid shelling out per query.
 */
function classifyFile(filePath) {
  const path = filePath.toLowerCase();
  const base = path.split('/').pop() || path;

  // Test patterns — directory or filename
  if (/(^|\/)(tests?|__tests__|specs?)\//.test(path)) return 'test';
  if (/(^|_)test_|_test\.(go|py|sh)$|test_.*\.py$|tests?\.py$|conftest\.py$/.test(base)) return 'test';
  if (/\.(test|spec)\.(ts|tsx|js|jsx|mjs|cjs)$/.test(base)) return 'test';
  if (/(test|tests|spec)\.java$/.test(base)) return 'test';

  // Doc patterns
  if (/\.(md|markdown|rst|txt|adoc)$/.test(base)) return 'doc';

  // Config patterns
  if (/\.(ya?ml|toml|json|ini|cfg|conf|env|properties)$/.test(base)) return 'config';
  if (/^(makefile|dockerfile|jenkinsfile|\.gitignore|\.dockerignore)$/i.test(base)) return 'config';

  return 'code';
}

function queryImpact(out, target) {
  if (!target) die('--file required for impact mode');

  const moduleGraph = loadModuleGraph(out);
  const moduleNodes = moduleGraph.filter(r => r.kind === 'node').map(r => r.id);

  // Build reverse include index once — O(modules × records) upfront cost,
  // eliminates the O(queue × modules × records) scan that the original BFS had.
  const reverseIndex = new Map(); // target → [{source, module}]
  for (const mod of moduleNodes) {
    for (const r of loadModuleFile(out, mod)) {
      if (r.kind !== 'include' && r.kind !== 'cross-include') continue;
      if (!reverseIndex.has(r.target)) reverseIndex.set(r.target, []);
      reverseIndex.get(r.target).push({ source: r.source, module: mod });
    }
  }

  // BFS: start from target file, find all transitive callers
  const visited = new Set([target]);
  const queue = [target];
  const impactList = [];
  const depthMap = new Map([[target, 0]]); // O(1) depth lookup, replaces O(n) list scan

  let head = 0; // index into queue — O(1) dequeue, no element shifting
  while (head < queue.length) {
    const current = queue[head++];
    const depth = depthMap.get(current) ?? 0;

    for (const { source, module } of (reverseIndex.get(current) || [])) {
      if (!visited.has(source)) {
        visited.add(source);
        depthMap.set(source, depth + 1);
        impactList.push({
          file: source,
          module,
          depth: depth + 1,
          category: classifyFile(source),
        });
        queue.push(source);
      }
    }
  }

  // Summarize affected modules and categories
  const affectedModules = [...new Set(impactList.map(i => i.module))];
  const byCategory = { code: 0, test: 0, doc: 0, config: 0 };
  for (const item of impactList) byCategory[item.category]++;

  const result = {
    target,
    impact: {
      files: impactList.length,
      modules: affectedModules.length,
      affected_modules: affectedModules,
      by_category: byCategory,
      files_by_depth: groupByDepth(impactList),
      files_by_category: groupByCategory(impactList),
    },
    warning: impactList.length > 50
      ? `High blast radius: ${impactList.length} files affected. Consider breaking this dependency.`
      : null,
  };

  console.log(JSON.stringify(result, null, 2));
}

// =============================================================================
// QUERY: HOTSPOTS
// Top complexity files, optionally filtered to a module
// =============================================================================

function queryHotspots(out, moduleFilter) {
  let hotspots = loadHotspots(out);

  if (moduleFilter) {
    hotspots = hotspots.filter(h => h.module === moduleFilter);
  }

  console.log(JSON.stringify({ hotspots: hotspots.slice(0, 20) }, null, 2));
}

// =============================================================================
// QUERY: MODULES
// Show inter-module dependency graph
// =============================================================================

function queryModules(out) {
  const records = loadModuleGraph(out);
  const nodes = records.filter(r => r.kind === 'node');
  const edges = records.filter(r => r.kind === 'edge').sort((a, b) => b.weight - a.weight);

  // Detect circular dependencies
  const cycles = detectCycles(nodes.map(n => n.id), edges);

  console.log(JSON.stringify({
    modules: nodes,
    dependencies: edges,
    cycles,
    summary: {
      modules: nodes.length,
      edges: edges.length,
      cycles: cycles.length,
      hub_modules: findHubs(nodes, edges),
    },
  }, null, 2));
}

// =============================================================================
// QUERY: CYCLES
// Find circular dependencies between modules
// =============================================================================

function queryCycles(out) {
  const records = loadModuleGraph(out);
  const nodes = records.filter(r => r.kind === 'node').map(r => r.id);
  const edges = records.filter(r => r.kind === 'edge');
  const cycles = detectCycles(nodes, edges);

  if (cycles.length === 0) {
    console.log(JSON.stringify({ cycles: [], message: 'No circular dependencies detected.' }));
  } else {
    console.log(JSON.stringify({
      cycles,
      count: cycles.length,
      warning: `${cycles.length} circular dependency cycle(s) detected. These indicate tight coupling.`,
    }, null, 2));
  }
}

// =============================================================================
// QUERY: MERMAID
// Generate Mermaid diagram text for module deps and/or proto service map.
// --symbol selects diagram type: 'module-deps', 'proto-map', or default (both).
// =============================================================================

function queryMermaid(out, diagramType) {
  if (diagramType === 'module-deps') {
    const result = generateModuleDeps(out);
    console.log(JSON.stringify(result, null, 2));
  } else if (diagramType === 'proto-map') {
    const result = generateProtoMap(out);
    console.log(JSON.stringify(result, null, 2));
  } else {
    const markdown = generateAllMermaid(out);
    if (markdown) {
      console.log(markdown);
    } else {
      console.log(JSON.stringify({ message: 'No graph data found to generate diagrams.' }));
    }
  }
}

// =============================================================================
// GRAPH ALGORITHMS
// =============================================================================

/** Detect cycles using iterative DFS + WHITE/GRAY/BLACK color marking.
 * Avoids call stack overflow on deeply linear module chains. */
function detectCycles(nodes, edges) {
  const adj = new Map();
  for (const n of nodes) adj.set(n, []);
  for (const e of edges) {
    if (adj.has(e.source)) adj.get(e.source).push(e.target);
  }

  const WHITE = 0, GRAY = 1, BLACK = 2;
  const color = new Map(nodes.map(n => [n, WHITE]));
  const cycles = [];

  for (const startNode of nodes) {
    if (color.get(startNode) !== WHITE) continue;

    // Each stack entry: [node, neighborIndex, path]
    const stack = [[startNode, 0, [startNode]]];
    color.set(startNode, GRAY);

    while (stack.length > 0) {
      const frame = stack[stack.length - 1];
      const [node, , currentPath] = frame;
      const neighbors = adj.get(node) || [];

      if (frame[1] >= neighbors.length) {
        // All neighbors visited — backtrack
        color.set(node, BLACK);
        stack.pop();
        continue;
      }

      const neighbor = neighbors[frame[1]++];

      if (color.get(neighbor) === GRAY) {
        // Cycle found — extract the cycle portion of path
        const cycleStart = currentPath.indexOf(neighbor);
        cycles.push([...currentPath.slice(cycleStart), neighbor]);
      } else if (color.get(neighbor) === WHITE) {
        color.set(neighbor, GRAY);
        stack.push([neighbor, 0, [...currentPath, neighbor]]);
      }
    }
  }

  return cycles;
}

/** Find hub modules (high in-degree = many dependents) */
function findHubs(nodes, edges) {
  const inDegree = new Map(nodes.map(n => [n.id, 0]));
  for (const e of edges) {
    inDegree.set(e.target, (inDegree.get(e.target) || 0) + e.weight);
  }
  return [...inDegree.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([id, weight]) => ({ module: id, dependents_weight: weight }));
}

function groupByDepth(items) {
  const groups = {};
  for (const item of items) {
    const d = item.depth;
    if (!groups[d]) groups[d] = [];
    groups[d].push(item.file);
  }
  return groups;
}

function groupByCategory(items) {
  const groups = { code: [], test: [], doc: [], config: [] };
  for (const item of items) groups[item.category].push(item.file);
  return groups;
}

module.exports = { query };
