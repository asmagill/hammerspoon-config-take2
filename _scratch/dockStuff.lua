--
-- Mucking around with the Dock
--
-- A few things I've figured out concerning the Dock that hs.axuielement gives us...
--
-- This has been tested with 10.15.4; it's not uncommon that Apple changes things with
-- updates, so YMMV with later versions, but we can hope it will continue to work!
--
-- Most of this has been gleaned by viewing the details captured with:
--
--       f = hs.axuielement.applicationElement("Dock"):elementSearch(function(m, r, c)
--          print(m, c, r:runTime())
--       end, { objectOnly = false })
--
-- Expose group only exists in Dock's elements when expose is actually active, so it was captured with:
-- (Note the timer to do the query after first invoking "doShowExpose" on the Finder)
--
--       hs.axuielement.applicationElement("Dock"):elementSearch(function(msg, e)
--           if #e > 0 then e[1]:doAXShowExpose() else hs.alert("Couldn't find application!") end
--       end, hs.axuielement.searchCriteriaFunction{ attribute = "AXTitle", value = "Finder", pattern = true })
--       t = hs.timer.doAfter(1, function()
--           f = hs.axuielement.applicationElement("Dock"):elementSearch(function(m, r, c)
--               print(m, c, r:runTime())
--           end, { objectOnly = false })
--           t = nil
--       end)
--
-- Similar for Mission Control, though I entered it manually... haven't found a way to do so programatically yet
--
--       t = hs.timer.doAfter(2, function()
--           f = hs.axuielement.applicationElement("Dock"):elementSearch(function(m, r, c)
--               print(m, c, r:runTime())
--           end, { objectOnly = false })
--       end)
--

local module = {}

local axuielement = require("hs.axuielement")
local inspect     = require("hs.inspect")

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

-- returns a table of the applications in the Dock as keys
-- value for each key is true if the application is running and false if it is not
module.appsInDock = function()
    local results = {}
    local axlist = getItemListFromDock()

    for i,v in ipairs(axlist) do
        if v.AXSubrole == "AXApplicationDockItem" then results[v.AXTitle] = v.AXIsApplicationRunning end
    end

    local asString = inspect(results)
    return setmetatable(results, { __tostring = function(_) return asString end })
end

-- enters Expose for the specified application
module.enterExposeFor = function(name)
    local axlist = getItemListFromDock()
    for i,v in ipairs(axlist) do
        if v.AXSubrole == "AXApplicationDockItem" and v.AXTitle == name then
            -- do it again to exit -- we setup a hotkey with the spacebar to exit expose
            local vk
            vk = hs.hotkey.bind({}, "space", nil, function() v:doAXShowExpose() ; vk:disable() ; vk = nil end)
            v:doAXShowExpose()
            return
        end
    end

    error(tostring(name) .. " not found in Dock application list")
end

-- is Expose currently active?
-- I don't see an obvious way to determine for what App, though...
module.isInAppExpose = function()
    local dockElement = getDock()

    local answer = false
    for i,v in ipairs(dockElement) do
        if v.AXIdentifier == "appexpose" then
            answer = true
            break
        end
    end

    return answer
end

-- same for Mission Control
module.isInMissionControl = function()
    local dockElement = getDock()

    local answer = false
    for i,v in ipairs(dockElement) do
        if v.AXIdentifier == "mc" then
            answer = true
            break
        end
    end

    return answer
end

-- try `doMenuItem("System Preferences", "General")`
module.doMenuItem = function(app, item)
    local axlist = getItemListFromDock()
    for i,v in ipairs(axlist) do
        if v.AXSubrole == "AXApplicationDockItem" and v.AXTitle == app then
            v:doAXShowMenu()
            for i2,v2 in ipairs(v[1]) do -- first child of application will be "AXMenu" and its children, the items in it.
                if v2.AXTitle == item then
                    v2:doAXPress()
                    return
                end
            end
            v:doAXShowMenu() -- close menu so we can error
            error(tostring(item) .. " not found in " .. tostring(app) .. " menu list")
        end
    end
    error(tostring(app) .. " not found in Dock application list")
end

return module
