local json = require('json')
local sqlite3 = require('lsqlite3')

Db = Db or sqlite3.open_memory()

local HandlerRoles = {
    ['Update-Profile'] = {'Owner', 'Admin'},
    ['Add-Uploaded-Asset'] = {'Owner', 'Admin', 'Contributor'},
    ['Add-Collection'] = {'Owner', 'Admin', 'Contributor'},
    ['Update-Collection-Sort'] = {'Owner', 'Admin'},
    ['Transfer'] = {'Owner', 'Admin'},
    ['Debit-Notice'] = {'Owner', 'Admin'},
    ['Credit-Notice'] = {'Owner', 'Admin'},
    ['Action-Response'] = {'Owner', 'Admin'},
    ['Run-Action'] = {'Owner', 'Admin'},
    ['Proxy-Action'] = {'Owner', 'Admin'},
    ['Update-Role'] = {'Owner', 'Admin'}
}

local function decode_message_data(data)
    local status, decoded_data = pcall(json.decode, data)
    if not status or type(decoded_data) ~= 'table' then
        return false, nil
    end
    return true, decoded_data
end

local function is_authorized(profile_id, user_id, roles)
    if not profile_id then
        return false
    end
    local query = [[
        SELECT role
        FROM ao_profile_authorization
        WHERE profile_id = ? AND delegate_address = ?
        LIMIT 1
    ]]
    local stmt = Db:prepare(query)
    stmt:bind_values(profile_id, user_id)
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

local function process_profile_action(msg)

    local decode_check, data = decode_message_data(msg.Data)
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

    local tags = msg.Tags or {}
    local action = msg.Action
    local reply_to = tags.ProfileProcess or msg.Target
    local profile_process_data_or_tag = tags.ProfileProcess or decode_check and data.ProfileProcess or nil
    -- handle legacy authorized_address tag
    local legacy_authorized_address = tags.AuthorizedAddress or decode_check and data.AuthorizedAddress or nil
    -- new api: profile_id is msg id on spawn or ProfileProcess tag/data in update TODO
    local profile_id = legacy_authorized_address and msg.From or profile_process_data_or_tag or msg.Id
    local user_id = legacy_authorized_address or msg.From -- (assigned)

    -- new api: after spawn, updates assigned will need to include ProfileProcess tag or data
    local is_actual_create = not profile_process_data_or_tag and action == "Create-Profile"
    -- handle legacy "every update is create action" bug by checking roles first
    if (action == "Create-Profile") then
        local check = Db:prepare('SELECT 1 FROM ao_profile_authorization WHERE delegate_address = ? LIMIT 1')
        check:bind_values(msg.From)
        if check:step() ~= sqlite3.ROW then
            is_actual_create = true
            local insert_auth = Db:prepare(
                    'INSERT INTO ao_profile_authorization (profile_id, delegate_address, role) VALUES (?, ?, ?)')
            insert_auth:bind_values(profile_id, user_id, 'Admin')
            insert_auth:step()
            insert_auth:finalize()
        else
            is_actual_create = false
        end
    end

    if not is_actual_create and not is_authorized(profile_id, user_id, HandlerRoles['Update-Profile']) then
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
        id = profile_id,
        username = tags.UserName or decode_check and data.UserName or nil,
        profile_image = tags.ProfileImage or decode_check and data.ProfileImage or nil,
        cover_image = tags.CoverImage or decode_check and data.CoverImage or nil,
        description = tags.Description or decode_check and data.Description or nil,
        display_name = tags.DisplayName or decode_check and data.DisplayName or nil,
        date_updated = msg.Timestamp,
        date_created = is_actual_create and msg.Timestamp or nil
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

        local sql = "INSERT INTO ao_profile_metadata (" .. table.concat(columns, ", ") .. ")"
        sql = sql .. " VALUES (" .. table.concat(placeholders, ", ") .. ")"

        return sql
    end

    local function generateUpdateQuery()
        -- first create setclauses for everything but id
        for key, val in pairs(metadataValues) do
            if val ~= nil and val ~= 'id' then
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
            end
        end
        -- now build querystring
        local sql = "UPDATE ao_profile_metadata SET "
        for i, v in ipairs(columns) do
            sql = sql .. columns[i] .. " = " .. placeholders[i]
            if i ~= #columns then
                sql = sql .. ","
            end
        end
        sql = sql .. " WHERE id = ?"
        return sql
    end
    -- A spawn create will have data including UserName
    -- A legacy create will only
    -- new api: profile assigns the spawn tx to the registry, which contains the data
    -- legacy api: profile send()s new message to registry with the data and authorized_address (user_id) of admin
    if not is_actual_create or (is_actual_create and (tags.UserName or decode_check and data.UserName)) then
        local sql = is_actual_create and generateInsertQuery() or generateUpdateQuery()
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

        if is_actual_create then
            -- bind values for INSERT statement
            stmt:bind_values(table.unpack(params))
        else
            -- bind values for UPDATE statement (id is last)
            table.insert(params, profile_id)
            stmt:bind_values(table.unpack(params))
        end

        local step_status = stmt:step()
        if step_status ~= sqlite3.OK and step_status ~= sqlite3.DONE and step_status ~= sqlite3.ROW then
            stmt:finalize()
            print("Error: " .. Db:errmsg())
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

    end

    ao.send({
        Target = reply_to,
        Action = 'Success',
        Tags = {
            Status = 'Success',
            Message = 'Record Inserted'
        },
        Data = json.encode(metadataValues)
    })


end

-- Verisioned handler definitions and processing logic
local HANDLER_VERSIONS = {
    process_profile_action = {
        ["0.0.0"] = process_profile_action_v000,
        ["0.0.1"] = process_profile_action_v001,
    },
}

local function version_dispatcher(action, msg, arg)
    local decode_check, data = decode_message_data(msg.Data)
    -- if the client doesn't pass a version, assume original code.
    local version = msg.Tags and msg.Tags.ProfileVersion or "0.0.0"
    local handlers = HANDLER_VERSIONS[action]

    if handlers and handlers[version] then
        if arg then
            handlers[version](msg, arg)
        else
            handlers[version](msg)
        end
    else
        ao.send({
            Target = msg.Target or msg.From,
            Action = 'Versioning-Error',
            Tags = {
                Status = 'Error',
                Message = string.format('Unsupported version %s for action %s', version, action)
            }
        })
    end
end

-- Handlers.add('migrate-database', ... ,  Db:exec [[ ALTER TABLE _ ADD new_field type ]]

Handlers.add('Prepare-Database', Handlers.utils.hasMatchingTag('Action', 'Prepare-Database'),
        function(msg)
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

            --todo create tables for: languages, following, followed, topic-tags, locations, external_links, external_wallets

            Db:exec [[
                CREATE TABLE IF NOT EXISTS ao_profile_metadata (
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
                CREATE TABLE IF NOT EXISTS ao_profile_authorization (
                    profile_id TEXT NOT NULL,
                    delegate_address TEXT NOT NULL,
                    role TEXT NOT NULL,
                    PRIMARY KEY (profile_id, delegate_address),
                    FOREIGN KEY (profile_id) REFERENCES ao_profile_metadata (id) ON DELETE CASCADE
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
        end)

-- Data - { ProfileIds [] }
Handlers.add('Get-Metadata-By-ProfileIds', Handlers.utils.hasMatchingTag('Action', 'Get-Metadata-By-ProfileIds'),
        function(msg)

            local decode_check, data = decode_message_data(msg.Data)

            if decode_check and data then
                if not data.ProfileIds then
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
                if #data.ProfileIds > 0 then
                    local placeholders = {}

                    for _, id in ipairs(data.ProfileIds) do
                        table.insert(placeholders, "?")
                    end

                    if #placeholders > 0 then
                        local stmt = Db:prepare([[
                        SELECT *
                        FROM ao_profile_metadata
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

                        stmt:bind_values(table.unpack(data.ProfileIds))

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
                            Message = 'No ProfileIds provided or the list is empty.'
                        }
                    })
                    print('No ProfileIds provided or the list is empty.')
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
                                'Data must be an object - { ProfileIds }')
                    }
                })
            end
        end)

-- Data - { Address }
Handlers.add('Get-Profiles-By-Delegate', Handlers.utils.hasMatchingTag('Action', 'Get-Profiles-By-Delegate'),
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

                local associated_profiles = {}

                local authorization_lookup = Db:prepare([[
                    SELECT profile_id, delegate_address, role
                        FROM ao_profile_authorization
                        WHERE delegate_address = ?
			    ]])

                authorization_lookup:bind_values(data.Address)

                for row in authorization_lookup:nrows() do
                    table.insert(associated_profiles, {
                        ProfileId = row.profile_id,
                        CallerAddress = row.delegate_address,
                        Role = row.role
                    })
                end

                authorization_lookup:finalize()

                if #associated_profiles > 0 then
                    ao.send({
                        Target = msg.From,
                        Action = 'Profile-Success',
                        Tags = {
                            Status = 'Success',
                            Message = 'Associated profiles fetched'
                        },
                        Data = json.encode(associated_profiles)
                    })
                else
                    ao.send({
                        Target = msg.From,
                        Action = 'Profile-Error',
                        Tags = {
                            Status = 'Error',
                            Message = 'This wallet address is not associated with a profile'
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

-- Create-Profile Handler (Original spawned profile message)
Handlers.add('Create-Profile', Handlers.utils.hasMatchingTag('Action', 'Create-Profile'),
        process_profile_action)

-- Update-Profile Handler
Handlers.add('Update-Profile', Handlers.utils.hasMatchingTag('Action', 'Update-Profile'),
        process_profile_action)

-- Data - { Id, Op, Role? }
Handlers.add('Update-Role', Handlers.utils.hasMatchingTag('Action', 'Update-Role'),
        function(msg)
            local decode_check, data = decode_message_data(msg.Data)

            if decode_check and data then
                if not data.Id or not data.Op then
                    ao.send({
                        Target = msg.From,
                        Action = 'Input-Error',
                        Tags = {
                            Status = 'Error',
                            Message = 'Invalid arguments, required { Id, Op, Role }'
                        }
                    })
                    return
                end
            end

            local tags = msg.Tags or {}
            local reply_to = tags.ProfileProcess or msg.Target
            local profile_process_data_or_tag = tags.ProfileProcess or decode_check and data.ProfileProcess or nil
            -- assigned message from user, to profile
            if not is_authorized(profile_process_data_or_tag, msg.From, HandlerRoles['Update-Role']) then
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

            -- handle add, update, or remove Ops
            local stmt
            if data.Op == 'Add' then
                stmt = Db:prepare(
                        'INSERT INTO ao_profile_authorization (profile_id, delegate_address, role) VALUES (?, ?, ?)')
                stmt:bind_values(profile_process_data_or_tag, data.Id, data.Role)

            elseif data.Op == 'Update' then
                stmt = Db:prepare(
                        'UPDATE ao_profile_authorization SET role = ? WHERE profile_id = ? AND delegate_address = ?')
                stmt:bind_values(data.Role, profile_process_data_or_tag, data.Id)

            elseif data.Op == 'Remove' then
                stmt = Db:prepare(
                        'DELETE FROM ao_profile_authorization WHERE profile_id = ? AND delegate_address = ?')
                stmt:bind_values(profile_process_data_or_tag, data.Id)
            end

            local step_status = stmt:step()
            if step_status ~= sqlite3.OK and step_status ~= sqlite3.DONE and step_status ~= sqlite3.ROW then
                print("Error: " .. Db:errmsg())
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

            ao.send({
                Target = reply_to,
                Action = 'Success',
                Tags = {
                    Status = 'Success',
                    Message = 'Auth Record Inserted'
                },
                Data = json.encode(queryValues)
            })
        end
)


Handlers.add('Count-Profiles', Handlers.utils.hasMatchingTag('Action', 'Count-Profiles'),
        function(msg)
            local count_sql = [[
                                SELECT COUNT(*)
                                FROM ao_profile_metadata
                    ]]
            local stmt = Db:prepare(count_sql)
            local result = stmt:step()
            local count = 0

            if result == sqlite3.ROW then
                count = stmt:get_value(0)
            else
                count = -1
            end

            ao.send({
                Target = msg.From,
                Action = 'Count-Profiles-Success',
                Tags = {
                    Status = 'Success',
                    Message = 'Profiles Counted',
                },
                Data = json.encode({ Count = count })
            })
            return json.encode({ Count = count })
        end)

Handlers.add('Read-Metadata', Handlers.utils.hasMatchingTag('Action', 'Read-Metadata'),
        function(msg)
            local metadata = {}
            local status, err = pcall(function()
                for row in Db:nrows('SELECT id, username, profile_image, cover_image, description, display_name, date_updated, date_created FROM ao_profile_metadata') do
                    table.insert(metadata, {
                        id = row.id,
                        Username = row.username,
                        ProfileImage = row.profile_image,
                        CoverImage = row.cover_image,
                        Description = row.description,
                        DisplayName = row.display_name,
                        DateCreated = row.date_created,
                        DateUpdated = row.date_updated
                    })
                end
            end)
            if err or not status then
                print("Error: ", err)
                return
            end

            if foundRows == false then
                print('No rows found matching the criteria.')
            end
            ao.send({
                Target = msg.From,
                Action = 'Read-Metadata-Success',
                Tags = {
                    Status = 'Success',
                    Message = 'Metadata retrieved',
                },
                Data = json.encode(metadata)
            })

            return json.encode(metadata)
        end)

Handlers.add('Read-Auth', Handlers.utils.hasMatchingTag('Action', 'Read-Auth'),
        function(msg)
            local metadata = {}
            local string = ''
            local foundRows = false
            local status, err = pcall(function()
                for row in Db:nrows('SELECT profile_id, delegate_address, role FROM ao_profile_authorization') do
                    foundRows = true
                    table.insert(metadata, {
                        ProfileId = row.profile_id,
                        CallerAddress = row.delegate_address,
                        Role = row.role,
                    })
                    string = string .. "ProfileId: " .. row.profile_id .. " CallerAddress: " .. row.delegate_address .. " Role: " .. row.role .. "\n"
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
                    Message = 'Metadata retrieved',
                },
                Data = json.encode(metadata)
            })
            return json.encode(metadata)
        end)

Handlers.add('Read-Profile', Handlers.utils.hasMatchingTag('Action', 'Read-Profile'),
        function(msg)
            local decode_check, data = decode_message_data(msg.Data)

            if decode_check ~= true then
                ao.send({
                    Target = msg.From,
                    Action = 'DB_CODE',
                    Tags = {
                        Status = 'DECODE_FAILED',
                        Message = "Failed to decode data"
                    },
                    Data = { Code = "DECODE_FAILED" }
                })
                return
            end

            local selectsql = [[
                        SELECT *
                        FROM ao_profile_metadata
                        WHERE id = ?
            ]]

            local row
            local select_stmt = Db:prepare(selectsql)
            local bind = -1
            if select_stmt then
                bind = select_stmt:bind_values(data.ProfileId)
            else
                ao.send({
                    Target = msg.From,
                    Action = 'DB_CODE',
                    Tags = {
                        Status = 'DB_PREPARE_FAILED',
                        Message = "DB PREPARED QUERY FAILED"
                    },
                    Data = { Code = "Failed to prepare select statement" }
                })
                print("Failed to prepare select statement")
                return json.encode({ Code = 'DB_PREPARE_FAILED' })
            end

            local step_status = select_stmt:step()
            if step_status ~= sqlite3.OK and step_status ~= sqlite3.DONE and step_status ~= sqlite3.ROW then
                ao.send({
                    Target = msg.From,
                    Action = 'DB_STEP_CODE',
                    Tags = {
                        Status = 'ERROR',
                        Message = 'sqlite step error'
                    },
                    Data = { DB_STEP_MSG = step_status }
                })
                return json.encode({ Code = step_status })
            end

            row = select_stmt:get_named_values()
            local metadata = {
                ProfileId = row.id,
                Username = row.username,
                ProfileImage = row.profile_image,
                CoverImage = row.cover_image,
                Description = row.description,
                DisplayName = row.display_name,
                DateCreated = row.date_created,
                DateUpdated = row.date_updated
            }
            ao.send({
                Target = msg.From,
                Action = 'Success',
                Tags = {
                    Status = 'Success',
                    Message = 'Record Inserted'
                },
                Data = json.encode(metadata)
            })
        end)
