-- AO Package Manager for easy installation of packages in ao processes
-------------------------------------------------------------------------
--      ___      .______   .___  ___.     __       __    __       ___
--     /   \     |   _  \  |   \/   |    |  |     |  |  |  |     /   \
--    /  ^  \    |  |_)  | |  \  /  |    |  |     |  |  |  |    /  ^  \
--   /  /_\  \   |   ___/  |  |\/|  |    |  |     |  |  |  |   /  /_\  \
--  /  _____  \  |  |      |  |  |  |  __|  `----.|  `--'  |  /  _____  \
-- /__/     \__\ | _|      |__|  |__| (__)_______| \______/  /__/     \__\
--
---------------------------------------------------------------------------
-- APM Registry source code: https://github.com/ankushKun/ao-package-manager
-- Web UI for browsing & publishing packages: https://apm.betteridea.dev
-- Built with ❤️ by BetterIDEa Team

local apm_id = "UdPDhw5S7pByV3pVqwyr1qzJ8mR8ktzi9olgsdsyZz4"
local version = "1.1.0"

json = require("json")
base64 = require(".base64")

-- common error handler
function handle_run(func, msg)
    local ok, err = pcall(func, msg)
    if not ok then
        local clean_err = err:match(":%d+: (.+)") or err
        print(msg.Action .. " - " .. err)
        -- Handlers.utils.reply(clean_err)(msg)
        if not msg.Target == ao.id then
            ao.send({
                Target = msg.From,
                Data = clean_err
            })
        end
    end
end

function split_package_name(query)
    local vendor, pkgname, version

    -- if only vendor is given
    if query:find("^@%w+$") then
        return query, nil, nil
    end

    -- check if version is provided
    local version_index = query:find("@%d+.%d+.%d+$")
    if version_index then
        version = query:sub(version_index + 1)
        query = query:sub(1, version_index - 1)
    end

    -- check if vendor is provided
    vendor, pkgname = query:match("@(%w+)/([%w%-%_]+)")
    if not vendor then
        vendor = "@apm"
        pkgname = query
    else
        vendor = "@" .. vendor
    end
    return vendor, pkgname, version
end

function hexdecode(hex)
    return (hex:gsub("%x%x", function(digits)
        return string.char(tonumber(digits, 16))
    end))
end

-- function to generate package data
-- @param name: Name of the package
-- @param Vendor: Vender under which package is published (leave nil for default @apm)
-- @param version: Version of the package (default 1.0.0)
-- @param readme: Readme content
-- @param description: Brief description of the package
-- @param main: Name of the main file (default main.lua)
-- @param dependencies: List of dependencies
-- @param repo_url: URL of the repository
-- @param items: List of files in the package
-- @param authors: List of authors
function generate_package_data(name, Vendor, version, readme, description, main, dependencies, repo_url, items, authors)
    assert(type(name) == "string", "Name must be a string")
    assert(type(Vendor) == "string" or Vendor == nil, "Vendor must be a string or nil")
    assert(type(version) == "string" or version == nil, "Version must be a string or nil")

    -- validate items
    if items then
        assert(type(items) == "table", "Items must be a table")
        for _, item in ipairs(items) do
            assert(type(item) == "table", "Each item must be a table")
            assert(type(item.meta) == "table", "Each item must have a meta table")
            assert(type(item.meta.name) == "string", "Each item.meta must have a name")
            assert(type(item.data) == "string", "Each item must have data string")
            -- verify if item.data is a working module
            local func, err = load(item.data)
            if not func then
                error("Error compiling item data: " .. err)
            end
        end
    end
    return {
        Name = name or "",
        Version = version or "1.0.0",
        Vendor = Vendor or "@apm",
        PackageData = {
            Readme = readme or "# New Package",
            Description = description or "",
            Main = main or "main.lua",
            Dependencies = dependencies or {},
            RepositoryUrl = repo_url or "",
            Items = items or {
                {
                    meta = {
                        name = "main.lua"
                    },
                    data = [[
                        local M = {}
                        function M.hello()
                            return "Hello from main.lua"
                        end
                        return M
                    ]]
                }
            },
            Authors = authors or {}
        }
    }
end

----------------------------------------

-- variant of the download response handler that supports assign()

function PublishAssignDownloadResponseHandler(msg)
    local data = json.decode(msg.Data)
    local vendor = data.Vendor
    local version = data.Version
    local PkgData = data.PackageData
    -- local items = json.decode(base64.decode(data.Items))
    local items = PkgData.Items
    local name = data.Name
    if vendor ~= "@apm" then
        name = vendor .. "/" .. name
    end
    local main = PkgData.Main
    local main_src
    for _, item in ipairs(items) do
        -- item.data = base64.decode(item.data)
        if item.meta.name == main then
            main_src = item.data
        end
    end
    assert(main_src, "❌ Unable to find " .. main .. " file to load")
    main_src = string.gsub(main_src, '^%s*(.-)%s*$', '%1') -- remove leading/trailing space
    print("ℹ️ Attempting to load " .. name .. "@" .. version .. " package")
    local func, err = load(string.format([[
        local function _load()
            %s
        end
        _G.package.loaded["%s"] = _load()
    ]], main_src, name))
    if not func then
        print(err)
        error("Error compiling load function: ")
    end
    func()
    print("📦 Package has been loaded, you can now import it using require function")
    APM.installed[name] = version
end

Handlers.add("APM.PublishAssignDownloadResponseHandler", Handlers.utils.hasMatchingTag("Action", "APM.Publish"),
        function(msg)
            handle_run(PublishAssignDownloadResponseHandler, msg)
        end)

function DownloadResponseHandler(msg)
    local pkgID = msg.Data
    local sender = msg.From
    assert(sender == APM.ID, "Invalid package source process")
    assert(type(pkgID) == "string", "Invalid package ID")
    local assignable_name = msg.AssignableName
    print("📦 Downloading package " .. pkgID .. " | " .. assignable_name)
    ao.addAssignable(assignable_name, {
        Id = pkgID
    })
    Assign({
        Message = pkgID,
        Processes = {
            ao.id
        }
    })
end

Handlers.add("APM.DownloadResponse", Handlers.utils.hasMatchingTag("Action", "APM.DownloadResponse"), function(msg)
    handle_run(DownloadResponseHandler, msg)
end)

----------------------------------------

function RegisterVendorResponseHandler(msg)
    print(msg.Data)
end

Handlers.add("APM.RegisterVendorResponse", Handlers.utils.hasMatchingTag("Action", "APM.RegisterVendorResponse"),
        function(msg)
            handle_run(RegisterVendorResponseHandler, msg)
        end)
----------------------------------------

function PublishResponseHandler(msg)
    print(msg.Data)
end

Handlers.add("APM.PublishResponse", Handlers.utils.hasMatchingTag("Action", "APM.PublishResponse"), function(msg)
    handle_run(PublishResponseHandler, msg)
end)

----------------------------------------

function InfoResponseHandler(msg)
    print(msg.Data)
end

Handlers.add("APM.InfoResponse", Handlers.utils.hasMatchingTag("Action", "APM.InfoResponse"), function(msg)
    handle_run(InfoResponseHandler, msg)
end)

----------------------------------------

function SearchResponseHandler(msg)
    local data = json.decode(msg.Data)
    local p = "\n"
    for _, pkg in ipairs(data) do
        p = p .. pkg.Vendor .. "/" .. pkg.Name .. " - " .. pkg.Description .. "\n"
    end
    print(p)
end

Handlers.add("APM.SearchResponse", Handlers.utils.hasMatchingTag("Action", "APM.SearchResponse"), function(msg)
    handle_run(SearchResponseHandler, msg)
end)

----------------------------------------

function GetPopularResponseHandler(msg)
    local data = json.decode(msg.Data)
    local p = "\n"
    for _, pkg in ipairs(data) do
        -- p = p .. pkg.Vendor .. "/" .. pkg.Name .. " - " .. (pkg.Description or pkg.Owner) .. "  " .. pkg.RepositoryUrl .. "\n"
        p = p .. pkg.Vendor .. "/" .. pkg.Name .. " - "
        if pkg.Description then
            p = p .. pkg.Description .. "  "
        else
            p = p .. pkg.Owner .. "  "
        end
        if pkg.RepositoryUrl then
            p = p .. pkg.RepositoryUrl .. "\n"
        else
            p = p .. "No Repo Url\n"
        end
    end
    print(p)
end

Handlers.add("APM.GetPopularResponse", Handlers.utils.hasMatchingTag("Action", "APM.GetPopularResponse"), function(msg)
    handle_run(GetPopularResponseHandler, msg)
end)

----------------------------------------

function TransferResponseHandler(msg)
    print(msg.Data)
end

Handlers.add("APM.TransferResponse", Handlers.utils.hasMatchingTag("Action", "APM.TransferResponse"), function(msg)
    handle_run(TransferResponseHandler, msg)
end)

----------------------------------------

function UpdateNoticeHandler(msg)
    print(msg.Data)
end

Handlers.add("APM.UpdateNotice", Handlers.utils.hasMatchingTag("Action", "APM.UpdateNotice"), function(msg)
    handle_run(UpdateNoticeHandler, msg)
end)

----------------------------------------

function UpdateClientResponseHandler(msg)
    assert(msg.From == APM.ID, "Invalid client package source process")
    local pkg = json.decode(msg.Data)
    local items = json.decode(hexdecode(pkg.Items))
    local main_src
    for _, item in ipairs(items) do
        if item.meta.name == pkg.Main then
            main_src = item.data
        end
    end
    assert(main_src, "❌ Unable to find main.lua file to load")
    print("ℹ️ Attempting to load client " .. pkg.Version)
    local func, err = load(string.format([[
            %s

    ]], main_src, pkg.Version))
    if not func then
        print(err)
        error("Error compiling load function: ")
    end
    print(func())
    APM._version = pkg.Version
    print(Colors.green .. "✨ Client has been updated to " .. pkg.Version .. Colors.reset)
end

Handlers.add("APM.UpdateClientResponse", Handlers.utils.hasMatchingTag("Action", "APM.UpdateClientResponse"),
        function(msg)
            handle_run(UpdateClientResponseHandler, msg)
        end)


----------------------------------------

APM = {}

APM.ID = apm_id
APM._version = APM._version or version
APM.installed = APM.installed or {}

function APM.registerVendor(name)
    Send({
        Target = APM.ID,
        Action = "APM.RegisterVendor",
        Data = name,
        Quantity = '100000000000',
        Version = APM._version
    })
    return "📤 Vendor registration request sent"
end

-- to publish an update set options = { Update = true }
function APM.publish(package_data, options)
    assert(type(package_data) == "table", "Package data must be a table")
    local data = json.encode(package_data)
    local quantity
    if options and options.Update == true then
        quantity = '10000000000'
    else
        quantity = '100000000000'
    end
    Send({
        Target = APM.ID,
        Action = "APM.Publish",
        Data = data,
        Quantity = quantity,
        Version = APM._version
    })
    return "📤 Publish request sent"
end

function APM.info(name)
    Send({
        Target = APM.ID,
        Action = "APM.Info",
        Data = name,
        Version = APM._version
    })
    return "📤 Fetching package info"
end

function APM.popular()
    Send({
        Target = APM.ID,
        Action = "APM.GetPopular",
        Version = APM._version
    })
    return "📤 Fetching top 50 downloaded packages"
end

function APM.search(query)
    assert(type(query) == "string", "Query must be a string")
    Send({
        Target = APM.ID,
        Action = "APM.Search",
        Data = query,
        Version = APM._version
    })
    return "📤 Searching for packages"
end

function APM.transfer(name, recipient)
    assert(type(name) == "string", "Name must be a string")
    assert(type(recipient) == "string", "Recipient must be a string")
    Send({
        Target = APM.ID,
        Action = "APM.Transfer",
        Data = name,
        To = recipient,
        Version = APM._version
    })
    return "📤 Transfer request sent"
end

function APM.install(name)
    assert(type(name) == "string", "Name must be a string")

    -- name cam be in the following formats:
    -- @vendor/pkgname@x.y.z
    -- pkgname@x.y.z
    -- pkgname
    -- @vendor/pkgname
    Send({
        Target = APM.ID,
        Action = "APM.Download",
        Data = name,
        Version = APM._version
    })
    return "📤 Download request sent"
end

function APM.uninstall(name)
    assert(type(name) == "string", "Name must be a string")
    if not APM.installed[name] then
        return "❌ Package is not installed"
    end
    _G.package.loaded[name] = nil
    APM.installed[name] = nil
    return "📦 Package has been uninstalled"
end

function APM.update()
    Send({
        Target = APM.ID,
        Action = "APM.UpdateClient",
        Version = APM._version
    })
    return "📤 Update request sent"
end

--
--
--return "📦 Loaded APM Client"

-- ================================================================================
-- ================================================================================
-- @permaweb/kv-base
-- ================================================================================
-- ================================================================================
local function load_kv()


local KV = {}

KV.__index = KV
local KVPackageName = "@permaweb/kv-base"
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

package.loaded[KVPackageName] = KV

return KV
end
package.loaded['@permaweb/kv-base'] = load_kv()



-- ================================================================================
-- ================================================================================
-- @permaweb/kv-batch
-- ================================================================================
-- ================================================================================
local function load_batch()
local BatchPlugin = {}
local PackageName = "@permaweb/kv-batch"
function BatchPlugin.new()
    local plugin = {}

    -- Register the plugin methods to a KV instance
    function plugin.register(kv)
        kv:registerPlugin("batchInit", function()
            return plugin.createBatch(kv)
        end)
    end

    function plugin.createBatch(kv)
        local batch = {}
        batch.operations = {}

        function batch:set(keyString, value)
            table.insert(self.operations, { op = "set", key = keyString, value = value })
        end
        -- TODO probably implement del?

        -- Execute all batched operations
        function batch:execute()
            for _, operation in ipairs(self.operations) do
                if operation.op == "set" then
                    kv:set(operation.key, operation.value)
                end
            end
            self:clear()  -- Optionally clear the batch after execution
        end

        -- Clear all batched operations
        function batch:clear()
            self.operations = {}
        end

        return batch
    end

    return plugin
end

package.loaded[PackageName] = BatchPlugin

return BatchPlugin
end
package.loaded['@permaweb/kv-batch'] = load_batch()



-- ================================================================================
-- ================================================================================
-- @permaweb/zone
-- ================================================================================
-- ================================================================================
local function load_zone()
local PackageName = "@permaweb/zone"
local KV = require("@permaweb/kv-base")
if not KV then
    error("KV Not found, install it")
end

local BatchPlugin = require("@permaweb/kv-batch")
if not BatchPlugin then
    error("BatchPlugin not found, install it")
end

if package.loaded[PackageName] then
    return package.loaded[PackageName]
end

if not Zone then Zone = {} end
if not Zone.zoneKV then Zone.zoneKV = KV.new({BatchPlugin}) end

-- handlers
Zone.ZONE_M_SET = "Zone-Metadata.Set"
Zone.ZONE_M_GET = "Zone-Metadata.Get"
Zone.ZONE_M_ERROR = "Zone-Metadata.Error"
Zone.ZONE_M_SUCCESS = "Zone-Metadata.Success"
Zone.ZONE_INFO = "Zone-Info"

function Zone.decodeMessageData(data)
    local status, decodedData = pcall(json.decode, data)
    if not status or type(decodedData) ~= 'table' then
        return false, nil
    end

    return true, decodedData
end

function Zone.isAuthorized(msg)
    if msg.From == Owner then
        return true
    end
    return false
end

function Zone.hello()
    print("Hello zone")
end

function Zone.zoneSet(msg)

    if Zone.isAuthorized(msg) ~= true then
        ao.send({
            Target = msg.From,
            Action = Zone.ZONE_M_ERROR,
            Tags = {
                Status = 'Error',
                Message =
                'Not Authorized'
            }
        })
        return
    end
    local decodeCheck, data = Zone.decodeMessageData(msg.Data)
    if not decodeCheck then
        ao.send({
            Target = msg.From,
            Action = Zone.ZONE_M_ERROR,
            Tags = {
                Status = 'Error',
                Message =
                'Invalid Data'
            }
        })
        return
    end

    local entries = data.entries

    local testkeys = {}

    if #entries then
        for _, entry in ipairs(entries) do
            if entry.key and entry.value then
                table.insert(testkeys, entry.key)
                Zone.zoneKV:set(entry.key, entry.value)
            end
        end
        ao.send({
            Target = msg.From,
            Action = Zone.ZONE_M_SUCCESS,
            Tags =  {
                Value1 = Zone.zoneKV:get(testkeys[1]),
                Key1 = testkeys[1]
            },
            Data = json.encode({ First = Zone.zoneKV:get(testkeys[1]) })
        })
        return
    end
end

function Zone.zoneGet(msg)

    local decodeCheck, data = Zone.decodeMessageData(msg.Data)
    if not decodeCheck then
        ao.send({
            Target = msg.From,
            Action = Zone.ZONE_M_ERROR,
            Tags = {
                Status = 'Error',
                Message =
                'Invalid Data'
            }
        })
        return
    end

    local keys = data.keys

    if not keys then
        error("no keys")
    end

    if keys then
        local results = {}
        for _, k in ipairs(keys) do
            results[k] = Zone.zoneKV:get(k)
        end
        ao.send({
            Target = msg.From,
            Action = Zone.ZONE_M_SUCCESS,
            Data = json.encode({Results = results} )
        })
    end
end

--Handlers.remove(Zone.ZONE_M_SET)
Handlers.add(
        Zone.ZONE_M_SET,
        Handlers.utils.hasMatchingTag("Action", Zone.ZONE_M_SET),
        Zone.zoneSet
)
--Handlers.remove(Zone.ZONE_M_GET)
Handlers.add(
        Zone.ZONE_M_GET,
        Handlers.utils.hasMatchingTag("Action", Zone.ZONE_M_GET),
        Zone.zoneGet
)

return Zone

end
package.loaded['@permaweb/zone'] = load_zone()

