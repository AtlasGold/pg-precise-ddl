#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" == "--patch-catalog" ]]; then
  exec "${SCRIPT_DIR}/../install.sh" --all --patch
fi

exec "${SCRIPT_DIR}/../install.sh" --all --no-patch
