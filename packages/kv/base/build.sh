#!/bin/bash
if [[ "$(uname)" == "Linux" ]]; then
    BIN_PATH="$HOME/.luarocks/bin"
else
    BIN_PATH="/opt/homebrew/bin"
fi

if [ ! -d "dist" ]; then
    mkdir dist
fi

$BIN_PATH/luacheck src/kv.lua
$BIN_PATH/amalg.lua -s src/kv.lua -o dist/main.lua