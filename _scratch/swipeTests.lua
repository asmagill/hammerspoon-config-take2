local event  = require("hs.eventtap.event")
local hotkey = require("hs.hotkey")
local timer  = require("hs.timer")
local math   = require("hs.math")

local module = {}
module._keys = {}

local sKeys = {
   h = "Left",
   j = "Down",
   k = "Up",
   l = "Right",
}

local mods = { "cmd", "shift", "alt", "ctrl" }

for key, dir in pairs(sKeys) do
    table.insert(module._keys, hotkey.new(mods, key, function()
        print("Swipe "..dir)
        event.newGesture("beginSwipe"..dir, 0):post()
        timer.doAfter(math.minFloat, function() event.newGesture("endSwipe"..dir):post() end)
    end))
end

module.disable = function()
    for _,v in ipairs(module._keys) do v:disable() end
    return module
end

module.enable = function()
    for _,v in ipairs(module._keys) do v:enable() end
    return module
end

return module.enable()
