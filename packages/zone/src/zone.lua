local PackageName = "@permaweb/zone"
local KV = require("@permaweb/kv-base")
if not KV then
    error("KV Not found, install it")
end

local BatchPlugin = require("@permaweb/kv-batch")
if not BatchPlugin then
    error("BatchPlugin not found, install it")
end

local AssetManager = require("@permaweb/asset-manager")
if not AssetManager then
    error("AssetManager not found, install it")
end

if package.loaded[PackageName] then
    return package.loaded[PackageName]
end

if not Zone then Zone = {} end
if not Zone.zoneKV then Zone.zoneKV = KV.new({BatchPlugin}) end
if not ZoneInitCompleted then ZoneInitCompleted = false end
local REGISTRY = ""

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
if not ZoneInitCompleted then
    ao.assign({Processes = { REGISTRY }, Message = ao.Id})
    ZoneInitCompleted = true
end

return Zone
