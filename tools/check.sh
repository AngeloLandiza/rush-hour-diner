#!/usr/bin/env bash
# Runs the same checks as CI. Usage: tools/check.sh [--fix]
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/_setup.sh

if [ "${1:-}" = "--fix" ]; then stylua src tests tools; fi

echo "== stylua";   stylua --check src tests tools
echo "== selene";   selene src
echo "== luau-lsp"; luau_analyze src
echo "== lune";     lune run tools/test
echo "== rojo";     rojo build default.project.json --output place.rbxl
echo "ALL CHECKS PASSED"
