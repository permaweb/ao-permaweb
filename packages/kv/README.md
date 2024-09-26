# Base
Base functions of the KV
- kv:get()
- kv:set()
- kv:del()

# Extensions
- Batch
  - kv:batchInit()
    - b:set(), b:execute()
- Normalized keys
- Lists
  - sorted
- Encoded values
  - encoding binary data for value
  - encoding json for value


# Installation
1. Make sure you have APM
   `load-blueprint apm`
2. Use APM to install
   `APM.install("@permaweb/kv-base")`

# Usage
1. Require
   `KV = require("@permaweb/kv-base")`
2. Instantiate
    ```
    local status, result = pcall(KV.new, plugins)

    local store = result
    ```
3. Set
    ```
   local nameKey = "FancyName"
   store:set(nameKey, "BobbaBouey")
   ```
4. Get
    ```
   local response = store:get(nameKey)
   ```

# Plugins
```
  KV = require("@permaweb/kv-base")
  plugin = require("someKvPlugin")
  local status, result = pcall(KV.new, { plugin })
```


# Development

## Luarocks
`sudo apt install luarocks`
`luarocks install busted --local`
`export PATH=$PATH:$HOME/.luarocks/bin`
## Testing
`cd kv/base; busted`

## Build
`cd kv/base; ./build.sh`
`cd kv/batchplugin; ./build.sh`

## Plugins
Plugins should have a register function
```
    function plugin.register(kv)
        kv:registerPlugin("aPluginFunction", function()
            return plugin.createBatch(kv)
        end)
        -- more
    end
```
Instantiate `myKV` and use `myKV:aPluginFunction()`

# APM Publish

1. Run build script in selected subfolder
   `./build/sh`
2. Publish `main.lua` from `dist/`

