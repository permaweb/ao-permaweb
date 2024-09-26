local AssetManager = {}

AssetManager.__index = AssetManager

local AssetManagerPackageName = '@permaweb/asset-manager'

function AssetManager.new()
    local self = setmetatable({}, AssetManager)
    self.uploads = {}
    return self
end

function AssetManager.get_uploads()
    print('Get uploads')
end

package.loaded[AssetManagerPackageName] = AssetManager

return AssetManager
