local module       = {}
local USERDATA_TAG = "_asm.gridded"
local mods         = require("hs._asm.extras").mods

local grid     = require("hs.grid")
local settings = require("hs.settings")
local hotkey   = require("hs.hotkey")
local alert    = require("hs.alert")

-- get the initial grid settings
grid.GRIDHEIGHT = math.floor(settings.get(USERDATA_TAG .. ".gridHeight")  or grid.GRIDHEIGHT)
grid.GRIDWIDTH  = math.floor(settings.get(USERDATA_TAG .. ".gridWidth")   or grid.GRIDWIDTH)
grid.MARGINX    = math.floor(settings.get(USERDATA_TAG .. ".gridMarginX") or grid.MARGINX)
grid.MARGINY    = math.floor(settings.get(USERDATA_TAG .. ".gridMarginY") or grid.MARGINY)

grid.ui.textSize = 32

local settingsShow = function()
        alert.show("  Grid Size: "..grid.GRIDWIDTH.."x"..grid.GRIDHEIGHT.."\n"
                 .."Margin Size: "..grid.MARGINX.."x"..grid.MARGINY
        )
end

local adjustGrid = function(rows, columns)
    return function()
        grid.setGrid{ w = math.max(grid.GRIDWIDTH + columns, 1), h = math.max(grid.GRIDHEIGHT + rows, 1) }
        settingsShow()
    end
end

local adjustMargins = function(rows, columns)
    return function()
        grid.setMargins{ w = math.max(grid.MARGINX + columns, 0), h = math.max(grid.MARGINY + rows, 0) }
        settingsShow()
    end
end

-- adjust grid settings
    hotkey.bind(mods.CAsC, "up",    adjustGrid( 1,  0), nil, adjustGrid( 1,  0))
    hotkey.bind(mods.CAsC, "down",  adjustGrid(-1,  0), nil, adjustGrid(-1,  0))
    hotkey.bind(mods.CAsC, "left",  adjustGrid( 0, -1), nil, adjustGrid( 0, -1))
    hotkey.bind(mods.CAsC, "right", adjustGrid( 0,  1), nil, adjustGrid( 0,  1))
    hotkey.bind(mods.CAsC, "/",     adjustGrid( 0,  0)) -- show current

    hotkey.bind(mods.CASC, "up",    adjustMargins( 1,  0), nil, adjustMargins( 1,  0))
    hotkey.bind(mods.CASC, "down",  adjustMargins(-1,  0), nil, adjustMargins(-1,  0))
    hotkey.bind(mods.CASC, "left",  adjustMargins( 0, -1), nil, adjustMargins( 0, -1))
    hotkey.bind(mods.CASC, "right", adjustMargins( 0,  1), nil, adjustMargins( 0,  1))

-- visual aid
    hotkey.bind(mods.CAsC, "v", grid.show)


return setmetatable(module, {
    __gc = function(me)
        -- save our grid details
        settings.set(USERDATA_TAG .. ".gridHeight",  grid.GRIDHEIGHT)
        settings.set(USERDATA_TAG .. ".gridWidth",   grid.GRIDWIDTH)
        settings.set(USERDATA_TAG .. ".gridMarginX", grid.MARGINX)
        settings.set(USERDATA_TAG .. ".gridMarginY", grid.MARGINY)
    end
})
