local hue   = require("hs._asm.hue")
local timer = require("hs.timer")

local module = {}

local waitForDefault = timer.waitUntil(function()
    return hue.default ~= nil
end, function(t)
    waitForDefault = nil

    local _groupMappings = {}
    for k,v in pairs(hue.default:get("/groups")) do
        _groupMappings[v.name] = k
    end

    module.livingRoom = function(state)
        if type(state) == "nil" then
            local ans = hue.default:get("/groups/" .. _groupMappings["Living Room"]).state
            return ans.all_on, ans.any_on
        else
            local change = {}
            if type(state) == "number" then change.bri = state end
            if type(state) == "boolean" then change.on = state end
            if type(state) == "table" then change = state end
            return hue.default:put("/groups/" .. _groupMappings["Living Room"] .. "/action", change)
        end
    end

    _lr = module.livingRoom
end)

return module
