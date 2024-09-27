local json = require('json')
local sqlite3 = require('lsqlite3')

-- primary registry should keep a list of wallet/zone-id pairs
Db = Db or sqlite3.open_memory()

-- we have roles on who can do things, for now only owner used
local HandlerRoles = {
    ['Zone-Metadata.Set'] = {'Owner', 'Admin'},
    ['Zone-Role.Set'] = {'Owner', 'Admin'},
    -- legacy handlers:
    --['Update-Profile'] = {'Owner', 'Admin'},
    --['Add-Uploaded-Asset'] = {'Owner', 'Admin', 'Contributor'},
    --['Add-Collection'] = {'Owner', 'Admin', 'Contributor'},
    --['Update-Collection-Sort'] = {'Owner', 'Admin'},
    --['Transfer'] = {'Owner', 'Admin'},
    --['Debit-Notice'] = {'Owner', 'Admin'},
    --['Credit-Notice'] = {'Owner', 'Admin'},
    --['Action-Response'] = {'Owner', 'Admin'},
    --['Run-Action'] = {'Owner', 'Admin'},
    --['Proxy-Action'] = {'Owner', 'Admin'},
}

-- a table storing a mapping from registry addresses to actions that should be forwarded
local Subscribers = {}

local function decode_message_data(data)
    local status, decoded_data = pcall(json.decode, data)
    if not status or type(decoded_data) ~= 'table' then
        return false, nil
    end
    return true, decoded_data
end

local function is_authorized(zone_id, user_id, roles)
    if not zone_id then
        return false
    end
    local query = [[
        SELECT role
        FROM zone_auth
        WHERE zone_id = ? AND user_id = ?
        LIMIT 1
    ]]
    local stmt = Db:prepare(query)
    stmt:bind_values(zone_id, user_id)
    local authorized = false
    for row in stmt:nrows() do
        for _, role in ipairs(roles) do
            if row.role == role then
                authorized = true
                break
            end
        end
    end
    stmt:finalize()
    return authorized
end

local function handle_subscribe(msg)
    -- registry owner can subscribe downstream registries to actions
    -- msg.from is the target
    -- msg.data: { actions: {"Action-One", "Action-Two"}, subscriber: "subscriber_id" }
    local decode_check, data = decode_message_data(msg.Data)
    if not decode_check then
        ao.send({
            Target = msg.From,
            Action = 'ERROR',
            Tags = {
                Status = 'DECODE_FAILED',
                Message = "Failed to decode data"
            },
            Data = { Code = "DECODE_FAILED" }
        })
        return
    end

    if not data or not data.actions or not #data.actions then
        ao.send({
            Target = msg.From,
            Action = 'ERROR',
            Tags = {
                Status = 'DECODE_FAILED',
                Message = "no subscribe actions found"
            },
            Data = { Code = "DECODE_FAILED" }
        })
        return
    end

    if not data.subscriber_id then
        ao.send({
            Target = msg.From,
            Action = 'ERROR',
            Tags = {
                Status = 'DECODE_FAILED',
                Message = "no subscriber_id found"
            },
            Data = { Code = "DECODE_FAILED" }
        })
        return
    end
    Subscribers[data.subscriber_id] = data.actions
end

local function handle_forward(msg)
    local assignTargets = {}
    -- for each Subscriber, add the subscriber to assignTargets if msg.Action is in Subscribers[subscriber_id]
    for subscriber, actions in pairs(Subscribers) do
        for _, action in ipairs(actions) do
            if action == msg.Action then
                table.insert(assignTargets, subscriber)
            end
        end
    end
    -- ao.assign to assignTargets
    -- ao.assign({Processes = { ...assignTargets }, Message = msg.Id})
    ao.assign({Processes = assignTargets, Message = msg.Id})
end

-- on spawn, Action = Create-Zone, initializes owner role for userid on zoneId
-- make sure spawn is the correct type of thing
local function handle_create_zone(msg)
    local reply_to = msg.From
    local decode_check, data = decode_message_data(msg.Data)
    -- data may contain {"UserName":"x", ...etc}

    if not decode_check then
        ao.send({
            Target = reply_to,
            Action = 'ERROR',
            Tags = {
                Status = 'DECODE_FAILED',
                Message = "Failed to decode data"
            },
            Data = { Code = "DECODE_FAILED" }
        })
        return
    end

    local ZoneId = msg.Id -- create = msg.Id spawn
    local UserId = msg.From -- (assigned) -- AuthorizedAddress

    local check = Db:prepare('SELECT 1 FROM zone_auth WHERE user_id = ? AND zone_id = ? LIMIT 1')
    check:bind_values(UserId, ZoneId)
    if check:step() ~= sqlite3.ROW then
        is_update = false
        local insert_auth = Db:prepare(
                'INSERT INTO zone_auth (zone_id, user_id, role) VALUES (?, ?, ?)')
        insert_auth:bind_values(ZoneId, UserId, 'Owner')
        insert_auth:step()
        insert_auth:finalize()
    else
        ao.send({
            Target = reply_to,
            Action = 'ERROR',
            Tags = {
                Status = 'DECODE_FAILED',
                Message = "Failed to decode data"
            },
            Data = { Code = "DECODE_FAILED" }
        })
        return
    end
    -- assign to subscribers
    ao.send({
        Target = reply_to,
        Action = 'Zone-Create-Success',
        Tags = {
            Status = 'Success',
            Message = "Sucessfully Created Zone"
        }
    })
    handle_forward(msg)
    return
end

local function handle_prepare_db(msg)
    if msg.From ~= Owner and msg.From ~= ao.id then
        ao.send({
            Target = msg.From,
            Action = 'Authorization-Error',
            Tags = {
                Status = 'Error',
                Message = 'Unauthorized to access this handler'
            }
        })
        return
    end

    Db:exec [[
                CREATE TABLE IF NOT EXISTS zone_auth (
                    zone_id TEXT NOT NULL,
                    user_id TEXT NOT NULL,
                    role TEXT NOT NULL,
                    PRIMARY KEY (zone_id, user_id)
                );
            ]]

    ao.send({
        Target = Owner,
        Action = 'DB-Init-Success',
        Tags = {
            Status = 'Success',
            Message = 'Created DB'
        }
    })
end

local function handle_update_role(msg)
    local decode_check, data = decode_message_data(msg.Data)
    local zone_id = msg.Target
    local user_id = msg.From
    if decode_check and data then
        if not data.Id or not data.Op then
            ao.send({
                Target = zone_id,
                Action = 'Input-Error',
                Tags = {
                    Status = 'Error',
                    Message = 'Invalid arguments, required { Id, Op, Role }'
                }
            })
            return
        end
    end

    if not is_authorized(zone_id, user_id, HandlerRoles['Zone.Update-Role']) then
        ao.send({
            Target = zone_id,
            Action = 'Authorization-Error',
            Tags = {
                Status = 'Error',
                Message = 'Unauthorized to access this handler'
            }
        })
        return
    end

    local Id = data.Id or msg.Tags.Id
    local Role = data.Role or msg.Tags.Role
    local Op = data.Op or msg.Tags.Op

    if not Id or not Op then
        ao.send({
            Target = zone_id,
            Action = 'Input-Error',
            Tags = {
                Status = 'Error',
                Message =
                'Invalid arguments, required { Id, Op } in data or tags'
            }
        })
        return
    end
    -- handle add, update, or remove Ops
    local stmt
    if data.Op == 'Add' then
        stmt = Db:prepare(
                'INSERT INTO zone_auth (zone_id, user_id, role) VALUES (?, ?, ?)')
        stmt:bind_values(zone_id, Id, Role)

    elseif data.Op == 'Update' then
        stmt = Db:prepare(
                'UPDATE zone_auth SET role = ? WHERE zone_id = ? AND user_id = ?')
        stmt:bind_values(Role, zone_id, Id)

    elseif data.Op == 'Delete' then
        stmt = Db:prepare(
                'DELETE FROM zone_auth WHERE zone_id = ? AND user_id = ?')
        stmt:bind_values(zone_id, Id)
    end

    local step_status = stmt:step()
    stmt:finalize()
    if step_status ~= sqlite3.OK and step_status ~= sqlite3.DONE and step_status ~= sqlite3.ROW then
        print("Error: " .. Db:errmsg())
        ao.send({
            Target = zone_id,
            Action = 'DB_STEP_CODE',
            Tags = {
                Status = 'ERROR',
                Message = 'sqlite step error'
            },
            Data = { DB_STEP_MSG = step_status }
        })
        return json.encode({ Code = step_status })
    end

    ao.send({
        Target = zone_id,
        Action = 'Success',
        Tags = {
            Status = 'Success',
            Message = 'Auth Record Success'
        },
        Data = json.encode({ ProfileId = zone_id, DelegateAddress = Id, Role = Role })
    })
end

Handlers.add('Prepare-Database', Handlers.utils.hasMatchingTag('Action', 'Prepare-Database'),
        handle_prepare_db)

-- Data - { Address }
Handlers.add('Get-Zones-For-User', Handlers.utils.hasMatchingTag('Action', 'Get-Zones-For-User'),
        function(msg)
            local decode_check, data = decode_message_data(msg.Data)

            if decode_check and data then
                if not data.Address then
                    ao.send({
                        Target = msg.From,
                        Action = 'Input-Error',
                        Tags = {
                            Status = 'Error',
                            Message = 'Invalid arguments, required { Address }'
                        }
                    })
                    return
                end

                local associated_zones = {}

                local authorization_lookup = Db:prepare([[
                    SELECT zone_id, user_id, role
                        FROM zone_auth
                        WHERE user_id = ?
			    ]])

                authorization_lookup:bind_values(data.Address)

                for row in authorization_lookup:nrows() do
                    table.insert(associated_zones, {
                        ZoneId = row.zone_id,
                        Address = row.user_id,
                        Role = row.role
                    })
                end

                authorization_lookup:finalize()

                if #associated_zones > 0 then
                    ao.send({
                        Target = msg.From,
                        Action = 'Profile-Success',
                        Tags = {
                            Status = 'Success',
                            Message = 'Associated zones fetched'
                        },
                        Data = json.encode(associated_zones)
                    })
                else
                    ao.send({
                        Target = msg.From,
                        Action = 'Profile-Error',
                        Tags = {
                            Status = 'Error',
                            Message = 'This wallet address is not associated with a zone'
                        }
                    })
                end
            else
                ao.send({
                    Target = msg.From,
                    Action = 'Input-Error',
                    Tags = {
                        Status = 'Error',
                        Message = string.format(
                                'Failed to parse data, received: %s. %s.', msg.Data,
                                'Data must be an object - { Address }')
                    }
                })
            end
        end)

-- Create-Profile Handler: (assigned from original zone spawn message)
Handlers.add('Create-Zone', Handlers.utils.hasMatchingTag('Action', 'Create-Zone'),
        handle_create_zone )

Handlers.add('Zone-Metadata.Set', Handlers.utils.hasMatchingTag('Action', 'Zone-Metadata.Set'),
        handle_forward)

Handlers.add('Zone-Role.Set', Handlers.utils.hasMatchingTag('Action', 'Zone-Role.Set'),
        handle_update_role
)

Handlers.add('Add-Subscriber', Handlers.utils.hasMatchingTag('Action', 'Add-Subscriber'),
        handle_subscribe
)

Handlers.add('Read-Auth', Handlers.utils.hasMatchingTag('Action', 'Read-Auth'),
        function(msg)
            local metadata = {}
            local string = ''
            local foundRows = false
            local status, err = pcall(function()
                for row in Db:nrows('SELECT zone_id, user_id, role FROM zone_auth') do
                    foundRows = true
                    table.insert(metadata, {
                        ProfileId = row.zone_id,
                        CallerAddress = row.user_id,
                        Role = row.role,
                    })
                    string = string .. "ZoneId: " .. row.zone_id .. " UserId: " .. row.user_id .. " Role: " .. row.role .. "\n"
                end
            end)
            if not status then
                print("Error: ", err)
                return
            end
            ao.send({
                Target = msg.From,
                Action = 'Read-Metadata-Success',
                Tags = {
                    Status = 'Success',
                    Message = 'Auth Data retrieved',
                },
                Data = json.encode(metadata)
            })
            return json.encode(metadata)
        end)
