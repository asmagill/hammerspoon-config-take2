local axuielement = require("hs.axuielement")
local application = require("hs.application")
local screen      = require("hs.screen")
local inspect     = require("hs.inspect")
local timer       = require("hs.timer")

-- TODO:
--    determine what hs._asm.undocumented.spaces has that this doesn't
--        what can we add without private APIs?
--        what of the private APIs is maybe worth keeping?
--        yabai supports *some* stuff on M1 without injection... investigate
--            move window to space           -- according to M1 tracking issue
--            ids of windows on other spaces -- observed
--            move from space to current?    -- check, not sure
--    fully document
--    add optional callback fn to gotoSpaceOnScreen and removeSpaceFromScreen
--    allow screenID argument to be hs.screen object?

local module = {}

local _dockElement
local getDockElement = function()
    -- if the Dock is killed for some reason, its element will be invalid
    if not (_dockElement and _dockElement:isValid()) then
        _dockElement = axuielement.applicationElement(application("Dock"))
    end
    return _dockElement
end

local _missionControlGroup
local getMissionControlGroup = function()
    if not (_missionControlGroup and _missionControlGroup:isValid()) then
        _missionControlGroup = nil
        local dockElement = getDockElement()
        for i,v in ipairs(dockElement) do
            if v.AXIdentifier == "mc" then
                _missionControlGroup = v
                break
            end
        end
    end
    return _missionControlGroup
end

local openMissionControl = function()
    local missionControlGroup = getMissionControlGroup()
    if not missionControlGroup then hs.execute([[open -a "Mission Control"]]) end
end

local closeMissionControl = function()
    local missionControlGroup = getMissionControlGroup()
    if missionControlGroup then hs.execute([[open -a "Mission Control"]]) end
end

local findSpacesSubgroup = function(targetIdentifier, screenID)
    local missionControlGroup = getMissionControlGroup()

    local mcChildren = missionControlGroup:attributeValue("AXChildren") or {}
    local mcDisplay = table.remove(mcChildren)
    while mcDisplay do
        if mcDisplay.AXIdentifier == "mc.display" and mcDisplay.AXDisplayID == screenID then
            break
        end
        mcDisplay = table.remove(mcChildren)
    end
    if not mcDisplay then
        return nil, "no display with specified id found"
    end

    local mcDisplayChildren = mcDisplay:attributeValue("AXChildren") or {}
    local mcSpaces = table.remove(mcDisplayChildren)
    while mcSpaces do
        if mcSpaces.AXIdentifier == "mc.spaces" then
            break
        end
        mcSpaces = table.remove(mcDisplayChildren)
    end
    if not mcSpaces then
        return nil, "unable to locate mc.spaces group for display"
    end

    local mcSpacesChildren = mcSpaces:attributeValue("AXChildren") or {}
    local targetChild = table.remove(mcSpacesChildren)
    while targetChild do
        if targetChild.AXIdentifier == targetIdentifier then break end
        targetChild = table.remove(mcSpacesChildren)
    end
    if not targetChild then
        return nil, string.format("unable to find target %s for display", targetIdentifier)
    end
    return targetChild
end

-- doAfter time for gotoSpaceOnScreen and removeSpaceFromScreen
module.queueTime = require("hs.math").minFloat

-- opens Mission Control page; probably not commonly useful
module.openMissionControl = openMissionControl

-- closes Mission Control page; may be useful if you're passing in false to functions
-- and forget to pass in true to last function or want to abort due to error before
-- final function in series
module.closeMissionControl = closeMissionControl

-- spacesForScreen([screenID], [closeMCOnCompletion]) -> table | nil, errMsg
-- returns array of Mission Control Names for spaces on specified (or main) screen
module.spacesForScreen = function(...)
    local args, screenID, closeMC = { ... }, nil, true
    assert(#args <= 2, "expected no more than 2 arguments")
    if #args == 1 then
        if type(args[1]) == "number" then
            screenID = args[1]
        else
            closeMC = args[1]
        end
    else
        screenID, closeMC = table.unpack(args)
    end
    if screenID == nil then screenID = screen.mainScreen():id() end
    assert(math.type(screenID) == "integer", "screen id must be an integer")
    assert(type(closeMC) == "boolean", "close flag must be boolean")

    openMissionControl()
    local mcSpacesList, errMsg = findSpacesSubgroup("mc.spaces.list", screenID)
    if not mcSpacesList then
        if closeMC then closeMissionControl() end
        return nil, errMsg
    end

    local results = {}
    for _, child in ipairs(mcSpacesList) do
        table.insert(results, (child.AXDescription:gsub("^exit to ", "")))
    end

    if closeMC then closeMissionControl() end
    return setmetatable(results, { __tostring = inspect })
end

-- allSpaces([closeMCOnCompletion]) -> table | nil, errMsg
-- returns k-v table where k is screenID and v is array from spacesForScreen(k)
module.allSpaces = function(...)
    local args, closeMC = { ... }, true
    assert(#args <= 1, "expected no more than 1 argument")
    if #args == 1 then
        closeMC = args[1]
    end
    assert(type(closeMC) == "boolean", "close flag must be boolean")

    openMissionControl()
    local results = {}

    for _, v in ipairs(screen.allScreens()) do
        local screenID = v:id()
        local spacesForScreen, errMsg = module.spacesForScreen(screenID, false)
        if not spacesForScreen then
            if closeMC then closeMissionControl() end
            return nil, errMsg
        end

        results[screenID] = spacesForScreen
    end

    if closeMC then closeMissionControl() end
    return setmetatable(results, { __tostring = inspect })
end

-- activeSpaceOnScreen([screenID], [closeMCOnCompletion]) -> string | nil, errMsg
-- returns Mission Control name of current space for specified (or main) screen
module.activeSpaceOnScreen = function(...)
    local args, screenID, closeMC = { ... }, nil, true
    assert(#args <= 2, "expected no more than 2 arguments")
    if #args == 1 then
        if type(args[1]) == "number" then
            screenID = args[1]
        else
            closeMC = args[1]
        end
    else
        screenID, closeMC = table.unpack(args)
    end
    if screenID == nil then screenID = screen.mainScreen():id() end
    assert(math.type(screenID) == "integer", "screen id must be an integer")
    assert(type(closeMC) == "boolean", "close flag must be boolean")

    openMissionControl()
    local mcSpacesList, errMsg = findSpacesSubgroup("mc.spaces.list", screenID)
    if not mcSpacesList then
        if closeMC then closeMissionControl() end
        return nil, errMsg
    end

    local results = {}
    for _, child in ipairs(mcSpacesList.AXSelectedChildren or {}) do
        table.insert(results, (child.AXDescription:gsub("^exit to ", "")))
    end

    if closeMC then closeMissionControl() end
    if #results == 0 then
        return nil, "unable to get selected spaces for display"
    elseif #results == 1 then
        return results[1]
    else
        return setmetatable(results, { __tostring = inspect })
    end
end

-- activeSpaces([closeMCOnCompletion]) -> table | nil, errMsg
-- returns k-v table where k is screenID and v is string from activeSpaceOnScreen(k)
module.activeSpaces = function(...)
    local args, closeMC = { ... }, true
    assert(#args <= 1, "expected no more than 1 argument")
    if #args == 1 then
        closeMC = args[1]
    end
    assert(type(closeMC) == "boolean", "close flag must be boolean")

    openMissionControl()
    local results = {}

    for _, v in ipairs(screen.allScreens()) do
        local screenID = v:id()
        local activeSpaceForScreen, errMsg = module.activeSpaceOnScreen(screenID, false)
        if not activeSpaceForScreen then
            if closeMC then closeMissionControl() end
            return nil, errMsg
        end

        results[screenID] = activeSpaceForScreen
    end

    if closeMC then closeMissionControl() end
    return setmetatable(results, { __tostring = inspect })
end

-- addSpaceToScreen([screenID], [closeMCOnCompletion]) -> true | nil, errMsg
-- adds space to specified (or main) screen
module.addSpaceToScreen = function(...)
    local args, screenID, closeMC = { ... }, nil, true
    assert(#args <= 2, "expected no more than 2 arguments")
    if #args == 1 then
        if type(args[1]) == "number" then
            screenID = args[1]
        else
            closeMC = args[1]
        end
    else
        screenID, closeMC = table.unpack(args)
    end
    if screenID == nil then screenID = screen.mainScreen():id() end
    assert(math.type(screenID) == "integer", "screen id must be an integer")
    assert(type(closeMC) == "boolean", "close flag must be boolean")

    openMissionControl()
    local mcSpacesAdd, errMsg = findSpacesSubgroup("mc.spaces.add", screenID)
    if not mcSpacesAdd then
        if closeMC then closeMissionControl() end
        return nil, errMsg
    end

    local status, errMsg2 = mcSpacesAdd:doAXPress()

    if closeMC then closeMissionControl() end
    if status then
        return true
    else
        return nil, errMsg2
    end
end

-- ** THESE PROBABLY SHOULD HAVE AN OPTIONAL CALLBACK FOR CHAINING MULTIPLE ACTIONS **

-- gotoSpaceOnScreen(target, [screenID], [closeMCOnCompletion]) -> true | nil, errMsg
-- goes to the specified screen (names compared with string.match) on the specified (or main) screen
--
-- * requires delayed firing of button press via timer, so probably should add callback fn to allow
-- specifying followup commands.
-- * closeMCOnCompletion ignored on success -- going to a new space forces closing Mission Control
-- * because of delayed triggering, Mission Control may be visible for more than a second; we can't avoid this, but it's still better than killing the Dock
module.gotoSpaceOnScreen = function(...)
    local args, target, screenID, closeMC = { ... }, nil, nil, true
    assert(#args >= 1 and #args <= 3, "expected between 1 and 3 arguments")
    if #args < 3 then
        target = args[1]
        if #args == 2 then
            if type(args[2]) == "number" then
                screenID = args[2]
            else
                closeMC = args[2]
            end
        end
    else
        target, screenID, closeMC = table.unpack(args)
    end
    target = tostring(target)
    if screenID == nil then screenID = screen.mainScreen():id() end
    assert(math.type(screenID) == "integer", "screen id must be an integer")
    assert(type(closeMC) == "boolean", "close flag must be boolean")

    openMissionControl()
    local mcSpacesList, errMsg = findSpacesSubgroup("mc.spaces.list", screenID)
    if not mcSpacesList then
        if closeMC then closeMissionControl() end
        return nil, errMsg
    end

    for _, child in ipairs(mcSpacesList) do
        local childName = child.AXDescription:gsub("^exit to ", "")
        if childName:match(target) then
            local tmr
            tmr = timer.doAfter(module.queueTime, function()
                tmr = nil -- make it an upvalue
                local status, errMsg2 = child:doAXPress()
                if not status then print(status, errMsg2) end
                if closeMC then closeMissionControl() end
            end)
            return true
        end
    end

    if closeMC then closeMissionControl() end
    return nil, string.format("unable to find space matching '%s' on display", target)
end

-- removeSpaceFromScreen(target, [screenID], [closeMCOnCompletion]) -> true | nil, errMsg
-- goes to the specified screen (names compared with string.match) on the specified (or main) screen
--
-- * requires delayed firing of button press via timer, so probably should add callback fn to allow
-- specifying followup commands.
-- * because of delayed triggering, Mission Control may be visible for more than a second; we can't avoid this, but it's still better than killing the Dock
module.removeSpaceFromScreen = function(...)
    local args, target, screenID, closeMC = { ... }, nil, nil, true
    assert(#args >= 1 and #args <= 3, "expected between 1 and 3 arguments")
    if #args < 3 then
        target = args[1]
        if #args == 2 then
            if type(args[2]) == "number" then
                screenID = args[2]
            else
                closeMC = args[2]
            end
        end
    else
        target, screenID, closeMC = table.unpack(args)
    end
    target = tostring(target)
    if screenID == nil then screenID = screen.mainScreen():id() end
    assert(math.type(screenID) == "integer", "screen id must be an integer")
    assert(type(closeMC) == "boolean", "close flag must be boolean")

    openMissionControl()
    local mcSpacesList, errMsg = findSpacesSubgroup("mc.spaces.list", screenID)
    if not mcSpacesList then
        if closeMC then closeMissionControl() end
        return nil, errMsg
    end

    for _, child in ipairs(mcSpacesList) do
        local childName = child.AXDescription:gsub("^exit to ", "")
        if childName:match(target) then
            local tmr
            tmr = timer.doAfter(module.queueTime, function()
                tmr = nil -- make it an upvalue
                local status, errMsg2 = child:performAction("AXRemoveDesktop")
                if not status then print(status, errMsg2) end
                if closeMC then closeMissionControl() end
            end)
            return true
        end
    end

    if closeMC then closeMissionControl() end
    return nil, string.format("unable to find space matching '%s' on display", target)
end

return module
