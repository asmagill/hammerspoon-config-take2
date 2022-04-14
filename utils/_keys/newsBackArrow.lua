local application = require("hs.application")
local hotkey      = require("hs.hotkey")
local axuielement = require("hs.axuielement")

-- I like labels better than numbers... easier to tell what they mean at a glance
local intToEvent = function(num)
    local answer = "unknown: " .. tostring(num)
    for k,v in pairs(application.watcher) do
        if type(v) == "number" and v == num then
            answer = k
            break
        end
    end
    return answer
end

local module = {}

module._hotkey = hotkey.new({ "cmd" }, "left", function()
    local frontBundle = application.frontmostApplication():bundleID()
    local newsApp     = axuielement.applicationElement("com.apple.news")

    -- shouldn't happen, but just in case
    if  not (frontBundle == "com.apple.news" and newsApp) then
        module._hotkey:disable()
        return
    end

    local focusedWin = newsApp.AXFocusedWindow
    if focusedWin then
        local buttons = focusedWin:childrenWithRole("AXToolbar")[1]:childrenWithRole("AXButton")

        for _, v in ipairs(buttons) do
            if v.AXDescription == "go back" then
                v:doAXPress()
                return
            end
        end

        -- means we need better error checking or Apple has changed something, so print warning
        print("** unable to find back button in News app")
    end
end)

module._appwatcher = application.watcher.new(function(name, event, obj)
    event = intToEvent(event)
    if name == "News" then
        if event == "activated" then
            module._hotkey:enable()
        elseif event == "deactivated" then
            module._hotkey:disable()
        end
    end
end):start()

return module
