#!/usr/bin/env bash
# Hygiene/verification tool stub (Foundations phase)
set -euo pipefail
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "${0##*/} — Foundations stub (see manifest §2.2)"
    exit 0
fi
echo "${0##*/}: stub — no violations (full impl in later phase)"
exit 0
