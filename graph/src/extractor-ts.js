'use strict';

const fs = require('fs');
const path = require('path');
const { walkFiles, countLinesFromContent, warn, initTreeSitter, walkNodeEnterLeave } = require('./util');

const TS_EXTS = new Set(['.ts', '.js', '.mjs', '.cjs']);
const TSX_EXTS = new Set(['.tsx', '.jsx']);
const ALL_EXTS = [...TS_EXTS, ...TSX_EXTS];
const TS_EXTS_LIST = ['.ts', '.js', '.mjs', '.cjs'];
const TSX_EXTS_LIST = ['.tsx', '.jsx'];

/**
 * Index TypeScript and JavaScript source files.
 *
 * Primary method: tree-sitter WASM (typescript + tsx grammars).
 * Fallback: regex-based extraction (~90% accurate for common patterns).
 *
 * Extracts:
 * functions — function declarations, arrow functions, methods
 * classes — class, interface, and type alias declarations
 * imports — ES module import statements
 * calls — intra-file function call edges (tree-sitter only)
 *
 * @param {string} repo
 * @param {RegExp[]} excludeRes pre-compiled exclude patterns
 * @param {Map<string,string[]>|null} allFiles pre-collected file map, or null to walk
 */
async function buildTsIndex(repo, excludeRes = [], allFiles = null) {
  const tsFiles = allFiles
    ? [...TS_EXTS_LIST, ...TSX_EXTS_LIST].flatMap(ext => allFiles.get(ext) || [])
    : walkFiles(repo, ALL_EXTS, excludeRes);

  const functions = [];
  const classes = [];
  const imports = [];
  const calls = [];

  if (tsFiles.length === 0) return { functions, classes, imports, calls };

  await tryLoadParsers();

  for (const f of tsFiles) {
    const rel = path.relative(repo, f);
    const parts = rel.split(path.sep);
    const module = parts.length > 1 ? parts[0] : '__root__';
    const ext = path.extname(f);

    let content;
    try { content = fs.readFileSync(f).toString('utf8').replace(/\0/g, ''); }
    catch (_) { continue; }

    const totalLines = countLinesFromContent(content);
    const useTsx = TSX_EXTS.has(ext);

    if (_parsers.ts || _parsers.tsx) {
      parseTsTreeSitter(content, rel, module, totalLines, functions, classes, imports, calls, useTsx);
    } else {
      parseTsRegex(content, rel, module, totalLines, functions, classes, imports);
    }
  }

  return { functions, classes, imports, calls };
}

// =============================================================================
// TREE-SITTER WASM
// =============================================================================

const _parsers = { ts: null, tsx: null, attempted: false };

async function tryLoadParsers() {
  if (_parsers.attempted) return;
  _parsers.attempted = true;

  const Parser = await initTreeSitter();
  if (!Parser) return;

  // Load TypeScript grammar (.ts, .js)
  try {
    let wasm;
    try {
      const { getAssetAsBlob } = require('node:sea');
      wasm = getAssetAsBlob('tree-sitter-typescript.wasm');
    } catch (_) {
      wasm = require.resolve('tree-sitter-wasms/out/tree-sitter-typescript.wasm');
    }
    const lang = await Parser.Language.load(wasm);
    const p = new Parser();
    p.setLanguage(lang);
    _parsers.ts = p;
  } catch (e) {
    warn(`tree-sitter TypeScript grammar unavailable: ${e.message}`);
  }

  // Load TSX grammar (.tsx, .jsx)
  try {
    let wasm;
    try {
      const { getAssetAsBlob } = require('node:sea');
      wasm = getAssetAsBlob('tree-sitter-tsx.wasm');
    } catch (_) {
      wasm = require.resolve('tree-sitter-wasms/out/tree-sitter-tsx.wasm');
    }
    const lang = await Parser.Language.load(wasm);
    const p = new Parser();
    p.setLanguage(lang);
    _parsers.tsx = p;
  } catch (e) {
    warn(`tree-sitter TSX grammar unavailable: ${e.message}`);
  }
}

function parseTsTreeSitter(content, filePath, module, totalLines, functions, classes, imports, calls, useTsx) {
  const parser = useTsx ? (_parsers.tsx || _parsers.ts) : (_parsers.ts || _parsers.tsx);
  if (!parser) {
    parseTsRegex(content, filePath, module, totalLines, functions, classes, imports);
    return;
  }

  try {
    const tree = parser.parse(content);
    const root = tree.rootNode;

    // State for tracking context during traversal
    const funcStack = []; // stack of enclosing function names
    const classStack = []; // stack of enclosing class names (handles nesting)
    let exportDepth = 0; // counter not bool: export{export{}} nests correctly

    walkNodeEnterLeave(root,
      // enter
      (node) => {
        switch (node.type) {
          case 'export_statement':
            exportDepth++;
            break;

          case 'function_declaration': {
            const nameNode = node.childForFieldName('name');
            const name = nameNode ? nameNode.text : '__anon__';
            const isAsync = !!node.children.find(c => c.type === 'async');
            functions.push({
              name, file: filePath, module,
              line: node.startPosition.row + 1,
              lines: totalLines,
              exported: exportDepth > 0,
              class: classStack.length > 0 ? classStack[classStack.length - 1] : null,
              async: isAsync,
            });
            funcStack.push(name);
            break;
          }

          case 'method_definition': {
            const nameNode = node.childForFieldName('name');
            const name = nameNode ? nameNode.text : '__anon__';
            const isAsync = !!node.children.find(c => c.type === 'async');
            if (name !== 'constructor') { // skip constructors — they're not independently callable
              functions.push({
                name, file: filePath, module,
                line: node.startPosition.row + 1,
                lines: totalLines,
                exported: false,
                class: classStack.length > 0 ? classStack[classStack.length - 1] : null,
                async: isAsync,
              });
            }
            funcStack.push(name);
            break;
          }

          case 'variable_declarator': {
            // const foo = () => { ... } or const foo = function() { ... }
            const valueNode = node.childForFieldName('value');
            if (valueNode && (valueNode.type === 'arrow_function' || valueNode.type === 'function')) {
              const nameNode = node.childForFieldName('name');
              const name = nameNode ? nameNode.text : '__anon__';
              const isAsync = !!valueNode.children.find(c => c.type === 'async');
              functions.push({
                name, file: filePath, module,
                line: node.startPosition.row + 1,
                lines: totalLines,
                exported: exportDepth > 0,
                class: classStack.length > 0 ? classStack[classStack.length - 1] : null,
                async: isAsync,
              });
              funcStack.push(name);
            }
            break;
          }

          case 'class_declaration': {
            const nameNode = node.childForFieldName('name');
            const name = nameNode ? nameNode.text : '__anon__';
            classStack.push(name); // push before emitting so methods inside see the right class
            classes.push({
              name, file: filePath, module,
              line: node.startPosition.row + 1,
              lines: totalLines,
              exported: exportDepth > 0,
              kind: 'class',
            });
            break;
          }

          case 'interface_declaration': {
            const nameNode = node.childForFieldName('name');
            if (nameNode) {
              classes.push({
                name: nameNode.text,
                file: filePath, module,
                line: node.startPosition.row + 1,
                lines: totalLines,
                exported: exportDepth > 0,
                kind: 'interface',
              });
            }
            break;
          }

          case 'type_alias_declaration': {
            const nameNode = node.childForFieldName('name');
            if (nameNode) {
              classes.push({
                name: nameNode.text,
                file: filePath, module,
                line: node.startPosition.row + 1,
                lines: totalLines,
                exported: exportDepth > 0,
                kind: 'type',
              });
            }
            break;
          }

          case 'import_statement': {
            const sourceNode = node.children.find(c => c.type === 'string');
            const from = sourceNode ? sourceNode.text.replace(/['"]/g, '') : '';
            const names = [];
            // Collect named imports from import_clause → named_imports
            for (const child of node.children) {
              if (child.type === 'import_clause') {
                for (const ic of child.children) {
                  if (ic.type === 'named_imports') {
                    for (const spec of ic.children) {
                      if (spec.type === 'import_specifier') {
                        const n = spec.child(0);
                        if (n) names.push(n.text);
                      }
                    }
                  } else if (ic.type === 'identifier') {
                    names.push(ic.text); // default import
                  }
                }
              }
            }
            imports.push({ from, names, file: filePath, module });
            break;
          }

          case 'call_expression': {
            const enclosing = funcStack.length > 0 ? funcStack[funcStack.length - 1] : null;
            if (!enclosing) break;
            const funcNode = node.child(0); // first child is the function being called
            let callee = null;
            // direct: bare identifier. inferred: member access collapses x.foo() and y.foo() to "foo".
            let confidence = 'direct';
            if (funcNode) {
              if (funcNode.type === 'identifier') {
                callee = funcNode.text;
              } else if (funcNode.type === 'member_expression') {
                const prop = funcNode.childForFieldName('property');
                if (prop) { callee = prop.text; confidence = 'inferred'; }
              }
            }
            if (callee && callee !== enclosing) { // skip self-calls
              calls.push({
                kind: 'ts-call', from: enclosing, to: callee,
                fromFile: filePath, module,
                line: node.startPosition.row + 1,
                resolved: false,
                confidence,
              });
            }
            break;
          }
        }
      },
      // leave
      (node) => {
        switch (node.type) {
          case 'export_statement':
            exportDepth--;
            break;

          case 'function_declaration':
          case 'method_definition':
            funcStack.pop();
            break;

          case 'variable_declarator': {
            const valueNode = node.childForFieldName('value');
            if (valueNode && (valueNode.type === 'arrow_function' || valueNode.type === 'function')) {
              funcStack.pop();
            }
            break;
          }

          case 'class_declaration':
            classStack.pop();
            break;
        }
      }
    );
  } catch (e) {
    warn(`tree-sitter parse failed for ${filePath}, falling back to regex: ${e.message}`);
    parseTsRegex(content, filePath, module, totalLines, functions, classes, imports);
  }
}

// =============================================================================
// REGEX FALLBACK
// =============================================================================

function parseTsRegex(content, filePath, module, totalLines, functions, classes, imports) {
  const lines = content.split('\n');

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trim();
    if (trimmed.startsWith('//') || trimmed === '') continue;

    const lineNo = i + 1;

    // import { foo } from './bar' or import foo from './bar'
    const importMatch = trimmed.match(/^import\s+(?:type\s+)?(?:.*?\s+from\s+)?['"]([^'"]+)['"]/);
    if (importMatch) {
      imports.push({ from: importMatch[1], names: [], file: filePath, module });
      continue;
    }

    // export? function name(
    const funcMatch = trimmed.match(/^(?:export\s+)?(?:async\s+)?function\s+(\w+)\s*[(<]/);
    if (funcMatch) {
      functions.push({
        name: funcMatch[1],
        file: filePath, module,
        line: lineNo, lines: totalLines,
        exported: trimmed.startsWith('export'),
        class: null, async: trimmed.includes('async'),
      });
      continue;
    }

    // export? const name = (async)? () => | function
    const arrowMatch = trimmed.match(/^(?:export\s+)?(?:const|let)\s+(\w+)\s*=\s*(?:async\s+)?(?:\(|function)/);
    if (arrowMatch) {
      functions.push({
        name: arrowMatch[1],
        file: filePath, module,
        line: lineNo, lines: totalLines,
        exported: trimmed.startsWith('export'),
        class: null, async: trimmed.includes('async'),
      });
      continue;
    }

    // export? class Name
    const classMatch = trimmed.match(/^(?:export\s+)?(?:abstract\s+)?class\s+(\w+)/);
    if (classMatch) {
      classes.push({
        name: classMatch[1],
        file: filePath, module,
        line: lineNo, lines: totalLines,
        exported: trimmed.startsWith('export'),
        kind: 'class',
      });
      continue;
    }

    // export? interface Name
    const ifaceMatch = trimmed.match(/^(?:export\s+)?interface\s+(\w+)/);
    if (ifaceMatch) {
      classes.push({
        name: ifaceMatch[1],
        file: filePath, module,
        line: lineNo, lines: totalLines,
        exported: trimmed.startsWith('export'),
        kind: 'interface',
      });
      continue;
    }

    // export? type Name =
    const typeMatch = trimmed.match(/^(?:export\s+)?type\s+(\w+)\s*[=<]/);
    if (typeMatch) {
      classes.push({
        name: typeMatch[1],
        file: filePath, module,
        line: lineNo, lines: totalLines,
        exported: trimmed.startsWith('export'),
        kind: 'type',
      });
    }
  }
}

module.exports = { buildTsIndex };
