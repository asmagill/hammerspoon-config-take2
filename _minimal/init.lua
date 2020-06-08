-- my regular paths are *after* everything else so, in general, this is as close as I can get
-- to a "clean" environment, given that I usually run a development version of Hammerspoon
package.path = package.path .. ";/Users/amagill/.config/hammerspoon/?.lua"
                            .. ";/Users/amagill/.config/hammerspoon/?/init.lua"
                            .. ";/Users/amagill/.config/hammerspoon/_Spoons/?.spoon/init.lua"
                            .. ";/Users/amagill/.config/hammerspoon/Spoons/?.spoon/init.lua"
package.cpath = package.cpath .. ";/Users/amagill/.config/hammerspoon/?.so"

-- insure `hs` command installed and registered
require("hs.ipc").cliInstall("/opt/amagill")

-- includes helpfull tools for debugging and checking callback parameters
require("utils._actions.inspectors")

local hotkey      = require("hs.hotkey")
-- key modifiers for our minimalist hotkeys
local mods = {
    CAsC = { "cmd", "alt", "ctrl" },
    CASC = { "cmd", "alt", "shift", "ctrl" },
}

-- toggle between current window and console
local windowHolder
hotkey.bind(mods.CAsC, "r", function()
    local hspoon = require("hs.application").applicationsForBundleID(hs.processInfo.bundleID)[1]
    local conswin = hspoon:mainWindow()
    if conswin and hspoon:isFrontmost() then
        conswin:close()
        if windowHolder and #windowHolder:role() ~= 0 then
            windowHolder:becomeMain():focus()
            windowHolder = nil
        end
    else
        windowHolder = require("hs.window").frontmostWindow()
        hs.openConsole()
    end
end, nil)

-- restart Hammerspoon completely
hotkey.bind(mods.CASC, "r", hs.relaunch)

hs.openConsole()

normalHS = function()
    require("hs.settings").set("MJConfigFile", "~/.config/hammerspoon/init.lua")
    hs.relaunch()
end

print("")
print("++ To return to normal configuration, enter `normalHS()` in the console")
print("")
