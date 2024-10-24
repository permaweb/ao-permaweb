local bint = require('.bint')(256)
local json = require('json')

if Name ~= '<NAME>' then Name = '<NAME>' end

Creator = Creator or '<CREATOR>'
Ticker = Ticker or '<TICKER>'
Denomination = Denomination or '<DENOMINATION>'
TotalSupply = TotalSupply or '<SUPPLY>'
Balances = Balances or { ['<CREATOR>'] = '<SUPPLY>' }
Collection = Collection or '<COLLECTION>'

Transferable = true

table.insert(ao.authorities, 'fcoN_xJeisVsPXA-trzVAuIiqO3ydLQxM-L4XbrQKzY')

local function checkValidAddress(address)
	if not address or type(address) ~= 'string' then
		return false
	end

	return string.match(address, "^[%w%-_]+$") ~= nil and #address == 43
end

local function checkValidAmount(data)
	return (math.type(tonumber(data)) == 'integer' or math.type(tonumber(data)) == 'float') and bint(data) > 0
end

local function decodeMessageData(data)
	local status, decodedData = pcall(json.decode, data)

	if not status or type(decodedData) ~= 'table' then
		return false, nil
	end

	return true, decodedData
end

-- Read process state
Handlers.add('Info', Handlers.utils.hasMatchingTag('Action', 'Info'), function(msg)
	msg.reply({
		Name = Name,
		Ticker = Ticker,
		Denomination = tostring(Denomination),
		Transferable = Transferable,
		Data = json.encode({
			Name = Name,
			Ticker = Ticker,
			Denomination = tostring(Denomination),
			Balances = Balances,
			Transferable = Transferable
		})
	})
end)

-- Transfer balance to recipient (Data - { Recipient, Quantity })
Handlers.add('Transfer', Handlers.utils.hasMatchingTag('Action', 'Transfer'), function(msg)
	if not Transferable and msg.From ~= ao.id then
		msg.reply({ Action = 'Validation-Error', Tags = { Status = 'Error', Message = 'Transfers are not allowed' } })
		return
	end

	local data = {
		Recipient = msg.Tags.Recipient,
		Quantity = msg.Tags.Quantity
	}

	if checkValidAddress(data.Recipient) and checkValidAmount(data.Quantity) and bint(data.Quantity) <= bint(Balances[msg.From]) then
		-- Transfer is valid, calculate balances
		if not Balances[msg.From] then
			Balances[msg.From] = '0'
		end

		if not Balances[data.Recipient] then
			Balances[data.Recipient] = '0'
		end

		Balances[msg.From] = tostring(bint(Balances[msg.From]) - bint(data.Quantity))
		Balances[data.Recipient] = tostring(bint(Balances[data.Recipient]) + bint(data.Quantity))

		-- If new balance zeroes out then remove it from the table
		if bint(Balances[msg.From]) <= bint(0) then
			Balances[msg.From] = nil
		end
		if bint(Balances[data.Recipient]) <= bint(0) then
			Balances[data.Recipient] = nil
		end

		local debitNoticeTags = {
			Status = 'Success',
			Message = 'Balance transferred, debit notice issued',
			Recipient = msg.Tags.Recipient,
			Quantity = msg.Tags.Quantity,
		}

		local creditNoticeTags = {
			Status = 'Success',
			Message = 'Balance transferred, credit notice issued',
			Sender = msg.From,
			Quantity = msg.Tags.Quantity,
		}

		for tagName, tagValue in pairs(msg) do
			if string.sub(tagName, 1, 2) == 'X-' then
				debitNoticeTags[tagName] = tagValue
				creditNoticeTags[tagName] = tagValue
			end
		end

		-- Send a debit notice to the sender
		ao.send({
			Target = msg.From,
			Action = 'Debit-Notice',
			Tags = debitNoticeTags,
			Data = json.encode({
				Recipient = data.Recipient,
				Quantity = tostring(data.Quantity)
			})
		})

		-- Send a credit notice to the recipient
		ao.send({
			Target = data.Recipient,
			Action = 'Credit-Notice',
			Tags = creditNoticeTags,
			Data = json.encode({
				Sender = msg.From,
				Quantity = tostring(data.Quantity)
			})
		})
	end
end)

-- Mint new tokens (Data - { Quantity })
Handlers.add('Mint', Handlers.utils.hasMatchingTag('Action', 'Mint'), function(msg)
	local decodeCheck, data = decodeMessageData(msg.Data)

	if decodeCheck and data then
		-- Check if quantity is present
		if not data.Quantity then
			msg.reply({ Action = 'Input-Error', Tags = { Status = 'Error', Message = 'Invalid arguments, required { Quantity }' } })
			return
		end

		-- Check if quantity is a valid integer greater than zero
		if not checkValidAmount(data.Quantity) then
			msg.reply({ Action = 'Validation-Error', Tags = { Status = 'Error', Message = 'Quantity must be an integer greater than zero' } })
			return
		end

		-- Check if owner is sender
		if msg.From ~= Owner then
			msg.reply({ Action = 'Validation-Error', Tags = { Status = 'Error', Message = 'Only the process owner can mint new tokens' } })
			return
		end

		-- Mint request is valid, add tokens to the pool
		if not Balances[Owner] then
			Balances[Owner] = '0'
		end

		Balances[Owner] = tostring(bint(Balances[Owner]) + bint(data.Quantity))

		msg.reply({ Action = 'Mint-Success', Tags = { Status = 'Success', Message = 'Tokens minted' } })
	else
		msg.reply({
			Action = 'Input-Error',
			Tags = {
				Status = 'Error',
				Message = string.format('Failed to parse data, received: %s. %s', msg.Data,
					'Data must be an object - { Quantity }')
			}
		})
	end
end)

-- Read balance ({ Recipient | Target })
Handlers.add('Balance', Handlers.utils.hasMatchingTag('Action', 'Balance'), function(msg)
	local data

	if msg.Tags.Recipient then
		data = { Target = msg.Tags.Recipient }
	elseif msg.Tags.Target then
		data = { Target = msg.Tags.Target }
	else
		data = { Target = msg.From }
	end

	if data then
		-- Check if target is present
		if not data.Target then
			msg.reply({ Action = 'Input-Error', Tags = { Status = 'Error', Message = 'Invalid arguments, required { Target }' } })
			return
		end

		-- Check if target is a valid address
		if not checkValidAddress(data.Target) then
			msg.reply({ Action = 'Validation-Error', Tags = { Status = 'Error', Message = 'Target is not a valid address' } })
			return
		end

		local balance = Balances[data.Target] or '0'

		msg.reply({
			Action = 'Balance-Notice',
			Tags = {
				Status = 'Success',
				Message = 'Balance received',
				Account = data.Target
			},
			Data = balance
		})
	else
		msg.reply({
			Action = 'Input-Error',
			Tags = {
				Status = 'Error',
				Message = string.format('Failed to parse data, received: %s. %s', msg.Data,
					'Data must be an object - { Target }')
			}
		})
	end
end)

-- Read balances
Handlers.add('Balances', Handlers.utils.hasMatchingTag('Action', 'Balances'),
	function(msg) msg.reply({ Data = json.encode(Balances) }) end)

-- Read total supply of token
Handlers.add('Total-Supply', Handlers.utils.hasMatchingTag('Action', 'Total-Supply'), function(msg)
	assert(msg.From ~= ao.id, 'Cannot call Total-Supply from the same process!')

	msg.reply({
		Action = 'Total-Supply',
		Data = tostring(TotalSupply),
		Ticker = Ticker
	})
end)

-- Initialize a request to add to creator zone
Handlers.once('Add-Upload-To-Zone', 'Add-Upload-To-Zone', function(msg)
	if msg.From ~= Creator and msg.From ~= Owner and msg.From ~= ao.id then return end
	ao.send({
		Target = Creator,
		Action = 'Add-Upload',
		AssetId = ao.id
	})
end)
