#!/usr/bin/env bash
set -euo pipefail

mod_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${mod_root}"

if [[ $# -gt 1 ]]; then
    printf 'Usage: bash tools/validate.sh [TpF3-install-directory]\n' >&2
    exit 2
fi

lua tests/settings_test.lua
lua tests/settings_ui_test.lua
if [[ $# -gt 0 ]]; then
    lua tests/settings_test.lua "$1"
    lua tests/palette_test.lua "$1"
else
    printf 'Game-source checks skipped; pass the TpF3 install directory to enable them.\n'
fi

if [[ ! -f content/gui/main/logging.lua ]]; then
    printf 'Dark UI logging module is missing; check the shared _logging symlink.\n' >&2
    exit 1
fi
luac -p content/gui/main/logging.lua
rg --files content tests -g '*.lua' -0 | xargs -0 -r -n1 luac -p
stylua --check content tests
python3 -m json.tool mod.json >/dev/null
python3 -m json.tool _metadata/modinfo.json >/dev/null
git diff --check

printf 'Dark UI validation passed.\n'
