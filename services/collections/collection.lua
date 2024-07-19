local json = require('json')

if Name ~= '<NAME>' then Name = '<NAME>' end
if Description ~= '<DESCRIPTION>' then Description = '<DESCRIPTION>' end
if Creator ~= '<CREATOR>' then Creator = '<CREATOR>' end
if Banner ~= '<BANNER>' then Banner = '<BANNER>' end
if Thumbnail ~= '<THUMBNAIL>' then Thumbnail = '<THUMBNAIL>' end

if DateCreated ~= '<DATECREATED>' then DateCreated = '<DATECREATED>' end
if LastUpdate ~= '<LASTUPDATE>' then LastUpdate = '<LASTUPDATE>' end

-- Assets: Id[]
if not Assets then Assets = {} end

local function decodeMessageData(data)
	local status, decodedData = pcall(json.decode, data)

	if not status or type(decodedData) ~= 'table' then
		return false, nil
	end

	return true, decodedData
end

local function assetExists(assetId)
	for _, id in ipairs(Assets) do
		if id == assetId then
			return true
		end
	end
	return false
end

local function checkValidAddress(address)
	if not address or type(address) ~= 'string' then
		return false
	end

	return string.match(address, "^[%w%-_]+$") ~= nil and #address == 43
end

Handlers.add('Info', Handlers.utils.hasMatchingTag('Action', 'Info'), function(msg)
	ao.send({
		Target = msg.From,
		Data = json.encode({
			Name = Name,
			Description = Description,
			Creator = Creator,
			Banner = Banner,
			Thumbnail = Thumbnail,
			DateCreated = DateCreated,
			Assets = Assets
		})
	})
end)

-- Add or remove assets
Handlers.add('Update-Assets', Handlers.utils.hasMatchingTag('Action', 'Update-Assets'), function(msg)
	if msg.From ~= Owner and msg.From ~= ao.id and msg.From ~= Creator then
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

	local decodeCheck, data = decodeMessageData(msg.Data)

	if decodeCheck and data then
		if not data.AssetIds or type(data.AssetIds) ~= 'table' or #data.AssetIds == 0 then
			ao.send({
				Target = msg.From,
				Action = 'Action-Response',
				Tags = {
					Status = 'Error',
					Message = 'Invalid or empty AssetIds list'
				}
			})
			return
		end

		if not data.UpdateType or (data.UpdateType ~= 'Add' and data.UpdateType ~= 'Remove') then
			ao.send({
				Target = msg.From,
				Action = 'Action-Response',
				Tags = {
					Status = 'Error',
					Message = 'UpdateType argument required (Add | Remove)'
				}
			})
			return
		end

		if data.UpdateType == 'Add' then
			for _, assetId in ipairs(data.AssetIds) do
				if not assetExists(assetId) then
					table.insert(Assets, assetId)
				end
			end
		end

		if data.UpdateType == 'Remove' then
			for _, assetId in ipairs(data.AssetIds) do
				for i, id in ipairs(Assets) do
					if id == assetId then
						table.remove(Assets, i)
						break
					end
				end
			end
		end

		LastUpdate = msg.Timestamp

		ao.send({
			Target = msg.From,
			Action = 'Action-Response',
			Tags = {
				Status = 'Success',
				Message = 'Assets updated successfully'
			}
		})
	else
		ao.send({
			Target = msg.From,
			Action = 'Input-Error',
			Tags = {
				Status = 'Error',
				Message = string.format('Failed to parse data, received: %s. %s',
					msg.Data,
					'Data must be an object - { AssetIds: [], UpdateType }')
			}
		})
	end
end)

-- Initialize a request to add the collection to a profile
Handlers.add('Add-Collection-To-Profile', Handlers.utils.hasMatchingTag('Action', 'Add-Collection-To-Profile'), function(msg)
	if msg.From ~= Owner and msg.From ~= Creator and msg.From ~= ao.id then
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
	if checkValidAddress(Creator) then
    	ao.assign({Processes = { Creator }, Message = ao.id})
    else
    	ao.send({
    		Target = msg.From,
    		Action = 'Input-Error',
    		Tags = {
    			Status = 'Error',
    			Message = 'ProfileProcess tag not specified or not a valid Process ID'
    		}
    	})
    end
end)
