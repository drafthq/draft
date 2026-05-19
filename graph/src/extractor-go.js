'use strict';

const fs = require('fs');
const path = require('path');
const { walkFiles, countLinesFromContent, warn, initTreeSitter, walkNodeEnterLeave } = require('./util');

/**
 * Index Go source files.
 *
 * Primary method: regex-based extraction (no dependencies, fast, ~95% accurate
 * for Go which has clean, regular syntax unlike C++).
 *
 * Optional enhancement: if tree-sitter WASM is available (bundled in the
 * SEA binary), use it for more precise extraction. Falls back to regex
 * gracefully if WASM load fails.
 *
 * Extracts:
 * functions — top-level func declarations + receiver methods
 * types — struct, interface, type alias definitions
 * imports — package-level imports for cross-file edge detection
 *
 * @param {string} repo
 * @param {RegExp[]} excludeRes pre-compiled exclude patterns
 * @param {Map<string,string[]>|null} allFiles pre-collected file map, or null to walk
 */
async function buildGoIndex(repo, excludeRes = [], allFiles = null) {
  const goFiles = allFiles
    ? (allFiles.get('.go') || [])
    : walkFiles(repo, ['.go'], excludeRes);

  const functions = [];
  const types = [];
  const imports = [];
  const calls = [];

  if (goFiles.length === 0) {
    return { functions, types, imports, calls };
  }

  // Try tree-sitter WASM first (more accurate)
  const tsAvailable = await tryLoadTreeSitter();

  for (const f of goFiles) {
    const rel = path.relative(repo, f);
    const parts = rel.split(path.sep);
    const module = parts.length > 1 ? parts[0] : '__root__';

    let content;
    try { content = fs.readFileSync(f).toString('utf8').replace(/\0/g, ''); }
    catch (_) { continue; }

    const lines = countLinesFromContent(content);

    if (tsAvailable) {
      parseGoTreeSitter(content, rel, module, lines, functions, types, imports, calls);
    } else {
      parseGoRegex(content, rel, module, lines, functions, types, imports);
    }
  }

  return { functions, types, imports, calls };
}

// =============================================================================
// REGEX PARSER (primary / fallback)
// =============================================================================

function parseGoRegex(content, filePath, module, totalLines, functions, types, imports) {
  const lines = content.split('\n');

  // Package declaration
  let pkg = '__unknown__';
  const pkgMatch = content.match(/^package\s+(\w+)/m);
  if (pkgMatch) pkg = pkgMatch[1];

  let inImportBlock = false;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trim();
    const lineNo = i + 1;

    // Skip comments
    if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;

    // ── func declaration ────────────────────────────────────────────────────
    // Matches:
    // func Name(...) ...
    // func (r *Receiver) Name(...) ...
    const funcMatch = trimmed.match(
      /^func\s+(?:\([^)]*\)\s+)?(\w+)\s*\(/
    );
    if (funcMatch) {
      const receiverMatch = trimmed.match(/^func\s+\(([^)]*)\)\s+(\w+)/);
      const name = receiverMatch ? receiverMatch[2] : funcMatch[1];
      const receiver = receiverMatch
        ? receiverMatch[1].trim().replace(/^\*/, '').split(/\s+/).pop()
        : null;

      functions.push({
        name,
        receiver,
        qualified: receiver ? `${receiver}.${name}` : name,
        file: filePath,
        module,
        package: pkg,
        line: lineNo,
        lines: totalLines,
      });
      continue;
    }

    // ── type declaration ────────────────────────────────────────────────────
    // Matches:
    // type Foo struct { ... }
    // type Bar interface { ... }
    // type Baz = SomeType
    const typeMatch = trimmed.match(/^type\s+(\w+)\s+(struct|interface|=|\w)/);
    if (typeMatch) {
      const kind = typeMatch[2] === 'struct' ? 'struct'
                 : typeMatch[2] === 'interface' ? 'interface'
                 : typeMatch[2] === '=' ? 'alias'
                 : 'type';
      types.push({
        name: typeMatch[1],
        kind,
        file: filePath,
        module,
        package: pkg,
        line: lineNo,
      });
      continue;
    }

    // ── import ──────────────────────────────────────────────────────────────
    // Track import block boundaries to avoid false positives from quoted
    // strings in composite literals, map keys, etc.
    if (trimmed === 'import (') {
      inImportBlock = true;
      continue;
    }
    if (inImportBlock && trimmed === ')') {
      inImportBlock = false;
      continue;
    }

    // Quoted path inside an import (...) block
    if (inImportBlock) {
      const importMatch = trimmed.match(/^(?:\w+\s+)?"([^"]+)"/);
      if (importMatch) {
        imports.push({
          path: importMatch[1],
          file: filePath,
          module,
        });
      }
      continue;
    }

    // Single-line import: import "path" or import alias "path"
    const singleImport = trimmed.match(/^import\s+(?:\w+\s+)?"([^"]+)"/);
    if (singleImport) {
      imports.push({
        path: singleImport[1],
        file: filePath,
        module,
      });
    }
  }
}

// =============================================================================
// TREE-SITTER WASM (optional, more accurate)
// =============================================================================

let _parser = null;

async function tryLoadTreeSitter() {
  if (_parser !== null) return _parser !== false;

  try {
    const Parser = await initTreeSitter();
    if (!Parser) { _parser = false; return false; }

    let goWasm;
    try {
      const { getAssetAsBlob } = require('node:sea');
      goWasm = getAssetAsBlob('tree-sitter-go.wasm');
    } catch (_) {
      goWasm = require.resolve('tree-sitter-wasms/out/tree-sitter-go.wasm');
    }

    const GoLang = await Parser.Language.load(goWasm);
    const parser = new Parser();
    parser.setLanguage(GoLang);
    _parser = parser;
    return true;
  } catch (e) {
    warn(`tree-sitter WASM unavailable, using regex for Go: ${e.message}`);
    _parser = false;
    return false;
  }
}

function parseGoTreeSitter(content, filePath, module, totalLines, functions, types, imports, calls) {
  if (!_parser) {
    parseGoRegex(content, filePath, module, totalLines, functions, types, imports);
    return;
  }

  try {
    const tree = _parser.parse(content);
    const root = tree.rootNode;

    let pkg = '__unknown__';
    const pkgNode = root.children.find(n => n.type === 'package_clause');
    if (pkgNode) {
      const pkgName = pkgNode.children.find(n => n.type === 'package_identifier');
      if (pkgName) pkg = pkgName.text;
    }

    // ── Pass 1: functions, types, imports ───────────────────────────────────
    walkNode(root, (node) => {
      switch (node.type) {
        case 'function_declaration':
        case 'method_declaration': {
          const nameNode = node.childForFieldName('name');
          const recvNode = node.childForFieldName('receiver');
          const name = nameNode ? nameNode.text : '__anon__';
          let receiver = null;

          if (recvNode) {
            // receiver: (r *TypeName) → extract TypeName
            const txt = recvNode.text.replace(/^\(|\)$/g, '').trim();
            const m = txt.match(/\*?(\w+)$/);
            if (m) receiver = m[1];
          }

          functions.push({
            name,
            receiver,
            qualified: receiver ? `${receiver}.${name}` : name,
            file: filePath,
            module,
            package: pkg,
            line: node.startPosition.row + 1,
            lines: totalLines,
          });
          break;
        }

        case 'type_declaration': {
          const specs = node.children.filter(n => n.type === 'type_spec');
          for (const spec of specs) {
            const nameNode = spec.childForFieldName('name');
            const typeNode = spec.childForFieldName('type');
            if (!nameNode) continue;

            const isAlias = spec.children.some(n => n.type === '=');
            const kind = isAlias ? 'alias'
                       : !typeNode ? 'type'
                       : typeNode.type === 'struct_type' ? 'struct'
                       : typeNode.type === 'interface_type' ? 'interface'
                       : 'type';

            types.push({
              name: nameNode.text,
              kind,
              file: filePath,
              module,
              package: pkg,
              line: spec.startPosition.row + 1,
            });
          }
          break;
        }

        case 'import_spec': {
          const pathNode = node.childForFieldName('path');
          if (pathNode) {
            imports.push({
              path: pathNode.text.replace(/"/g, ''),
              file: filePath,
              module,
            });
          }
          break;
        }
      }
    });

    // ── Pass 2: call edges (stateful — needs enclosing function context) ────
    const funcStack = [];
    walkNodeEnterLeave(root,
      (node) => {
        if (node.type === 'function_declaration' || node.type === 'method_declaration') {
          const nameNode = node.childForFieldName('name');
          funcStack.push(nameNode ? nameNode.text : '__anon__');
        }
        if (node.type === 'call_expression' && funcStack.length > 0) {
          const enclosing = funcStack[funcStack.length - 1];
          // function field: identifier or selector_expression (obj.Method)
          const funcNode = node.childForFieldName('function') || node.child(0);
          let callee = null;
          // direct: bare identifier (no receiver collapsing). inferred: selector_expression
          // collapses obj.Foo and bar.Foo to "Foo" — same name, different functions.
          let confidence = 'direct';
          if (funcNode) {
            if (funcNode.type === 'identifier') {
              callee = funcNode.text;
            } else if (funcNode.type === 'selector_expression') {
              const field = funcNode.childForFieldName('field');
              if (field) { callee = field.text; confidence = 'inferred'; }
            }
          }
          if (callee && callee !== enclosing) {
            calls.push({
              kind: 'go-call',
              from: enclosing,
              to: callee,
              fromFile: filePath,
              module,
              line: node.startPosition.row + 1,
              resolved: false,
              confidence,
            });
          }
        }
      },
      (node) => {
        if (node.type === 'function_declaration' || node.type === 'method_declaration') {
          funcStack.pop();
        }
      }
    );
  } catch (e) {
    warn(`tree-sitter parse failed for ${filePath}, falling back to regex: ${e.message}`);
    parseGoRegex(content, filePath, module, totalLines, functions, types, imports);
  }
}

function walkNode(node, visitor) {
  const stack = [node];
  while (stack.length > 0) {
    const n = stack.pop();
    visitor(n);
    for (let i = n.childCount - 1; i >= 0; i--) stack.push(n.child(i));
  }
}

module.exports = { buildGoIndex };
