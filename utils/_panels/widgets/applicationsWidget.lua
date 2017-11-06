local module = {}
local USERDATA_TAG = "applicationsWidget"

local canvas      = require("hs.canvas")
local settings    = require("hs.settings")
local image       = require("hs.image")
local application = require("hs.application")

local _bundleIDs = settings.get(USERDATA_TAG)
if not _bundleIDs then
    _bundleIDs = { hs.processInfo.bundleID }
    settings.set(USERDATA_TAG, _bundleIDs)
end


local _canvas = canvas.new{ h = 42 }:appendElements{
    {
        id               = "background",
        type             = "rectangle",
        fillColor        = { alpha = .7, white = .5 },
        strokeColor      = { alpha = .5 },
        roundedRectRadii = { xRadius = 5, yRadius = 5 },
        clipToPath       = true, -- makes for sharper edges
    }
}:mouseCallback(function(c, m, i, x, y)
    if m == "mouseUp" then
        application.launchOrFocusByBundleID(i)
    end
end)

local updateCanvas = function()
    local _bundleIDs = settings.get(USERDATA_TAG)
--     print("Updating at " .. os.date("%c"))
    for i = #_canvas, 2, -1 do _canvas[i] = nil end
    for i, v in ipairs(_bundleIDs) do
        _canvas[i + 1] = {
            type         = "image",
            id           = v,
            frame        = { x = 5 + (i - 1) * 37, y = 5, h = 32, w = 32 },
            trackMouseUp = true,
            image        = image.imageFromAppBundle(v),
        }
    end
    _canvas:size{ h = 42, w = #_bundleIDs * 37 + 5 }
end
updateCanvas()

settings.watchKey(USERDATA_TAG .. "Identifier", USERDATA_TAG, updateCanvas)

return _canvas, { y = 0, cX = ".5", id = "applications" }
