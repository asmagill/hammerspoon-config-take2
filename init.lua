local lVer = _VERSION:match("Lua (.+)$")
-- or specify luarocks path yourself if this doesn't find it in the normal places
local luarocks = hs.execute("which luarocks"):gsub("\n", "")
if #luarocks > 0 then
    package.path = package.path .. ";" .. hs.execute(
            luarocks .. " --lua-version " .. lVer .. " path --lr-path"
        ):gsub("\n", "")
    package.cpath = package.cpath .. ";" .. hs.execute(
            luarocks .. " --lua-version " .. lVer .. " path --lr-cpath"
        ):gsub("\n", "")
end

local logger = require("hs.logger")
logger.historySize(1000)
logger.truncateID = "head"
logger.truncateIDWithEllipsis = true

-- I do too much with developmental versions of HS -- I don't need
-- extraneous info in the Console application for every require; very
-- few of my crashes  make it into Crashlytics anyways...
--
-- I don't recommend this unless you like doing your own troubleshooting
-- since it defeats some of the data captured for crash reports.
--
_asm = {}
_asm.hs_default_require = require
require = rawrequire

-- I link the Spoons dir to the primary repo's Source directory, so this is where I'll put in progress or
-- personal Spoons
package.path = hs.configdir .. "/_Spoons/?.spoon/init.lua;" .. package.path

-- override print so that it can render styled text objects directly in the console
-- this needs to happen before hs.ipc is loaded since it also overrides print for mirroring
local console     = require("hs.console")
_asm.hs_default_print = print
print = console.printStyledtext

local requirePlus = require("utils.require")
local crash       = require("hs.crash")
local window      = require("hs.window")
local application = require("hs.application")
local timer       = require("hs.timer")
local ipc         = require("hs.ipc")
local alert       = require("hs.alert")
local image       = require("hs.image")
local math        = require("hs.math")
local settings    = require("hs.settings")

-- wrap these here so my personal modules see the wrapped versions
local _hsrelaunch = hs.relaunch
hs.relaunch = function(...)
    local hspoon = application.applicationsForBundleID(hs.processInfo.bundleID)[1]
    local conswin = hspoon:mainWindow()
    if conswin then
        settings.set("openConsoleOnLoad", true)

        local fr = conswin:frame()
        -- stupid hs.geometry doesn't allow settings to serialize this properly
        fr = { x = fr.x, y = fr.y, h = fr.h, w = fr.w }
        settings.set("positionConsoleOnLoad", fr)
    end
    return _hsrelaunch(...)
end

local _hsreload = hs.reload
hs.reload = function(...)
    local hspoon = application.applicationsForBundleID(hs.processInfo.bundleID)[1]
    local conswin = hspoon:mainWindow()
    if conswin then
        local fr = conswin:frame()
        -- stupid hs.geometry doesn't allow settings to serialize this properly
        fr = { x = fr.x, y = fr.y, h = fr.h, w = fr.w }
        settings.set("positionConsoleOnLoad", fr)
    end
    return _hsreload(...)
end

-- something steals focus from an application which was focused before HS starts; capture that
-- window and then we'll switch back to it at the end
local fmW = window.frontmostWindow()

crash.crashLogToNSLog = true
-- local coreCrashLog = crash._crashLog
-- crash._crashLog = function(message, passAlong)
--     print("** " .. timestamp() .. " " .. message)
--     return coreCrashLog(message, passAlong)
-- end
crash.crashLog("Disabled require logging to make log file sane")

window.animationDuration = 0 -- I'm a philistine, sue me
ipc.cliInstall("/opt/amagill")

-- adjust hotkey logging... info as the default is too much.
require("hs.hotkey").setLogLevel("warning")

-- If something grows into usefulness, I'll modularize it.
_xtras = require("hs._asm.extras")

-- _asm.relaunch = function()
--     os.execute([[ (while ps -p ]]..hs.processInfo.processID..[[ > /dev/null ; do sleep 1 ; done ; open -a "]]..hs.processInfo.bundlePath..[[" ) & ]])
--     hs._exit(true, true)
-- end

_asm.hexstring2ascii = function(stuff)
    stuff = stuff:lower():gsub("[<>\n\r ]+", ""):gsub("0x", "")
    local result = ""
    for k in stuff:gmatch("(..)") do result = result .. string.char(tonumber(k, 16)) end
    return result
end

_asm._panels  = requirePlus.requirePath("utils._panels")
_asm._keys    = requirePlus.requirePath("utils._keys")
_asm._actions = requirePlus.requirePath("utils._actions")
_asm._menus   = requirePlus.requirePath("utils._menus")

-- terminal shell equivalencies...
edit = function(where)
    where = where or "."
    os.execute("/usr/local/bin/edit "..where)
end
m = function(which)
    os.execute("open x-man-page://"..tostring(which))
end

-- hs.drawing.windowBehaviors.moveToActiveSpace
console.behavior(2)
--console.titleVisibility("hidden")
console.toolbar():addItems{
    id = "clear",
    image = hs.image.imageFromName("NSTrashFull"),
    fn = function(...) console.clearConsole() end,
    label = "clear",
    tooltip = "Clear Console"
}:insertItem("clear", #console.toolbar():visibleItems() + 1)

console.smartInsertDeleteEnabled(false)
if console.darkMode() then
    console.outputBackgroundColor{ white = 0 }
    console.consoleCommandColor{ white = 1 }
    console.alpha(.8)
else
    console.windowBackgroundColor({red=.6,blue=.7,green=.7})
    console.outputBackgroundColor({red=.8,blue=.8,green=.8})
    console.alpha(.9)
end

history = _asm._actions.consoleHistory.history

minimalHS = function()
    settings.set("MJConfigFile", "~/.config/hammerspoon/_minimal/init.lua")
    hs.relaunch()
end

-- preview = _asm._actions.quickPreview.preview

_asm.gc  = require("utils.gc")

print()
print("++ Application Path: "..hs.processInfo.bundlePath)
print("++    Accessibility: "..tostring(hs.accessibilityState()))
if hs.processInfo.debugBuild then
    local gitbranchfile = hs.processInfo.resourcePath .. "/gitbranch"
    local gfile = io.open(gitbranchfile, "r")
    if gfile then
        GITBRANCH = gfile:read("l")
        gfile:close()
    else
        GITBRANCH = "<" .. gitbranchfile .. " missing>"
    end
    print("++    Debug Version: " .. hs.processInfo.version .. ", " .. hs.processInfo.buildTime)
    print("++            Build: " .. GITBRANCH)
else
    print("++  Release Version: " .. hs.processInfo.version)
end
print()

require"hs.doc".preloadSpoonDocs()

hs.loadSpoon("AnyComplete")
spoon.AnyComplete:bindHotkeys{ toggle = { { "cmd", "alt", "ctrl" }, "g" } }

hs.loadSpoon("SleepCorners"):start()
hs.loadSpoon("BonjourLauncher"):start():addRecipes("SSH", "SMB", "AFP", "VNC_RealVNC_Alternate"):bindHotkeys{
    toggle      = { { "cmd", "alt", "ctrl" }, "=" },
    toggle_SSH  = { { "cmd", "alt", "ctrl" }, "s" },
    toggle_HTTP = { { "cmd", "alt", "ctrl" }, "w" },
    toggle_VNC  = { { "cmd", "alt", "ctrl" }, "v" },
}
-- using ESP8266 with ESP-Link on some, my own code on others; ESP-Link advertises only one type; mine both
-- _http._tcp. and _arduino._tcp. but on differing ports; this captures the _arduino._tcp. entries and filters
-- out those that are on the default arduino OTA update port (or that haven't been resolved yet as -1 indicates
-- that the service is still being resolved) under the assumption that such an advertisement that uses a
-- different port is probably a web server... So far, this has held, but we'll see about future updates...
table.insert(spoon.BonjourLauncher.templates, {
    image   = hs.image.imageFromAppBundle("cc.arduino.Arduino"),
    label   = "Arduino",
    type    = "_arduino._tcp.",
    text    = "%name% (%txt:vendor %)",
    subText = "http://%hostname%:%port%/%txt:path%",
    url     = "http://%hostname%:%port%/%txt:path%",
    filter  = function(svc) local p = svc:port() ; return (p ~= 8266) and (p ~= -1) end,
    hidden  = true,
})
hs.loadSpoon("FadeLogo"):start(.5)

-- now restore console and its position, if it was open when we relaunched/loaded
if settings.get("openConsoleOnLoad") then
    hs.openConsole()
else
    -- refocus captured window from begining
    local restoreFMWTimer = timer.doAfter(math.minFloat, function()
        if fmW then fmW:focus() end
        restoreFMWTimer = nil
    end)
end

local prevFrame = settings.get("positionConsoleOnLoad")
if prevFrame then
    local hspoon = application.applicationsForBundleID(hs.processInfo.bundleID)[1]
    local conswin = hspoon:mainWindow()
    if conswin then conswin:setFrame(prevFrame) end
end

settings.clear("openConsoleOnLoad")
settings.clear("positionConsoleOnLoad")

_objc = require("hs._asm.objc")
