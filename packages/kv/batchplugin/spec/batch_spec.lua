local KV = require('kv')
local BatchPlugin = require('batch')

describe("Should set and get simple strings", function()
    it("should set and get", function()

        -- Create a batch plugin instance
        local batchPlugin = BatchPlugin.new()

        -- Create a KV instance with the batch plugin
        local myKV = KV.new({batchPlugin})

        -- Set a key using base method
        myKV:set("president", "Steve")
        local president = myKV:get("president")
        assert.are.same(president, "Steve")

        -- Use the batch methods via the KV instance
        local b = myKV:batchInit()
        b:set("count", 1)
        b:set("vice-president", "John")

        -- Execute batch operations
        b:execute()
        assert.are.same(myKV:get("vice-president"), "John")
        assert.are.same(myKV:get("count"), 1)
    end)
end)
