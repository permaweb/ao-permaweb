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
-- commented out in src to not exit bundle:
-- return "📦 Loaded APM Client"

 -- ENDFILE 

package.loaded["pkg-api"] = nil
package.loaded["storage-vanilla"] = nil
package.loaded["storage-db"] = nil
do
    local _ENV = _ENV
    package.preload["pkg-api"] = function(...)
        local arg = _G.arg;
        local json = require("json")
        local bint = require(".bint")(256)

        local function newmodule(pkg)
            --[[
              {
                topic: string = eventCheckFn: () => boolean
              }
            ]]
            pkg.TopicsAndChecks = pkg.TopicsAndChecks or {}

            pkg.PAYMENT_TOKEN = '8p7ApPZxC_37M06QHVejCQrKsHbcJEerd3jWNkDUWPQ'
            pkg.PAYMENT_TOKEN_TICKER = 'BRKTST'


            -- REGISTRATION

            function pkg.registerSubscriber(processId, whitelisted)
                local subscriberData = pkg._storage.getSubscriber(processId)

                if subscriberData then
                    error('Process ' ..
                            processId ..
                            ' is already registered as a subscriber.')
                end

                pkg._storage.registerSubscriber(processId, whitelisted)

                ao.send({
                    Target = processId,
                    Action = 'Subscriber-Registration-Confirmation',
                    Whitelisted = tostring(whitelisted),
                    OK = 'true'
                })
            end

            function pkg.handleRegisterSubscriber(msg)
                local processId = msg.From

                pkg.registerSubscriber(processId, false)
                pkg._subscribeToTopics(msg, processId)
            end

            function pkg.handleRegisterWhitelistedSubscriber(msg)
                if msg.From ~= Owner and msg.From ~= ao.id then
                    error('Only the owner or the process itself is allowed to register whitelisted subscribers')
                end

                local processId = msg.Tags['Subscriber-Process-Id']

                if not processId then
                    error('Subscriber-Process-Id is required')
                end

                pkg.registerSubscriber(processId, true)
                pkg._subscribeToTopics(msg, processId)
            end

            function pkg.handleGetSubscriber(msg)
                local processId = msg.Tags['Subscriber-Process-Id']
                local subscriberData = pkg._storage.getSubscriber(processId)
                ao.send({
                    Target = msg.From,
                    Data = json.encode(subscriberData)
                })
            end

            pkg.updateBalance = function(processId, amount, isCredit)
                local subscriber = pkg._storage.getSubscriber(processId)
                if not isCredit and not subscriber then
                    error('Subscriber ' .. processId .. ' is not registered. Register first, then make a payment')
                end

                if not isCredit and bint(subscriber.balance) < bint(amount) then
                    error('Insufficient balance for subscriber ' .. processId .. ' to be debited')
                end

                pkg._storage.updateBalance(processId, amount, isCredit)
            end

            function pkg.handleReceivePayment(msg)
                local processId = msg.Tags["X-Subscriber-Process-Id"]

                local error
                if not processId then
                    error = "No subscriber specified"
                end

                if msg.From ~= pkg.PAYMENT_TOKEN then
                    error = "Wrong token. Payment token is " .. (pkg.PAYMENT_TOKEN or "?")
                end

                if error then
                    ao.send({
                        Target = msg.From,
                        Action = 'Transfer',
                        Recipient = msg.Sender,
                        Quantity = msg.Quantity,
                        ["X-Action"] = "Subscription-Payment-Refund",
                        ["X-Details"] = error
                    })

                    ao.send({
                        Target = msg.Sender,
                        ["Response-For"] = "Pay-For-Subscription",
                        OK = "false",
                        Data = error
                    })
                    return
                end

                pkg.updateBalance(msg.Tags.Sender, msg.Tags.Quantity, true)

                ao.send({
                    Target = msg.Sender,
                    ["Response-For"] = "Pay-For-Subscription",
                    OK = "true"
                })
                print('Received subscription payment from ' ..
                        msg.Tags.Sender .. ' of ' .. msg.Tags.Quantity .. ' ' .. msg.From .. " (" .. pkg.PAYMENT_TOKEN_TICKER .. ")")
            end

            function pkg.handleSetPaymentToken(msg)
                pkg.PAYMENT_TOKEN = msg.Tags.Token
            end

            -- TOPICS

            function pkg.configTopicsAndChecks(cfg)
                pkg.TopicsAndChecks = cfg
            end

            function pkg.getTopicsInfo()
                local topicsInfo = {}
                for topic, _ in pairs(pkg.TopicsAndChecks) do
                    local topicInfo = pkg.TopicsAndChecks[topic]
                    topicsInfo[topic] = {
                        description = topicInfo.description,
                        returns = topicInfo.returns,
                        subscriptionBasis = topicInfo.subscriptionBasis
                    }
                end

                return topicsInfo
            end

            function pkg.getInfo()
                return {
                    paymentTokenTicker = pkg.PAYMENT_TOKEN_TICKER,
                    paymentToken = pkg.PAYMENT_TOKEN,
                    topics = pkg.getTopicsInfo()
                }
            end

            -- SUBSCRIPTIONS

            function pkg._subscribeToTopics(msg, processId)
                assert(msg.Tags['Topics'], 'Topics is required')

                local topics = json.decode(msg.Tags['Topics'])

                pkg.onlyRegisteredSubscriber(processId)

                pkg._storage.subscribeToTopics(processId, topics)

                local subscriber = pkg._storage.getSubscriber(processId)

                ao.send({
                    Target = processId,
                    ['Response-For'] = 'Subscribe-To-Topics',
                    OK = "true",
                    ["Updated-Topics"] = json.encode(subscriber.topics)
                })
            end

            -- same for regular and whitelisted subscriptions - the subscriber must call it
            function pkg.handleSubscribeToTopics(msg)
                local processId = msg.From
                pkg._subscribeToTopics(msg, processId)
            end

            function pkg.unsubscribeFromTopics(processId, topics)
                pkg.onlyRegisteredSubscriber(processId)

                pkg._storage.unsubscribeFromTopics(processId, topics)

                local subscriber = pkg._storage.getSubscriber(processId)

                ao.send({
                    Target = processId,
                    ["Response-For"] = 'Unsubscribe-From-Topics',
                    OK = "true",
                    ["Updated-Topics"] = json.encode(subscriber.topics)
                })
            end

            function pkg.handleUnsubscribeFromTopics(msg)
                assert(msg.Tags['Topics'], 'Topics is required')

                local processId = msg.From
                local topics = msg.Tags['Topics']

                pkg.unsubscribeFromTopics(processId, topics)
            end

            -- NOTIFICATIONS

            -- core dispatch functionality

            function pkg.notifySubscribers(topic, payload)
                local targets = pkg._storage.getTargetsForTopic(topic)
                for _, target in ipairs(targets) do
                    ao.send({
                        Target = target,
                        Action = 'Notify-On-Topic',
                        Topic = topic,
                        Data = json.encode(payload)
                    })
                end
            end

            -- notify without check

            function pkg.notifyTopics(topicsAndPayloads, timestamp)
                for topic, payload in pairs(topicsAndPayloads) do
                    payload.timestamp = timestamp
                    pkg.notifySubscribers(topic, payload)
                end
            end

            function pkg.notifyTopic(topic, payload, timestamp)
                return pkg.notifyTopics({
                    [topic] = payload
                }, timestamp)
            end

            -- notify with configured checks

            function pkg.checkNotifyTopics(topics, timestamp)
                for _, topic in ipairs(topics) do
                    local shouldNotify = pkg.TopicsAndChecks[topic].checkFn()
                    if shouldNotify then
                        local payload = pkg.TopicsAndChecks[topic].payloadFn()
                        payload.timestamp = timestamp
                        pkg.notifySubscribers(topic, payload)
                    end
                end
            end

            function pkg.checkNotifyTopic(topic, timestamp)
                return pkg.checkNotifyTopics({ topic }, timestamp)
            end

            -- HELPERS

            pkg.onlyRegisteredSubscriber = function(processId)
                local subscriberData = pkg._storage.getSubscriber(processId)
                if not subscriberData then
                    error('process ' .. processId .. ' is not registered as a subscriber')
                end
            end
        end

        return newmodule
    end
end

do
    local _ENV = _ENV
    package.preload["storage-db"] = function(...)
        local arg = _G.arg;
        local sqlite3 = require("lsqlite3")
        local bint = require(".bint")(256)
        local json = require("json")

        local function newmodule(pkg)
            local mod = {}
            pkg._storage = mod

            local sql = {}

            DB = DB or sqlite3.open_memory()

            sql.create_subscribers_table = [[
    CREATE TABLE IF NOT EXISTS subscribers (
        process_id TEXT PRIMARY KEY,
        topics TEXT,  -- treated as JSON (an array of strings)
        balance TEXT,
        whitelisted INTEGER NOT NULL, -- 0 or 1 (false or true)
    );
  ]]

            local function createTableIfNotExists()
                DB:exec(sql.create_subscribers_table)
                print("Err: " .. DB:errmsg())
            end

            createTableIfNotExists()

            -- REGISTRATION & BALANCES

            ---@param whitelisted boolean
            function mod.registerSubscriber(processId, whitelisted)
                local stmt = DB:prepare [[
    INSERT INTO subscribers (process_id, balance, whitelisted)
    VALUES (:process_id, :balance, :whitelisted)
  ]]
                if not stmt then
                    error("Failed to prepare SQL statement for registering process: " .. DB:errmsg())
                end
                stmt:bind_names({
                    process_id = processId,
                    balance = "0",
                    whitelisted = whitelisted and 1 or 0
                })
                local _, err = stmt:step()
                stmt:finalize()
                if err then
                    error("Err: " .. DB:errmsg())
                end
            end

            function mod.getSubscriber(processId)
                local stmt = DB:prepare [[
    SELECT * FROM subscribers WHERE process_id = :process_id
  ]]
                if not stmt then
                    error("Failed to prepare SQL statement for checking subscriber: " .. DB:errmsg())
                end
                stmt:bind_names({ process_id = processId })
                local result = sql.queryOne(stmt)
                if result then
                    result.whitelisted = result.whitelisted == 1
                    result.topics = json.decode(result.topics)
                end
                return result
            end

            function sql.updateBalance(processId, amount, isCredit)
                local currentBalance = bint(sql.getBalance(processId))
                local diff = isCredit and bint(amount) or -bint(amount)
                local newBalance = tostring(currentBalance + diff)

                local stmt = DB:prepare [[
    UPDATE subscribers
    SET balance = :new_balance
    WHERE process_id = :process_id
  ]]
                if not stmt then
                    error("Failed to prepare SQL statement for updating balance: " .. DB:errmsg())
                end
                stmt:bind_names({
                    process_id = processId,
                    new_balance = newBalance,
                })
                local result, err = stmt:step()
                stmt:finalize()
                if err then
                    error("Error updating balance: " .. DB:errmsg())
                end
            end

            function sql.getBalance(processId)
                local stmt = DB:prepare [[
    SELECT * FROM subscribers WHERE process_id = :process_id
  ]]
                if not stmt then
                    error("Failed to prepare SQL statement for getting balance entry: " .. DB:errmsg())
                end
                stmt:bind_names({ process_id = processId })
                local row = sql.queryOne(stmt)
                return row and row.balance or "0"
            end

            -- SUBSCRIPTION

            function sql.subscribeToTopics(processId, topics)
                -- add the topics to the existing topics while avoiding duplicates
                local stmt = DB:prepare [[
    UPDATE subscribers
    SET topics = (
        SELECT json_group_array(topic)
        FROM (
            SELECT json_each.value as topic
            FROM subscribers, json_each(subscribers.topics)
            WHERE process_id = :process_id

            UNION

            SELECT json_each.value as topic
            FROM json_each(:topics)
        )
    )
    WHERE process_id = :process_id;
  ]]
                if not stmt then
                    error("Failed to prepare SQL statement for subscribing to topics: " .. DB:errmsg())
                end
                stmt:bind_names({
                    process_id = processId,
                    topic = topics
                })
                local _, err = stmt:step()
                stmt:finalize()
                if err then
                    error("Err: " .. DB:errmsg())
                end
            end

            function sql.unsubscribeFromTopics(processId, topics)
                -- remove the topics from the existing topics
                local stmt = DB:prepare [[
    UPDATE subscribers
    SET topics = (
        SELECT json_group_array(topic)
        FROM (
            SELECT json_each.value as topic
            FROM subscribers, json_each(subscribers.topics)
            WHERE process_id = :process_id

            EXCEPT

            SELECT json_each.value as topic
            FROM json_each(:topics)
        )
    )
    WHERE process_id = :process_id;
  ]]
                if not stmt then
                    error("Failed to prepare SQL statement for unsubscribing from topics: " .. DB:errmsg())
                end
                stmt:bind_names({
                    process_id = processId,
                    topic = topics
                })
                local _, err = stmt:step()
                stmt:finalize()
                if err then
                    error("Err: " .. DB:errmsg())
                end
            end

            -- NOTIFICATIONS

            function mod.activationCondition()
                return [[
    (subs.whitelisted = 1 OR subs.balance <> "0")
  ]]
            end

            function sql.getTargetsForTopic(topic)
                local activationCondition = mod.activationCondition()
                local stmt = DB:prepare [[
    SELECT process_id
    FROM subscribers as subs
    WHERE json_contains(topics, :topic) AND ]] .. activationCondition

                if not stmt then
                    error("Failed to prepare SQL statement for getting notifiable subscribers: " .. DB:errmsg())
                end
                stmt:bind_names({ topic = topic })
                return sql.queryMany(stmt)
            end

            -- UTILS

            function sql.queryMany(stmt)
                local rows = {}
                for row in stmt:nrows() do
                    table.insert(rows, row)
                end
                stmt:reset()
                return rows
            end

            function sql.queryOne(stmt)
                return sql.queryMany(stmt)[1]
            end

            function sql.rawQuery(query)
                local stmt = DB:prepare(query)
                if not stmt then
                    error("Err: " .. DB:errmsg())
                end
                return sql.queryMany(stmt)
            end

            return sql
        end

        return newmodule
    end
end

do
    local _ENV = _ENV
    package.preload["storage-vanilla"] = function(...)
        local arg = _G.arg;
        local bint = require ".bint"(256)
        local json = require "json"
        local utils = require ".utils"

        local function newmodule(pkg)
            local mod = {
                Subscribers = pkg._storage and pkg._storage.Subscribers or {} -- we preserve state from previously used package
            }

            --[[
              mod.Subscribers :
              {
                processId: ID = {
                  topics: string, -- JSON (string representation of a string[])
                  balance: string,
                  whitelisted: number -- 0 or 1 -- if 1, receives data without the need to pay
                }
              }
            ]]

            pkg._storage = mod

            -- REGISTRATION & BALANCES

            function mod.registerSubscriber(processId, whitelisted)
                mod.Subscribers[processId] = mod.Subscribers[processId] or {
                    balance = "0",
                    topics = json.encode({}),
                    whitelisted = whitelisted and 1 or 0,
                }
            end

            function mod.getSubscriber(processId)
                local data = json.decode(json.encode(mod.Subscribers[processId]))
                if data then
                    data.whitelisted = data.whitelisted == 1
                    data.topics = json.decode(data.topics)
                end
                return data
            end

            function mod.updateBalance(processId, amount, isCredit)
                local current = bint(mod.Subscribers[processId].balance)
                local diff = isCredit and bint(amount) or -bint(amount)
                mod.Subscribers[processId].balance = tostring(current + diff)
            end

            -- SUBSCRIPTIONS

            function mod.subscribeToTopics(processId, topics)
                local existingTopics = json.decode(mod.Subscribers[processId].topics)

                for _, topic in ipairs(topics) do
                    if not utils.includes(topic, existingTopics) then
                        table.insert(existingTopics, topic)
                    end
                end
                mod.Subscribers[processId].topics = json.encode(existingTopics)
            end

            function mod.unsubscribeFromTopics(processId, topics)
                local existingTopics = json.decode(mod.Subscribers[processId].topics)
                for _, topic in ipairs(topics) do
                    existingTopics = utils.filter(
                            function(t)
                                return t ~= topic
                            end,
                            existingTopics
                    )
                end
                mod.Subscribers[processId].topics = json.encode(existingTopics)
            end

            -- NOTIFICATIONS

            function mod.getTargetsForTopic(topic)
                local targets = {}
                for processId, v in pairs(mod.Subscribers) do
                    local mayReceiveNotification = mod.hasEnoughBalance(processId) or v.whitelisted == 1
                    if mod.isSubscribedTo(processId, topic) and mayReceiveNotification then
                        table.insert(targets, processId)
                    end
                end
                return targets
            end

            -- HELPERS

            mod.hasEnoughBalance = function(processId)
                return mod.Subscribers[processId] and bint(mod.Subscribers[processId].balance) > 0
            end

            mod.isSubscribedTo = function(processId, topic)
                local subscription = mod.Subscribers[processId]
                if not subscription then
                    return false
                end

                local topics = json.decode(subscription.topics)
                for _, subscribedTopic in ipairs(topics) do
                    if subscribedTopic == topic then
                        return true
                    end
                end
                return false
            end
        end

        return newmodule
    end
end

local function newmodule(cfg)
    local isInitial = Subscribable == nil

    -- for bug-prevention, force the package user to be explicit on initial require
    assert(not isInitial or cfg and cfg.useDB ~= nil,
            "cfg.useDb is required: are you using the sqlite version (true) or the Lua-table based version (false)?")

    local pkg = Subscribable or
            { useDB = cfg.useDB } -- useDB can only be set on initialization; afterwards it remains the same

    pkg.version = '1.3.8'

    -- pkg acts like the package "global", bundling the state and API functions of the package

    if pkg.useDB then
        require "storage-db"(pkg)
    else
        require "storage-vanilla"(pkg)
    end

    require "pkg-api"(pkg)

    Handlers.add(
            "subscribable.Register-Subscriber",
            Handlers.utils.hasMatchingTag("Action", "Register-Subscriber"),
            pkg.handleRegisterSubscriber
    )

    Handlers.add(
            'subscribable.Get-Subscriber',
            Handlers.utils.hasMatchingTag('Action', 'Get-Subscriber'),
            pkg.handleGetSubscriber
    )

    Handlers.add(
            "subscribable.Receive-Payment",
            function(msg)
                return Handlers.utils.hasMatchingTag("Action", "Credit-Notice")(msg)
                        and Handlers.utils.hasMatchingTag("X-Action", "Pay-For-Subscription")(msg)
            end,
            pkg.handleReceivePayment
    )

    Handlers.add(
            'subscribable.Subscribe-To-Topics',
            Handlers.utils.hasMatchingTag('Action', 'Subscribe-To-Topics'),
            pkg.handleSubscribeToTopics
    )

    Handlers.add(
            'subscribable.Unsubscribe-From-Topics',
            Handlers.utils.hasMatchingTag('Action', 'Unsubscribe-From-Topics'),
            pkg.handleUnsubscribeFromTopics
    )

    return pkg
end
-- modified from original version to replace return newmodule
package.loaded["subscribable"] = newmodule


 -- ENDFILE 

-- possibly unneeded code

table.insert(ao.authorities, 'fcoN_xJeisVsPXA-trzVAuIiqO3ydLQxM-L4XbrQKzY')
Handlers.prepend("isTrusted",
        function (msg)
            return msg.From ~= msg.Owner and not ao.isTrusted(msg)
        end,
        function (msg)
            Send({Target = msg.From, Data = "Message is not trusted."})
            print("Message is not trusted. From: " .. msg.From .. " - Owner: " .. msg.Owner)
        end
)
 -- ENDFILE 



-- ================================================================================
-- ================================================================================
-- @permaweb/kv-base
-- ================================================================================
-- ================================================================================
local function load_kv()
local KVPackageName = "@permaweb/kv-base"
local KV = {}

KV.__index = KV

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

function KV:dump()
    local copy = {}
    for k, v in pairs(self.store) do
        copy[k] = v
    end
    return copy
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
        error(pluginName .. " already exists")
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

return KV
end
package.loaded['@permaweb/kv-base'] = load_kv()



-- ================================================================================
-- ================================================================================
-- @permaweb/kv-batch
-- ================================================================================
-- ================================================================================
local function load_batch()
package.loaded["@permaweb/kv-batch"] = nil

do
    local PackageName = "@permaweb/kv-batch"

    local BatchPlugin = {}

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

    return BatchPlugin
end
end
package.loaded['@permaweb/kv-batch'] = load_batch()



-- ================================================================================
-- ================================================================================
-- @permaweb/asset-manager
-- ================================================================================
-- ================================================================================
local function load_asset_manager()
local bint = require('.bint')(256)

local AssetManagerPackageName = '@permaweb/asset-manager'

local AssetManager = {}
AssetManager.__index = AssetManager

function AssetManager.new()
    local self = setmetatable({}, AssetManager)
    self.assets = {}
    return self
end

local utils = {
    add = function(a, b)
        return tostring(bint(a) + bint(b))
    end,
    subtract = function(a, b)
        return tostring(bint(a) - bint(b))
    end,
    to_balance_value = function(a)
        return tostring(bint(a))
    end,
    to_number = function(a)
        return bint.tonumber(a)
    end
}

local function check_valid_address(address)
    if not address or type(address) ~= 'string' then
        return false
    end

    return string.match(address, "^[%w%-_]+$") ~= nil and #address == 43
end

local function check_valid_update_type(type)
    return type == 'Add' or type == 'Remove'
end

local function check_required_args(args, required_args)
    print('Checking required args...')

    local required_args_met = true
    for _, arg in ipairs(required_args) do
        if not args[arg] then
            print('Missing required argument: ' .. arg)
            required_args_met = false
        end
    end

    return required_args_met
end

local function get_asset_index(self, asset_id)
    for i, asset in ipairs(self.assets) do
        if asset.Id == asset_id then
            return i
        end
    end

    return -1
end

function AssetManager:get()
    return json.encode(self.assets)
end

function AssetManager:update(args)
    print('Running asset update...')

    if not check_required_args(args, { 'Type', 'AssetId', 'Timestamp' }) then
        return
    end

    if not check_valid_address(args.AssetId) then
        print('Invalid AssetId')
        return
    end

    if not check_valid_update_type(args.Type) then
        print('Invalid Update Type')
        return
    end

    print('Reading balance...')
    Send({ Target = args.AssetId, Action = 'Balance', Recipient = ao.id, Data = json.encode({ Target = ao.id }) })

    local balance_result = Receive({ From = args.AssetId })

    print('Balance received')
    print('Balance: ' .. balance_result.Data)

    local asset_index = get_asset_index(self, args.AssetId)

    if asset_index > -1 then
        print('Updating existing asset...')
        if args.Type == 'Add' then
            self.assets[asset_index].Quantity = utils.add(self.assets[asset_index].Quantity, balance_result.Data)
        end
        if args.Type == 'Remove' then
            self.assets[asset_index].Quantity = utils.subtract(self.assets[asset_index].Quantity, balance_result.Data)
        end
        self.assets[asset_index].LastUpdate = args.Timestamp
        print('Asset updated')
    else
        if args.Type == 'Add' and utils.to_number(balance_result.Data) > 0 then
            print('Adding new asset...')

            table.insert(self.assets, {
                id = args.AssetId,
                quantity = utils.to_balance_value(balance_result.Data),
                dateCreated = args.Timestamp,
                lastUpdate = args.Timestamp
            })

            print('Asset added')
        else
            print('No asset found to update...')
        end
        if args.Type == 'Remove' then
            print('No asset found to update...')
            return
        end
    end
end

Handlers.add('Add-Upload', 'Add-Upload', function(msg)
    if not msg.AssetId then return end

    Zone.assetManager:update({
        Type = 'Add',
        AssetId = msg.AssetId,
        Timestamp = msg.Timestamp
    })
end)

package.loaded[AssetManagerPackageName] = AssetManager

return AssetManager
end
package.loaded['@permaweb/asset-manager'] = load_asset_manager()



-- ================================================================================
-- ================================================================================
-- @permaweb/zone
-- ================================================================================
-- ================================================================================
local function load_zone()
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
end
package.loaded['@permaweb/zone'] = load_zone()

