local AssetManager = require('@permaweb/asset-manager')
if not AssetManager then
    error('AssetManager not found, install it')
end

-- TODO
-- if not ZoneAssetManager then ZoneAssetManager = AssetManager.new() end
ZoneAssetManager = AssetManager.new()

Handlers.add('Get-Assets', 'Get-Assets', function(msg)
    msg.reply({ Action = 'Assets-Notice', Data = ZoneAssetManager:get() })
end)

-- TODO: Auth
Handlers.add('Add-Asset', 'Add-Asset', function(msg)
    print('AssetId: ' .. (msg.AssetId or 'None'))
    print('Timestamp: ' .. (msg.Timestamp or 'None'))

    ZoneAssetManager:update({
        Type = 'Add',
        AssetId = msg.AssetId,
        Timestamp = msg.Timestamp
    })
end)
