'use strict';

const fs = require('fs');
const path = require('path');
const { walkFiles, countLinesFromContent, warn, initTreeSitter, walkNodeEnterLeave } = require('./util');

/**
 * Index Python source files.
 *
 * Primary method: tree-sitter WASM (python grammar, ~98% accurate).
 * Fallback: regex-based extraction (~90% accurate).
 *
 * Extracts:
 * functions — top-level and method definitions
 * classes — class definitions with base classes
 * imports — import statements for cross-file edge detection
 * calls — intra-file function call edges (tree-sitter only)
 *
 * @param {string} repo
 * @param {RegExp[]} excludeRes pre-compiled exclude patterns
 * @param {Map<string,string[]>|null} allFiles pre-collected file map, or null to walk
 */
async function buildPythonIndex(repo, excludeRes = [], allFiles = null) {
  const pyFiles = allFiles
    ? (allFiles.get('.py') || [])
    : walkFiles(repo, ['.py'], excludeRes);

  const functions = [];
  const classes = [];
  const imports = [];
  const calls = [];

  if (pyFiles.length === 0) return { functions, classes, imports, calls };

  const tsAvailable = await tryLoadTreeSitter();

  for (const f of pyFiles) {
    const rel = path.relative(repo, f);
    const parts = rel.split(path.sep);
    const module = parts.length > 1 ? parts[0] : '__root__';

    let content;
    try { content = fs.readFileSync(f).toString('utf8').replace(/\0/g, ''); }
    catch (_) { continue; }

    const lines = countLinesFromContent(content);

    if (tsAvailable) {
      parsePythonTreeSitter(content, rel, module, lines, functions, classes, imports, calls);
    } else {
      parsePythonRegex(content, rel, module, lines, functions, classes, imports);
    }
  }

  return { functions, classes, imports, calls };
}

// =============================================================================
// TREE-SITTER WASM
// =============================================================================

let _parser = null;

async function tryLoadTreeSitter() {
  if (_parser !== null) return _parser !== false;

  try {
    const Parser = await initTreeSitter();
    if (!Parser) { _parser = false; return false; }

    let pyWasm;
    try {
      const { getAssetAsBlob } = require('node:sea');
      pyWasm = getAssetAsBlob('tree-sitter-python.wasm');
    } catch (_) {
      pyWasm = require.resolve('tree-sitter-wasms/out/tree-sitter-python.wasm');
    }

    const PyLang = await Parser.Language.load(pyWasm);
    const parser = new Parser();
    parser.setLanguage(PyLang);
    _parser = parser;
    return true;
  } catch (e) {
    warn(`tree-sitter WASM unavailable for Python, using regex: ${e.message}`);
    _parser = false;
    return false;
  }
}

function parsePythonTreeSitter(content, filePath, module, totalLines, functions, classes, imports, calls) {
  try {
    const tree = _parser.parse(content);
    const root = tree.rootNode;

    const funcStack = []; // stack of enclosing function names
    const classStack = []; // stack of enclosing class names

    walkNodeEnterLeave(root,
      // enter
      (node) => {
        switch (node.type) {
          case 'function_definition': {
            const nameNode = node.childForFieldName('name');
            const name = nameNode ? nameNode.text : '__anon__';
            const cls = classStack.length > 0 ? classStack[classStack.length - 1] : null;
            functions.push({
              name,
              receiver: cls,
              file: filePath,
              module,
              line: node.startPosition.row + 1,
              lines: totalLines,
            });
            funcStack.push(name);
            break;
          }

          case 'class_definition': {
            const nameNode = node.childForFieldName('name');
            const name = nameNode ? nameNode.text : '__anon__';
            // Extract base classes from argument_list
            const argsNode = node.childForFieldName('superclasses') ||
                              node.children.find(c => c.type === 'argument_list');
            const bases = [];
            if (argsNode) {
              for (const child of argsNode.children) {
                if (child.type === 'identifier' || child.type === 'attribute') {
                  bases.push(child.text);
                }
              }
            }
            classes.push({
              name, bases, file: filePath, module,
              line: node.startPosition.row + 1,
            });
            classStack.push(name);
            break;
          }

          case 'import_statement': {
            // import foo, import foo.bar
            for (const child of node.children) {
              if (child.type === 'dotted_name' || child.type === 'identifier') {
                imports.push({ path: child.text, file: filePath, module });
              }
            }
            break;
          }

          case 'import_from_statement': {
            // from foo.bar import baz
            const modNode = node.childForFieldName('module_name') ||
                            node.children.find(c => c.type === 'dotted_name' || c.type === 'relative_import');
            if (modNode) {
              imports.push({ path: modNode.text, file: filePath, module });
            }
            break;
          }

          case 'call': {
            // Python uses 'call' not 'call_expression'
            const enclosing = funcStack.length > 0 ? funcStack[funcStack.length - 1] : null;
            if (!enclosing) break;
            const funcNode = node.childForFieldName('function') || node.child(0);
            let callee = null;
            // direct: bare identifier. inferred: attribute access collapses obj.foo() to "foo".
            let confidence = 'direct';
            if (funcNode) {
              if (funcNode.type === 'identifier') {
                callee = funcNode.text;
              } else if (funcNode.type === 'attribute') {
                const attr = funcNode.childForFieldName('attribute');
                if (attr) { callee = attr.text; confidence = 'inferred'; }
              }
            }
            if (callee && callee !== enclosing && callee !== 'self' && callee !== 'super') {
              calls.push({
                kind: 'py-call',
                from: enclosing,
                to: callee,
                fromFile: filePath,
                module,
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
        if (node.type === 'function_definition') funcStack.pop();
        if (node.type === 'class_definition') classStack.pop();
      }
    );
  } catch (e) {
    warn(`tree-sitter parse failed for ${filePath}, falling back to regex: ${e.message}`);
    parsePythonRegex(content, filePath, module, totalLines, functions, classes, imports);
  }
}

// =============================================================================
// REGEX FALLBACK
// =============================================================================

function parsePythonRegex(content, filePath, module, totalLines, functions, classes, imports) {
  const lines = content.split('\n');

  // Stack-based class tracking: each entry is { name, indent }
  const classStack = [];

  const getCurrentClass = (lineIndent) => {
    while (classStack.length > 0 && lineIndent <= classStack[classStack.length - 1].indent) {
      classStack.pop();
    }
    return classStack.length > 0 ? classStack[classStack.length - 1].name : null;
  };

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trim();

    if (trimmed.startsWith('#') || trimmed === '') continue;

    const currentIndent = line.length - line.trimStart().length;

    const importMatch = trimmed.match(/^import\s+([\w.]+)/);
    if (importMatch) {
      imports.push({ path: importMatch[1], file: filePath, module });
      continue;
    }

    const fromImportMatch = trimmed.match(/^from\s+([\w.]+)\s+import/);
    if (fromImportMatch) {
      imports.push({ path: fromImportMatch[1], file: filePath, module });
      continue;
    }

    const classMatch = trimmed.match(/^class\s+(\w+)\s*(?:\(([^)]*)\))?\s*:/);
    if (classMatch) {
      getCurrentClass(currentIndent);
      classStack.push({ name: classMatch[1], indent: currentIndent });
      classes.push({
        name: classMatch[1],
        bases: classMatch[2] ? classMatch[2].split(',').map(b => b.trim()) : [],
        file: filePath,
        module,
        line: i + 1,
      });
      continue;
    }

    const funcMatch = trimmed.match(/^def\s+(\w+)\s*\(/);
    if (funcMatch) {
      const currentClass = getCurrentClass(currentIndent);
      const isMethod = currentIndent > 0 && currentClass !== null;
      functions.push({
        name: funcMatch[1],
        receiver: isMethod ? currentClass : null,
        file: filePath,
        module,
        line: i + 1,
        lines: totalLines,
      });
    }
  }
}

module.exports = { buildPythonIndex };
