#!/bin/bash
if [[ "$(uname)" == "Linux" ]]; then
    BIN_PATH="$HOME/.luarocks/bin"
else
    BIN_PATH="/opt/homebrew/bin"
fi

if [ ! -d "dist" ]; then
    mkdir dist
fi


$BIN_PATH/amalg.lua -s src/batch.lua -o dist/main.lua
$BIN_PATH/luacheck --no-cache dist/main.lua