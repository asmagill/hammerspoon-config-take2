
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
local logger      = require("hs.logger")
local timer       = require("hs.timer")
local ipc         = require("hs.ipc")
local alert       = require("hs.alert")

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

logger.historySize(1000)
logger.truncateID = "head"
logger.truncateIDWithEllipsis = true

window.animationDuration = 0 -- I'm a philistine, sue me
ipc.cliInstall("/opt/amagill")

-- adjust hotkey logging... info as the default is too much.
require("hs.hotkey").setLogLevel("warning")

-- If something grows into usefulness, I'll modularize it.
_xtras = require("hs._asm.extras")

_asm.relaunch = function()
    os.execute([[ (while ps -p ]]..hs.processInfo.processID..[[ > /dev/null ; do sleep 1 ; done ; open -a "]]..hs.processInfo.bundlePath..[[" ) & ]])
    hs._exit(true, true)
end

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

-- refocus captured window from begining
timer.doAfter(1, function()
    if fmW then
        fmW:focus()
    else
        local finder = application("Finder")
        if finder then
            alert("Activating Finder")
            finder:activate()
        end
    end
end)

hs.loadSpoon('FadeLogo'):start(.5)
