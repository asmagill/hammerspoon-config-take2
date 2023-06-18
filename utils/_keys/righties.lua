local module = {}

-- even if it's been started already, invoking it again doesn't
-- hurt
local lrhk        = hs.loadSpoon("LeftRightHotkey"):start()
local application = require("hs.application")
local window      = require("hs.window")
local doc         = require("hs.doc")
local timer       = require("hs.timer")


local appList = {
    ["1"] = "1Password",
    ["b"] = "BBEdit",
    ["g"] = "SmartGit",
    ["m"] = "Mail",
    ["n"] = "nvALT",
    ["s"] = "Safari",
    ["t"] = "Terminal",
}

for k, v in pairs(appList) do
    module["app_" .. v] = lrhk:bind({ "rCmd" }, k, function()
        application.launchOrFocus(v)
    end)
end

module.hs_help = lrhk:bind({ "rCmd", "rAlt" }, "h", function()
    if doc.hsdocs._browser and doc.hsdocs._browser:hswindow() and doc.hsdocs._browser:hswindow() == window.frontmostWindow() then
        doc.hsdocs._browser:hide()
    else
        if doc.hsdocs._browser then
            doc.hsdocs._browser:show()
            timer.waitUntil(function() return doc.hsdocs._browser:hswindow() end,
                            function(t) doc.hsdocs._browser:hswindow():focus() end,
                            .1)
        else
            doc.hsdocs.help()
        end
    end
end)

local windowHolder
module.hs_console = lrhk:bind({ "rCmd", "rAlt" }, "r", function()
    local hspoon = application.applicationsForBundleID(hs.processInfo.bundleID)[1]
    local conswin = hspoon:mainWindow()
    if conswin and hspoon:isFrontmost() then
        conswin:close()
        if windowHolder and #windowHolder:role() ~= 0 then
            windowHolder:becomeMain():focus()
        end
        windowHolder = nil
    else
        windowHolder = window.frontmostWindow()
        hs.openConsole()
    end
end, nil)

module.hs_relaunch = lrhk:bind({ "rCmd", "rAlt", "rShift" }, "r", hs.relaunch)

return module
