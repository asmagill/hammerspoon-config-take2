--
-- Based heavily on MiddleClick, https://github.com/artginzburg/MiddleClick-Catalina
--

--
-- leaving here because linked to in https://github.com/Hammerspoon/hammerspoon/issues/2057
-- further work, cleanup, etc. being done at https://github.com/asmagill/hs._asm.undocumented.touchdevice/blob/master/Examples/middleButton.lua
--

local touchdevice = require("hs._asm.undocumented.touchdevice")
local menubar     = require("hs.menubar")
local eventtap    = require("hs.eventtap")
local canvas      = require("hs.canvas")
local settings    = require("hs.settings")
local caffeinate  = require("hs.caffeinate")
local mouse       = require("hs.mouse")
local timer       = require("hs.timer")
local stext       = require("hs.styledtext")

local eventTypes      = eventtap.event.types
local eventProperties = eventtap.event.properties

local module                    = {}
local USERDATA_TAG              = "threeFingers"
local settings_fingersLabel     = USERDATA_TAG .. "_fingers"
local settings_needToClickLabel = USERDATA_TAG .. "_needClick"

local _menu        = nil
local _needToClick = settings.get(settings_needToClickLabel)
local _fingers     = settings.get(settings_fingersLabel) or 3

-- if _needToClick was false, the trick above for setting the default _fingers won't work, so explicitly check
if _needToClick == nil then _needToClick = true end

local _attachedDeviceCallbacks = {}
local _threeDown               = false
local _wasThreeDown            = false

local _leftClickTap = nil
local _sleepWatcher = nil

local _touchStartTime    = nil
local _middleclickPoint  = nil
local _middleclickPoint2 = nil
local _maybeMiddleClick  = false

local _menuIcon = canvas.new{ x = 0, y = 0, h = 128, w = 128}
_menuIcon[#_menuIcon + 1] = {
    type      = "oval",
    action    = "fill",
    fillColor = { white = 0 },
    frame     = { x = 1, y = 64, h = 48, w = 28 }
}
_menuIcon[#_menuIcon + 1] = {
    type      = "oval",
    action    = "fill",
    fillColor = { white = 0 },
    frame     = { x = 43, y = 32, h = 48, w = 28 }
}
_menuIcon[#_menuIcon + 1] = {
    type      = "oval",
    action    = "fill",
    fillColor = { white = 0 },
    frame     = { x = 97, y = 16, h = 48, w = 28 }
}

module.fingers = function(fingers)
    if type(fingers) == "nil" then
        return _fingers
    else
        assert(math.type(fingers) == "integer", "expected integer")
        assert(fingers > 2, "expected integer greater than 2")
        _fingers = fingers
        settings.set(settings_fingersLabel, _fingers)
        return module
    end
end

module.click = function(on)
    if type(on) == "nil" then
        return _needToClick
    else
        assert(type(on) == "boolean", "expected boolean")
        _needToClick = on
        settings.set(settings_needToClickLabel, _needToClick)
        if _leftClickTap then
            if _needToClick then
                _leftClickTap:start()
            else
                _leftClickTap:stop()
            end
        end
        return module
    end
end

-- touchdevice doesn't currently have a way to detect when new devices added/removed
-- but I think I have sample code now, so maybe in the future...
module.rescan = function()
    -- clear the current callbacks
    for _, v in ipairs(_attachedDeviceCallbacks) do v:stop() end

    -- if we're running, start up new callbcaks for all currently attached devices
    if _menu then
        _attachedDeviceCallbacks = {}
        for _, v in ipairs(touchdevice.devices()) do
            table.insert(
                _attachedDeviceCallbacks,
                touchdevice.forDeviceID(v):frameCallback(function(_, touches, _, _)
                    local nFingers = #touches

                    if (_needToClick) then
                        _threeDown = (nFingers == _fingers)
                    else
                        if nFingers == 0 then
                            if _middleclickPoint and _middleclickPoint2 then
                                local delta = math.abs(_middleclickPoint.x - _middleclickPoint2.x) +
                                              math.abs(_middleclickPoint.y - _middleclickPoint2.y)
                                if delta < 0.4 then
                                    eventtap.middleClick(mouse.getAbsolutePosition())
                                end
                            end
                            _touchStartTime    = nil
                            _middleclickPoint  = nil
                            _middleclickPoint2 = nil
                        elseif nFingers > 0 and not _touchStartTime then
                            _touchStartTime   = timer.secondsSinceEpoch()
                            _maybeMiddleClick = true
                            _middleclickPoint = { x = 0, y = 0 }
                        elseif _maybeMiddleClick then
                            local elapsedTime = timer.secondsSinceEpoch() - _touchStartTime
                            if elapsedTime > .5 then
                                _maybeMiddleClick  = false
                                _middleclickPoint  = nil
                                _middleclickPoint2 = nil
                            end
                        end

                        if nFingers > _fingers then
                            _maybeMiddleClick  = false
                            _middleclickPoint  = nil
                            _middleclickPoint2 = nil
                        elseif nFingers == _fingers then
                            local xAggregate = touches[1].absoluteVector.position.x + touches[2].absoluteVector.position.x + touches[3].absoluteVector.position.x
                            local yAggregate = touches[1].absoluteVector.position.y + touches[2].absoluteVector.position.y + touches[3].absoluteVector.position.y

                            if _maybeMiddleClick then
                                _middleclickPoint  = { x = xAggregate, y = yAggregate }
                                _middleclickPoint2 = { x = xAggregate, y = yAggregate }
                                _maybeMiddleClick  = false;
                            else
                                _middleclickPoint2 = { x = xAggregate, y = yAggregate }
                            end
                        end
                    end
                end):start()
            )
        end
    end
    return module
end

module.start = function()
    if not _menu then
        _menu = menubar.new():setIcon(_menuIcon:imageFromCanvas():template(true):size{ h = 22, w = 22 })
                             :setTooltip("MiddleClick")
                             :setMenu(function(_)
                                 return {
                                     {
                                         title = stext.new(USERDATA_TAG .. " for Hammerspoon", {
                                             font  = { name = "Arial-BoldItalicMT", size = 13 },
                                             color = { list = "x11", name = "royalblue" },
                                         }),
                                         disabled = true
                                     },
                                     { title = "-" },
                                     {
                                         title   = string.format("%d Finger Click", _fingers),
                                         fn      = function(_) module.click(true) end,
                                         checked = (_needToClick == true)
                                     }, {
                                         title   = string.format("%d Finger Tap", _fingers),
                                         fn      = function(_) module.click(false) end,
                                         checked = (_needToClick == false)
                                     },
                                     { title = "-" },
                                     { title = "Rescan Multitouch devices", fn = module.rescan },
                                     { title = "-" },
                                     { title = "Quit", fn = module.stop },
                                 }
                             end)

        module.rescan() -- will attach all currently attached devices
        _threeDown    = false
        _wasThreeDown = false

        _leftClickTap = eventtap.new({ eventTypes.leftMouseDown, eventTypes.leftMouseUp }, function(event)
            if _needToClick then
                local eType = event:getType()
                if _threeDown and eType == eventTypes.leftMouseDown then
                    _wasThreeDown = true
                    _threeDown = false
                    return true, { eventtap.event.newMouseEvent(
                        eventTypes.otherMouseDown,
                        event:location()
                    ):rawFlags(event:rawFlags())
                    :setProperty(eventProperties.mouseEventButtonNumber, 2) }
                elseif _wasThreeDown and eType == eventTypes.leftMouseUp then
                    _wasThreeDown = false
                    return true, { eventtap.event.newMouseEvent(
                        eventTypes.otherMouseUp,
                        event:location()
                    ):rawFlags(event:rawFlags())
                    :setProperty(eventProperties.mouseEventButtonNumber, 2) }
                end
            end
            return false
        end)
        if _needToClick then _leftClickTap:start() end
        _sleepWatcher = caffeinate.watcher.new(function(event)
            if event == caffeinate.watcher.systemDidWake then
                module.rescan()
            end
        end):start()
    end
    return module
end

module.stop = function()
    if _menu then
        _menu:delete()
        _menu = nil
        module.rescan() -- will clear all device callbacks
        _threeDown    = false
        _wasThreeDown = false

        _leftClickTap:stop() ; _leftClickTap = nil
        _sleepWatcher:stop() ; _sleepWatcher = nil
    end
    return module
end

-- remove :start() if you don't want this to auto-start
return module:start()
