local module = {}

local kAXMenuItemModifierControl = (1 << 2)
local kAXMenuItemModifierNoCommand = (1 << 3)
local kAXMenuItemModifierOption = (1 << 1)
local kAXMenuItemModifierShift = (1 << 0)

local _getMenuStructure
_getMenuStructure = function(item)
    local values = item:allAttributeValues()
    local thisMenuItem = {
        AXTitle                = values["AXTitle"] or "",
        AXRole                 = values["AXRole"] or "",
        AXMenuItemMarkChar     = values["AXMenuItemMarkChar"] or "",
        AXMenuItemCmdChar      = values["AXMenuItemCmdChar"] or "",
        AXMenuItemCmdModifiers = values["AXMenuItemCmdModifiers"] or "",
        AXEnabled              = values["AXEnabled"] or "",
        AXMenuItemCmdGlyph     = values["AXMenuItemCmdGlyph"] or "",
    }

--     if thisMenuItem["AXTitle"] == "Apple" then
--         thisMenuItem = nil
--     else
        local role = thisMenuItem["AXRole"]

        local modsDst = nil
        local modsVal = thisMenuItem["AXMenuItemCmdModifiers"]
        if type(modsVal) == "number" then
            modsDst = ((modsVal & kAXMenuItemModifierNoCommand) > 0) and {} or { "cmd" }
            if (modsVal & kAXMenuItemModifierShift)   > 0 then table.insert(modsDst, "shift") end
            if (modsVal & kAXMenuItemModifierOption)  > 0 then table.insert(modsDst, "alt") end
            if (modsVal & kAXMenuItemModifierControl) > 0 then table.insert(modsDst, "ctrl") end
        end
        thisMenuItem["AXMenuItemCmdModifiers"] = modsDst

        local children = {}
        for i = 1, #item, 1 do table.insert(children, _getMenuStructure(item[i])) end
        if #children > 0 then thisMenuItem["AXChildren"] = children end

        if not (role == "AXMenuItem" or role == "AXMenuBarItem") then
            thisMenuItem = (#children > 0) and children or nil
        end
--     end
    coroutine.applicationYield()
    return thisMenuItem
end

module.getMenuItems = function(appObject, callback)
    local ax = require"hs.axuielement"
    hs.assert(getmetatable(appObject) == hs.getObjectMetatable("hs.application"), "expect hs.application for first parameter")
    hs.assert(type(callback) == "function" or (getmetatable(callback) or {}).__call, "expected function for second parameter")

    local app = ax.applicationElement(appObject)
    local menus

    local menuBar = app("menuBar")
    if menuBar then
        coroutine.wrap(function(m, c)
            local menus = _getMenuStructure(m)
            c(menus)
        end)(menuBar, callback)
    else
        callback(menus)
    end
end

return module
