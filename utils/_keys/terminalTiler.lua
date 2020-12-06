local axuielement = require("hs.axuielement")
local hotkey      = require("hs.hotkey")
local alert       = require("hs.alert")
local awatcher    = require("hs.application.watcher")
local wtiling     = require("hs.window.tiling")
local screen      = require("hs.screen")

local module = {}

local ignoreList = {}

local toggleWindowInclusion = function()
    local win = axuielement.applicationElement("Terminal").AXFocusedWindow
    if win and win.AXSubrole == "AXStandardWindow" then
        local winID = win:asHSWindow():id()
        ignoreList[winID] = (not ignoreList[winID]) and true or nil
        alert(string.format("Window %d will be %s", winID, ignoreList[winID] and "ignored" or "tiled"))
    end
end

local tileTerminals = function()
    local windows = {}
    for i,v in ipairs(axuielement.applicationElement("Terminal")) do
        if v.AXRole == "AXWindow" and v.AXSubrole == "AXStandardWindow" then
            local hsw = v:asHSWindow()
            if not ignoreList[hsw:id()] then table.insert(windows, v:asHSWindow()) end
        end
    end
    wtiling.tileWindows(windows,screen.mainScreen():frame(), 1, false, false, 0)
end

local _toggleInclusion = hotkey.new({"cmd", "alt", "ctrl"}, "i", nil, toggleWindowInclusion)
local _tileWindows     = hotkey.new({"cmd", "alt", "ctrl"}, "t", nil, tileTerminals)

-- I like labels better than numbers... easier to tell what they mean at a glance
local intToEvent = function(num)
    local answer = "unknown: " .. tostring(num)
    for k,v in pairs(awatcher) do
        if type(v) == "number" and v == num then
            answer = k
            break
        end
    end
    return answer
end

-- only activate hotkey within Finder and deactivate it again when we leave
module._appWatcher = awatcher.new(function(name, event, obj)
    event = intToEvent(event)
-- print(name, event)
    if name == "Terminal" then
        if event == "activated" then
            _toggleInclusion:enable()
            _tileWindows:enable()
        elseif event == "deactivated" then
            _toggleInclusion:disable()
            _tileWindows:disable()
        end
    end
end):start()

return module
