local json = require('json')

-- Profile: {
--   UserName
--   DisplayName
--   Description
--   CoverImage
--   ProfileImage
--   DateCreated
--   DateUpdated
--	 Version
-- }
CurrentProfileVersion = 0.1

if not Profile then Profile = {} end

if not Profile.Version then Profile.Version = CurrentProfileVersion end

if not FirstRunCompleted then FirstRunCompleted = false end

-- Assets: { Id, Type, Quantity } []

if not Assets then Assets = {} end

-- Collections: { Id, SortOrder } []

if not Collections then Collections = {} end

-- keep this list consistent with registry
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

-- Roles: { AddressOrProfile, Role } []
if not Roles then Roles = {} end

REGISTRY = 'dWdBohXUJ22rfb8sSChdFh6oXJzbAtGe4tC6__52Zk4'

local function check_valid_address(address)
	if not address or type(address) ~= 'string' then
		return false
	end
	return string.match(address, "^[%w%-_]+$") ~= nil and #address == 43
end

local function check_valid_role(role, op)
	if op == 'Delete' then
		return true
	end
	if not role or type(role) ~= 'string' then
		return false
	end
	return role == 'Admin' or role == 'Contributor' or role == 'Moderator' or role == 'Owner'
end

local function check_required_data(data, tags, required_fields)
	local localtags = tags or {}
	for _, field in ipairs(required_fields) do
		if field == "UserName" then
			if (data ~= nil and data[field] == '') or localtags[field] == '' then
				return false
			end
		end
		if (data ~= nil and data[field] ~= nil) or localtags[field] ~= nil  then
			return true
		end
	end
	return false
end

local function decode_message_data(data)
	local status, decoded_data = pcall(json.decode, data)

	if not status or type(decoded_data) ~= 'table' then
		return false, nil
	end

	return true, decoded_data
end

local function authorizeRoles(msg)
	-- If Roles is blank, the initial call should be from the owner
	if msg.From ~= Owner and msg.From ~= ao.id and #Roles == 0 then
		return false, {
			Target = msg.Target or msg.From,
			Action = 'Authorization-Error',
			Tags = {
				Status = 'Error',
				ErrorMessage = 'Initial Roles not set, owner is not authorized for this handler'
			}
		}
	end
	-- change to 'admin', 'contributor', 'moderator', 'owner'
	local existingRole = nil

	for _, role in pairs(Roles) do
		if role.AddressOrProfile == msg.From then
			existingRole = role.Role
			break
		end
	end

	-- determine if they have a role
	-- determine if they can call the action handler
	-- determine if owner-only actions are allowed

	if not existingRole then
		if msg.From == Owner then
			-- If Roles table is empty or owner doesn't exist, authorize the owner
			table.insert(Roles, {Role = "Owner", AddressOrProfile = msg.From})
			existingRole = 'Owner'
		else
			return false, {
				Target = msg.Target or msg.From,
				Action = 'Authorization-Error',
				Tags = {
					Status = 'Error',
					ErrorMessage = 'Unauthorized to access this handler'
				}
			}
		end
	else
		-- now check if the role is allowed to access the handler
		local handlerRoles = HandlerRoles[msg.Action]
		if not handlerRoles then
			return false, {
				Target = msg.Target or msg.From,
				Action = 'Authorization-Error',
				Tags = {
					Status = 'Error',
					ErrorMessage = 'Handler does not exist'
				}
			}
		else
			local authorized = false
			for _, role in pairs(handlerRoles) do
				if role == existingRole then
					authorized = true
					break
				end
			end

			if not authorized then
				return false, {
					Target = msg.Target or msg.From,
					Action = 'Authorization-Error',
					Tags = {
						Status = 'Error',
						ErrorMessage = 'Unauthorized to access this handler'
					}
				}

			end
			return authorized, nil
		end
	end

	return true
end

local function sort_collections()
	table.sort(Collections, function(a, b)
		return a.SortOrder < b.SortOrder
	end)
end

local function update_profile(msg)
	local authorizeResult, message = authorizeRoles(msg)
	if not authorizeResult then
		ao.send(message)
		return
	end

	local decode_check, data = decode_message_data(msg.Data)
	create_required_data = { "UserName" }
	update_required_data = { "UserName", "DisplayName", "Description", "CoverImage", "ProfileImage" }

	if decode_check and data then
		if not check_required_data(data, msg.Tags, FirstRunCompleted and update_required_data or create_required_data) then
			ao.send({
				Target = msg.From,
				Action = 'Input-Error',
				Tags = {
					Status = 'Error',
					EMessage =
					'Invalid data or Tags, required at least Username for creation, or one of { UserName, DisplayName, Description, CoverImage, ProfileImage } for updates'
				}
			})
			return
		end

		local function getUpdatedProfileField(tagField, dataField, profileField)
			if tagField == "" then
				return nil
			end
			if dataField == "" then
				return nil
			end
			return tagField or dataField or profileField
		end

		Profile.UserName = getUpdatedProfileField(msg.Tags.UserName, data.UserName, Profile.UserName)
		Profile.DisplayName = getUpdatedProfileField(msg.Tags.DisplayName, data.DisplayName, Profile.DisplayName)
		Profile.Description = getUpdatedProfileField(msg.Tags.Description, data.Description, Profile.Description)
		Profile.CoverImage = getUpdatedProfileField(msg.Tags.CoverImage, data.CoverImage, Profile.CoverImage)
		Profile.ProfileImage = getUpdatedProfileField(msg.Tags.ProfileImage, data.ProfileImage, Profile.ProfileImage)
		Profile.DateCreated = Profile.DateCreated or msg.Timestamp
		Profile.DateUpdated = msg.Timestamp

		if FirstRunCompleted then
			ao.assign({Processes = { REGISTRY }, Message = msg.Id})
		else
			ao.assign({Processes = { REGISTRY }, Message = ao.id})
			-- if data is missing this will fix it?
			ao.assign({Processes = { REGISTRY }, Message = msg.Id})
			FirstRunCompleted = true
		end

		if Profile.Version ~= CurrentProfileVersion then
			Profile.Version = CurrentProfileVersion
		end

		ao.send({
			Target = msg.From,
			Action = 'Profile-Success',
			Tags = {
				Status = 'Success',
				Message = 'Profile updated'
			}
		})
	else
		ao.send({
			Target = msg.From,
			Action = 'Input-Error',
			Tags = {
				Status = 'Error',
				EMessage = string.format(
						'Failed to parse data, received: %s. %s.', msg.Data,
						'Data must be an object - { UserName, DisplayName, Description, CoverImage, ProfileImage }')
			}
		})
	end
end

-- Data - { Id, Quantity }. This should be sunset eventually as it doesn't perform any validation
local function add_uploaded_asset_v000(msg)
	local decode_check, data = decode_message_data(msg.Data)

	if decode_check and data then
		if not data.Id or not data.Quantity then
			ao.send({
				Target = msg.From,
				Action = 'Input-Error',
				Tags = {
					Status = 'Error',
					Message =
					'Invalid arguments, required { Id, Quantity }'
				}
			})
			return
		end

		if not check_valid_address(data.Id) then
			ao.send({ Target = msg.From, Action = 'Validation-Error', Tags = { Status = 'Error', Message = 'Asset Id must be a valid address' } })
			return
		end

		local exists = false
		for _, asset in ipairs(Assets) do
			if asset.Id == data.Id then
				exists = true
				break
			end
		end

		if not exists then
			table.insert(Assets, { Id = data.Id, Type = 'Upload', Quantity = data.Quantity })
			ao.send({
				Target = msg.From,
				Action = 'Add-Uploaded-Asset-Success',
				Tags = {
					Status = 'Success',
					Message = 'Asset added to profile'
				}
			})
		else
			ao.send({
				Target = msg.From,
				Action = 'Validation-Error',
				Tags = {
					Status = 'Error',
					Message = string.format(
							'Asset with Id %s already exists', data.Id)
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
						'Data must be an object - { Id, Quantity }')
			}
		})
	end
end

-- Tag - { Quantity = # } - Assignment from Spawn, msg.Id is the asset ID
local function add_uploaded_asset_v001(msg)
	local reply_to = msg.Target or msg.From
	local authorizeResult, message = authorizeRoles(msg)
	-- there's current a bug with sending back a message via assignment to msg.From
	if not authorizeResult then
		ao.send(message)
		return
	end

	local quantity = msg.Tags.Quantity and tonumber(msg.Tags.Quantity)

	if not quantity and quantity > 0 then
		ao.send({
			Target = reply_to,
			Action = 'Input-Error',
			Tags = {
				Status = 'Error',
				Message =
				'Invalid argument, required Quantity tag on Atomic Asset Spawn must exist and be a number greater than 0 }'
			}
		})
		return
	end


	if not check_valid_address(msg.Id) then
		ao.send({ Target = reply_to, Action = 'Validation-Error', Tags = { Status = 'Error', Message = 'Asset Id must be a valid address' } })
		return
	end

	local exists = false
	for _, asset in ipairs(Assets) do
		if asset.Id == msg.Id then
			exists = true
			break
		end
	end

	if not exists then
		table.insert(Assets, { Id = msg.Id, Type = 'Upload', Quantity = msg.Tags.Quantity })
		ao.send({
			Target = reply_to,
			Action = 'Add-Uploaded-Asset-Success',
			Tags = {
				Status = 'Success',
				Message = 'Asset added to profile'
			}
		})
	else
		ao.send({
			Target = reply_to,
			Action = 'Validation-Error',
			Tags = {
				Status = 'Error',
				Message = string.format(
						'Asset with Id %s already exists', msg.Id)
			}
		})
	end
end

local function add_collection_v000(msg)
	local decode_check, data = decode_message_data(msg.Data)

	if decode_check and data then
		if not data.Id or not data.Name then
			ao.send({
				Target = msg.From,
				Action = 'Input-Error',
				Tags = {
					Status = 'Error',
					Message =
					'Invalid arguments, required { Id, Name }'
				}
			})
			return
		end

		if not check_valid_address(data.Id) then
			ao.send({ Target = msg.From, Action = 'Validation-Error', Tags = { Status = 'Error', Message = 'Collection Id must be a valid address' } })
			return
		end

		local exists = false
		for _, collection in ipairs(Collections) do
			if collection.Id == data.Id then
				exists = true
				break
			end
		end

		-- Ensure the highest SortOrder for new items
		local highestSortOrder = 0
		for _, collection in ipairs(Collections) do
			if collection.SortOrder > highestSortOrder then
				highestSortOrder = collection.SortOrder
			end
		end

		if not exists then
			table.insert(Collections, { Id = data.Id, Name = data.Name, SortOrder = highestSortOrder + 1 })
			sort_collections()
			ao.send({
				Target = msg.From,
				Action = 'Add-Collection-Success',
				Tags = {
					Status = 'Success',
					Message = 'Collection added'
				}
			})
		else
			ao.send({
				Target = msg.From,
				Action = 'Validation-Error',
				Tags = {
					Status = 'Error',
					Message = string.format(
							'Collection with Id %s already exists', data.Id)
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
						'Data must be an object - { Id, Name, Items }')
			}
		})
	end
end

local function add_collection_v001(msg)
	local reply_to = msg.Target or msg.From
	local authorizeResult, message = authorizeRoles(msg)
	if not authorizeResult then
		ao.send(message)
		return
	end

	if not check_valid_address(msg.Id) then
		ao.send({ reply_to, Action = 'Validation-Error', Tags = { Status = 'Error', Message = 'Collection Id must be a valid address' } })
		return
	end

	local exists = false
	for _, collection in ipairs(Collections) do
		if collection.Id == msg.Id then
			exists = true
			break
		end
	end

	-- Ensure the highest SortOrder for new items
	local highestSortOrder = 0
	for _, collection in ipairs(Collections) do
		if collection.SortOrder > highestSortOrder then
			highestSortOrder = collection.SortOrder
		end
	end

	if not exists then
		table.insert(Collections, { Id = msg.Id, SortOrder = highestSortOrder + 1 })
		sort_collections()
		ao.send({
			Target = reply_to,
			Action = 'Add-Collection-Success',
			Tags = {
				Status = 'Success',
				Message = 'Collection added'
			}
		})
	else
		ao.send({
			Target = reply_to,
			Action = 'Validation-Error',
			Tags = {
				Status = 'Error',
				Message = string.format(
						'Collection with Id %s already exists', msg.Id)
			}
		})
	end
end

local function compare_version( a_version, b_version )
	local a_version_parts = { string.match(a_version, "(%d+)%.(%d+)%.(%d+)") }
	local b_version_parts = { string.match(b_version, "(%d+)%.(%d+)%.(%d+)") }

	for i = 1, 3 do
		if tonumber(a_version_parts[i]) > tonumber(b_version_parts[i]) then
			return 1
		elseif tonumber(a_version_parts[i]) < tonumber(b_version_parts[i]) then
			return -1
		end
	end

	return 0
end

-- sort versions in descending order
local function sort_versions(versions)
	table.sort(versions, function(a, b)
		return compare_version(a, b) > 0
	end)
end

local HANDLER_VERSIONS = {
	add_uploaded_asset = {
		["0.0.0"] = add_uploaded_asset_v000,
		["0.0.1"] = add_uploaded_asset_v001,
	},
	add_collection = {
		["0.0.0"] = add_collection_v000,
		["0.0.1"] = add_collection_v001,
	}
}

local function version_dispatcher(action, msg)
	-- eventually once we start versioning, we potentially make the non-versioned the latest/default,
	-- and require version for backwards compatability
	local msg_version = msg.Tags and msg.Tags.ProfileVersion or '0.0.0'  -- Default named version if not specified
	local handlers = HANDLER_VERSIONS[action]

	if handlers then
		if handlers[msg_version] then
			handlers[msg_version](msg)
		else
			local versions = {}
			for key, _ in pairs(handlers) do
				table.insert(versions, key)
			end

			table.sort(versions, function(a, b)
				return compare_version(a, b) > 0
			end)

			local handlerVersion
			for _, available_version in ipairs(versions) do
				-- return the first version that is less than or equal to the message version
				if compare_version(msg_version, available_version) >= 0 then

					handlerVersion = available_version
					break
				end
			end

			handlers[handlerVersion](msg)
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

Handlers.add('Info', Handlers.utils.hasMatchingTag('Action', 'Info'),
	function(msg)
		ao.send({
			Target = msg.From,
			Action = 'Read-Success',
			Data = json.encode({
				Profile = Profile,
				Assets = Assets,
				Collections = Collections,
				Owner = Owner,
				Roles = Roles or {}
			})
		})
	end)

-- Data - { UserName?, DisplayName?, Description?, CoverImage, ProfileImage }
--[[
This function handles the 'Update-Profile' action. It first checks if the sender of the message is authorized to perform this action.
If the sender is authorized, it then decodes the data from the message. If the data is valid and contains at least one of the required fields,
it updates the profile with the new data and sends a success message to the sender and the registry. If the data is not valid or does not contain
any of the required fields, it sends an error message to the sender.

Parameters:
msg:
{
	data: { },
	tags: { }

Returns:
None. This function sends messages to the sender or the registry but does not return anything.
--]]
Handlers.add('Update-Profile', Handlers.utils.hasMatchingTag('Action', 'Update-Profile'), update_profile )

-- Data - { Id, Op, Role? }
Handlers.add('Update-Role', Handlers.utils.hasMatchingTag('Action', 'Update-Role'),
	function(msg)
		local authorizeResult, message = authorizeRoles(msg)
		if not authorizeResult then
			ao.send(message)
			return
		end

		local decode_check, data = decode_message_data(msg.Data)

		if decode_check and data then
			if not data.Id or not data.Op then
				ao.send({
					Target = msg.From,
					Action = 'Input-Error',
					Tags = {
						Status = 'Error',
						Message =
						'Invalid arguments, required { Id, Role }'
					}
				})
				return
			end

			if not check_valid_address(data.Id) then
				ao.send({ Target = msg.From, Action = 'Validation-Error', Tags = { Status = 'Error', Message = 'Id must be a valid address' }, Data = msg.Data })
				return
			end

			if not check_valid_role(data.Role, data.Op) then
				ao.send({ Target = msg.From, Action = 'Validation-Error', Tags = { Status = 'Error', Message = 'Role must be one of "Admin", "Contributor", "Moderator"' }, Data = msg.Data })
				return
			end

			-- Add, update, or remove role
			local role_index = -1
			local current_role = nil
			for i, role in ipairs(Roles) do
				if role.AddressOrProfile == data.Id then
					role_index = i
					current_role = role.Role
					break
				end
			end

			if role_index == -1 then
				if (data.Op == 'Add') then
					table.insert(Roles, { AddressOrProfile = data.Id, Role = data.Role })
				else
					ao.send({
						Target = msg.From,
						Action = 'Update-Role-Failed',
						Tags = {
							Status = 'Error',
							Message = 'Role Op not possible, role does not exist to delete or update'
						}
					})
					return
				end
			else
				if data.Op == 'Delete' and current_role ~= 'Owner' then
					table.remove(Roles, role_index)
				elseif data.Op == "Update" then
					Roles[role_index].Role = data.Role
				end
			end

			-- assign to registry
			ao.assign({Processes = { REGISTRY }, Message = ao.id})
			ao.send({
				Target = msg.From,
				Action = 'Update-Role-Success',
				Tags = {
					Status = 'Success',
					Message = 'Role updated'
				}
			})
		else
			ao.send({
				Target = msg.From,
				Action = 'Input-Error',
				Tags = {
					Status = 'Error',
					Message = string.format(
						'Failed to parse data, received: %s. %s.', msg.Data,
						'Data must be an object - { Id, Role }')
				}
			})
		end

	end)


-- Data - { Target, Recipient, Quantity }
Handlers.add('Transfer', Handlers.utils.hasMatchingTag('Action', 'Transfer'),
	function(msg)
		local authorizeResult, message = authorizeRoles(msg)
		if not authorizeResult then
			ao.send(message)
			return
		end

		ao.send({
			Target = msg.Tags.Target,
			Action = 'Transfer',
			Tags = msg.Tags,
			Data = msg.Data
		})
	end)

-- Tags - { Recipient, Quantity }
Handlers.add('Debit-Notice', Handlers.utils.hasMatchingTag('Action', 'Debit-Notice'),
	function(msg)
		if not msg.Tags.Recipient or not msg.Tags.Quantity then
			ao.send({
				Target = msg.From,
				Action = 'Input-Error',
				Tags = {
					Status = 'Error',
					Message =
					'Invalid arguments, required { Recipient, Quantity }'
				}
			})
			return
		end

		if not check_valid_address(msg.Tags.Recipient) then
			ao.send({ Target = msg.From, Action = 'Validation-Error', Tags = { Status = 'Error', Message = 'Recipient must be a valid address' } })
			return
		end

		local asset_index = -1
		for i, asset in ipairs(Assets) do
			if asset.Id == msg.From then
				asset_index = i
				break
			end
		end

		if asset_index > -1 then
			local updated_quantity = tonumber(Assets[asset_index].Quantity) - tonumber(msg.Tags.Quantity)

			if updated_quantity <= 0 then
				table.remove(Assets, asset_index)
			else
				Assets[asset_index].Quantity = tostring(updated_quantity)
			end

			ao.send({
				Target = Owner,
				Action = 'Transfer-Success',
				Tags = {
					Status = 'Success',
					Message = 'Balance transferred'
				}
			})
		else
			ao.send({
				Target = msg.From,
				Action = 'Transfer-Failed',
				Tags = {
					Status = 'Error',
					Message = 'No asset found to debit'
				}
			})
		end
	end)

-- Tags - { Sender, Quantity }
Handlers.add('Credit-Notice', Handlers.utils.hasMatchingTag('Action', 'Credit-Notice'),
	function(msg)
		if not msg.Tags.Sender or not msg.Tags.Quantity then
			ao.send({
				Target = msg.From,
				Action = 'Input-Error',
				Tags = {
					Status = 'Error',
					Message =
					'Invalid arguments, required { Sender, Quantity }'
				}
			})
			return
		end

		if not check_valid_address(msg.Tags.Sender) then
			ao.send({ Target = msg.From, Action = 'Validation-Error', Tags = { Status = 'Error', Message = 'Sender must be a valid address' } })
			return
		end

		local asset_index = -1
		for i, asset in ipairs(Assets) do
			if asset.Id == msg.From then
				asset_index = i
				break
			end
		end

		if asset_index > -1 then
			local updated_quantity = tonumber(Assets[asset_index].Quantity) + tonumber(msg.Tags.Quantity)

			Assets[asset_index].Quantity = tostring(updated_quantity)
		else
			table.insert(Assets, { Id = msg.From, Quantity = msg.Tags.Quantity })

			ao.send({
				Target = Owner,
				Action = 'Transfer-Success',
				Tags = {
					Status = 'Success',
					Message = 'Balance transferred'
				}
			})
		end
	end)

Handlers.add('Add-Uploaded-Asset', Handlers.utils.hasMatchingTag('Action', 'Add-Uploaded-Asset'),
		function(msg)
			version_dispatcher('add_uploaded_asset', msg)
		end)

-- Tag - { SortOrder = # }, Assignment from Spawn, msg.Id is the collection ID. Sort Order = highest to lowest
-- todo handle resorting of other items if sortOrder is passed.
Handlers.add('Add-Collection', Handlers.utils.hasMatchingTag('Action', 'Add-Collection'),
	function(msg)
			version_dispatcher('add_collection', msg)
	end)

-- Data - { Ids: [Id1, Id2, ..., IdN] }
Handlers.add('Update-Collection-Sort', Handlers.utils.hasMatchingTag('Action', 'Update-Collection-Sort'),
	function(msg)
		local reply_to = msg.Target or msg.From
		local authorizeResult, message = authorizeRoles(msg)
		if not authorizeResult then
			ao.send(message)
			return
		end

		local decode_check, data = decode_message_data(msg.Data)

		if decode_check and data then
			if not data.Ids then
				ao.send({
					Target = reply_to,
					Action = 'Input-Error',
					Tags = {
						Status = 'Error',
						Message = 'Invalid arguments, required { Ids }'
					}
				})
				return
			end

			-- Validate all IDs exist in the Collections table
			local valid_ids = {}
			local id_set = {}
			for _, id in ipairs(data.Ids) do
				for _, collection in ipairs(Collections) do
					if collection.Id == id then
						table.insert(valid_ids, id)
						id_set[id] = true
						break
					end
				end
			end

			-- Update SortOrder for valid collections
			for i, id in ipairs(valid_ids) do
				for _, collection in ipairs(Collections) do
					if collection.Id == id then
						collection.SortOrder = i
					end
				end
			end

			-- Place any collections not in the valid_ids list at the end, preserving their relative order
			local remaining_collections = {}
			for _, collection in ipairs(Collections) do
				if not id_set[collection.Id] then
					table.insert(remaining_collections, collection)
				end
			end

			-- Sort remaining collections by their current SortOrder
			table.sort(remaining_collections, function(a, b)
				return a.SortOrder < b.SortOrder
			end)

			-- Assign new SortOrder to remaining collections
			local new_sort_order = #valid_ids + 1
			for _, collection in ipairs(remaining_collections) do
				collection.SortOrder = new_sort_order
				new_sort_order = new_sort_order + 1
			end

			-- Sort collections by SortOrder
			sort_collections()

			ao.send({
				Target = reply_to,
				Action = 'Update-Collection-Sort-Success',
				Tags = {
					Status = 'Success',
					Message = 'Collections sorted'
				}
			})
		else
			ao.send({
				Target = reply_to,
				Action = 'Input-Error',
				Tags = {
					Status = 'Error',
					Message = string.format(
						'Failed to parse data, received: %s. %s.', msg.Data,
						'Data must be an object - { Ids }')
				}
			})
		end
	end)

Handlers.add('Action-Response', Handlers.utils.hasMatchingTag('Action', 'Action-Response'),
	function(msg)
		if msg.Tags['Status'] and msg.Tags['Message'] then
			local response_tags = {
				Status = msg.Tags['Status'],
				Message = msg.Tags['Message']
			}

			if msg.Tags['Handler'] then response_tags.Handler = msg.Tags['Handler'] end

			ao.send({
				Target = Owner,
				Action = 'Action-Response',
				Tags = response_tags
			})
		end
	end)

Handlers.add('Run-Action', Handlers.utils.hasMatchingTag('Action', 'Run-Action'),
	function(msg)
		local authorizeResult, message = authorizeRoles(msg)
		if not authorizeResult then
			ao.send(message)
			return
		end

		local decode_check, data = decode_message_data(msg.Data)

		if decode_check and data then
			if not data.Target or not data.Action or not data.Input then
				ao.send({
					Target = msg.From,
					Action = 'Input-Error',
					Tags = {
						Status = 'Error',
						Message =
						'Invalid arguments, required { Target, Action, Input }'
					}
				})
				return
			end

			if not check_valid_address(data.Target) then
				ao.send({ Target = msg.From, Action = 'Validation-Error', Tags = { Status = 'Error', Message = 'Target must be a valid address' } })
				return
			end

			ao.send({
				Target = data.Target,
				Action = data.Action,
				Data = data.Input
			})
		else
			ao.send({
				Target = msg.From,
				Action = 'Input-Error',
				Tags = {
					Status = 'Error',
					Message = string.format(
						'Failed to parse data, received: %s. %s.', msg.Data,
						'Data must be an object - { Target, Action, Input }')
				}
			})
		end
	end)

-- Tags { Proxy-Action, Proxy-Target }, Data = Message content or JSON
Handlers.add('Proxy-Action', Handlers.utils.hasMatchingTag('Action', 'Proxy-Action'),
		function(msg)
			local authorizeResult, message = authorizeRoles(msg)
			if not authorizeResult then
				ao.send(message)
				return
			end

			if not msg.Tags['Proxy-Target'] or not msg.Tags['Proxy-Action'] then
				ao.send({
					Target = msg.From,
					Action = 'Input-Error',
					Tags = {
						Status = 'Error',
						Message =
						'Invalid arguments, required { Target, Action, Input }'
					}
				})
				return
			end

			local newTags = msg.Tags or {}
			local proxyTarget
			if not check_valid_address(newTags['Proxy-Target']) then
				ao.send({ Target = msg.From, Action = 'Validation-Error', Tags = { Status = 'Error', Message = 'Tag Proxy-Target must be a provided and a valid address' } })
				return
			end

			if newTags['Action'] and newTags ['Proxy-Action'] then
				newTags['Action'] = newTags['Proxy-Action']
			end

			if newTags['Proxy-Target'] then
				proxyTarget = newTags['Proxy-Target']
				newTags['Proxy-Target'] = nil
			end

			ao.send({
				Target = proxyTarget,
				Action = newTags.Action,
				Data = msg.Data,
				Tags = newTags
			})

		end)
