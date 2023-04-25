--
-- Based heavily on MiddleClick, https://github.com/artginzburg/MiddleClick-Catalina
--

local touchdevice = require("hs._asm.undocumented.touchdevice")
local menubar     = require("hs.menubar")
local eventtap    = require("hs.eventtap")
local canvas      = require("hs.canvas")
local settings    = require("hs.settings")
local caffeinate  = require("hs.caffeinate")
local timer       = require("hs.timer")
local stext       = require("hs.styledtext")

local eventTypes      = eventtap.event.types
local eventProperties = eventtap.event.properties

local hasTDWatcher = touchdevice.watcher and true or false

local module                    = {}
local USERDATA_TAG              = "middleButton"
local settings_fingersLabel     = USERDATA_TAG .. "_fingers"
local settings_needToClickLabel = USERDATA_TAG .. "_needToClick"
local settings_showMenuLabel    = USERDATA_TAG .. "_showMenu"
local settings_tapDeltaLabel    = USERDATA_TAG .. "_tapDelta"

-- convert functions apparently haven't caught up with Big Sur because italicizing the default
-- menu font gives ".SFNS-RegularItalic" which is now reported as "unknown". This seems to work
-- for now, but will need to see if there is a new "preferred" way to "convert" fonts.
local _italicMenuFontName = stext.defaultFonts.menu.name .. "Italic"

local _menu        = nil
local _fingers     = settings.get(settings_fingersLabel) or 3
local _tapDelta    = settings.get(settings_tapDeltaLabel) or 0.4
local _needToClick = settings.get(settings_needToClickLabel)
local _showMenu    = settings.get(settings_showMenuLabel)

-- if _showMenu was false, the trick above for setting the default _fingers won't work, so explicitly check
if _showMenu == nil then _showMenu = true end
-- ditto for _needToClick
if _needToClick == nil then _needToClick = true end

local _attachedDeviceCallbacks = {}
local _enoughDown              = false
local _wasEnoughDown           = false

local _leftClickTap  = nil
local _sleepWatcher  = nil
local _deviceWatcher = nil

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

local _menuFunction = function(_)
    local menuItems = {
        {
            title = stext.new(USERDATA_TAG .. " for Hammerspoon", {
                font  = { name = _italicMenuFontName, size = 13 },
                color = { list = "x11", name = "royalblue" },
            }),
            disabled = true
        }, {
            title = stext.new(
                string.format("%d finger %s", _fingers, _needToClick and "click" or "tap"), {
                font  = { name = _italicMenuFontName, size = 13 },
                color = { list = "x11", name = "magenta" },
                paragraphStyle = { alignment = "center" },
            }),
            disabled = true
        },
        { title = "-" },
        {
            title = "Mode",
            menu = {
                {
                    title   = "Click",
                    fn      = function(_) module.click(true) end,
                    checked = _needToClick,
                }, {
                    title   = "Tap",
                    fn      = function(_) module.click(false) end,
                    checked = not _needToClick,
                },
            }
        }, {
            title = "Fingers",
            menu = { } -- placeholder for the moment
        },
        { title = "-" },
        {
            title    = "Hide menu",
            fn       = module.toggleMenu,
            tooltip  = not hasTDWatcher and "Currently not recommended if you add/remove multitouch devices" or nil,
        }, {
            title    = "Rescan for Multitouch devices",
            fn       = module.rescan,
            tooltip  = "Not required if using v0.3+ of hs._asm.undocumented.touchdevice",
            disabled = hasTDWatcher,
        }, {
            title = stext.new(
                string.format("%d devices detected", #_attachedDeviceCallbacks), {
                font  = { name = _italicMenuFontName, size = 10 },
                paragraphStyle = { alignment = "right" },
            }),
            disabled = true
        },
        { title = "-" },
        { title = "Quit", fn = module.stop },
    }

    for _, v in ipairs(menuItems) do
        if v.title == "Fingers" then
            for i = 3, 10, 1 do
                table.insert(v.menu, {
                    title   = tostring(i),
                    checked = (i == _fingers),
                    fn      = function(_, _) module.fingers(i) end,
                })
            end
            break
        end
    end

    return menuItems
end

local _setupMenu = function()
    if _menu and type(_menu) ~= "boolean" then _menu:delete() end
    if _showMenu then
        _menu = menubar.new():setIcon(_menuIcon:imageFromCanvas()
                             :template(true):size{ h = 22, w = 22 })
                             :setTooltip("MiddleClick")
                             :setMenu(_menuFunction)
                             :autosaveName(USERDATA_TAG)
    else
        _menu = true
    end
end

--- middleButton._debugDelta
--- Variable
--- Flag indicating if delta mismatches should be printed to the Hammerspoon console when `middleButton.click() == false` (i.e. in tap mode).
---
--- Notes:
---  * Set this to true if you wish to use this in tap mode, but it isn't working reliably. Messages will be printed to the console indicating the detected delta value so you can adjust the threshold delta with `middleButton.tapDelta`
---  * This value is *not* saved so it will not persist through restarting or relaunching Hammerspoon.
module._debugDelta = false

--- middleButton.fingers([number]) -> current value | module
--- Function
--- Get or set the number of fingers which indicate that we wish to trigger a middle mouse button click.
---
--- Parameters:
---  * `number` - an integer, between 3 and 10 inclusive, specifying the number of fingers which need to tap or click the trackpad to trigger a middle mouse button press. Defaults to 3.
---
--- Returns:
---  * if a value was specified, returns the module; otherwise returns the current value
---
--- Notes:
---  * this function is invoked by the menu when selecting the number of fingers to watch for
---  * this value is saved via `hs.settings` so it will persist through reloading or relaunch Hammerspoon.
module.fingers = function(fingers)
    if type(fingers) == "nil" then
        return _fingers
    else
        assert(math.type(fingers) == "integer", "expected integer")
        assert(fingers > 2 and fingers < 11, "expected integer between 3 and 10 inclusive")

        _fingers = fingers
        settings.set(settings_fingersLabel, _fingers)

        -- required number may have changed, so reset state
        _enoughDown        = false
        _wasEnoughDown     = false
        _touchStartTime    = nil
        _maybeMiddleClick  = nil
        _middleclickPoint  = nil
        _middleclickPoint2 = nil
        return module
    end
end

--- middleButton.click([state]) -> current value | module
--- Function
--- Get or set whether the middle mouse button should be triggered by a mouse click or a mouse tap.
---
--- Parameters:
---  * `state` - a boolean, default true, specifying if the middle button is triggered by a mouse click (true) or a mouse tap (false).
---
--- Returns:
---  * if a value was specified, returns the module; otherwise returns the current value
---
--- Notes:
---  * this function is invoked by the menu when selecting the trigger mode.
---  * this value is saved via `hs.settings` so it will persist through reloading or relaunch Hammerspoon.
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

        -- required action may have changed, so reset state
        _enoughDown        = false
        _wasEnoughDown     = false
        _touchStartTime    = nil
        _maybeMiddleClick  = nil
        _middleclickPoint  = nil
        _middleclickPoint2 = nil
        return module
    end
end

--- middleButton.toggleMenu() -> module
--- Function
--- Toggles the display of the middleButton menu in the status area of the macOS menubar.
---
--- Parameters:
---  * None
---
--- Returns:
---  * returns the module
---
--- Notes:
---  * this function is invoked when you select the "Hide menu" item from the menu.
---  * this visibilty of the menu is saved via `hs.settings` so it will persist through reloading or relaunch Hammerspoon.
---  * if you load this file with require (e.g. `require("middleButton")`), then you can type `package.loaded["middleButton"].toggleMenu()` in the Hammerspoon console to bring back the menu if it is currently hidden.
module.toggleMenu = function()
    _showMenu = not _showMenu
    settings.set(settings_showMenuLabel, _showMenu)
    _setupMenu()
end

--- middleButton.tapDelta([delta]) -> current value | module
--- Function
--- Get or set the magnitude of the variance between finger position readings when determining if a tap should trigger the middle button click.
---
--- Parameters:
---  * `delta` - a float, default 0.4, specifying the variance between the detected position of the first three fingers (the others are ignored) of a tap when they are first detected vs when they are released to determine if the tap should trigger the middle button click when `middleButton.click()` is false (i.e. in tap mode).
---
--- Returns:
---  * if a value was specified, returns the module; otherwise returns the current value
---
--- Notes:
---  * this value is saved via `hs.settings` so it will persist through reloading or relaunch Hammerspoon.
---  * this value is ignored when in click mode (i.e. `middleButton.click()` is true.
---
---  * if you are having problems with taps beeing detected, set `middleButton._debugDelta = true` to get a real-time report of the calculcated delta for taps when the correct number of fingers are detected, but the delta was too large.
---  * everyone's fingers are different, so you may need to adjust this, but to reduce spurious triggering, you should keep it as small as you can while still being able to trigger it reliably.
module.tapDelta = function(delta)
    if type(delta) == "nil" then
        return _tapDelta
    else
        assert(type(delta) == "number", "expected number")
        assert(delta > 0, "expected number > 0")
        _tapDelta = delta
        settings.set(settings_tapDeltaLabel, _tapDelta)
        return module
    end
end

--- middleButton.rescan() -> module
--- Function
--- Rescans for multi touch devices and starts watchers for those detected.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the module
---
--- Notes:
---  * this function is invoked when you select the "Scan for Multitouch devices" from the menu.
module.rescan = function()
    -- clear the current callbacks
    for _, v in ipairs(_attachedDeviceCallbacks) do v:stop() end
    _attachedDeviceCallbacks = {}

    -- if we're running, start up new callbcaks for all currently attached devices
    if _menu then
        for _, v in ipairs(touchdevice.devices()) do
            local device = touchdevice.forDeviceID(v)
            if device:details().MTHIDDevice then
                table.insert(
                    _attachedDeviceCallbacks,
                    device:frameCallback(function(_, touches, _, _)
                        local nFingers = #touches

                        if (_needToClick) then
                            _enoughDown = (nFingers == _fingers)
                        else
                            if nFingers == 0 then
                                if _middleclickPoint and _middleclickPoint2 then
                                    local delta = math.abs(_middleclickPoint.x - _middleclickPoint2.x) +
                                                  math.abs(_middleclickPoint.y - _middleclickPoint2.y)
                                    if delta < _tapDelta then
                                        -- empty events default to current mouse location
                                        local nullEvent = eventtap.event.newEvent()
                                        eventtap.middleClick(nullEvent:location())
                                    elseif module._debugDelta then
                                        print(string.format("%s - tap delta mismatch: want < %f, got %f", USERDATA_TAG, _tapDelta, delta))
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
                                local xAggregate = touches[1].absoluteVector.position.x +
                                                   touches[2].absoluteVector.position.x +
                                                   touches[3].absoluteVector.position.x
                                local yAggregate = touches[1].absoluteVector.position.y +
                                                   touches[2].absoluteVector.position.y +
                                                   touches[3].absoluteVector.position.y

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
    end
    return module
end

--- middleButton.start() -> module
--- Function
--- Starts watching the currently attached multitouch devices for finger clicks and taps to determine if they should be converted into middle button mouse clicks.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the module
---
--- Notes:
---  * if the menu has not previously been hidden by invoking `middleButton.toggleMenu()` or selecting "Hide menu" from the menu, the menu will also be created when this function is invoked.
module.start = function()
    if not _menu then
        _setupMenu()
        module.rescan() -- will attach all currently attached devices
        _enoughDown        = false
        _wasEnoughDown     = false
        _touchStartTime    = nil
        _maybeMiddleClick  = nil
        _middleclickPoint  = nil
        _middleclickPoint2 = nil

        _leftClickTap = eventtap.new({ eventTypes.leftMouseDown, eventTypes.leftMouseUp }, function(event)
            if _needToClick then
                local eType = event:getType()
                if _enoughDown and eType == eventTypes.leftMouseDown then
                    _wasEnoughDown = true
                    _enoughDown    = false
                    return true, {
                        eventtap.event.newMouseEvent(
                                eventTypes.otherMouseDown,
                                event:location()
                            ):rawFlags(event:rawFlags())
                             :setProperty(eventProperties.mouseEventButtonNumber, 2)
                    }
                elseif _wasEnoughDown and eType == eventTypes.leftMouseUp then
                    _wasEnoughDown = false
                    return true, {
                        eventtap.event.newMouseEvent(
                                eventTypes.otherMouseUp,
                                event:location()
                            ):rawFlags(event:rawFlags())
                             :setProperty(eventProperties.mouseEventButtonNumber, 2)
                    }
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
        _deviceWatcher = hasTDWatcher and touchdevice.watcher.new(function(...)
            module.rescan()
        end):start()
    end
    return module
end

--- middleButton.stop() -> module
--- Function
--- Stop detecting multi-finger clicks and taps and remove the menu, if it is visible.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the module
---
--- Notes:
---  * this function is invoked if you select "Quit" from the menu.
---  * if you load this file with require (e.g. `require("middleButton")`), then you can type `package.loaded["middleButton"].start()` in the Hammerspoon console to reactivate.
module.stop = function()
    if _menu then
        if type(_menu) ~= "boolean" then _menu:delete() end
        _menu = nil
        module.rescan() -- will clear all device callbacks
        _leftClickTap:stop() ; _leftClickTap = nil
        _sleepWatcher:stop() ; _sleepWatcher = nil
        if _deviceWatcher then
            _deviceWatcher:stop() ; _deviceWatcher = nil
        end
    end
    return module
end

-- remove :start() if you don't want this to auto-start
return module:start()
