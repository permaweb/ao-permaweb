local json = require('json')

local function match_assignable_actions(a, assignables)
    for _, v in ipairs(assignables) do
        if a == v then
            return true
        end
    end
end

if not Zone then
    Zone = {}
end

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

-- incoming handlers
Zone.H_SUBSCRIBER_UPDATE = "Zone-Subscriber.Update"
Zone.H_SUBSCRIBER_REMOVE = "Zone-Subscriber.Remove"
Zone.H_SUBSCRIBER_LIST = "Zone-Subscriber.List"

-- response handlers
Zone.H_SUBSCRIBER_UPDATE_ERROR = "Zone-Subscriber.Add-Error"
Zone.H_SUBSCRIBER_REMOVE_ERROR = "Zone-Subscriber.Remove-Error"
Zone.H_SUBSCRIBER_UPDATE_SUCCESS = "Zone-Subscriber.Add-Success"
Zone.H_SUBSCRIBER_REMOVE_SUCCESS = "Zone-Subscriber.Remove-Success"
Zone.H_SUBSCRIBER_LIST_SUCCESS = "Zone-Subscriber.List-Success"

local ASSIGNABLES = {
    Zone.H_SUBSCRIBER_LIST
}

ao.addAssignable("AssignableActions", { Action = function(a) return match_assignable_actions(a, ASSIGNABLES) end } )

-- handlers to be forwarded
local H_META_SET = "Zone-Metadata.Set"
local H_ROLE_SET = "Zone-Role.Set"
local H_CREATE_ZONE = "Create-Zone"
local REGISTRIES = { "X2g794G_f-y_4U_htwjZufZVEEiVAd4SBA4GVw0c-0Q" }
if not Zone.Subscribers then
    Zone.Subscribers = { [REGISTRIES[1]] = { H_META_SET, H_ROLE_SET, H_CREATE_ZONE } }
end

-- Add a registry to the zone
-- @param msg The message to decode and process
-- @param msg.data The data to add to the registry
-- @param msg.data.Actions A table of action strings
-- @param msg.data.RegistryId The ID of the registry to add to
-- @return nil
function Zone.updateSubscribers(msg)
    local replyTo = msg.From
    local success, decodedData = Zone.decodeMessageData(msg.Data)
    if not success or decodedData == nil then
        ao.send({
            Target = replyTo,
            Action = Zone.H_SUBSCRIBER_UPDATE_ERROR,
            Tags = {
                Status = 'Error',
            },
            Data = msg.Data
        })
        return
    end

    local registryId = decodedData.RegistryId

    if registryId == nil or type(registryId) ~= 'string' then
        ao.send({
            Target = replyTo,
            Action = Zone.H_SUBSCRIBER_UPDATE_ERROR,
            Tags = {
                Status = 'Error',
            },
            Data = json.encode({
                Message = 'data.RegistryId is required'
            })
        })

    end

    local actions = decodedData.Actions
    if type(actions) ~= 'table' then
        ao.send({
            Target = replyTo,
            Action = Zone.H_SUBSCRIBER_UPDATE_ERROR,
            Tags = {
                Status = 'Error',
            },
            Data = json.encode({
                Message = 'data.Actions is required'
            })
        })
    end

    for _, action in ipairs(decodedData.Actions) do
        if type(action) ~= 'string' then
            ao.send({
                Target = replyTo,
                Action = Zone.H_SUBSCRIBER_UPDATE_ERROR,
                Tags = {
                    Status = 'Error',
                },
                Data = json.encode({
                    Message = "Actions must be a table of strings"
                })
            })
        end
    end

    Zone.Subscribers[registryId] = actions
    ao.send({
        Target = replyTo,
        Action = Zone.H_SUBSCRIBER_LIST_SUCCESS,
        Tags = {
            Status = 'Success',
        },
        Data = json.encode({
            Subscribers = Zone.Subscribers
        })
    })
end

-- Remove a registry from subscribers
-- @param msg The message to decode and process
-- @param msg.data The data to remove from the registry
-- @param msg.data.RegistryId The ID of the registry to remove from
-- @return nil

function Zone.removeSubscribers(msg)
    local replyTo = msg.From
    local success, decodedData = Zone.decodeMessageData(msg.Data)
    if not success or decodedData == nil then
        ao.send({
            Target = replyTo,
            Action = Zone.H_SUBSCRIBER_REMOVE_ERROR,
            Tags = {
                Status = 'Error',
            },
            Data = json.encode({
                Message = 'Invalid Json Data'
            })
        })
        return
    end

    local registryId = decodedData.RegistryId
    if registryId == nil or type(registryId) ~= 'string' then
        ao.send({
            Target = replyTo,
            Action = Zone.H_SUBSCRIBER_REMOVE_ERROR,
            Tags = {
                Status = 'Error',
            },
            Data = json.encode({
                Message = 'data.RegistryId is required'
            })
        })

    end


    if not Zone.Subscribers[registryId] then
        ao.send({
            Target = replyTo,
            Action = Zone.H_SUBSCRIBER_REMOVE_ERROR,
            Tags = {
                Status = 'Error',
            },
            Data = json.encode({
                Message = 'data.RegistryId not found',
                RegistryId = registryId
            })
        })
    end

    -- Remove Subscribers[RegistryId]
    Zone.Subscribers[registryId] = nil

    ao.send({
        Target = replyTo,
        Action = Zone.H_SUBSCRIBER_REMOVE_SUCCESS,
        Tags = {
            Status = 'Success',
        },
        Data = json.encode({
            Message = 'Subscriber removed',
            SubscriberId = registryId
        })

    })
end

function Zone.listSubscribers(msg)
    local replyTo = msg.From
    ao.send({
        Target = replyTo,
        Action = Zone.H_SUBSCRIBER_LIST_SUCCESS,
        Tags = {
            Status = 'Success',
        },
        Data = json.encode({
            Subscribers = Zone.Subscribers
        })
    })
end


Handlers.add(
        Zone.H_SUBSCRIBER_UPDATE,
        Handlers.utils.hasMatchingTag("Action", Zone.H_SUBSCRIBER_UPDATE),
        Zone.updateSubscribers
)

Handlers.add(
        Zone.H_SUBSCRIBER_REMOVE,
        Zone.H_SUBSCRIBER_REMOVE,
        Zone.removeSubscribers
)

Handlers.add(
        Zone.H_SUBSCRIBER_LIST,
        Zone.H_SUBSCRIBER_LIST,
        Zone.listSubscribers
)

return Zone
