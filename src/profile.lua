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

-- Assets: { Id, Type, Quantity } []

if not Assets then Assets = {} end

if not Roles then Roles = {} end

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

local function decode_message_data(data)
	local status, decoded_data = pcall(json.decode, data)

	if not status or type(decoded_data) ~= 'table' then
		return false, nil
	end

	return true, decoded_data
end

local function authorizeRoles(msg, Roles)
  -- If Roles is blank, the initial call should be from the owner
  if msg.From ~= Owner and msg.From ~= ao.id and next(Roles) == nil then
    return false, {
      Target = msg.From,
      Action = 'Authorization-Error',
      Tags = {
        Status = 'Error',
        Message = 'Initial Roles not set, owner is not authorized for this handler'
      }
    }
  end

  local existingRole = false
  for _, role in pairs(Roles) do
    if role.AddressOrProfile == msg.From then
      existingRole = true
      break
    end
  end

  if not existingRole and msg.From == Owner then
    -- If Roles table is empty or owner doesn't exist, authorize the owner
    table.insert(Roles, { Role = 'Owner', AddressOrProfile = msg.From })
  end

  if not existingRole then
    return false, {
      Target = msg.From,
      Action = 'Authorization-Error',
      Tags = {
        Status = 'Error',
        Message = 'Unauthorized to access this handler'
      }
    }
  end

  return true
end

Handlers.add('Info', Handlers.utils.hasMatchingTag('Action', 'Info'),
	function(msg)
		ao.send({
			Target = msg.From,
			Action = 'Read-Success',
			Data = json.encode({
				Profile = Profile,
				Assets = Assets,
				Owner = Owner
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
Handlers.add('Update-Profile', Handlers.utils.hasMatchingTag('Action', 'Update-Profile'),
	function(msg)
	    local authorizeResult, message = authorizeRoles(msg)
	    if not authorizeResult then
            ao.send(message)
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

			Profile.UserName = data.UserName or Profile.UserName or ''
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
					UserName = data.UserName or nil,
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
						'Data must be an object - { UserName, DisplayName, Description, CoverImage, ProfileImage }')
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

-- Data - { Recipient, Quantity }
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

-- Data - { Sender, Quantity }
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

-- Data - { Id, Quantity }
Handlers.add('Add-Uploaded-Asset', Handlers.utils.hasMatchingTag('Action', 'Add-Uploaded-Asset'),
	function(msg)
	    local authorizeResult, message = authorizeRoles(msg)
	    if not authorizeResult then
            ao.send(message)
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