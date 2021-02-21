local canvas   = require("hs.canvas")
local dockicon = require("hs.dockicon")
local timer    = require("hs.timer")

local timeString = "%R:%S\n%A\n%D"
local module = {}

local tileSize = dockicon.tileSize()
local _canvas = canvas.new{ x = 0, y = 0, h = tileSize.h, w = tileSize.w }
_canvas[#_canvas + 1] = {
    id            = "time",
    type          = "text",
    text          = "",
    textAlignment = "center"
}

local _timer = timer.doEvery(1, function()
    local output = os.date(timeString)
    local minSize = _canvas:minimumTextSize(output)
    _canvas["time"].frame = {
        x = (tileSize.w - minSize.w) / 2,
        y = (tileSize.h - minSize.h) / 2,
        w = minSize.w,
        h = minSize.h
    }
    _canvas["time"].text = output
    dockicon.tileUpdate()
end)

module.start = function()
    local _view = dockicon.tileCanvas()
    if _view ~= _canvas then
        dockicon.tileCanvas(_canvas)
        _timer:start()
    end
    return module
end

module.stop = function()
    local _view = dockicon.tileCanvas()
    if _view == _canvas then
        dockicon.tileCanvas(nil)
        _timer:stop()
    end
    return module
end

return setmetatable(module.start(), { __gc = module.stop })
