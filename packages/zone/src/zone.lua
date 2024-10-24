local KV = require('@permaweb/kv-base')
if not KV then
    error('KV Not found, install it')
end

local BatchPlugin = require('@permaweb/kv-batch')
if not BatchPlugin then
    error('BatchPlugin not found, install it')
end

local AssetManager = require('@permaweb/asset-manager')
if not AssetManager then
    error('AssetManager not found, install it')
end

local Subscribable = require 'subscribable' ({
    useDB = false
})

if not Zone then Zone = {} end
if not Zone.zoneKV then Zone.zoneKV = KV.new({ BatchPlugin }) end
if not Zone.assetManager then Zone.assetManager = AssetManager.new() end
if not ZoneInitCompleted then ZoneInitCompleted = false end

-- Action handler and notice names
Zone.H_ZONE_ERROR = 'Zone.Error'
Zone.H_ZONE_SUCCESS = 'Zone.Success'

Zone.H_ZONE_GET = 'Info'
Zone.H_ZONE_UPDATE = 'Update-Zone'
Zone.H_ZONE_CREDIT_NOTICE = 'Credit-Notice'
Zone.H_ZONE_DEBIT_NOTICE = 'Debit-Notice'
Zone.H_ZONE_RUN_ACTION = 'Run-Action'

function Zone.decodeMessageData(data)
    local status, decodedData = pcall(json.decode, data)
    if not status or type(decodedData) ~= 'table' then
        return false, nil
    end

    return true, decodedData
end

function Zone.isAuthorized(msg)
    if msg.From == Owner or msg.From == ao.id then
        return true
    end
    return false
end

function Zone.zoneGet(msg)
    msg.reply({
        Target = msg.From,
        Action = Zone.H_ZONE_SUCCESS,
        Data = json.encode({
            store = Zone.zoneKV:dump(),
            assets = Zone.assetManager.assets
        })
    })
end

function Zone.zoneUpdate(msg)
    if Zone.isAuthorized(msg) ~= true then
        ao.send({
            Target = msg.From,
            Action = Zone.H_ZONE_ERROR,
            Tags = {
                Status = 'Error',
                Message = 'Not Authorized'
            }
        })
        return
    end

    local decodeCheck, data = Zone.decodeMessageData(msg.Data)

    if not decodeCheck then
        ao.send({
            Target = msg.From,
            Action = Zone.H_ZONE_ERROR,
            Tags = {
                Status = 'Error',
                Message = 'Invalid Data'
            }
        })
        return
    end

    local entries = data and data.entries

    if entries and #entries then
        for _, entry in ipairs(entries) do
            if entry.key and entry.value then
                Zone.zoneKV:set(entry.key, entry.value)
            end
        end
        ao.send({
            Target = msg.From,
            Action = Zone.H_ZONE_SUCCESS,
        })
        Subscribable.notifySubscribers(Zone.H_ZONE_UPDATE, { UpdateTx = msg.Id })
        return
    end
end

function Zone.creditNotice(msg)
    Zone.assetManager:update({
        Type = 'Add',
        AssetId = msg.From,
        Timestamp = msg.Timestamp
    })
end

function Zone.debitNotice(msg)
    Zone.assetManager:update({
        Type = 'Remove',
        AssetId = msg.From,
        Timestamp = msg.Timestamp
    })
end

function Zone.runAction(msg)
    if Zone.isAuthorized(msg) ~= true then
        msg.reply({
            Action = Zone.H_ZONE_ERROR,
            Tags = {
                Status = 'Error',
                Message = 'Not Authorized'
            }
        })
        return
    end

    if not msg.ForwardTo or not msg.ForwardAction then
        ao.send({
            Target = msg.From,
            Action = 'Input-Error',
            Tags = {
                Status = 'Error',
                Message = 'Invalid arguments, required { ForwardTo, ForwardAction }'
            }
        })
        return
    end

    ao.send({
        Target = msg.ForwardTo,
        Action = msg.ForwardAction,
        Data = msg.Data,
        Tags = msg.Tags
    })
end

Handlers.add(Zone.H_ZONE_GET, Zone.H_ZONE_GET, Zone.zoneGet)
Handlers.add(Zone.H_ZONE_UPDATE, Zone.H_ZONE_UPDATE, Zone.zoneUpdate)
Handlers.add(Zone.H_ZONE_CREDIT_NOTICE, Zone.H_ZONE_CREDIT_NOTICE, Zone.creditNotice)
Handlers.add(Zone.H_ZONE_DEBIT_NOTICE, Zone.H_ZONE_DEBIT_NOTICE, Zone.creditNotice)
Handlers.add(Zone.H_ZONE_RUN_ACTION, Zone.H_ZONE_RUN_ACTION, Zone.runAction)

Handlers.add(
    'Register-Whitelisted-Subscriber',
    Handlers.utils.hasMatchingTag('Action', 'Register-Whitelisted-Subscriber'),
    Subscribable.handleRegisterWhitelistedSubscriber
)

Subscribable.configTopicsAndChecks({
    ['Update-Zone'] = {
        description = 'Zone updated',
        returns = '{ "UpdateTx" : string }',
        subscriptionBasis = 'Whitelisting'
    },
})

if not ZoneInitCompleted then
    ZoneInitCompleted = true
end

return Zone
