local json = require('json')
local sqlite3 = require('lsqlite3')

-- primary registry should keep a list of wallet/zone-id pairs
Db = Db or sqlite3.open_memory()

-- we have roles on who can do things, for now only owner used
-- registry handlers
local H_READ_AUTH = "Read-Auth"
local H_GET_USER_ZONES = "Get-Zones-For-User"
local H_GET_ZONES_METADATA = "Get-Zones-Metadata"
local H_PREPARE_DB = "Prepare-Database"

-- handlers to be forwarded
local H_META_SET = "Zone-Metadata.Set"
local H_META_GET = "Zone-Metadata.Get"
local H_ROLE_SET = "Zone-Role.Set"
local H_CREATE_ZONE = "Create-Zone"
ao.addAssignable(H_META_SET, { Action = H_META_SET })
ao.addAssignable(H_ROLE_SET, { Action = H_ROLE_SET })
ao.addAssignable(H_CREATE_ZONE, { Action = H_CREATE_ZONE })
ao.addAssignable(H_GET_USER_ZONES, { Action = H_GET_USER_ZONES })

local HandlerRoles = {
    [H_META_SET] = {'Owner', 'Admin'},
    [H_ROLE_SET] = {'Owner'},
    -- TODO add code to allow
}

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
                Status = 'ERROR',
                Message = "Zone already found, cannot insert"
            },
            Data = { Code = "INSERT_FAILED" }
        })
        return
    end

    local columns = {}
    local placeholders = {}
    local params = {}
    local metadataValues = {
        id = ZoneId,
        username = data.UserName or nil,
        profile_image = data.ProfileImage or nil,
        cover_image = data.CoverImage or nil,
        description = data.Description or nil,
        display_name = data.DisplayName or nil,
        date_updated = msg.Timestamp,
        date_created = msg.Timestamp
    }
    local function generateInsertQuery()
        for key, val in pairs(metadataValues) do
            if val ~= nil then
                -- Include the field if provided
                table.insert(columns, key)
                if val == "" then
                    -- If the field is an empty string, insert NULL
                    table.insert(placeholders, "NULL")
                else
                    -- Otherwise, prepare to bind the actual value
                    table.insert(placeholders, "?")
                    table.insert(params, val)
                end
            else
                -- If field is nil and not mandatory, insert NULL
                if key ~= "id" then
                    table.insert(columns, key)
                    table.insert(placeholders, "NULL")
                end
            end
        end

        local sql = "INSERT INTO ao_zone_metadata (" .. table.concat(columns, ", ") .. ")"
        sql = sql .. " VALUES (" .. table.concat(placeholders, ", ") .. ")"

        return sql
    end
    local sql = generateInsertQuery()
    local stmt = Db:prepare(sql)

    if not stmt then
        ao.send({
            Target = reply_to,
            Action = 'DB_CODE',
            Tags = {
                Status = 'DB_PREPARE_FAILED',
                Message = "DB PREPARED QUERY FAILED"
            },
            Data = { Code = "Failed to prepare insert statement",
                     SQL = sql,
                     ERROR = Db:errmsg()
            }
        })
        print("Failed to prepare insert statement")
        return json.encode({ Code = 'DB_PREPARE_FAILED' })
    end

    -- bind values for INSERT statement
    local bindres = stmt:bind_values(table.unpack(params))

    if not bindres then
        ao.send({
            Target = reply_to,
            Action = 'DB_CODE',
            Tags = {
                Status = 'DB_PREPARE_FAILED',
                Message = "DB BIND QUERY FAILED"
            },
            Data = { Code = "Failed to prepare insert statement",
                     SQL = sql,
                     ERROR = Db:errmsg()
            }
        })
        print("Failed to prepare insert statement")
        return json.encode({ Code = 'DB_PREPARE_FAILED' })
    end
    local step_status = stmt:step()

    if step_status ~= sqlite3.OK and step_status ~= sqlite3.DONE and step_status ~= sqlite3.ROW then
        stmt:finalize()
        print("Error: " .. Db:errmsg())
        print("SQL" .. sql)
        ao.send({
            Target = reply_to,
            Action = 'DB_STEP_CODE',
            Tags = {
                Status = 'ERROR',
                Message = 'sqlite step error'
            },
            Data = { DB_STEP_MSG = step_status }
        })
        return json.encode({ Code = step_status })
    end
    stmt:finalize()    ao.send({
        Target = reply_to,
        Action = 'Success',
        Tags = {
            Status = 'Success',
            Message = is_update and 'Record Updated' or 'Record Inserted'
        },
        Data = json.encode(metadataValues)
    })

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
                CREATE TABLE IF NOT EXISTS ao_zone_metadata (
                    id TEXT PRIMARY KEY NOT NULL,
                    username TEXT,
                    display_name TEXT,
                    description TEXT,
                    profile_image TEXT,
                    cover_image TEXT,
                    date_created INTEGER NOT NULL,
                    date_updated INTEGER NOT NULL
                );
            ]]

    Db:exec [[
                CREATE TABLE IF NOT EXISTS zone_auth (
                    zone_id TEXT NOT NULL,
                    user_id TEXT NOT NULL,
                    role TEXT NOT NULL,
                    PRIMARY KEY (zone_id, user_id)
                    FOREIGN KEY (zone_id) REFERENCES ao_zone_metadata (id) ON DELETE CASCADE
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
    local authCheck = is_authorized(zone_id, user_id, HandlerRoles['Zone.Update-Role'])
    if not authCheck then
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
    local stmt = ""
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

local function handle_meta_get(msg)
    local decode_check, data = decode_message_data(msg.Data)

    if decode_check and data then
        if not data.ZoneIds then
            ao.send({
                Target = msg.From,
                Action = 'Input-Error',
                Tags = {
                    Status = 'Error',
                    Message = 'Invalid arguments, required { ProfileIds }'
                },
                Data = msg.Data
            })
            return
        end

        local metadata = {}
        if #data.ZoneIds > 0 then
            local placeholders = {}

            for _, _ in ipairs(data.ZoneIds) do
                table.insert(placeholders, "?")
            end

            if #placeholders > 0 then
                local stmt = Db:prepare([[
                        SELECT *
                        FROM ao_zone_metadata
                        WHERE id IN (]] .. table.concat(placeholders, ',') .. [[)
                        ]])

                if not stmt then
                    ao.send({
                        Target = msg.From,
                        Action = 'DB_CODE',
                        Tags = {
                            Status = 'DB_PREPARE_FAILED',
                            Message = "DB PREPARED QUERY FAILED"
                        },
                        Data = { Code = "Failed to prepare insert statement" }
                    })
                    print("Failed to prepare insert statement")
                    return json.encode({ Code = 'DB_PREPARE_FAILED' })
                end

                stmt:bind_values(table.unpack(data.ZoneIds))

                local foundRows = false
                for row in stmt:nrows() do
                    foundRows = true
                    table.insert(metadata, { ProfileId = row.id,
                                             Username = row.username,
                                             ProfileImage = row.profile_image,
                                             CoverImage = row.cover_image,
                                             Description = row.description,
                                             DisplayName = row.display_name
                    })
                end

                if not foundRows then
                    print('No rows found matching the criteria.')
                end

                ao.send({
                    Target = msg.From,
                    Action = 'Get-Metadata-Success',
                    Tags = {
                        Status = 'Success',
                        Message = 'Metadata retrieved',
                    },
                    Data = json.encode(metadata)
                })
            else
                print('Profile ID list is empty after validation.')
            end
        else
            ao.send({
                Target = msg.From,
                Action = 'Input-Error',
                Tags = {
                    Status = 'Error',
                    Message = 'No ZoneIds provided or the list is empty.'
                }
            })
            print('No ZoneIds provided or the list is empty.')
            return

        end
    else
        ao.send({
            Target = msg.From,
            Action = 'Input-Error',
            Tags = {
                Status = 'Error',
                Message = string.format(
                        'Failed to parse data, received: %s. %s.', msg.Data,
                        'Data must be an object - { ZoneIds }')
            }
        })
    end
end

-- assignment of message from authorized wallet to profile_id
local function handle_meta_set(msg)
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
    --local TargetZone = msg.Target
    local ZoneId = msg.Target -- Is this original target? confirm.
    local UserId = msg.From -- (assigned) -- AuthorizedAddress

    if not is_authorized(ZoneId, UserId, HandlerRoles[H_META_SET]) then
        ao.send({
            Target = reply_to,
            Action = 'Authorization-Error',
            Tags = {
                Status = 'Error',
                Message = 'Unauthorized to access this handler'
            }
        })
        return
    end

    local columns = {}
    local placeholders = {}
    local params = {}
    local metadataValues = {
        id = ZoneId,
        username = data.UserName or nil,
        profile_image = data.ProfileImage or nil,
        cover_image = data.CoverImage or nil,
        description = data.Description or nil,
        display_name = data.DisplayName or nil,
        date_updated = msg.Timestamp,
        date_created = msg.Timestamp
    }
    local function generateInsertQuery()
        for key, val in pairs(metadataValues) do
            if val ~= nil then
                -- Include the field if provided
                table.insert(columns, key)
                if val == "" then
                    -- If the field is an empty string, insert NULL
                    table.insert(placeholders, "NULL")
                else
                    -- Otherwise, prepare to bind the actual value
                    table.insert(placeholders, "?")
                    table.insert(params, val)
                end
            else
                -- If field is nil and not mandatory, insert NULL
                if key ~= "id" then
                    table.insert(columns, key)
                    table.insert(placeholders, "NULL")
                end
            end
        end

        local sql = "INSERT INTO ao_zone_metadata (" .. table.concat(columns, ", ") .. ")"
        sql = sql .. " VALUES (" .. table.concat(placeholders, ", ") .. ")"

        return sql
    end
    local sql = generateInsertQuery()
    local stmt = Db:prepare(sql)

    if not stmt then
        ao.send({
            Target = reply_to,
            Action = 'DB_CODE',
            Tags = {
                Status = 'DB_PREPARE_FAILED',
                Message = "DB PREPARED QUERY FAILED"
            },
            Data = { Code = "Failed to prepare insert statement",
                     SQL = sql,
                     ERROR = Db:errmsg()
            }
        })
        print("Failed to prepare insert statement")
        return json.encode({ Code = 'DB_PREPARE_FAILED' })
    end

    -- bind values for INSERT statement
    stmt:bind_values(table.unpack(params))

    local step_status = stmt:step()
    if step_status ~= sqlite3.OK and step_status ~= sqlite3.DONE and step_status ~= sqlite3.ROW then
        stmt:finalize()
        print("Error: " .. Db:errmsg())
        print("SQL" .. sql)
        ao.send({
            Target = reply_to,
            Action = 'DB_STEP_CODE',
            Tags = {
                Status = 'ERROR',
                Message = 'sqlite step error'
            },
            Data = { DB_STEP_MSG = step_status }
        })
        return json.encode({ Code = step_status })
    end
    stmt:finalize()
    return
end

Handlers.add(H_PREPARE_DB, Handlers.utils.hasMatchingTag('Action', H_PREPARE_DB),
        handle_prepare_db)

-- Data - { Address }
Handlers.add(H_GET_USER_ZONES, Handlers.utils.hasMatchingTag('Action', H_GET_USER_ZONES),
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
Handlers.add(H_CREATE_ZONE, Handlers.utils.hasMatchingTag('Action', H_CREATE_ZONE),
        handle_create_zone )

Handlers.add(H_META_SET, Handlers.utils.hasMatchingTag('Action', H_META_SET),
        handle_meta_set)

Handlers.add(H_ROLE_SET, Handlers.utils.hasMatchingTag('Action', H_ROLE_SET),
        handle_update_role)

Handlers.add(H_META_GET, Handlers.utils.hasMatchingTag('Action', H_META_SET),
        handle_meta_get)

Handlers.add(H_READ_AUTH, Handlers.utils.hasMatchingTag('Action', H_READ_AUTH),
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
