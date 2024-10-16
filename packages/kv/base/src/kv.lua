

package.loaded["@permaweb/kv-base"] = nil

do
    local KVPackageName = "@permaweb/kv-base"
    local KV = {}

    KV.__index = KV

    function KV.new(plugins)

        if type(plugins) ~= "table" and type(plugins) ~= "nil" then
            print("invalid plugins")
            error("Invalid plugins arg, must be table or nil")
        end

        local self = setmetatable({}, KV)

        if plugins and type(plugins) == "table" then
            for _, plugin in ipairs(plugins) do
                if type(plugin) == "table" and plugin.register then
                    plugin.register(self)
                end
            end
        end
        self.store = {}
        return self
    end

    function KV:get(keyString)
        return self.store[keyString]
    end

    function KV:set(keyString, value)
        self.store[keyString] = value
    end

    function KV:len()
        local count = 0
        for _ in pairs(self.store) do
            count = count + 1
        end
        return count
    end

    function KV:del(keyString)
        self.store[keyString] = nil
    end

    function KV:keys()
        local keys = {}
        for k, _ in pairs(self.store) do
            table.insert(keys, k)
        end
        return keys
    end

    function KV:registerPlugin(pluginName, pluginFunction)
        if type(pluginName) ~= "string" or type(pluginFunction) ~= "function" then
            error("Invalid plugin name or function")
        end
        if self[pluginName] then
           error(pluginName .. " already exists" )
        end

        self[pluginName] = pluginFunction
    end

    function KV.filter_store(store, fn)
        local results = {}
        for k, v in pairs(store) do
            if fn(k, v) then
                results[k] = v
            end
        end
        return results
    end

    function KV.starts_with(str, prefix)
        return str:sub(1, #prefix) == prefix
    end

    function KV:getPrefix(str)
        return KV.filter_store(self.store, function(k, _)
            return KV.starts_with(k, str)
        end)
    end
    package.preload[KVPackageName] = KV
end
