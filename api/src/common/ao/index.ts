import {APICreateProcessType, APIDryRunType, APIResultType, APISendType, APISpawnType} from 'types/ao';
import { TagType } from 'types/helpers';

import { connect, createDataItemSigner, dryrun, message, result, results  } from '@permaweb/aoconnect';

import { getTagValue } from '../utils';
import {GATEWAYS, getTxEndpoint} from "../helpers";
import {getGQLData} from "../gql";
import {RETRY_COUNT} from "./utils";

export async function aoSpawn(args: APISpawnType): Promise<any> {
	const aos = connect();
	
	const processId = await aos.spawn({
		module: args.module,
		scheduler: args.scheduler,
		signer: createDataItemSigner(args.wallet),
		tags: args.tags,
		data: JSON.stringify(args.data),
	});

	return processId;
}

export async function aoSend(args: APISendType): Promise<any> {
	try {
		const tags: TagType[] = [{ name: 'Action', value: args.action }];
		if (args.tags) tags.push(...args.tags);

		const data = args.useRawData ? args.data : JSON.stringify(args.data);

		const txId = await message({
			process: args.processId,
			signer: createDataItemSigner(args.wallet),
			tags: tags,
			data: data,
		});

		return txId;
	} catch (e) {
		console.error(e);
	}
}

export async function aoDryRun(args: APIDryRunType): Promise<any> {
	try {
		const tags = [{ name: 'Action', value: args.action }];
		if (args.tags) tags.push(...args.tags);
		let data = JSON.stringify(args.data || {});

		const response = await dryrun({
			process: args.processId,
			tags: tags,
			data: data,
		});

		if (response.Messages && response.Messages.length) {
			if (response.Messages[0].Data) {
				return JSON.parse(response.Messages[0].Data);
			} else {
				if (response.Messages[0].Tags) {
					return response.Messages[0].Tags.reduce((acc: any, item: any) => {
						acc[item.name] = item.value;
						return acc;
					}, {});
				}
			}
		}
	} catch (e) {
		console.error(e);
	}
}

export async function aoMessageResult(args: APIResultType): Promise<any> {
	try {
		const { Messages } = await result({ message: args.messageId, process: args.processId });

		if (Messages && Messages.length) {
			const response: { [key: string]: any } = {};

			Messages.forEach((message: any) => {
				const action = getTagValue(message.Tags, 'Action') || args.messageAction;

				let responseData = null;
				const messageData = message.Data;

				if (messageData) {
					try {
						responseData = JSON.parse(messageData);
					} catch {
						responseData = messageData;
					}
				}

				const responseStatus = getTagValue(message.Tags, 'Status');
				const responseMessage = getTagValue(message.Tags, 'Message');

				response[action] = {
					id: args.messageId,
					status: responseStatus,
					message: responseMessage,
					data: responseData,
				};
			});

			return response;
		} else return null;
	} catch (e) {
		console.error(e);
	}
}

// TODO: Remove unnecessary handler arg / get correct responses
export async function aoMessageResults(args: {
	processId: string;
	wallet: any;
	action: string;
	tags: TagType[] | null;
	data: any;
	responses?: string[];
	handler?: string;
}): Promise<any> {
	try {
		const tags = [{ name: 'Action', value: args.action }];
		if (args.tags) tags.push(...args.tags);

		await message({
			process: args.processId,
			signer: createDataItemSigner(args.wallet),
			tags: tags,
			data: JSON.stringify(args.data),
		});

		await new Promise((resolve) => setTimeout(resolve, 1000));

		const messageResults = await results({
			process: args.processId,
			sort: 'DESC',
			limit: 100,
		});

		if (messageResults && messageResults.edges && messageResults.edges.length) {
			const response: any = {};

			for (const result of messageResults.edges) {
				if (result.node && result.node.Messages && result.node.Messages.length) {
					const resultSet: any[] = [args.action];
					if (args.responses) resultSet.push(...args.responses);

					for (const message of result.node.Messages) {
						const action = getTagValue(message.Tags, 'Action');

						if (action) {
							let responseData = null;
							const messageData = message.Data;

							if (messageData) {
								try {
									responseData = JSON.parse(messageData);
								} catch {
									responseData = messageData;
								}
							}

							const responseStatus = getTagValue(message.Tags, 'Status');
							const responseMessage = getTagValue(message.Tags, 'Message');

							if (action === 'Action-Response') {
								const responseHandler = getTagValue(message.Tags, 'Handler');
								if (args.handler && args.handler === responseHandler) {
									response[action] = {
										status: responseStatus,
										message: responseMessage,
										data: responseData,
									};
								}
							} else {
								if (resultSet.indexOf(action) !== -1) {
									response[action] = {
										status: responseStatus,
										message: responseMessage,
										data: responseData,
									};
								}
							}

							if (Object.keys(response).length === resultSet.length) break;
						}
					}
				}
			}

			return response;
		}

		return null;
	} catch (e) {
		console.error(e);
	}
}

const testsrc = `
-- AO Package Manager for easy installation of packages in ao processes
-------------------------------------------------------------------------
--      ___      .______   .___  ___.     __       __    __       ___
--     /   \\     |   _  \\  |   \\/   |    |  |     |  |  |  |     /   \\
--    /  ^  \\    |  |_)  | |  \\  /  |    |  |     |  |  |  |    /  ^  \\
--   /  /_\\  \\   |   ___/  |  |\\/|  |    |  |     |  |  |  |   /  /_\\  \\
--  /  _____  \\  |  |      |  |  |  |  __|  \`----.|  \`--'  |  /  _____  \\
-- /__/     \\__\\ | _|      |__|  |__| (__)_______| \\______/  /__/     \\__\\
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
    local p = "\\n"
    for _, pkg in ipairs(data) do
        p = p .. pkg.Vendor .. "/" .. pkg.Name .. " - " .. pkg.Description .. "\\n"
    end
    print(p)
end

Handlers.add("APM.SearchResponse", Handlers.utils.hasMatchingTag("Action", "APM.SearchResponse"), function(msg)
    handle_run(SearchResponseHandler, msg)
end)

----------------------------------------

function GetPopularResponseHandler(msg)
    local data = json.decode(msg.Data)
    local p = "\\n"
    for _, pkg in ipairs(data) do
        -- p = p .. pkg.Vendor .. "/" .. pkg.Name .. " - " .. (pkg.Description or pkg.Owner) .. "  " .. pkg.RepositoryUrl .. "\\n"
        p = p .. pkg.Vendor .. "/" .. pkg.Name .. " - "
        if pkg.Description then
            p = p .. pkg.Description .. "  "
        else
            p = p .. pkg.Owner .. "  "
        end
        if pkg.RepositoryUrl then
            p = p .. pkg.RepositoryUrl .. "\\n"
        else
            p = p .. "No Repo Url\\n"
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
--
--return "📦 Loaded APM Client"
`

async function waitForProcess(processId: string, setStatus?: (status: any) => void) {
	let retries = 0;

	while (retries < RETRY_COUNT) {
		await new Promise((r) => setTimeout(r, 2000));

		const gqlResponse = await getGQLData({
			gateway: GATEWAYS.goldsky,
			ids: [processId],
		});

		if (gqlResponse?.data?.length) {
			const foundProcess = gqlResponse.data[0].node.id;
			console.log(`Fetched transaction -`, foundProcess);
			return foundProcess;
		} else {
			console.log(`Transaction not found -`, processId);
			retries++;
			setStatus && setStatus(`Retrying: ${retries}`);
		}
	}

	setStatus && setStatus("Error, not found");
	throw new Error(`Profile not found, please try again`);
}

export async function aoCreateProcess(args: APICreateProcessType, statusCB?: (status: any) => void): Promise<any> {
	try {
		const processSrcFetch = await fetch(getTxEndpoint(args.evalTxid));

		const processId = await aoSpawn({
			module: args.module,
			scheduler: args.scheduler,
			data: args.spawnData,
			tags: args.tags,
			wallet: args.wallet
		})

		const src = await processSrcFetch.text()

		console.log(src)
		await waitForProcess(processId, statusCB)
		statusCB && statusCB("Spawned and found:" + processId)
		const evalMessage = await aoSend({
			processId,
			wallet: args.wallet,
			action: 'Eval',
			data: src,
			tags: args.tags,
			useRawData: true,
		})
		statusCB && statusCB("Eval sent")
		console.log('evalmsg', evalMessage)

		const evalResult = await aoMessageResult({
			processId: processId,
			messageId: evalMessage,
			messageAction: 'Eval',
		});
		statusCB && statusCB("Eval success")
		console.log(evalResult);

	} catch (e: unknown) {
		let message = '';
		if (e instanceof Error) {
			message = e.message;
		} else if (typeof e === "string" ) {
			message = e;
		} else {
			message = "Unknown error";
		}
		statusCB && statusCB(`Create failed: message: ${message}`)
	}
	// spawn
	// wait/fetch
	// eval
}
