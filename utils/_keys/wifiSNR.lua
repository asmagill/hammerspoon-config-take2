local timer  = require("hs.timer")
local wifi   = require("hs.wifi")
local canvas = require("hs.canvas")
local screen = require("hs.screen")

local hotkey  = require("hs.hotkey")
local mods    = require("hs._asm.extras").mods

local wifimeter = require("utils.wifimeter")

local module = {}

local noiseColor  = { green = 1, alpha = .5 }
local signalColor = { blue = 1,  alpha = .5 }

-- not counting background box, height = scaleToHeight, width = sampleSize * sampleRate
local sampleSize    = 50
local scaleToHeight = 100
local sampleRate    = 2

local padding       = 5
local offsetFromLLx = 1
local offsetFromLLy = 1

-- some pre-calculations that don't change over time or with screen changes
local scaleRatio = scaleToHeight / 120
local screenOffsetFromLLx = sampleSize * sampleRate + padding * 2 + offsetFromLLx
local screenOffsetFromLLy = scaleToHeight + padding * 2 + offsetFromLLy
local boxWidth = sampleSize * sampleRate + padding * 2
local boxHeight = scaleToHeight + padding * 2

local signalPoints, noisePoints = {}, {}
for i = 1, sampleSize, 1 do
    table.insert(noisePoints, { x = padding + i * sampleRate, y = boxHeight - padding})
    table.insert(signalPoints, { x = padding + i * sampleRate, y = boxHeight - padding})
end
table.insert(noisePoints, 1, { x = padding + sampleRate, y = boxHeight - padding })
table.insert(noisePoints, { x = padding + sampleSize * sampleRate, y = boxHeight - padding })
table.insert(signalPoints, 1, { x = padding + sampleRate, y = boxHeight - padding })
table.insert(signalPoints, { x = padding + sampleSize * sampleRate, y = boxHeight - padding })

local _canvas = canvas.new{ x = 0, y = 0, h = boxHeight, w = boxWidth }:behavior{"canJoinAllSpaces"}

_canvas[#_canvas + 1] = {
    type        = "rectangle",
    action      = "strokeAndFill",
    fillColor   = { white = .75, alpha = .5 },
    strokeColor = {alpha = .75},
    roundedRectRadii = { xRadius = padding, yRadius = padding },
}

_canvas[#_canvas + 1] = {
    id          = "signalPoints",
    action      = "strokeAndFill",
    type        = "segments",
    coordinates = signalPoints,
    closed      = true,
    strokeColor = signalColor,
    fillColor   = signalColor,
}

_canvas[#_canvas + 1] = {
    id          = "noisePoints",
    action      = "strokeAndFill",
    type        = "segments",
    coordinates = noisePoints,
    closed      = true,
    strokeColor = noiseColor,
    fillColor   = noiseColor,
}

module._canvas = _canvas
module._noisePoints = noisePoints
module._signalPoints = signalPoints

local updateDataPoints = function()
    local screenFrame = screen.primaryScreen():fullFrame()
    _canvas:topLeft{
        x = screenFrame.x + screenFrame.w - screenOffsetFromLLx,
        y = screenFrame.y + screenFrame.h - screenOffsetFromLLy
    }:show()

    canvas.disableScreenUpdates()

    local wifiDetails = wifi.interfaceDetails()
    -- Signal and Noise are measured between 0 and -120. Signal closer to 0 is good.
    -- Noise closer to -120 is good.
    local signal = (120 + wifiDetails.rssi) * scaleRatio
    local noise = (120 + wifiDetails.noise) * scaleRatio
--     print(signal, noise)
    for i = 1, sampleSize - 1, 1 do
        noisePoints[i + 1].y = noisePoints[i + 2].y
        signalPoints[i + 1].y = signalPoints[i + 2].y
    end
    noisePoints[sampleSize + 1].y = padding + scaleToHeight - noise
    signalPoints[sampleSize + 1].y = padding + scaleToHeight - signal

    _canvas.noisePoints.coordinates = noisePoints
    _canvas.signalPoints.coordinates = signalPoints

    canvas.enableScreenUpdates()
end

module.sampleTimer = timer.new(sampleRate, updateDataPoints)

module.start = function()
    updateDataPoints()
    module._canvas:show()
    module.sampleTimer:start()
end

module.stop = function()
    module._canvas:hide()
    module.sampleTimer:stop()
end

module.wifimeter = wifimeter
module["2GHz"] = wifimeter.new("2GHz"):setNetworkPersistence(0)
module["5GHz"] = wifimeter.new("5GHz"):setNetworkPersistence(0)

hotkey.bind(mods.CASC, "w", function()
    if module.sampleTimer:running() then
        module.stop()
        module["2GHz"] = module["2GHz"]:hide():stop()
        module["5GHz"] = module["5GHz"]:hide():stop()
    else
        module.start()
        local screenFrame = screen.primaryScreen():fullFrame()
        module["2GHz"] = module["2GHz"]:setFrame{
            x = screenFrame.x + screenFrame.w * 1/10,
            y = screenFrame.y + 44,
            h = screenFrame.h * 1/3,
            w = screenFrame.w * 8/10,
        }:show():start()
        module["5GHz"] = module["5GHz"]:setFrame{
            x = screenFrame.x + screenFrame.w * 1/10,
            y = screenFrame.y + 66 + screenFrame.h * 1/3,
            h = screenFrame.h * 1/3,
            w = screenFrame.w * 8/10,
        }:show():start()

    end
end)

return module
