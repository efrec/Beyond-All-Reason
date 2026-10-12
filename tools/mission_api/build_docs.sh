#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'USAGE'
usage: EMMYLUA_DOC_CLI=<path to emmylua_doc_cli> [LUA=<lua 5.1 interpreter>] tools/mission_api/build_docs.sh

Regenerates luarules/mission_api/mission_api.json and doc/mission_api/ from the annotations in
luarules/mission_api. Run it from the repository root.

  EMMYLUA_DOC_CLI  Required. The emmylua_doc_cli 0.25.1 binary.
  LUA              A Lua 5.1 interpreter; defaults to lua5.1. Locally the float32 engine Lua is
                   the one to use: LUA=data/tools/lua-f32/lua.sh (relative to the BAR data dir).

The doc_cli export goes to a temporary directory and never into the repository.
USAGE
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
	usage
	exit 0
fi

if [ -z "${EMMYLUA_DOC_CLI:-}" ]; then
	echo "EMMYLUA_DOC_CLI is not set." >&2
	usage >&2
	exit 2
fi

if [ ! -f .emmyrc.json ] || [ ! -d luarules/mission_api ]; then
	echo "Run this from the repository root." >&2
	exit 2
fi

LUA="${LUA:-lua5.1}"
TOOLS=tools/mission_api
CATALOG=luarules/mission_api/mission_api.json
DOCS=doc/mission_api

# Git Bash hands Lua a /c/... path that doc_cli's C:/... locations never match.
ROOT=$(pwd -W 2>/dev/null || pwd)

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

GAME_VERSION=$(git describe --always --dirty)

"$EMMYLUA_DOC_CLI" -c .emmyrc.json -f json -o "$TMP" luarules/mission_api

"$LUA" "$TOOLS/export_catalog.lua" \
	--doc "$TMP/doc.json" \
	--root "$ROOT" \
	--out "$CATALOG" \
	--game-version "$GAME_VERSION"

"$LUA" "$TOOLS/check_catalog.lua" \
	--catalog "$CATALOG" \
	--doc "$TMP/doc.json" \
	--root "$ROOT"

rm -rf "$DOCS"
mkdir -p "$DOCS/actions"
"$LUA" "$TOOLS/render_docs.lua" \
	--catalog "$CATALOG" \
	--out "$DOCS" \
	--root "$ROOT"
