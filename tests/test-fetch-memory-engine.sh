#!/usr/bin/env bash
# Test suite for scripts/fetch-memory-engine.sh verification behavior.
#
# What this tests:
# - A checksum MISMATCH is always fatal (default and strict)
# - A MISSING checksums.txt warns and installs by default
# - DRAFT_STRICT_VERIFY=1 turns that warning into a hard failure
# - A matching checksum installs an executable binary
# - The pinned version is a concrete tag, not a floating ref
# - bin/README.md documents the trust story it promises
#
# Why: the graph engine is a third-party binary and Draft's core
# differentiator. "SHA-256 verified" is only true when the release publishes a
# checksums file; the strict switch is what makes that guarantee absolute for
# anyone who needs to attest to what runs on their machine.
#
# Runs against a throwaway local HTTPS server (self-signed cert pinned via
# CURL_CA_BUNDLE) rather than file://, because the script's HTTPS-only guard is
# itself a control worth keeping — the test adapts to it instead of relaxing it.
# No outbound network.
#
# Usage:
#   ./tests/test-fetch-memory-engine.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
FETCH="$ROOT_DIR/scripts/fetch-memory-engine.sh"

source "$SCRIPT_DIR/test-helpers.sh"
cd "$ROOT_DIR"

echo "=== fetch-memory-engine verification tests ==="
echo ""

assert "script is executable" "$([[ -x "$FETCH" ]] && echo true || echo false)"
assert "script parses" "$(bash -n "$FETCH" 2>/dev/null && echo true || echo false)"

echo "## Version pinning"
pinned="$(grep -E '^DEFAULT_VERSION=' "$FETCH" | head -1 | sed 's/.*="\([^"]*\)".*/\1/')"
assert "DEFAULT_VERSION is a concrete v-tag ($pinned)" \
    "$([[ "$pinned" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] && echo true || echo false)"
assert "DEFAULT_VERSION is not 'latest'" \
    "$([[ "$pinned" != "latest" ]] && echo true || echo false)"

echo ""
echo "## HTTPS-only download guard"
set +e
CMM_DOWNLOAD_URL="http://127.0.0.1:1/nope" "$FETCH" --dest "$(mktemp -d)" --force >/dev/null 2>&1
plain_rc=$?
CMM_DOWNLOAD_URL="file:///tmp" "$FETCH" --dest "$(mktemp -d)" --force >/dev/null 2>&1
file_rc=$?
set -e
assert "plain http:// base URL refused (exit $plain_rc)" \
    "$([[ "$plain_rc" -eq 2 ]] && echo true || echo false)"
assert "file:// base URL refused (exit $file_rc)" \
    "$([[ "$file_rc" -eq 2 ]] && echo true || echo false)"

for dep in curl openssl python3; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo "## $dep unavailable — skipping fetch behavior tests"
        finish_test "fetch-memory-engine"
    fi
done

tmp="$(mktemp -d)"
server_pid=""
cleanup() {
    [[ -n "$server_pid" ]] && kill "$server_pid" 2>/dev/null
    rm -rf "$tmp"
}
trap cleanup EXIT
rel="$tmp/release"
mkdir -p "$rel" "$tmp/stage" "$tmp/tls"

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$(uname -m)" in
    x86_64|amd64) arch=amd64 ;;
    arm64|aarch64) arch=arm64 ;;
    *) arch="$(uname -m)" ;;
esac
archive="codebase-memory-mcp-${os}-${arch}-portable.tar.gz"

printf '#!/bin/sh\necho "codebase-memory-mcp 0.0.0-test"\n' > "$tmp/stage/codebase-memory-mcp"
chmod +x "$tmp/stage/codebase-memory-mcp"
tar -czf "$rel/$archive" -C "$tmp/stage" codebase-memory-mcp

if command -v sha256sum >/dev/null 2>&1; then
    real_sum="$(sha256sum "$rel/$archive" | awk '{print $1}')"
else
    real_sum="$(shasum -a 256 "$rel/$archive" | awk '{print $1}')"
fi

# Self-signed cert, pinned for curl via CURL_CA_BUNDLE — real TLS validation
# against a CA we control, not disabled verification.
openssl req -x509 -newkey rsa:2048 -keyout "$tmp/tls/key.pem" -out "$tmp/tls/cert.pem" \
    -days 1 -nodes -subj "/CN=localhost" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" >/dev/null 2>&1

cat > "$tmp/serve.py" <<'PY'
import http.server, os, ssl, sys
os.chdir(sys.argv[1])
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(sys.argv[2], sys.argv[3])
httpd = http.server.HTTPServer(("127.0.0.1", 0), http.server.SimpleHTTPRequestHandler)
httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)
print(httpd.server_address[1], flush=True)
httpd.serve_forever()
PY

python3 "$tmp/serve.py" "$rel" "$tmp/tls/cert.pem" "$tmp/tls/key.pem" > "$tmp/port.txt" 2>"$tmp/server.log" &
server_pid=$!

port=""
for _ in $(seq 1 40); do
    port="$(head -n 1 "$tmp/port.txt" 2>/dev/null || true)"
    [[ "$port" =~ ^[0-9]+$ ]] && break
    sleep 0.25
done

if [[ ! "$port" =~ ^[0-9]+$ ]]; then
    assert "local HTTPS release server started" "false"
    finish_test "fetch-memory-engine"
fi
assert "local HTTPS release server started (port $port)" "true"

run_fetch() {  # run_fetch <dest-suffix> [env assignments...]
    local suffix="$1"; shift
    rm -rf "$tmp/dest-$suffix"
    set +e
    env "$@" CMM_DOWNLOAD_URL="https://localhost:$port" CURL_CA_BUNDLE="$tmp/tls/cert.pem" \
        "$FETCH" --dest "$tmp/dest-$suffix" --force >"$tmp/$suffix.log" 2>&1
    local rc=$?
    set -e
    printf '%s' "$rc"
}

echo ""
echo "## No checksums.txt published"
rc="$(run_fetch nosum)"
assert "default install succeeds without a checksum (exit $rc)" \
    "$([[ "$rc" -eq 0 ]] && echo true || echo false)"
assert "and warns that verification was skipped" \
    "$(grep -qi 'skipping verification' "$tmp/nosum.log" && echo true || echo false)"
assert "warning points at the strict switch" \
    "$(grep -q 'DRAFT_STRICT_VERIFY=1' "$tmp/nosum.log" && echo true || echo false)"
assert "binary installed and executable" \
    "$([[ -x "$tmp/dest-nosum/codebase-memory-mcp" ]] && echo true || echo false)"

rc="$(run_fetch strictnosum DRAFT_STRICT_VERIFY=1)"
assert "DRAFT_STRICT_VERIFY=1 refuses it (exit $rc)" \
    "$([[ "$rc" -eq 2 ]] && echo true || echo false)"
assert "strict refusal names the reason" \
    "$(grep -qi 'refuses unverified binaries' "$tmp/strictnosum.log" && echo true || echo false)"
assert "strict mode installs nothing" \
    "$([[ ! -e "$tmp/dest-strictnosum/codebase-memory-mcp" ]] && echo true || echo false)"

echo ""
echo "## Archive absent from checksums.txt"
printf '%s  some-other-archive.tar.gz\n' "$real_sum" > "$rel/checksums.txt"
rc="$(run_fetch unlisted)"
assert "default installs with a warning (exit $rc)" \
    "$([[ "$rc" -eq 0 ]] && echo true || echo false)"
assert "warning names the unlisted archive" \
    "$(grep -q 'not listed in checksums.txt' "$tmp/unlisted.log" && echo true || echo false)"
rc="$(run_fetch strictunlisted DRAFT_STRICT_VERIFY=1)"
assert "strict refuses an unlisted archive (exit $rc)" \
    "$([[ "$rc" -eq 2 ]] && echo true || echo false)"

echo ""
echo "## Checksum mismatch is always fatal"
printf '%s  %s\n' "0000000000000000000000000000000000000000000000000000000000000000" "$archive" > "$rel/checksums.txt"
rc="$(run_fetch mismatch)"
assert "default mode rejects a mismatch (exit $rc)" \
    "$([[ "$rc" -eq 2 ]] && echo true || echo false)"
assert "mismatch message is explicit" \
    "$(grep -q 'checksum mismatch' "$tmp/mismatch.log" && echo true || echo false)"
assert "nothing installed on mismatch" \
    "$([[ ! -e "$tmp/dest-mismatch/codebase-memory-mcp" ]] && echo true || echo false)"
rc="$(run_fetch strictmismatch DRAFT_STRICT_VERIFY=1)"
assert "strict mode also rejects a mismatch (exit $rc)" \
    "$([[ "$rc" -eq 2 ]] && echo true || echo false)"

echo ""
echo "## Matching checksum installs"
printf '%s  %s\n' "$real_sum" "$archive" > "$rel/checksums.txt"
rc="$(run_fetch ok)"
assert "valid checksum installs (exit $rc)" \
    "$([[ "$rc" -eq 0 ]] && echo true || echo false)"
assert "reports checksum OK" \
    "$(grep -q 'checksum OK' "$tmp/ok.log" && echo true || echo false)"
assert "installed binary is executable" \
    "$([[ -x "$tmp/dest-ok/codebase-memory-mcp" ]] && echo true || echo false)"
rc="$(run_fetch strictok DRAFT_STRICT_VERIFY=1)"
assert "strict mode accepts a verified archive (exit $rc)" \
    "$([[ "$rc" -eq 0 ]] && echo true || echo false)"

echo ""
echo "## Trust story is documented"
DOC="$ROOT_DIR/bin/README.md"
assert "bin/README.md has a Trust story section" \
    "$(grep -q '^## Trust story' "$DOC" && echo true || echo false)"
assert "documents DRAFT_STRICT_VERIFY" \
    "$(grep -q 'DRAFT_STRICT_VERIFY' "$DOC" && echo true || echo false)"
assert "states there is no signing / provenance" \
    "$(grep -qi 'no code signing or SLSA provenance' "$DOC" && echo true || echo false)"
assert "documents the opt-out path" \
    "$(grep -q 'DRAFT_MEMORY_DISABLE' "$DOC" && echo true || echo false)"
assert "documents a stall contingency" \
    "$(grep -qi 'Contingency if the upstream project stalls' "$DOC" && echo true || echo false)"
assert "contingency names the coupling surface" \
    "$(grep -q 'memory_cli' "$DOC" && echo true || echo false)"
assert "memory_cli still exists (contingency is not stale)" \
    "$(grep -q 'memory_cli' "$ROOT_DIR/scripts/tools/_lib.sh" && echo true || echo false)"

finish_test "fetch-memory-engine"
