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

local Subscribable = require 'subscribable' ({
    useDB = false
})



if not Zone then Zone = {} end
if not Zone.zoneKV then Zone.zoneKV = KV.new({ BatchPlugin }) end
if not Zone.assetManager then Zone.assetManager = AssetManager.new() end
if not ZoneInitCompleted then ZoneInitCompleted = false end

-- handlers
Zone.H_ROLE_SET = H_ROLE_SET
Zone.H_PROFILE_ERROR = "Zone-Metadata.Error"
Zone.H_PROFILE_SUCCESS = "Zone-Metadata.Success"
Zone.H_INFO = "Zone-Info"
Zone.H_PROFILE_GET = "Get-Profile"
Zone.H_PROFILE_UPDATE = "Update-Profile"

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

function Zone.profileUpdate(msg)
    if Zone.isAuthorized(msg) ~= true then
        ao.send({
            Target = msg.From,
            Action = Zone.H_PROFILE_ERROR,
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
            Action = Zone.H_PROFILE_ERROR,
            Tags = {
                Status = 'Error',
                Message =
                'Invalid Data'
            }
        })
        return
    end

    local entries = data.entries

    if #entries then
        for _, entry in ipairs(entries) do
            if entry.key and entry.value then
                Zone.zoneKV:set(entry.key, entry.value)
            end
        end
        ao.send({
            Target = msg.From,
            Action = Zone.H_PROFILE_SUCCESS,
        })
        Subscribable.notifySubscribers(Zone.H_PROFILE_UPDATE, { UpdateTx = msg.Id })
        return
    end
end

function Zone.profileGet(msg)
    local decodeCheck, data = Zone.decodeMessageData(msg.Data)
    if not decodeCheck then
        ao.send({
            Target = msg.From,
            Action = Zone.H_PROFILE_ERROR,
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
            Action = Zone.H_PROFILE_SUCCESS,
            Data = json.encode({ Results = results })
        })
    end
end

Handlers.add(
    Zone.H_PROFILE_UPDATE,
    Handlers.utils.hasMatchingTag("Action", Zone.H_PROFILE_UPDATE),
    Zone.profileUpdate
)

Handlers.add(
    Zone.H_PROFILE_GET,
    Handlers.utils.hasMatchingTag("Action", Zone.H_PROFILE_GET),
    Zone.profileGet
)

Handlers.add('Credit-Notice', 'Credit-Notice', function(msg)
    Zone.assetManager:update({
        Type = 'Add',
        AssetId = msg.From,
        Timestamp = msg.Timestamp
    })
end)

-- Register: Tags.Topics = "{"topic","topic2}"
-- Tags.Subscriber-Process-Id = "123"

Handlers.add(
        "Register-Whitelisted-Subscriber",
        Handlers.utils.hasMatchingTag("Action", "Register-Whitelisted-Subscriber"),
        Subscribable.handleRegisterWhitelistedSubscriber
)

Handlers.add('Debit-Notice', 'Debit-Notice', function(msg)
    Zone.assetManager:update({
        Type = 'Remove',
        AssetId = msg.From,
        Timestamp = msg.Timestamp
    })
end)

Subscribable.configTopicsAndChecks({
    ['Update-Profile'] = {
        -- omit below because we're calling notifySubscribers directly
        -- checkFn = checkForProfileUpdate,
        -- payloadFn = payloadForProfileUpdate,
        description = 'Profile Updated',
        returns = '{ "UpdateTx" : string }',
        subscriptionBasis = "Whitelisting"
    },
})


if not ZoneInitCompleted then
    ZoneInitCompleted = true
end

return Zone
