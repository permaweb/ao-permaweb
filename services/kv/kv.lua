local json = require('json')
if not KV then KV = {} end
if not KV.store then
    KV.store = {
        ["@x/Display-Name"] = "BobbaBouey",
        ["@x/Username"] = "Bobba",
        ["@x/Topics#01"] = "Comedy",
        ["@x/Topics#02"] = "Action",
        ["@x/Topics#03"] = "Adventure",
        ["@y/Topics#01"] = "Nonsense",
        ["@x/Email/Yahoo"] = "example@yahoo.com",
        ["@x/Email/Gmail"] = "example@gmail.com"
    }
end

KV.store["@x/Description"] = json.encode({ value= "Welcome to Rocketry Frontier, your go-to source for all things rockets and space flight! Dive into the universe of cutting-edge rocket technology and space missions with us. Stay updated on the latest developments, from new rocket launches to groundbreaking space exploration projects. Our channel features expert interviews, in-depth analyses, and live coverage of major space events. Connect with us at [rocketfrontier.com](https://rocketfrontier.com) for more information. For inquiries, reach out to us at (555) 123-4567 or email us at contact@rocketfrontier.com. Follow us on our social media channels: [Facebook](https://facebook.com/rocketryfrontier), [Twitter](https://twitter.com/rocketryfrontier), and [Instagram](https://instagram.com/rocketryfrontier). Join our community and embark on an exhilarating journey through the stars with Rocketry Frontier!" })

local PATH_DELIM = "/"
local INDEX_DELIM = "#"
function starts_with(str, start)
    return str:sub(1, #start) == start
end

function split(str, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for part in string.gmatch(str, "([^" .. sep .. "]+)") do
        table.insert(t, part)
    end
    return t;
end

local function get_index_and_value(keyParts)
    print(#keyParts)
    if #keyParts == 2 then
        return nil, keyParts[2]
    elseif #keyParts == 3 then
        return keyParts[2], keyParts[3]
    end
end

-- get single or multi value response
function KV.get(keysParams)
    local results = {} -- { ns: { _key: value|values[] }}
    for _, keyParams in ipairs(keysParams) do
        local nsParam, keyParam = keyParams.ns, keyParams.key
        if not results[nsParam] then results[nsParam] = {} end
        local matchKey = nsParam .. PATH_DELIM .. keyParam
        local matches = {} -- { { index: 1, value: "Tag1" }, { index: 2, value: "Tag2" } }
        local hasIndex = false
        for storeKey, storeValue in pairs(KV.store) do
            if starts_with(storeKey, matchKey) then
                local keyParts = split(storeKey, PATH_DELIM)
                if #keyParts < 2 or #keyParts > 3 then
                    print("UNKNOWN ERROR: CANNOT PARSE KEY: " .. storeKey)
                    return
                end
                local idx, val = get_index_and_value(keyParts)

                if idx then
                    print("STOREKEY " .. storeKey)
                    table.insert(matches, {index = idx, value = storeValue})
                else
                    table.insert(matches, storeValue)
                end
            end
        end
        if hasIndex then
            -- if there are multiple matches, return a multi result
            results[nsParam][keyParam] = matches
        else
            -- if there is no index, return a single result
            results[nsParam][keyParam] = matches[1]
        end
    end
    return json.encode(results)
end

function KV.set(args) --    ns, key, subkey, value, inx
    local ns, keyparts

    local compositeKey = ns .. PATH_DELIM .. key
    if subkey then
        compositeKey = compositeKey .. PATH_DELIM .. subkey
    end
    if inx then
        compositeKey = compositeKey .. INDEX_DELIM .. inx
    end
    KV.store[compositeKey] = value
end

function KV.delete(ns, key, subkey, value)
    local compositeKey = ns .. SEP .. key .. PATH_DELIM .. subkey .. PATH_DELIM .. value
    KV.store[compositeKey] = nil
end

local ret = KV.get({ { ns = "@x", key = "Topics" } })
print(ret)
--local ret2 = KV.get({ { ns = "@x", key = "Display-Name" }, { ns = "@x", key = "Description" } })
--print(ret2)
--local ret3 = KV.get({ { ns = "@x", key = "Topics" }, { ns = "@x", key = "Display-Name" }, { ns = "@y", key = "Topics"} })
--print(ret3)




