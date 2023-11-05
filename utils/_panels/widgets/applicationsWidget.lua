--
-- rewrite to be editable/managable like a module or userdata
-- panel updates will (soon) allow for configuring widget after its installed as well

local module = {}
local USERDATA_TAG = "applicationsWidget"

local uitk        = require("hs._asm.uitk")
-- local canvas      = require("hs.canvas")
local settings    = require("hs.settings")
local image       = require("hs.image")
local application = require("hs.application")

local _bundleIDs = settings.get(USERDATA_TAG)
if not _bundleIDs then
    _bundleIDs = { hs.processInfo.bundleID }
    settings.set(USERDATA_TAG, _bundleIDs)
end


local _canvas = uitk.element.canvas{ h = 42 }:appendElements{
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
        -- odd behavior with SmartGit in that it tries to launch a second time if it's already running,
        -- so check to see if the app is already present first:
        local obj = application(i)
        if obj then
            obj:activate()
        else
            application.launchOrFocusByBundleID(i)
        end
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

module.canvas = _canvas

module.add = function(name, pos)
    local _bundleIDs = settings.get(USERDATA_TAG)
    pos = pos or (#_bundleIDs + 1)
    if application.infoForBundleID(name) then
        local idx
        for i,v in ipairs(_bundleIDs) do
            if v == name then
                idx = i
                break
            end
        end
        if idx then
            if idx < pos then pos = pos - 1 end
            table.remove(_bundleIDs, idx)
        end
        table.insert(_bundleIDs, pos, name)
        settings.set(USERDATA_TAG, _bundleIDs) -- this will trigger an update so we don't have to
        return true
    else
        return false
    end
end

module.remove = function(name)
    local _bundleIDs = settings.get(USERDATA_TAG)
    local idx
    for i,v in ipairs(_bundleIDs) do
        if v == name then
            idx = i
            break
        end
    end
    if idx then
        table.remove(_bundleIDs, idx)
        settings.set(USERDATA_TAG, _bundleIDs) -- this will trigger an update so we don't have to
        return true
    else
        return false
    end
end

module.registered = function()
    return settings.get(USERDATA_TAG)
end

return {
    element = _canvas,
    source  = module,
    frameDetails = { y = 0, cX = ".5", id = "applications" },
}
