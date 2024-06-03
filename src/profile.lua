local bint = require('.bint')(256)
local json = require('json')

-- Profile: {
--   UserName
--   DisplayName
--   Description
--   CoverImage
--   ProfileImage
--   DateCreated
--   DateUpdated
-- }

if not Profile then Profile = {} end

-- Assets: { Id, Quantity } []

if not Assets then Assets = {} end

if not Roles then Roles = {} end
--hello
REGISTRY = 'kFYMezhjcPCZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI'

local function check_valid_address(address)
	if not address or type(address) ~= 'string' then
		return false
	end

	return string.match(address, "^[%w%-_]+$") ~= nil and #address == 43
end

local function check_required_data(data, required_fields)
	for _, field in ipairs(required_fields) do
		if data[field] ~= nil then
			return true
		end
	end
	return false
end

local function check_valid_amount(data)
	return (math.type(tonumber(data)) == 'integer' or math.type(tonumber(data)) == 'float') and bint(data) > 0
end

local function decode_message_data(data)
	local status, decoded_data = pcall(json.decode, data)

	if not status or type(decoded_data) ~= 'table' then
		return false, nil
	end

	return true, decoded_data
end

local function validate_transfer_data(msg)
	local decodeCheck, data = decode_message_data(msg.Data)

	if not decodeCheck or not data then
		return nil, string.format('Failed to parse data, received: %s. %s.', msg.Data,
			'Data must be an object - { Target, Recipient, Quantity }')
	end

	-- Check if target, recipient and quantity are present
	if not data.Target or not data.Recipient or not data.Quantity then
		return nil, 'Invalid arguments, required { Target, Recipient, Quantity }'
	end

	-- Check if target is a valid address
	if not check_valid_address(data.Target) then
		return nil, 'Target must be a valid address'
	end

	-- Check if recipient is a valid address
	if not check_valid_address(data.Recipient) then
		return nil, 'Recipient must be a valid address'
	end

	-- Check if quantity is a valid integer greater than zero
	if not check_valid_amount(data.Quantity) then
		return nil, 'Quantity must be an integer greater than zero'
	end

	-- Recipient cannot be sender
	if msg.From == data.Recipient then
		return nil, 'Recipient cannot be sender'
	end

	return data
end

Handlers.add('Info', Handlers.utils.hasMatchingTag('Action', 'Info'),
	function(msg)
		ao.send({
			Target = msg.From,
			Action = 'Read-Success',
			Data = json.encode({
				Profile = Profile,
				Assets = Assets
			})
		})
	end)

-- Data - { UserName?, DisplayName?, Description?, CoverImage, ProfileImage }
Handlers.add('Update-Profile', Handlers.utils.hasMatchingTag('Action', 'Update-Profile'),
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

		local decode_check, data = decode_message_data(msg.Data)

		if decode_check and data then
			if not check_required_data(data, { "UserName", "DisplayName", "Description", "CoverImage", "ProfileImage" }) then
				ao.send({
					Target = msg.From,
					Action = 'Input-Error',
					Tags = {
						Status = 'Error',
						EMessage =
						'Invalid arguments, required at least one of { UserName, DisplayName, Description, CoverImage, ProfileImage }'
					}
				})
				return
			end

			--if (data.UserName) then
			--	Profile.UserName = data.UserName
			--end
			Profile.Username = data.UserName or Profile.Username or ''
			Profile.DisplayName = data.DisplayName or Profile.DisplayName or ''
			Profile.Description = data.Description or Profile.Description or ''
			Profile.CoverImage = data.CoverImage or Profile.CoverImage or ''
			Profile.ProfileImage = data.ProfileImage or Profile.ProfileImage or ''
			Profile.DateCreated = Profile.DateCreated or msg.Timestamp
			Profile.DateUpdated = msg.Timestamp

			ao.send({
				Target = REGISTRY,
				Action = 'Update-Profile',
				Data = json.encode({
					ProfileId = ao.id,
					AuthorizedAddress = msg.From,
					Username = data.Username or nil,
					DisplayName = data.DisplayName or nil,
					Description = data.Description or nil,
					CoverImage = data.CoverImage or nil,
					ProfileImage = data.ProfileImage or nil,
					DateCreated = Profile.DateCreated,
					DateUpdated = Profile.DateUpdated
				}),
				Tags = msg.Tags
			})

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
						'Data must be an object - { Username }')
				}
			})
		end
	end)

-- Data - { Target, Recipient, Quantity }
Handlers.add('Transfer', Handlers.utils.hasMatchingTag('Action', 'Transfer'),
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

		local data, error = validate_transfer_data(msg)

		if data then
			local forwardedTags = {}

			for tagName, tagValue in pairs(msg) do
				if string.sub(tagName, 1, 2) == 'X-' then
					forwardedTags[tagName] = tagValue
				end
			end

			ao.send({
				Target = data.Target,
				Action = 'Transfer',
				Tags = forwardedTags,
				Data = json.encode({
					Recipient = data.Recipient,
					Quantity = data.Quantity
				})
			})
		else
			ao.send({
				Target = msg.From,
				Action = 'Transfer-Error',
				Tags = { Status = 'Error', Message = error or 'Error transferring balances' }
			})
		end
	end)

-- Data - { Recipient, Quantity }
Handlers.add('Debit-Notice', Handlers.utils.hasMatchingTag('Action', 'Debit-Notice'),
	function(msg)
		local decode_check, data = decode_message_data(msg.Data)

		if decode_check and data then
			if not data.Recipient or not data.Quantity then
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

			if not check_valid_address(data.Recipient) then
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
				local updated_quantity = tonumber(Assets[asset_index].Quantity) - tonumber(data.Quantity)

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
			end
		else
			ao.send({
				Target = msg.From,
				Action = 'Input-Error',
				Tags = {
					Status = 'Error',
					Message = string.format(
						'Failed to parse data, received: %s. %s.', msg.Data,
						'Data must be an object - { Recipient, Quantity }')
				}
			})
		end
	end)

-- Data - { Sender, Quantity }
Handlers.add('Credit-Notice', Handlers.utils.hasMatchingTag('Action', 'Credit-Notice'),
	function(msg)
		local decode_check, data = decode_message_data(msg.Data)

		if decode_check and data then
			if not data.Sender or not data.Quantity then
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

			if not check_valid_address(data.Sender) then
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
				local updated_quantity = tonumber(Assets[asset_index].Quantity) + tonumber(data.Quantity)

				Assets[asset_index].Quantity = tostring(updated_quantity)
			else
				table.insert(Assets, { Id = msg.From, Quantity = data.Quantity })

				ao.send({
					Target = Owner,
					Action = 'Transfer-Success',
					Tags = {
						Status = 'Success',
						Message = 'Balance transferred'
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
						'Data must be an object - { Sender, Quantity }')
				}
			})
		end
	end)

-- Data - { Id, Quantity }
Handlers.add('Add-Uploaded-Asset', Handlers.utils.hasMatchingTag('Action', 'Add-Uploaded-Asset'),
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
				table.insert(Assets, { Id = data.Id, Quantity = data.Quantity })
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
	end)

