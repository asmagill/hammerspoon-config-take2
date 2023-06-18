local module = {}

local mods        = require("hs._asm.extras").mods
local hotkey      = require("hs.hotkey")
-- local fnutils     = require("hs.fnutils")
local application = require("hs.application")
local alert       = require("hs.alert").show
local bluetooth   = require("hs._asm.undocumented.bluetooth")
local hints       = require("hs.hints")
local window      = require("hs.window")
-- local doc         = require("hs.doc")
-- local timer       = require("hs.timer")
local axuielement = require("hs.axuielement")
local axbrowse    = require("_scratch.axbrowse")

hotkey.bind(mods.CAsC, "f12", function()
    local listener = require("utils.speech")
    if listener.recognizer then
        if listener:isListening() then
            listener:disableCompletely()
        else
            listener:start()
        end
    else
        listener = listener.init():start()
    end
end)

hotkey.bind(mods.CASC, "b", function()
    alert("Bluetooth is power is now: ".. (bluetooth.power(not bluetooth.power()) and "On" or "Off"))
end, nil)

hotkey.bind(mods.CASC, "e", nil, function()
    os.execute("/usr/local/bin/edit " .. hs.configdir .. " /opt/amagill/src/hammerspoon")
end)

hotkey.bind(mods.CAsC, "space", function() hints.windowHints() end, nil)

hotkey.bind(mods.CASC, "space", function()
    hints.windowHints(window.focusedWindow():application():allWindows())
end)

local lastApp
hotkey.bind(mods.CAsC, "b", function()
    local currentApp = axuielement.applicationElement(application.frontmostApplication())

    if currentApp == lastApp then
        axbrowse.browse()
    else
        lastApp = currentApp
        axbrowse.browse(currentApp)
    end
end)

-- hotkey.bind(mods.CAsC, 'h', function()
--     if doc.hsdocs._browser and doc.hsdocs._browser:hswindow() and doc.hsdocs._browser:hswindow() == window.frontmostWindow() then
--         doc.hsdocs._browser:hide()
--     else
--         if doc.hsdocs._browser then
--             doc.hsdocs._browser:show()
--             timer.waitUntil(function() return doc.hsdocs._browser:hswindow() end,
--                             function(t) doc.hsdocs._browser:hswindow():focus() end,
--                             .1)
--         else
--             doc.hsdocs.help()
--         end
--     end
-- end)

-- hotkey.bind(mods.CAsC, "n", function() application.launchOrFocus("nvALT") end, nil)
--
-- local windowHolder
-- hotkey.bind(mods.CAsC, "r", function()
--     local hspoon = application.applicationsForBundleID(hs.processInfo.bundleID)[1]
--     local conswin = hspoon:mainWindow()
--     if conswin and hspoon:isFrontmost() then
--         conswin:close()
--         if windowHolder and #windowHolder:role() ~= 0 then
--             windowHolder:becomeMain():focus()
--         end
--         windowHolder = nil
--     else
--         windowHolder = window.frontmostWindow()
--         hs.openConsole()
--     end
-- end, nil)
--
-- hotkey.bind(mods.CASC, "r", hs.relaunch)

return module
