--
-- TODO:
--     Document
--     allow for keyboard modifier(s) to skip delay before sleeping?
--        immediate locking?
--     allow keyboard modifier(s) to "lock" noSleep so mouse pointer can move?
--

--- === SleepCorners ===
---
--- Trigger or prevent screen saver/sleep by moving your mouse pointer to specified hot corners on your screen.
---
--- While this functionality is provided by macOS in the Mission Control System Preferences, it doesn't provide any type of visual feedback so it's easy to forget which corners have been assigned which roles.
---
--- The visual feed back provided by this spoon is of a small plus (for triggering sleep now) or a small minus (to prevent sleep) when the mouse pointer is moved into the appropriate corner. This feedback was inspired by a vague recollection of an early Mac screen saver (After Dark maybe?) which provided similar functionality. If someone knows for certain, please inform me and I will give appropriate attribution.
---
--- Note that sleep prevention is not guaranteed; the macOS may override our attempts at staying awake in extreme situations (CPU temperature dangerously high, extremely low battery, etc.) See `hs.caffeinate` for more details.
---
--- Download: `svn export https://github.com/asmagill/hammerspoon-config/trunk/_Spoons/SleepCorners.spoon`

-- local logger  = require("hs.logger")

local obj    = {
-- Metadata
    name      = "SleepCorners",
    author    = "A-Ron",
    homepage  = "https://github.com/asmagill/hammerspoon-config/tree/master/_Spoons/SleepCorners.spoon",
    license   = "MIT - https://opensource.org/licenses/MIT",
    spoonPath = debug.getinfo(1, "S").source:match("^@(.+/).+%.lua$"),
}
-- version is outside of obj table definition to facilitate its auto detection by
-- external documentation generation scripts
obj.version   = "0.1"

local canvas     = require("hs.canvas")
local caffeinate = require("hs.caffeinate")
local screen     = require("hs.screen")
local image      = require("hs.image")
local timer      = require("hs.timer")
local fnutils    = require("hs.fnutils")

local metadataKeys = {} ; for k, v in fnutils.sortByKeys(obj) do table.insert(metadataKeys, k) end

local defaultLevel = canvas.windowLevels.screenSaver

obj.__index = obj

-- collection of details that probably shouldn't be externally changed but may help
-- in debugging
obj._internals = {}

obj._internals.sleepDelay = 2

obj._internals.sleepScreen = screen.primaryScreen()

obj._internals.sleepNowCorner = "LL"

obj._internals.noSleepCorner = "LR"

obj._internals.feedbackSize = 20

obj._internals.triggerSize = 2

obj._internals.preferSleepNow = false

local noSleepSymbol = [[
1*******2
*       *
*       *
*       *
*  a*a  *
*       *
*       *
*       *
4*******3]]

local sleepNowSymbol = [[
1*******2
*       *
*       *
*   c   *
*  a*a  *
*   c   *
*       *
*       *
4*******3]]

local validScreenCorners = { "UL", "UR", "LR", "LL", "*" }

local _noSleepCanvas  = canvas.new{
    h = obj._internals.feedbackSize,
    w = obj._internals.feedbackSize
}
local _sleepNowCanvas = canvas.new{
    h = obj._internals.feedbackSize,
    w = obj._internals.feedbackSize
}

local lastSleepSetting = caffeinate.get("displayIdle")
local noSleepFunction = function(c, m, i, x, y)
    -- this corner is disabled so skip
    if obj._internals.noSleepCorner == "*" then return end
    -- if we're being displayed for reference, skip the triggering
    if obj._internals._showTimer then return end
    if m == "mouseEnter" then
        lastSleepSetting = caffeinate.get("displayIdle")
        caffeinate.set("displayIdle", true)
        _noSleepCanvas["image"].action = "strokeAndFill"
    elseif m == "mouseExit" then
        caffeinate.set("displayIdle", lastSleepSetting)
        _noSleepCanvas["image"].action = "skip"
    end
end

local sleepNowFunction = function(c, m, i, x, y)
    -- this corner is disabled so skip
    if obj._internals.sleepNowCorner == "*" then return end
    -- if we're being displayed for reference, skip the triggering
    if obj._internals._showTimer then return end
    if m == "mouseEnter" then
        if obj._internals._sleepNowTimer then
            print("*** sleep delay timer already exists and shouldn't; resetting")
            obj._internals._sleepNowTimer:stop()
            obj._internals._sleepNowTimer = nil
        end
        obj._internals._sleepNowTimer = timer.doAfter(obj.sleepDelay, function()
            obj._internals._sleepNowTimer:stop()
            obj._internals._sleepNowTimer = nil
            caffeinate.startScreensaver()
        end)
        _sleepNowCanvas["image"].action = "strokeAndFill"
    elseif m == "mouseExit" then
        if obj._internals._sleepNowTimer then
            obj._internals._sleepNowTimer:stop()
            obj._internals._sleepNowTimer = nil
        end
        _sleepNowCanvas["image"].action = "skip"
    end
end

_noSleepCanvas:mouseCallback(noSleepFunction)
              :behavior("canJoinAllSpaces")
              :level(defaultLevel + (obj._internals.preferSleepNow and 0 or 1))
_noSleepCanvas[#_noSleepCanvas + 1] = {
    type                = "rectangle",
    id                  = "activator",
    strokeColor         = { alpha = 0 },
    fillColor           = { alpha = 0 },
    frame               = {
        x = 0,
        y = 0,
        h = obj._internals.triggerSize,
        w = obj._internals.triggerSize
    },
    trackMouseEnterExit = true,
}
_noSleepCanvas[#_noSleepCanvas + 1] = {
    type   = "image",
    id     = "image",
    action = "skip",
    image  = image.imageFromASCII(noSleepSymbol, {
        { fillColor = { white = 1, alpha = .5 }, strokeColor = { alpha = 1 } },
        { fillColor = { alpha = 0 }, strokeColor = { alpha = 1 } },
    })
}

_sleepNowCanvas:mouseCallback(sleepNowFunction)
               :behavior("canJoinAllSpaces")
               :level(defaultLevel + (obj._internals.preferSleepNow and 1 or 0))
_sleepNowCanvas[#_sleepNowCanvas + 1] = {
    type                = "rectangle",
    id                  = "activator",
    strokeColor         = { alpha = 0 },
    fillColor           = { alpha = 0 },
    frame               = {
        x = 0,
        y = 0,
        h = obj._internals.triggerSize,
        w = obj._internals.triggerSize
    },
    trackMouseEnterExit = true,
}
_sleepNowCanvas[#_sleepNowCanvas + 1] = {
    type   = "image",
    id     = "image",
    action = "skip",
    image  = image.imageFromASCII(sleepNowSymbol, {
        { fillColor = { white = 1, alpha = .5 }, strokeColor = { alpha = 1 } },
        { fillColor = { alpha = 0 }, strokeColor = { alpha = 1 } },
    })
}

local positionCanvas = function(c, p)
    local frame = (type(obj._internals.sleepScreen) == "function" and obj._internals.sleepScreen() or obj._internals.sleepScreen):fullFrame()
    if p == "UL" then
        c:frame{
            x = frame.x,
            y = frame.y,
            h = obj._internals.feedbackSize,
            w = obj._internals.feedbackSize
        }
        c["activator"].frame = {
            x = 0,
            y = 0,
            h = obj._internals.triggerSize,
            w = obj._internals.triggerSize
        }
    elseif p == "UR" then
        c:frame{
            x = frame.x + frame.w - obj._internals.feedbackSize,
            y = frame.y,
            h = obj._internals.feedbackSize,
            w = obj._internals.feedbackSize
        }
        c["activator"].frame = {
            x = obj._internals.feedbackSize - obj._internals.triggerSize,
            y = 0,
            h = obj._internals.triggerSize,
            w = obj._internals.triggerSize
        }
    elseif p == "LR" then
        c:frame{
            x = frame.x + frame.w - obj._internals.feedbackSize,
            y = frame.y + frame.h - obj._internals.feedbackSize,
            h = obj._internals.feedbackSize,
            w = obj._internals.feedbackSize
        }
        c["activator"].frame = {
            x = obj._internals.feedbackSize - obj._internals.triggerSize,
            y = obj._internals.feedbackSize - obj._internals.triggerSize,
            h = obj._internals.triggerSize,
            w = obj._internals.triggerSize
        }
    elseif p == "LL" then
        c:frame{
            x = frame.x,
            y = frame.y + frame.h - obj._internals.feedbackSize,
            h = obj._internals.feedbackSize,
            w = obj._internals.feedbackSize
        }
        c["activator"].frame = {
            x = 0,
            y = obj._internals.feedbackSize - obj._internals.triggerSize,
            h = obj._internals.triggerSize,
            w = obj._internals.triggerSize
        }
    elseif p == "*" then
        c:frame{
            x = 0,
            y = 0,
            h = 0,
            w = 0,
        }
    end
end

obj._internals._sleepNowCanvas = _sleepNowCanvas
obj._internals._noSleepCanvas  = _noSleepCanvas

-- we use newWithActiveScreen in case they've set sleepScreen to a function
-- which returns the main screen (i.e. the screen with the currently focused
-- window)
obj._internals._screenWatcher = screen.watcher.newWithActiveScreen(function(state)
    positionCanvas(_sleepNowCanvas, obj._internals.sleepNowCorner)
    positionCanvas(_noSleepCanvas, obj._internals.noSleepCorner)
end)

obj.start = function(self)
    -- in case called as function
    if self ~= obj then self = obj end
    if self._internals._showTimer then self._internals._showTimer:fire() end
    if not _sleepNowCanvas:isShowing() then
        _sleepNowCanvas:show()
        _noSleepCanvas:show()
        self._internals._screenWatcher:start()
    end
    return self
end

obj.stop = function(self)
    -- in case called as function
    if self ~= obj then self = obj end
    if self._internals._showTimer then self._internals._showTimer:fire() end
    if _sleepNowCanvas:isShowing() then
        _sleepNowCanvas:hide()
        _noSleepCanvas:hide()
        -- just in case, reset timer and return sleep setting to last known state
        if self._internals._sleepNowTimer then
            self._internals._sleepNowTimer:stop()
            self._internals._sleepNowTimer = nil
        end
        caffeinate.set("displayIdle", lastSleepSetting)
        self._internals._screenWatcher:stop()
    end
    return self
end

obj.toggle = function(self, value)
    -- in case called as function
    if self ~= obj then self, value = obj, self end
    local shouldTurnOn = not _sleepNowCanvas:isShowing()
    if type(value) == "boolean" then shouldTurnOn = value end
    if shouldTurnOn then
        self:start()
    else
        self:stop()
    end
    return self
end

obj.init = function(self)
    positionCanvas(_sleepNowCanvas, self._internals.sleepNowCorner)
    positionCanvas(_noSleepCanvas, self._internals.noSleepCorner)
    return self
end

obj.show = function(self, duration)
    -- in case called as function
    if self ~= obj then self, duration = obj, self end
    if duration == false then
        if self._internals._showTimer then self._internals._showTimer:fire() end
        return
    end
    duration = duration or 3
    -- disable timer since we will be in an indeterminate state for a bit
    if self._internals._sleepNowTimer then
        self._internals._sleepNowTimer:stop()
        self._internals._sleepNowTimer = nil
    end
    local wasShowing = _sleepNowCanvas:isShowing()
    _sleepNowCanvas:show()
    _sleepNowCanvas["image"].action = "strokeAndFill"
    _noSleepCanvas:show()
    _noSleepCanvas["image"].action = "strokeAndFill"
    self._internals._showTimer = timer.doAfter(duration, function()
        self._internals._showTimer:stop()
        self._internals._showTimer = nil
        if not wasShowing then
            _sleepNowCanvas:hide()
            _noSleepCanvas:hide()
        end
        _sleepNowCanvas["image"].action = "skip"
        _noSleepCanvas["image"].action = "skip"
    end)
    return self
end

return setmetatable(obj, {
    __tostring = function(self)
        local result, fieldSize = "", 0
        for i, v in ipairs(metadataKeys) do fieldSize = math.max(fieldSize, #v) end
        for i, v in ipairs(metadataKeys) do
            result = result .. string.format("%-"..tostring(fieldSize) .. "s %s\n", v, self[v])
        end
        return result
    end,
    __index = function(self, key)
        return obj._internals[key]
    end,
    __newindex = function(self, key, value)
        if key == "sleepNowCorner" then
            if type(value) == "string" and fnutils.find(validScreenCorners, function(a)
                return a == string.upper(value)
            end) then
                obj._internals.sleepNowCorner = string.upper(value)
                positionCanvas(_sleepNowCanvas, obj._internals.sleepNowCorner)
            else
                error("sleepNowCorner must be one of " .. table.concat(validScreenCorners, ", "), 2)
            end
        elseif key == "noSleepCorner" then
            if type(value) == "string" and fnutils.find(validScreenCorners, function(a)
                return a == string.upper(value)
            end) then
                obj._internals.noSleepCorner = string.upper(value)
                positionCanvas(_noSleepCanvas, obj._internals.noSleepCorner)
            else
                error("noSleepCorner must be one of " .. table.concat(validScreenCorners, ", "), 2)
            end
        elseif key == "sleepDelay" then
            if type(value) == "number" then
                obj._internals.sleepDelay = value
            else
                error("sleepDelay must be a number", 2)
            end
        elseif key == "feedbackSize" then
            if type(value) == "number" then
                obj._internals.feedbackSize = value
                positionCanvas(_sleepNowCanvas, obj._internals.sleepNowCorner)
                positionCanvas(_noSleepCanvas, obj._internals.noSleepCorner)
            else
                error("feedbackSize must be a number", 2)
            end
        elseif key == "triggerSize" then
            if type(value) == "number" then
                obj._internals.triggerSize = value
                positionCanvas(_sleepNowCanvas, obj._internals.sleepNowCorner)
                positionCanvas(_noSleepCanvas, obj._internals.noSleepCorner)
            else
                error("triggerSize must be a number", 2)
            end
        elseif key == "sleepScreen" then
            local testValue = type(value) == "function" and value() or value
            if getmetatable(testValue) == hs.getObjectMetatable("hs.screen") then
                obj._internals.sleepScreen = value
                positionCanvas(_sleepNowCanvas, obj._internals.sleepNowCorner)
                positionCanvas(_noSleepCanvas, obj._internals.noSleepCorner)
            else
                error("sleepScreen must be an hs.screen object or a function which returns an hs.screen object", 2)
            end
        elseif key == "preferSleepNow" then
            if type(value) == "boolean" then
                obj._internals.preferSleepNow = value
                _noSleepCanvas:level(defaultLevel + (value and 0 or 1))
                _sleepNowCanvas:level(defaultLevel + (value and 1 or 0))
            else
                error("preferSleepNow must be a boolean", 2)
            end
        else
            error(tostring(key) .. " is not a recognized paramter of SleepCorners", 2)
        end
    end
})
