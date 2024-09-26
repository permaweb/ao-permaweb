local bint = require('.bint')(256)

local function load_asset_manager()
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
        toBalanceValue = function(a)
            return tostring(bint(a))
        end,
        toNumber = function(a)
            return bint.tonumber(a)
        end
    }

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
        print(self.assets)
    end

    function AssetManager:update(args)
        if not check_required_args(args, { 'AssetId', 'Quantity', 'Timestamp' }) then
            return
        end

        local asset_index = get_asset_index(self, args.AssetId)

        -- TODO: Handle subtration
        if asset_index > -1 then
            print('Updating existing asset...')
            self.assets[asset_index].Quantity = utils.add(self.assets[asset_index].Quantity, args.Quantity)
            self.assets[asset_index].LastUpdate = args.Timestamp
        else
            print('Adding new asset...')
            table.insert(self.assets, {
                Id = args.AssetId,
                Quantity = args.Quantity,
                DateCreated = args.Timestamp,
                LastUpdate = args.Timestamp
            })
        end
    end

    package.loaded[AssetManagerPackageName] = AssetManager

    return AssetManager
end

package.loaded['@permaweb/asset-manager'] = load_asset_manager()

local AssetManager = require('@permaweb/asset-manager')
if not AssetManager then
    error('AssetManager not found, install it')
end

-- TODO
-- if not ZoneAssetManager then ZoneAssetManager = AssetManager.new() end
ZoneAssetManager = AssetManager.new()

Handlers.add('Get-Assets', 'Get-Assets', function(msg)
    ZoneAssetManager:get()
end)

-- TODO: Auth
Handlers.add('Add-Asset', 'Add-Asset', function(msg)
    print('AssetId: ' .. msg.AssetId)
    print('Quantity: ' .. msg.Quantity)
    print('Timestamp: ' .. msg.Timestamp)

    ZoneAssetManager:update({
        AssetId = msg.AssetId,
        Quantity = msg.Quantity,
        Timestamp = msg.Timestamp,
    })
end)
