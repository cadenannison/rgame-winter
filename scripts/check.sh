#!/usr/bin/env bash
# Quality gates. Tier: light | standard | full (KIT_TIER overrides .kit-tier).
set -euo pipefail
export PATH="$HOME/.rokit/bin:$PATH"
cd "$(dirname "$0")/.."
mkdir -p Packages ServerPackages build
TIER="${KIT_TIER:-$(tr -d '[:space:]' < .kit-tier)}"
DEFS_URL="https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.None.d.luau"
DEFS=".luau-types/globalTypes.None.d.luau"

case "$TIER" in light | standard | full) ;; *)
	echo "FAIL tier: unknown tier '$TIER'" >&2
	exit 2
	;;
esac

gate() {
	local name="$1"
	shift
	if "$@"; then
		echo "PASS $name"
	else
		echo "FAIL $name" >&2
		exit 1
	fi
}

gate stylua stylua --check src tests
gate selene selene src tests

if [ "$TIER" != "light" ]; then
	# Fresh clone: install Wally packages once (no-op when already installed).
	if [ ! -d ServerPackages/_Index ] && [ ! -d Packages/_Index ]; then
		gate wally-install wally install
		mkdir -p Packages ServerPackages
	fi
	gate sourcemap rojo sourcemap default.project.json -o sourcemap.json
	if [ ! -f "$DEFS" ]; then
		mkdir -p .luau-types
		curl -fsSL "$DEFS_URL" -o "$DEFS"
	fi
	gate luau-analyze luau-lsp analyze --definitions="$DEFS" --sourcemap=sourcemap.json src tests
	gate rojo-build rojo build default.project.json -o build/game.rbxl
fi

if [ "$TIER" = "full" ]; then
	gate tests lune run tests/run
fi

echo "OK tier=$TIER"
