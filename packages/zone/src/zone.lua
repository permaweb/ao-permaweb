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
if not Zone.zoneKV then Zone.zoneKV = KV.new({ BatchPlugin }) end
if not Zone.assetManager then Zone.assetManager = AssetManager.new() end
if not ZoneInitCompleted then ZoneInitCompleted = false end

-- Notice queue: table of confirmation notices where we store array of assignmentId and registry destination
Zone.noticeQueue = {}
-- a table storing a mapping from registry addresses to actions that should be forwarded

-- handlers to be forwarded
local H_META_SET = "Zone-Metadata.Set"
local H_ROLE_SET = "Zone-Role.Set"
local H_CREATE_ZONE = "Create-Zone"
local REGISTRIES = {"X2g794G_f-y_4U_htwjZufZVEEiVAd4SBA4GVw0c-0Q"}
if not Zone.Subscribers then Zone.Subscribers = {[REGISTRIES[1]]={H_META_SET, H_ROLE_SET}} end

-- handlers
Zone.H_META_SET = H_META_SET
Zone.H_ROLE_SET = H_ROLE_SET
Zone.H_META_GET = "Zone-Metadata.Get"
Zone.H_META_ERROR = "Zone-Metadata.Error"
Zone.H_META_SUCCESS = "Zone-Metadata.Success"
Zone.H_INFO = "Zone-Info"

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
            Action = Zone.H_META_ERROR,
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
            Action = Zone.H_META_ERROR,
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
            Action = Zone.H_META_SUCCESS,
            Tags = {
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
            Action = Zone.H_META_ERROR,
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
            Action = Zone.H_META_SUCCESS,
            Data = json.encode({ Results = results })
        })
    end
end

Handlers.add(
    Zone.H_META_SET,
    Handlers.utils.hasMatchingTag("Action", Zone.H_META_SET),
    Zone.zoneSet
)

Handlers.add(
    Zone.H_META_GET,
    Handlers.utils.hasMatchingTag("Action", Zone.H_META_GET),
    Zone.zoneGet
)

Handlers.add('Credit-Notice', 'Credit-Notice', function(msg)
    Zone.assetManager:update({
        Type = 'Add',
        AssetId = msg.From,
        Timestamp = msg.Timestamp
    })
end)

-- Whenever we assign to registries, wait for a notice.


Handlers.add('Debit-Notice', 'Debit-Notice', function(msg)
    Zone.assetManager:update({
        Type = 'Remove',
        AssetId = msg.From,
        Timestamp = msg.Timestamp
    })
end)

if not ZoneInitCompleted then
    ao.assign({ Processes = REGISTRIES, Message = ao.id })
    ZoneInitCompleted = true
end

return Zone
