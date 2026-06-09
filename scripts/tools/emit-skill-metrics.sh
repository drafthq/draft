#!/usr/bin/env bash
# emit-skill-metrics.sh — Append a NDJSON metrics record to ~/.draft/metrics.jsonl
#
# Usage: emit-skill-metrics.sh <json-payload>
# json-payload: a JSON object string (must be valid JSON, single line)
#
# Exit codes: always 0 (silent on all errors — never break the calling skill)
# Concurrency: uses flock on the metrics file to prevent interleaved writes

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: emit-skill-metrics.sh '<json-payload>'

Appends a single NDJSON record to ~/.draft/metrics.jsonl with an injected
"ts" field (ISO-8601 UTC). Concurrency-safe via flock. Silent on all errors —
never fails the calling skill. Rotates the metrics file to the last 1000 lines
when it exceeds 10MB.

Example:
  emit-skill-metrics.sh '{"skill":"review","verdict":"approve"}'

Resolution (when invoked by a skill):
  1. $DRAFT_PLUGIN_ROOT/scripts/tools/emit-skill-metrics.sh
  2. $HOME/.claude/plugins/draft/scripts/tools/emit-skill-metrics.sh
  3. $PWD/scripts/tools/emit-skill-metrics.sh

Self-test: /draft:draft metrics-check
EOF
  exit 0
fi

METRICS_DIR="${HOME}/.draft"
METRICS_FILE="${METRICS_DIR}/metrics.jsonl"
LOCK_FILE="${METRICS_DIR}/metrics.lock"

payload="${1:-}"

# Validate that a payload was provided
if [[ -z "${payload}" ]]; then
  exit 0
fi

# Ensure the metrics directory exists (silent — never fail the caller)
mkdir -p "${METRICS_DIR}" 2>/dev/null || exit 0

# Append ISO timestamp to the payload and write under an exclusive lock
# flock -x -w 2: acquire exclusive lock, wait up to 2 seconds, then give up
(
  flock -x -w 2 200 2>/dev/null || exit 0

  # Inject timestamp into the payload using sed (avoids requiring jq)
  # Assumes payload ends with '}' — insert timestamp field before closing brace
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")"
  record="${payload%\}},\"ts\":\"${ts}\"}"
  echo "${record}" >> "${METRICS_FILE}" 2>/dev/null || true

  # Rotate when file exceeds 10MB: keep last 1000 lines.
  # Cheap size check via `wc -c`; only invoke rotation when triggered.
  if [[ -f "${METRICS_FILE}" ]]; then
    size_bytes=$(wc -c < "${METRICS_FILE}" 2>/dev/null || echo 0)
    if [[ "${size_bytes}" -gt 10485760 ]]; then
      tail -n 1000 "${METRICS_FILE}" > "${METRICS_FILE}.tmp" 2>/dev/null \
        && mv -f "${METRICS_FILE}.tmp" "${METRICS_FILE}" 2>/dev/null \
        || rm -f "${METRICS_FILE}.tmp" 2>/dev/null
    fi
  fi

) 200>"${LOCK_FILE}" 2>/dev/null || true

