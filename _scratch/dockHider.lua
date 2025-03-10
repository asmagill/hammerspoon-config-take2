local module = {}

local axuielement = require("hs.axuielement")
local eventtap    = require("hs.eventtap")
local keycodes    = require("hs.keycodes")
local application = require("hs.application")
local watcher     = require("hs.application.watcher")
local fnutils     = require("hs.fnutils")
local timer       = require("hs.timer")

-- Not sure if these differ from language to language, so set here if you need to; if you
-- want to get really fancy and look at the localization strings, see the code for `hs.spaces`
-- at: https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/spaces/spaces.lua
local onMenuItem  = "Turn Hiding On"
local offMenuItem = "Turn Hiding Off"

-- app titles which should show the Dock; if it's not in here, the dock will be hidden
module.showDockIn = {
    "Finder",
}

-- axuielement dock stuff

local dockState -- track internally when we switch to minimize spurious menu flashes

local getDock = function()
    local dockElement = axuielement.applicationElement("com.apple.dock")
    assert(dockElement, "Unable to aquire Dock accessibility element")
    return dockElement
end

local getItemListFromDock = function()
    local dockElement = getDock()
    local axlist
    for i,v in ipairs(dockElement) do
        if v.AXRole == "AXList" and v.AXRoleDescription == "list" then
            axlist = v.AXChildren
            break
        end
    end
    assert(axlist, "Unable to get child list from Dock")
    return axlist
end

local getSeparator = function()
    local axlist = getItemListFromDock()

    for i,v in ipairs(axlist) do
        if v.AXSubrole == "AXSeparatorDockItem" then return v end
    end
    return false
end

-- generally this should remain valid unless you restart the Dock, so we check in the
-- various functions, just to be sure...
local separator = getSeparator()

module.isHidingOn = function()
    if not separator:isValid() then separator = getSeparator() end
    separator:doAXShowMenu()

    while not separator.AXShownMenuUIElement do end

    local answer
    for _, menuItem in ipairs(separator.AXShownMenuUIElement) do
        if answer == nil then
            if menuItem.AXTitle == onMenuItem then
                answer = false
            elseif menuItem.AXTitle == offMenuItem then
                answer = true
            end
        end
    end

-- hmm, macos has changed a bit; this no longer closes when already open
--     separator:doAXShowMenu()
    eventtap.event.newKeyEvent({}, keycodes.map.escape, true):post()
    eventtap.event.newKeyEvent({}, keycodes.map.escape, false):post()

    if answer == nil then
        error([[ unable to find Menu Item "Turn Hiding On" or "Turn Hiding Off" ]])
    else
        return answer
    end
end

module.hideDock = function(skipShowMenu)
    if not separator:isValid() then separator = getSeparator() end
    if not skipShowMenu then separator:doAXShowMenu() end

    local currentTime = timer.secondsSinceEpoch()
    while not separator.AXShownMenuUIElement do
        if timer.secondsSinceEpoch() - currentTime > 5 then
            error("timeout waiting for AXShownMenuUIElement")
        end
    end

    local answer
    for _, menuItem in ipairs(separator.AXShownMenuUIElement) do
        if menuItem.AXTitle == onMenuItem then
            menuItem:doAXPress()
            return
        end
    end

-- see isHidingOn
    eventtap.event.newKeyEvent({}, keycodes.map.escape, true):post()
    eventtap.event.newKeyEvent({}, keycodes.map.escape, false):post()
end

module.showDock = function(skipShowMenu)
    if not separator:isValid() then separator = getSeparator() end
    if not skipShowMenu then separator:doAXShowMenu() end

    local currentTime = timer.secondsSinceEpoch()
    while not separator.AXShownMenuUIElement do
        if timer.secondsSinceEpoch() - currentTime > 5 then
            error("timeout waiting for AXShownMenuUIElement")
        end
    end

    local answer
    for _, menuItem in ipairs(separator.AXShownMenuUIElement) do
        if menuItem.AXTitle == offMenuItem then
            menuItem:doAXPress()
            return
        end
    end

-- see isHidingOn
    eventtap.event.newKeyEvent({}, keycodes.map.escape, true):post()
    eventtap.event.newKeyEvent({}, keycodes.map.escape, false):post()
end

-- application watcher stuff

local appwatcher
local initialState

local watcherCallback = function(title, state, app)
--     print(title, state, app)
    if state == watcher.activated then
        if fnutils.contains(module.showDockIn, title) then
            if dockState then -- only change if it's actually different
                module.showDock()
                dockState = false
            end
        else
            if not dockState then
                module.hideDock()
                dockState = true
            end
        end
    end
end

module.start = function()
    if not appwatcher then
        initialState = module.isHidingOn()
        dockState = initialState

        appwatcher = watcher.new(watcherCallback):start()

        -- match for current app
        local frontAppTitle = application.frontmostApplication():title()

        -- because the closing of the menu doesn't actually occur instantaneously in
        -- isHidingOn, we can't just call the callback with fake parameters... it causes
        -- AXShownMenuUIElement to be invalidated when the menu is "opened" again.
        -- This passes the "hidden" parameter to hide/show to skip that step
        if fnutils.contains(module.showDockIn, frontAppTitle) then
            if dockState then
                module.showDock(true)
                dockState = false
            end
        else
            if not dockState then
                module.hideDock(true)
                dockState = true
            end
        end
    end
    return module
end

module.stop = function()
    if appwatcher then
        appwatcher:stop()
        appwatcher = nil
        if initialState then
            module.hideDock()
        else
            module.showDock()
        end
        initialState = nil
    end
    return module
end

-- set garbage collection on the module so we reset the dock to it's initial state when
-- restarting
return setmetatable(module, { __gc = module.stop })


