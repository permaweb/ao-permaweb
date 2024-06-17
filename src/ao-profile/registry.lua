local json = require('json')
local sqlite3 = require('lsqlite3')

Db = Db or sqlite3.open_memory()

local function decode_message_data(data)
    local status, decoded_data = pcall(json.decode, data)
    if not status or type(decoded_data) ~= 'table' then
        return false, nil
    end
    return true, decoded_data
end

local function is_authorized(profile_id, address)
    if not profile_id then
        return true
    end
    local query = [[
        SELECT role
        FROM ao_profile_authorization
        WHERE profile_id = ? AND delegate_address = ?
        LIMIT 1
    ]]
    local stmt = Db:prepare(query)
    stmt:bind_values(profile_id, address)
    local authorized = false
    for row in stmt:nrows() do
        authorized = true
        break
    end
    stmt:finalize()
    return authorized
end

local function process_profile_action(msg, profile_id_to_check_for_update)
    if profile_id_to_check_for_update and not is_authorized(profile_id_to_check_for_update, msg.From) then
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

    local tags = msg.Tags or {}

    local queryValues = {
        id = profile_id_to_check_for_update or msg.From,
        username = tags.UserName or data.UserName or nil,
        profile_image = tags.ProfileImage or data.ProfileImage or nil,
        cover_image = tags.CoverImage or data.CoverImage or nil,
        description = tags.Description or data.Description or nil,
        display_name = tags.DisplayName or data.DisplayName or nil,
        date_updated = msg.Timestamp,
        date_created = not profile_id_to_check_for_update and msg.Timestamp or nil
    }

    local columns = {}
    local placeholders = {}
    local params = {}

    local function generateInsertQuery()
        for key, val in pairs(queryValues) do
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
        for key, val in pairs(queryValues) do
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

    local stmt = profile_id_to_check_for_update and Db:prepare(generateUpdateQuery()) or Db:prepare(generateInsertQuery())

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

    if profile_id_to_check_for_update then
        -- bind values for UPDATE statement (id is last)
        table.insert(params, profile_id_to_check_for_update)
        stmt:bind_values(table.unpack(params))
    else
        -- bind values for INSERT statement
        stmt:bind_values(table.unpack(params))
    end

    local step_status = stmt:step()
    if step_status ~= sqlite3.OK and step_status ~= sqlite3.DONE and step_status ~= sqlite3.ROW then
        print("Error: " .. Db:errmsg())
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

    ao.send({
        Target = msg.From,
        Action = 'Success',
        Tags = {
            Status = 'Success',
            Message = 'Record Inserted'
        },
        Data = json.encode(queryValues)
    })

    stmt:finalize()
    if (not profile_id_to_check_for_update) then
        local check = Db:prepare('SELECT 1 FROM ao_profile_authorization WHERE delegate_address = ? LIMIT 1')
        check:bind_values(msg.From)
        if check:step() ~= sqlite3.ROW then
            local insert_auth = Db:prepare(
                    'INSERT INTO ao_profile_authorization (profile_id, delegate_address, role) VALUES (?, ?, ?)')
            insert_auth:bind_values(msg.From, data.AuthorizedAddress, 'Admin')
            insert_auth:step()
        end
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
Handlers.add('Get-Metadata-By-Profile-Ids', Handlers.utils.hasMatchingTag('Action', 'Get-Metadata-By-Profile-Ids'),
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

-- Create-Profile Handler
Handlers.add('Create-Profile', Handlers.utils.hasMatchingTag('Action', 'Create-Profile'),
        function(msg)
            process_profile_action(msg, nil)
        end)

-- Update-Profile Handler
Handlers.add('Update-Profile', Handlers.utils.hasMatchingTag('Action', 'Update-Profile'),
        function(msg)
            process_profile_action(msg, msg.Target)
        end)

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
                for row in Db:nrows('SELECT username, profile_image, cover_image, description, display_name, date_updated, date_created FROM ao_profile_metadata') do
                    table.insert(metadata, {
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

Handlers.add('Read-Auth', Handlers.utils.hasMatchingTag('Action', 'Read-Auth'),
        function(msg)
            local metadata = {}
            local status, err = pcall(function()
                for row in Db:nrows('SELECT profile_id, delegate_address, role FROM ao_profile_authorization') do
                    table.insert(metadata, {
                        ProfileId = row.profile_id,
                        MaybeDelegatedAddress = row.delegate_address,
                        Role = row.role,
                    })
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
