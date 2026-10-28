#!/usr/bin/env bash
# Checks scoped to the paths a sub-agent owns, so other agents' in-progress files don't block it.
# Usage: tools/agent_check.sh [--fix] <owned path>...   e.g. tools/agent_check.sh src/client
set -uo pipefail
cd "$(dirname "$0")/.."
source tools/_setup.sh

fix=0
if [ "${1:-}" = "--fix" ]; then fix=1; shift; fi
if [ $# -eq 0 ]; then echo "usage: tools/agent_check.sh [--fix] <owned paths...>"; exit 2; fi
if [ $fix -eq 1 ]; then stylua "$@"; fi

fail=0
src_paths=()
for p in "$@"; do case "$p" in src/*) src_paths+=("$p");; esac; done

echo "== stylua"; stylua --check "$@" || fail=1
if [ ${#src_paths[@]} -gt 0 ]; then
	echo "== selene"; selene "${src_paths[@]}" || fail=1
	echo "== luau-lsp (errors in owned paths)"
	patterns=()
	for p in "${src_paths[@]}"; do patterns+=(-e "$PWD/$p"); done
	errors=$(luau_analyze src 2>&1 | grep -F "${patterns[@]}" || true)
	if [ -n "$errors" ]; then echo "$errors"; fail=1; else echo "no type errors"; fi
fi
echo "== lune"; lune run tools/test || fail=1
echo "== rojo"; rojo build default.project.json --output "${TMPDIR:-/tmp}/rhd-agent-$$.rbxl" >/dev/null || fail=1

if [ $fail -eq 0 ]; then echo "AGENT CHECKS PASSED"; else echo "AGENT CHECKS FAILED"; exit 1; fi
