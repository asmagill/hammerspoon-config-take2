-- Inspired by https://github.com/Hammerspoon/hammerspoon/issues/2196 and the code found at
-- https://github.com/lodestone/macpaste

local eventtap   = require("hs.eventtap")
local eventTypes = eventtap.event.types
local timer      = require("hs.timer")
local mouse      = require("hs.mouse")
local keycodes   = require("hs.keycodes")

local module = {}

local clickDownTime   = 0
local wasDragging     = false
local doubleClickTime = eventtap.doubleClickInterval()

module._copyWatcher = eventtap.new({eventTypes.leftMouseDown, eventTypes.leftMouseDragged, eventTypes.leftMouseUp}, function(e)
    -- probably overkill since the synthetic mouseDown/Up should be too quick and not involve dragging, but just in
    -- case, lets check to see if we're currently doing a "paste" operation and skip this if we are...
    if not module._pasteTimer then
        local t = e:getType()
        local additionalEvents = nil
        if t == eventTypes.leftMouseDown then
            clickDownTime = timer.secondsSinceEpoch()
        elseif t == eventTypes.leftMouseDragged then
            wasDragging = true
        elseif t == eventTypes.leftMouseUp then
            if wasDragging or (timer.secondsSinceEpoch() - clickDownTime <= doubleClickTime) then
                additionalEvents = {
                    eventtap.event.newKeyEvent({"cmd"}, "c", true),
                    eventtap.event.newKeyEvent({"cmd"}, "c", false),
                }
            end
            wasDragging = false
        end
        if additionalEvents then
            return false, additionalEvents
        end
    end
    return false
end):start()

module._pasteWatcher = eventtap.new({eventTypes.otherMouseDown}, function(e)
    if e:getProperty(eventtap.event.properties.mouseEventButtonNumber) == 2 then -- the button numbers starts at 0
        -- we do this after a few milliseconds to make sure that the cursor has a chance to activate whatever we're pasting into
        module._pasteTimer = timer.doAfter(.25, function()
            eventtap.event.newKeyEvent({"cmd"}, "v", true):post()
            eventtap.event.newKeyEvent({"cmd"}, "v", false):post()
            module._pasteTimer = nil
        end)
        local mousePos = mouse.getAbsolutePosition()
        return false, {
            eventtap.event.newMouseEvent(eventTypes.leftMouseDown, mousePos),
            eventtap.event.newMouseEvent(eventTypes.leftMouseUp, mousePos),
        }
    else
        return false
    end
end):start()

module.start = function()
    module._copyWatcher:start()
    module._pasteWatcher:start()
    return module
end

module.stop = function()
    if module._pasteTimer then
        module._pasteTimer:stop()
        module._pasteTimer = nil
    end
    module._copyWatcher:stop()
    module._pasteWatcher:stop()
    return module
end

return module
