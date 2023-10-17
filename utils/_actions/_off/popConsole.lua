local noises      = require("hs.noises")
local watchable   = require("hs.watchable")
local window      = require("hs.window")
local application = require("hs.application")
local timer       = require("hs.timer")
local settings    = require("hs.settings")
local caffeinate  = require("hs.caffeinate")

local USERDATA_TAG = "_asm_popConsole"

local module = {}
module.watchables = watchable.new("popConsole", true)

local startEnabled = settings.get(USERDATA_TAG)
startEnabled = (startEnabled == nil) or startEnabled
module.watchables.enabled = startEnabled

local supressSettingsUpdate = false

module.popTimeout = 1
module.popFunctions = {}

module.debug   = false

local popTimer
local popCount = 0

local handlePops = function()
    if module.debug then hs.printf("~~ heard %d pop(s) in %d second(s)", popCount, module.popTimeout) end
    local doIt = module.popFunctions[popCount]
    if doIt then doIt() end
    popTimer = nil
    popCount = 0
end

local consolePopWatcher = function()
    if not popTimer then
        popTimer = timer.doAfter(module.popTimeout, handlePops)
    end
    popCount = popCount + 1
end

module.callback = function(w)
    if w == 1 then     -- start "sssss" sound
    elseif w == 2 then -- end "sssss" sound
    elseif w == 3 then -- mouth popping sound
        consolePopWatcher()
    end
end

module._noiseWatcher = noises.new(module.callback)
if module.watchables.enabled then module._noiseWatcher:start() end

module.toggleForWatchablesEnabled = watchable.watch("popConsole.enabled", function(w, p, i, oldValue, value)
    if value then
        module._noiseWatcher:start()
    else
        module._noiseWatcher:stop()
    end
    if not supressSettingsUpdate then settings.set(USERDATA_TAG, value) end
end)

-- the listener can prevent or delay system sleep, so disable as appropriate
module.watchCaffeinatedState = watchable.watch("generalStatus.caffeinatedState", function(w, p, i, old, new)
--     print(string.format("~~~ %s popConsole caffeinatedWatcher called with %s (%d), was %s (%d), currently %s", timestamp(), caffeinate.watcher[new], new, caffeinate.watcher[old], old, module.watchables.enabled))
    -- we don't want to save the toggling if enabled is changed by the caffeinate watcher
    supressSettingsUpdate = true
    if new == 1 or new == 10 then -- systemWillSleep or screensDidLock
        module.wasActive = module.watchables.enabled
        module.watchables.enabled = false
    elseif new == 0 or new == 11 then -- systemDidWake or screensDidUnlock
        if type(module.wasActive) == "boolean" then
            module.watchables.enabled = module.wasActive
        else
            module.watchables.enabled = true
        end
    end
    supressSettingsUpdate = false
end)

local prevWindowHolder
module.popFunctions[3] = function()
-- this attempts to keep track of the previously focused window and return us to it
--     local conswin = window.get("Hammerspoon Console")
--     if conswin and application.get("Hammerspoon"):isFrontmost() then
    local hspoon = application.applicationsForBundleID(hs.processInfo.bundleID)[1]
    local conswin = hspoon:mainWindow()
    if conswin and hspoon:isFrontmost() then
        conswin:close()
        if prevWindowHolder and #prevWindowHolder:role() ~= 0 then
            prevWindowHolder:becomeMain():focus()
            prevWindowHolder = nil
        end
    else
        prevWindowHolder = window.frontmostWindow()
        hs.openConsole()
    end
end

-- local alert = require("hs.alert")
-- module.popConsole.popFunctions[2] = function() alert("Oooh, so close!") end
-- module.popConsole.popFunctions[4] = function() alert("Ok, now you're just showing off...") end

return setmetatable(module, { __tostring = function(self)
    return "Adjust with `self`.watchables.enabled or using hs.watchables with path 'popConsole.enabled'"
end })
