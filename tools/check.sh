#!/usr/bin/env bash
# Runs the same checks as CI. Usage: tools/check.sh [--fix]
set -euo pipefail
cd "$(dirname "$0")/.."

DEFS_VERSION="1.70.1"
DEFS=".cache/globalTypes.d.luau"

if [ ! -f "$DEFS" ]; then
	mkdir -p .cache
	curl -sSfL "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/${DEFS_VERSION}/scripts/globalTypes.None.d.luau" -o "$DEFS"
fi

# Packages are (re)installed once and then typed; the marker avoids re-running wally-package-types.
if [ ! -f Packages/.typed ] || [ wally.toml -nt Packages/.typed ]; then
	wally install >/dev/null
	rojo sourcemap default.project.json --output sourcemap.json --include-non-scripts >/dev/null
	wally-package-types --sourcemap sourcemap.json Packages/ >/dev/null
	touch Packages/.typed
fi
rojo sourcemap default.project.json --output sourcemap.json --include-non-scripts >/dev/null

if [ "${1:-}" = "--fix" ]; then stylua src tests tools; fi

echo "== stylua";   stylua --check src tests tools
echo "== selene";   selene src
echo "== luau-lsp"; luau-lsp analyze --definitions=@roblox="$DEFS" --sourcemap=sourcemap.json \
	--base-luaurc=.luaurc --ignore="Packages/**" --ignore="vendor/**" src
echo "== lune";     lune run tools/test
echo "== rojo";     rojo build default.project.json --output place.rbxl
echo "ALL CHECKS PASSED"
