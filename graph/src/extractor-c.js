'use strict';

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const { walkFiles, countLinesFromContent, warn, initTreeSitter,
        walkNodeEnterLeave, C_CPP_EXTS_LIST, detectUniversalCtags } = require('./util');

const C_EXTS = new Set(['.c', '.h']);
const CPP_EXTS = new Set(['.cc', '.cpp', '.cxx', '.hpp', '.hxx', '.h++']);

/**
 * Index C and C++ source files for symbol extraction.
 *
 * This extractor supplements (does NOT replace) the include-graph extractor.
 * The include graph remains the primary C++ structural signal.
 *
 * Primary method: tree-sitter WASM (c + cpp grammars).
 * Fallback: universal-ctags shell-out (if available).
 * Final fallback: skip silently — include graph still provides value.
 *
 * Extracts:
 * functions — function definitions (declarations skipped — too noisy in headers)
 * types — struct, class (C++), enum definitions
 * calls — intra-file function call edges (tree-sitter only)
 *
 * @param {string} repo
 * @param {RegExp[]} excludeRes pre-compiled exclude patterns
 * @param {Map<string,string[]>|null} allFiles pre-collected file map, or null to walk
 */
async function buildCIndex(repo, excludeRes = [], allFiles = null) {
  const cFiles = allFiles
    ? C_CPP_EXTS_LIST.flatMap(ext => allFiles.get(ext) || [])
    : walkFiles(repo, C_CPP_EXTS_LIST, excludeRes);

  const functions = [];
  const types = [];
  const calls = [];

  if (cFiles.length === 0) return { functions, types, calls };

  await tryLoadParsers();

  // ctags is checked unconditionally: it serves as fallback for files whose
  // specific grammar (c or cpp) failed to load, not only when both fail.
  const ctagsBin = detectUniversalCtags();

  for (const f of cFiles) {
    const rel = path.relative(repo, f);
    const parts = rel.split(path.sep);
    const module = parts.length > 1 ? parts[0] : '__root__';
    const ext = path.extname(f).toLowerCase();

    let content;
    try { content = fs.readFileSync(f).toString('utf8').replace(/\0/g, ''); }
    catch (_) { continue; }

    const totalLines = countLinesFromContent(content);
    const isCpp = CPP_EXTS.has(ext) || (ext === '.h' && content.includes('class '));

    if (isCpp && _parsers.cpp) {
      parseCTreeSitter(content, rel, module, totalLines, functions, types, calls, _parsers.cpp, 'cpp');
    } else if (!isCpp && _parsers.c) {
      // Use the C parser only for C files; avoid silently applying C grammar to C++ syntax
      parseCTreeSitter(content, rel, module, totalLines, functions, types, calls, _parsers.c, 'c');
    } else if (ctagsBin) {
      parseCCtags(ctagsBin, f, rel, module, totalLines, functions, types);
    }
    // else: silently skip — include graph still provides structural value
  }

  return { functions, types, calls };
}

// =============================================================================
// TREE-SITTER WASM
// =============================================================================

const _parsers = { c: null, cpp: null, attempted: false };

async function tryLoadParsers() {
  if (_parsers.attempted) return;
  _parsers.attempted = true;

  const Parser = await initTreeSitter();
  if (!Parser) return;

  // Load C grammar
  try {
    let wasm;
    try {
      const { getAssetAsBlob } = require('node:sea');
      wasm = getAssetAsBlob('tree-sitter-c.wasm');
    } catch (_) {
      wasm = require.resolve('tree-sitter-wasms/out/tree-sitter-c.wasm');
    }
    const lang = await Parser.Language.load(wasm);
    const p = new Parser();
    p.setLanguage(lang);
    _parsers.c = p;
  } catch (e) {
    warn(`tree-sitter C grammar unavailable: ${e.message}`);
  }

  // Load C++ grammar
  try {
    let wasm;
    try {
      const { getAssetAsBlob } = require('node:sea');
      wasm = getAssetAsBlob('tree-sitter-cpp.wasm');
    } catch (_) {
      wasm = require.resolve('tree-sitter-wasms/out/tree-sitter-cpp.wasm');
    }
    const lang = await Parser.Language.load(wasm);
    const p = new Parser();
    p.setLanguage(lang);
    _parsers.cpp = p;
  } catch (e) {
    warn(`tree-sitter C++ grammar unavailable: ${e.message}`);
  }
}

function parseCTreeSitter(content, filePath, module, totalLines, functions, types, calls, parser, language) {
  try {
    const tree = parser.parse(content);
    const root = tree.rootNode;

    const funcStack = []; // stack of enclosing function names
    const nsStack = []; // namespace stack for nested C++ namespaces

    walkNodeEnterLeave(root,
      // enter
      (node) => {
        switch (node.type) {
          case 'namespace_definition': {
            // namespace foo { ... } — push onto stack to handle nesting
            const nameNode = node.childForFieldName('name');
            nsStack.push(nameNode ? nameNode.text : null);
            break;
          }

          case 'function_definition': {
            const name = extractFuncName(node);
            if (name) {
              functions.push({
                name, file: filePath, module,
                line: node.startPosition.row + 1,
                lines: totalLines,
                language,
                namespace: nsStack.length > 0 ? nsStack[nsStack.length - 1] : null,
              });
              funcStack.push(name);
            }
            break;
          }

          case 'struct_specifier': {
            const nameNode = node.childForFieldName('name');
            if (nameNode && node.childForFieldName('body')) { // only definitions, not usages
              types.push({
                name: nameNode.text,
                file: filePath, module,
                line: node.startPosition.row + 1,
                kind: 'struct',
                language,
              });
            }
            break;
          }

          case 'class_specifier': { // C++ only
            const nameNode = node.childForFieldName('name');
            if (nameNode && node.childForFieldName('body')) {
              types.push({
                name: nameNode.text,
                file: filePath, module,
                line: node.startPosition.row + 1,
                kind: 'class',
                language,
              });
            }
            break;
          }

          case 'enum_specifier': {
            const nameNode = node.childForFieldName('name');
            if (nameNode && node.childForFieldName('body')) {
              types.push({
                name: nameNode.text,
                file: filePath, module,
                line: node.startPosition.row + 1,
                kind: 'enum',
                language,
              });
            }
            break;
          }

          case 'call_expression': {
            const enclosing = funcStack.length > 0 ? funcStack[funcStack.length - 1] : null;
            if (!enclosing) break;
            const funcNode = node.child(0);
            let callee = null;
            // direct: bare identifier or fully-qualified call. inferred: field_expression
            // collapses obj.foo() / ptr->foo() to "foo" — same name, different functions.
            let confidence = 'direct';
            if (funcNode) {
              if (funcNode.type === 'identifier') {
                callee = funcNode.text;
              } else if (funcNode.type === 'field_expression') {
                const field = funcNode.childForFieldName('field');
                if (field) { callee = field.text; confidence = 'inferred'; }
              } else if (funcNode.type === 'qualified_identifier') {
                // Foo::bar → use 'bar' (qualified, so direct)
                const last = funcNode.children[funcNode.childCount - 1];
                if (last) callee = last.text;
              }
            }
            if (callee && callee !== enclosing) {
              calls.push({
                kind: 'c-call', from: enclosing, to: callee,
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
        if (node.type === 'function_definition') funcStack.pop();
        if (node.type === 'namespace_definition') nsStack.pop();
      }
    );
  } catch (e) {
    warn(`tree-sitter C/C++ parse failed for ${filePath}: ${e.message}`);
  }
}

/**
 * Extract function name from a function_definition node.
 * Handles: int foo(), int* foo(), void Foo::bar(), template<> void foo()
 */
function extractFuncName(funcDefNode) {
  const declaratorNode = funcDefNode.childForFieldName('declarator');
  if (!declaratorNode) return null;
  return extractNameFromDeclarator(declaratorNode);
}

function extractNameFromDeclarator(node) {
  if (!node) return null;
  switch (node.type) {
    case 'function_declarator': {
      const inner = node.childForFieldName('declarator');
      return extractNameFromDeclarator(inner);
    }
    case 'pointer_declarator':
    case 'reference_declarator':
    case 'abstract_pointer_declarator': {
      // int* foo() → pointer_declarator → function_declarator
      for (let i = 0; i < node.childCount; i++) {
        const result = extractNameFromDeclarator(node.child(i));
        if (result) return result;
      }
      return null;
    }
    case 'identifier':
    case 'field_identifier':
      return node.text;
    case 'qualified_identifier': {
      // Foo::bar → last component
      const last = node.children[node.childCount - 1];
      return last ? last.text : null;
    }
    case 'destructor_name': // ~Foo
      return node.text;
    case 'operator_name': // operator==
      return node.text;
    default:
      return null;
  }
}

// =============================================================================
// CTAGS FALLBACK
// =============================================================================

function parseCCtags(ctagsBin, filePath, relPath, module, totalLines, functions, types) {
  if (!ctagsBin) return;
  try {
    // Use spawnSync with arg array to avoid shell injection via file paths
    const result = spawnSync(ctagsBin, ['--output-format=json', '--fields=+n', '-f', '-', filePath],
      { encoding: 'utf8', timeout: 10000, maxBuffer: 2 * 1024 * 1024 });
    if (result.error) throw result.error;
    const output = result.stdout || '';
    for (const line of output.split('\n')) {
      if (!line.trim() || line.startsWith('!_')) continue;
      try {
        const tag = JSON.parse(line);
        if (tag.kind === 'function' || tag.kind === 'f') {
          functions.push({
            name: tag.name, file: relPath, module,
            line: tag.line || 1, lines: totalLines,
            language: tag.language ? tag.language.toLowerCase() : 'c',
            namespace: tag.scope || null,
          });
        } else if (tag.kind === 'struct' || tag.kind === 's' || tag.kind === 'class' || tag.kind === 'c' || tag.kind === 'enum' || tag.kind === 'g') {
          types.push({
            name: tag.name, file: relPath, module,
            line: tag.line || 1,
            kind: tag.kind === 'class' || tag.kind === 'c' ? 'class'
                : tag.kind === 'enum' || tag.kind === 'g' ? 'enum' : 'struct',
            language: tag.language ? tag.language.toLowerCase() : 'c',
          });
        }
      } catch (_) {}
    }
  } catch (_) {
    // ctags failed for this file — skip silently
  }
}

module.exports = { buildCIndex };
