'use strict';

const fs = require('fs');
const path = require('path');

/**
 * Generate Mermaid diagram text from graph JSONL data.
 *
 * Supports two diagram types:
 * - module-deps: Module dependency graph from module-graph.jsonl
 * - proto-map: Proto service topology from proto-index.jsonl
 *
 * Large graphs are automatically filtered to keep diagrams readable.
 */

const MAX_NODES_FULL = 30;
const MAX_EDGES_FULL = 80;
const DEFAULT_TOP_EDGES = 20;
const WEIGHT_DIVISOR = 10;

// ─────────────────────────────────────────────────────────────────────────────
// LOADERS
// ─────────────────────────────────────────────────────────────────────────────

function loadJsonl(filePath) {
  if (!fs.existsSync(filePath)) return [];
  return fs.readFileSync(filePath, 'utf8')
    .split('\n')
    .filter(Boolean)
    .map(line => { try { return JSON.parse(line); } catch (_) { return null; } })
    .filter(Boolean);
}

// ─────────────────────────────────────────────────────────────────────────────
// MERMAID: MODULE DEPENDENCY GRAPH
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @param {string} graphDir Path to draft/graph/ directory
 * @param {object} opts
 * @param {Array} [opts.records] Pre-loaded module-graph records (skips disk read)
 * @param {number} [opts.maxEdges] Max edges to show (default: auto)
 * @param {number} [opts.minWeight] Min edge weight to include (default: auto)
 * @param {string} [opts.direction] 'LR' or 'TD' (default: 'LR')
 * @returns {{ mermaid: string, filtered: boolean, stats: object }}
 */
function generateModuleDeps(graphDir, opts = {}) {
  const records = opts.records || loadJsonl(path.join(graphDir, 'module-graph.jsonl'));
  const nodes = records.filter(r => r.kind === 'node');
  const edges = records.filter(r => r.kind === 'edge')
    .sort((a, b) => b.weight - a.weight);

  if (nodes.length === 0) {
    return { mermaid: '', filtered: false, stats: { nodes: 0, edges: 0 } };
  }

  const direction = opts.direction || 'LR';
  let filtered = false;
  let visibleEdges = edges;

  if (nodes.length > MAX_NODES_FULL || edges.length > MAX_EDGES_FULL) {
    filtered = true;
    const maxWeight = edges.length > 0 ? edges[0].weight : 0;
    const autoMin = opts.minWeight || Math.max(1, Math.floor(maxWeight / WEIGHT_DIVISOR));
    const maxEdges = opts.maxEdges || DEFAULT_TOP_EDGES;

    visibleEdges = edges.filter(e => e.weight >= autoMin).slice(0, maxEdges);
  }

  const referencedNodes = new Set();
  for (const e of visibleEdges) {
    referencedNodes.add(e.source);
    referencedNodes.add(e.target);
  }

  const visibleNodes = filtered
    ? nodes.filter(n => referencedNodes.has(n.id))
    : nodes.filter(n => referencedNodes.has(n.id) || edges.some(e => e.source === n.id || e.target === n.id) || nodes.length <= MAX_NODES_FULL);

  // Build collision-safe node ID map: sanitizeId can produce identical results
  // for distinct originals (e.g. "auth-service" and "auth_service" → "auth_service").
  const usedIds = new Map(); // sanitized base → count
  const nodeIdMap = new Map(); // original id → final sanitized id

  for (const n of visibleNodes) {
    const base = sanitizeId(n.id);
    if (usedIds.has(base)) {
      const count = usedIds.get(base) + 1;
      usedIds.set(base, count);
      nodeIdMap.set(n.id, `${base}_${count}`);
    } else {
      usedIds.set(base, 1);
      nodeIdMap.set(n.id, base);
    }
  }

  const nodeLabels = new Map();
  for (const n of visibleNodes) {
    const safeId = nodeIdMap.get(n.id);
    const totalFiles = n.files ? n.files.total : 0;
    const label = totalFiles > 0
      ? `${safeId}["${n.id}<br/>${totalFiles} files"]`
      : `${safeId}["${n.id}"]`;
    nodeLabels.set(n.id, label);
  }

  const cycleEdges = detectCycleEdges(nodes.map(n => n.id), edges);

  const lines = [`graph ${direction}`];

  for (const [id, label] of nodeLabels) {
    lines.push(` ${label}`);
  }

  for (const e of visibleEdges) {
    if (!referencedNodes.has(e.source) || !referencedNodes.has(e.target)) continue;
    const src = nodeIdMap.get(e.source) || sanitizeId(e.source);
    const tgt = nodeIdMap.get(e.target) || sanitizeId(e.target);
    const isCycle = cycleEdges.has(`${e.source}->${e.target}`);
    const arrow = isCycle ? '-.->' : '-->';
    lines.push(` ${src} ${arrow}|${e.weight}| ${tgt}`);
  }

  const stats = {
    nodes: visibleNodes.length,
    edges: visibleEdges.length,
    totalNodes: nodes.length,
    totalEdges: edges.length,
  };

  return { mermaid: lines.join('\n'), filtered, stats };
}

// ─────────────────────────────────────────────────────────────────────────────
// MERMAID: PROTO SERVICE MAP
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @param {string} graphDir Path to draft/graph/ directory
 * @param {object} opts
 * @param {Array} [opts.records] Pre-loaded proto-index records (skips disk read)
 * @returns {{ mermaid: string, stats: object }}
 */
function generateProtoMap(graphDir, opts = {}) {
  const records = opts.records || loadJsonl(path.join(graphDir, 'proto-index.jsonl'));
  const services = records.filter(r => r.kind === 'service');
  const rpcs = records.filter(r => r.kind === 'rpc');

  if (services.length === 0) {
    return { mermaid: '', stats: { services: 0, rpcs: 0 } };
  }

  const rpcCounts = new Map();
  for (const r of rpcs) {
    const key = `${r.module}::${r.service}`;
    rpcCounts.set(key, (rpcCounts.get(key) || 0) + 1);
  }

  const byModule = new Map();
  for (const s of services) {
    const mod = s.module || '__root__';
    if (!byModule.has(mod)) byModule.set(mod, []);
    byModule.get(mod).push(s);
  }

  // Build collision-safe node ID map for service nodes across all modules.
  const usedSvcIds = new Map(); // sanitized base → count
  const svcNodeIdMap = new Map(); // "${mod}::${svc.name}" → final sanitized id

  for (const [mod, svcList] of byModule) {
    for (const svc of svcList) {
      const base = sanitizeId(`${mod}_${svc.name}`);
      const mapKey = `${mod}::${svc.name}`;
      if (usedSvcIds.has(base)) {
        const cnt = usedSvcIds.get(base) + 1;
        usedSvcIds.set(base, cnt);
        svcNodeIdMap.set(mapKey, `${base}_${cnt}`);
      } else {
        usedSvcIds.set(base, 1);
        svcNodeIdMap.set(mapKey, base);
      }
    }
  }

  // Build collision-safe subgraph IDs for modules.
  const usedModIds = new Map(); // sanitized base → count
  const modNodeIdMap = new Map(); // original mod → final sanitized id

  for (const mod of byModule.keys()) {
    const base = sanitizeId(mod);
    if (usedModIds.has(base)) {
      const cnt = usedModIds.get(base) + 1;
      usedModIds.set(base, cnt);
      modNodeIdMap.set(mod, `${base}_${cnt}`);
    } else {
      usedModIds.set(base, 1);
      modNodeIdMap.set(mod, base);
    }
  }

  const lines = ['graph TD'];

  for (const [mod, svcList] of byModule) {
    const safeMod = modNodeIdMap.get(mod);
    lines.push(` subgraph ${safeMod}["${mod}"]`);

    for (const svc of svcList) {
      const mapKey = `${mod}::${svc.name}`;
      const rpcKey = `${svc.module}::${svc.name}`;
      const count = rpcCounts.get(rpcKey) || 0;
      const nodeId = svcNodeIdMap.get(mapKey);
      lines.push(` ${nodeId}["${svc.name}<br/>${count} RPCs"]`);
    }

    lines.push(' end');
  }

  const stats = {
    services: services.length,
    rpcs: rpcs.length,
    modules: byModule.size,
  };

  return { mermaid: lines.join('\n'), stats };
}

// ─────────────────────────────────────────────────────────────────────────────
// COMBINED: Both diagrams as markdown-ready text
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @param {string} graphDir
 * @returns {string} Markdown text with fenced Mermaid blocks, ready for injection
 */
function generateAllMermaid(graphDir) {
  const sections = [];

  const deps = generateModuleDeps(graphDir);
  if (deps.mermaid) {
    let header = '## Module Dependency Graph (auto-generated)';
    header += '\n\n<!-- AUTO-GENERATED by draft:init from draft/graph/module-graph.jsonl -->';
    if (deps.filtered) {
      header += `\n\n> Showing top ${deps.stats.edges} edges by weight`
        + ` (${deps.stats.totalEdges} total). Dashed edges indicate cycles.`;
    } else if (deps.stats.edges > 0) {
      header += '\n\n> Dashed edges indicate circular dependencies.';
    }
    header += '\n\n```mermaid\n' + deps.mermaid + '\n```';
    sections.push(header);
  }

  const proto = generateProtoMap(graphDir);
  if (proto.mermaid) {
    let header = '## Proto Service Map (auto-generated)';
    header += '\n\n<!-- AUTO-GENERATED by draft:init from draft/graph/proto-index.jsonl -->';
    header += `\n\n> ${proto.stats.services} proto services across ${proto.stats.modules} modules`
      + ` (${proto.stats.rpcs} RPCs total).`;
    header += '\n\n```mermaid\n' + proto.mermaid + '\n```';
    sections.push(header);
  }

  return sections.join('\n\n');
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

function sanitizeId(id) {
  return id.replace(/[^a-zA-Z0-9_]/g, '_');
}

function detectCycleEdges(nodeIds, edges) {
  const adj = new Map();
  for (const n of nodeIds) adj.set(n, []);
  for (const e of edges) {
    if (adj.has(e.source)) adj.get(e.source).push(e.target);
  }

  // Iterative DFS to find all nodes that are part of any cycle
  const WHITE = 0, GRAY = 1, BLACK = 2;
  const color = new Map(nodeIds.map(n => [n, WHITE]));
  const cycleNodes = new Set();

  for (const startNode of nodeIds) {
    if (color.get(startNode) !== WHITE) continue;

    const stack = [[startNode, 0, [startNode]]];
    color.set(startNode, GRAY);

    while (stack.length > 0) {
      const frame = stack[stack.length - 1];
      const [node, , currentPath] = frame;
      const neighbors = adj.get(node) || [];

      if (frame[1] >= neighbors.length) {
        color.set(node, BLACK);
        stack.pop();
        continue;
      }

      const neighbor = neighbors[frame[1]++];

      if (color.get(neighbor) === GRAY) {
        // All nodes in the cycle path get marked
        const cycleStart = currentPath.indexOf(neighbor);
        for (const n of currentPath.slice(cycleStart)) {
          cycleNodes.add(n);
        }
        cycleNodes.add(neighbor);
      } else if (color.get(neighbor) === WHITE) {
        color.set(neighbor, GRAY);
        stack.push([neighbor, 0, [...currentPath, neighbor]]);
      }
    }
  }

  // An edge is a cycle edge if BOTH source and target are in cycle nodes
  // AND there is a path back (i.e., target can reach source)
  const cycleEdgeSet = new Set();
  for (const e of edges) {
    if (cycleNodes.has(e.source) && cycleNodes.has(e.target)) {
      cycleEdgeSet.add(`${e.source}->${e.target}`);
    }
  }

  return cycleEdgeSet;
}

module.exports = { generateModuleDeps, generateProtoMap, generateAllMermaid };
