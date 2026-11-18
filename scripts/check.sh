#!/usr/bin/env bash
# Quality gates. Tier: light | standard | full (KIT_TIER overrides .kit-tier).
# Quiet by default: one summary line, or on failure the first 30 lines of the failing gate.
# Full output always goes to .logs/check.log. --verbose (or CHECK_VERBOSE=1) prints everything.
set -euo pipefail
export PATH="$HOME/.rokit/bin:$PATH"
cd "$(dirname "$0")/.."
VERBOSE="${CHECK_VERBOSE:-0}"
[ "${1:-}" = "--verbose" ] && VERBOSE=1
mkdir -p Packages ServerPackages build .logs
LOG=".logs/check.log"
: > "$LOG"
PASSED=""
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
	local out
	out="$(mktemp)"
	{
		echo "=== $name ==="
	} >> "$LOG"
	if "$@" > "$out" 2>&1; then
		cat "$out" >> "$LOG"
		[ "$VERBOSE" = "1" ] && { echo "PASS $name"; cat "$out"; }
		PASSED="$PASSED $name"
		if [ "$name" = "tests" ]; then TEST_COUNT="$(grep -o '^tests: [0-9]* passed' "$out" | grep -o '[0-9]*' || true)"; fi
		rm -f "$out"
	else
		cat "$out" >> "$LOG"
		echo "FAIL $name (first 30 lines; full: $LOG)" >&2
		grep -v '^ok ' "$out" | head -30 >&2
		rm -f "$out"
		exit 1
	fi
}
TEST_COUNT=0

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
	gate tests lune run tests/run -- $([ "$VERBOSE" = "1" ] && echo --verbose)
fi

echo "OK tier=$TIER:$PASSED (tests ok: $TEST_COUNT) log=$LOG"
