local module = {}
module.sleepDelay = 2

-- TODO:
--    Make into spoon
--    adjust positions when screen changes
--    decide how to handle multiple screens
--    decide how to let user choose activation corners (will need to adjust "activator" element position)
--    allow modifier keypress to skip timer for sleep now corner?
--    allow change of size for image? activator square?

local canvas     = require("hs.canvas")
local caffeinate = require("hs.caffeinate")
local screen     = require("hs.screen")
local image      = require("hs.image")
local timer      = require("hs.timer")

-- local noSleepSymbol = [[
-- 1*****2
-- *     *
-- *     *
-- * a*a *
-- *     *
-- *     *
-- 4*****3]]
--
-- local yesSleepSymbol = [[
-- 1*****2
-- *     *
-- *  c  *
-- * a*a *
-- *  c  *
-- *     *
-- 4*****3]]
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

local yesSleepSymbol = [[
1*******2
*       *
*       *
*   c   *
*  a*a  *
*   c   *
*       *
*       *
4*******3]]

local _noSleepCanvas = canvas.new{ h = 20, w = 20 }

local lastSleepSetting = caffeinate.get("displayIdle")
local noSleepFunction = function(c, m, i, x, y)
    if m == "mouseEnter" then
        lastSleepSetting = caffeinate.get("displayIdle")
        caffeinate.set("displayIdle", true)
        _noSleepCanvas["image"].action = "strokeAndFill"
    elseif m == "mouseExit" then
        caffeinate.set("displayIdle", lastSleepSetting)
        _noSleepCanvas["image"].action = "skip"
    end
end

_noSleepCanvas:mouseCallback(noSleepFunction)
              :behavior("canJoinAllSpaces")
              :level("screenSaver")
              :show()
_noSleepCanvas[#_noSleepCanvas + 1] = {
    type                = "rectangle",
    id                  = "activator",
    strokeColor         = { alpha = 0 },
    fillColor           = { alpha = 0 },
    frame               = { x = 18, y = 18, h = 2, w = 2 },
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

local _yesSleepCanvas = canvas.new{ h = 20, w = 20 }

local yesSleepFunction = function(c, m, i, x, y)
    if m == "mouseEnter" then
        if module._yesTimer then
            print("*** sleep delay timer already exists and shouldn't; resetting")
            module._yesTimer:stop()
            module._yesTimer = nil
        end
        module._yesTimer = timer.doAfter(module.sleepDelay, function()
            module._yesTimer:stop()
            module._yesTimer = nil
            caffeinate.startScreensaver()
        end)
        _yesSleepCanvas["image"].action = "strokeAndFill"
    elseif m == "mouseExit" then
        if module._yesTimer then
            module._yesTimer:stop()
            module._yesTimer = nil
        end
        _yesSleepCanvas["image"].action = "skip"
    end
end

_yesSleepCanvas:mouseCallback(yesSleepFunction)
               :behavior("canJoinAllSpaces")
               :level("screenSaver")
               :show()
_yesSleepCanvas[#_yesSleepCanvas + 1] = {
    type                = "rectangle",
    id                  = "activator",
    strokeColor         = { alpha = 0 },
    fillColor           = { alpha = 0 },
    frame               = { x = 0, y = 18, h = 2, w = 2 },
    trackMouseEnterExit = true,
}
_yesSleepCanvas[#_yesSleepCanvas + 1] = {
    type   = "image",
    id     = "image",
    action = "skip",
    image  = image.imageFromASCII(yesSleepSymbol, {
        { fillColor = { white = 1, alpha = .5 }, strokeColor = { alpha = 1 } },
        { fillColor = { alpha = 0 }, strokeColor = { alpha = 1 } },
    })
}

module._yes = _yesSleepCanvas
module._no  = _noSleepCanvas

module.setCorners = function()
    local workingFrame = screen.primaryScreen():fullFrame()
    _yesSleepCanvas:topLeft{
        x = workingFrame.x,
        y = workingFrame.y + workingFrame.h - 20
    }
    _noSleepCanvas:topLeft{
        x = workingFrame.x + workingFrame.w - 20,
        y = workingFrame.y + workingFrame.h - 20
    }
end

module._screenWatcher = screen.watcher.newWithActiveScreen(module.setCorners)
module.setCorners()

return module
