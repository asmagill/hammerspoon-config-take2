local module = {}
local application = require("hs.application")
local timer       = require("hs.timer")
local axuielement = require("hs.axuielement")

local _timers = {}

local labelFor = function(e)
    for k, v in pairs(application.watcher) do
        if v == e then return k end
    end
    return nil
end

module._watcher = application.watcher.new(function(n, e, a)
    e = labelFor(e)
    if e == "launched" then
        local ax = axuielement.applicationElement(a)
        local tm = timer.secondsSinceEpoch()
        _timers[n] = timer.doEvery(.1, function()
            local value, msg = ax:attributeValue("AXMenuBar")
            print(value, msg)
            if value ~= nil then
--             if ax.AXFocusedWindow ~= nil then
--             if a:focusedWindow() ~= nil then
                print(string.format("%s AXFocusedWindow created %f after launch", n, timer.secondsSinceEpoch() - tm))
                _timers[n]:stop()
                _timers[n] = nil
            end
        end)
    elseif e == "terminated" and _timers[n] then
        _timers[n]:stop()
        _timers[n] = nil
    end
--     print(n, e)
end):start()

return module
