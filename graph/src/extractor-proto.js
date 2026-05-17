'use strict';

const fs = require('fs');
const path = require('path');
const { walkFiles } = require('./util');

/**
 * Parse all .proto files and extract:
 * services — gRPC service definitions
 * rpcs — individual RPC methods with request/response types
 * messages — message type definitions
 *
 * Pure line-by-line parsing, no proto compiler needed.
 * Handles single-line and multi-line rpc definitions.
 *
 * @param {string} repo
 * @param {RegExp[]} excludeRes pre-compiled exclude patterns
 * @param {Map<string,string[]>|null} allFiles pre-collected file map, or null to walk
 */
function buildProtoIndex(repo, excludeRes = [], allFiles = null) {
  const protoFiles = allFiles
    ? (allFiles.get('.proto') || [])
    : walkFiles(repo, ['.proto'], excludeRes);

  const services = [];
  const rpcs = [];
  const messages = [];
  const enums = [];

  for (const f of protoFiles) {
    const rel = path.relative(repo, f);
    const parts = rel.split(path.sep);
    const module = parts.length > 1 ? parts[0] : '__root__';

    let content;
    try { content = fs.readFileSync(f).toString('utf8').replace(/\0/g, ''); }
    catch (_) { continue; }

    parseProtoFile(content, rel, module, services, rpcs, messages, enums);
  }

  return { services, rpcs, messages, enums };
}

// =============================================================================
// PROTO PARSER
// =============================================================================

function parseProtoFile(content, filePath, module, services, rpcs, messages, enums) {
  const lines = content.split('\n');
  let currentService = null;
  let blockDepth = 0;
  let inService = false;
  let rpcBuffer = ''; // accumulate multi-line rpc declarations

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trim();

    // Skip comments
    if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;

    // Track brace depth for block detection.
    // Strip option blocks [...] and string literals "..." first so that
    // braces inside field annotations / option values don't corrupt the count.
    const strippedLine = line
      .replace(/\[[^\]]*\]/g, '') // remove [...] option blocks
      .replace(/"(?:[^"\\]|\\.)*"/g, '""'); // collapse string literals
    const opens = (strippedLine.match(/{/g) || []).length;
    const closes = (strippedLine.match(/}/g) || []).length;

    // ── Service definition ──────────────────────────────────────────────────
    const svcMatch = trimmed.match(/^service\s+(\w+)/);
    if (svcMatch) {
      currentService = svcMatch[1];
      inService = true;
      blockDepth = 1; // opening '{' on the service line counts as depth 1
      services.push({
        name: currentService,
        file: filePath,
        module,
        line: i + 1,
      });
    }

    // ── Message definition ──────────────────────────────────────────────────
    const msgMatch = trimmed.match(/^message\s+(\w+)/);
    if (msgMatch) {
      messages.push({
        name: msgMatch[1],
        file: filePath,
        module,
        line: i + 1,
      });
    }

    // ── Enum definition ────────────────────────────────────────────────────
    const enumMatch = trimmed.match(/^enum\s+(\w+)/);
    if (enumMatch) {
      enums.push({
        name: enumMatch[1],
        file: filePath,
        module,
        line: i + 1,
      });
    }

    // ── RPC definition (may span multiple lines) ────────────────────────────
    if (inService) {
      if (trimmed.startsWith('rpc ') || rpcBuffer) {
        rpcBuffer += ' ' + trimmed;

        // Check if we have a complete rpc declaration
        // Forms:
        // rpc Foo (Bar) returns (Baz);
        // rpc Foo (stream Bar) returns (stream Baz) {}
        const rpcMatch = rpcBuffer.match(
          /rpc\s+(\w+)\s*\(\s*(?:stream\s+)?([\w.]+)\s*\)\s*returns\s*\(\s*(?:stream\s+)?([\w.]+)\s*\)/i
        );

        if (rpcMatch) {
          // Detect whether stream keyword was present in each position
          const streamReqRe = /rpc\s+\w+\s*\(\s*stream\s+[\w.]+\s*\)/i;
          const streamRespRe = /returns\s*\(\s*stream\s+[\w.]+\s*\)/i;
          rpcs.push({
            name: rpcMatch[1],
            request: rpcMatch[2],
            response: rpcMatch[3],
            streaming_request: streamReqRe.test(rpcBuffer),
            streaming_response: streamRespRe.test(rpcBuffer),
            service: currentService,
            file: filePath,
            module,
            line: i + 1,
          });
          rpcBuffer = '';
        } else if (rpcBuffer.length > 500) {
          // Safety: abandon runaway buffer
          rpcBuffer = '';
        }
      }
    }

    // Track brace depth to know when service block ends
    blockDepth += opens - closes;
    if (inService && blockDepth <= 0) {
      inService = false;
      currentService = null;
      blockDepth = 0;
      rpcBuffer = '';
    }
  }
}

module.exports = { buildProtoIndex };
