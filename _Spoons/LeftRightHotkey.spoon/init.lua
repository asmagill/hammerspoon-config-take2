--- === LeftRightHotkey ===
---
--- This spoon addresses a limitation within the [hs.hotkey](hs.hotkey.html) module that allows the creation of hotkeys bound to specific left or right keyboard modifiers while leaving the other side free.
---
--- This is accomplished by creating unactivated hotkeys for each definition and using an [hs.eventtap](hs.eventtap.html) watcher to detect when modifier keys are pressed and conditionally activating only those hotkeys which correspond to the left or right modifiers currently active as specified by the `bind` and `new` methods of this spoon.
---
--- The `LeftRightHotkeyObject` that is returned by [LeftRightHotkey:new](#new) and [LeftRightHotkey:bind](#bind) supports the following methods in a manner similar to the [hs.hotkey](hs.hotkey.html) equivalents:
---
---  * `LeftRightHotkeyObject:enable()`   -- enables the registered hotkey.
---  * `LeftRightHotkeyObject:disable()`  -- disables the registered hotkey.
---  * `LeftRightHotkeyObject:delete()`   -- deletes the registered hotkey.
---  * `LeftRightHotkeyObject:isEnabled() -- returns a boolean value specifying whether the hotkey is currently enabled (true) or disabled (false)
---
--- Like all Spoons, don't forget to use the [LeftRightHotkey:start()](#start) method to activate the modifier key watcher.
---
--- Download: `svn export https://github.com/asmagill/hammerspoon-config-take2/trunk/_Spoons/LeftRightHotkey.spoon`

local spoons  = require("hs.spoons")
-- local log     = require("hs.logger").new("LeftRightHotkey", settings.get("LeftRightHotkey_logLevel") or "warning")

local fnutils  = require("hs.fnutils")
local hotkey   = require("hs.hotkey")
local keycodes = require("hs.keycodes")
local eventtap = require("hs.eventtap")
local etevent  = eventtap.event

local obj    = {
-- Metadata
    name      = "LeftRightHotkey",
    author    = "A-Ron",
    homepage  = "https://github.com/asmagill/hammerspoon-config-take2/tree/master/_Spoons/LeftRightHotkey.spoon",
    license   = "MIT - https://opensource.org/licenses/MIT",
    spoonPath = spoons.scriptPath(),
}
-- version is outside of obj table definition to facilitate its auto detection by
-- external documentation generation scripts
obj.version   = "0.1"

-- defines the keys to display in object's __tostring metamethod; define here so subsequent
-- additions are not included in the output
local metadataKeys = {} ; for k, v in fnutils.sortByKeys(obj) do table.insert(metadataKeys, k) end

obj.__index = obj

---------- Local Functions And Variables ----------

local modiferBase = {
    ["lcmd"]   = "cmd",
    ["rcmd"]   = "cmd",
    ["lshift"] = "shift",
    ["rshift"] = "shift",
    ["lalt"]   = "alt",
    ["ralt"]   = "alt",
    ["lctrl"]  = "ctrl",
    ["rctrl"]  = "ctrl",
}

local altMods = {
    ["⇧"]       = "shift",
    ["opt"]     = "alt",
    ["option"]  = "alt",
    ["⌥"]       = "alt",
    ["⌘"]       = "cmd",
    ["command"] = "cmd",
    ["⌃"]       = "ctrl",
    ["control"] = "ctrl",
}

local modifierMasks = {
    lcmd   = 1 << 0,
    rcmd   = 1 << 1,
    lshift = 1 << 2,
    rshift = 1 << 3,
    lalt   = 1 << 4,
    ralt   = 1 << 5,
    lctrl  = 1 << 6,
    rctrl  = 1 << 7,
}

local existantHotKeys = {}

local queuedHotKeys = {}
for i = 1, (1 << 8) - 1, 1 do queuedHotKeys[i] = setmetatable({}, { __mode = "k" }) end

local shallowCopyTable = function(tbl)
    local newTbl = {}
    local key, value = next(tbl)
    while key do
        newTbl[key] = value
        key, value = next(tbl, key)
    end
    return newTbl
end

local normalizeModsTable = function(tbl)
    local newTbl = shallowCopyTable(tbl)
    for i, m in ipairs(newTbl) do
        local mod = m:lower()
        for k, v in pairs(altMods) do
            local s, e = mod:find(k .. "$")
            if s then
                newTbl[i] = mod:sub(1, s - 1) .. v
                break
            end
        end
        newTbl[i] = newTbl[i]:lower()
    end
    return newTbl
end

local _flagWatcher ;
local flagChangeCallback = function(ev)
    local rf = ev:getRawEventData().CGEventData.flags
    local queueIndex = 0
    if rf & etevent.rawFlagMasks.deviceLeftAlternate > 0 then
        queueIndex = queueIndex | modifierMasks.lalt
    end
    if rf & etevent.rawFlagMasks.deviceLeftCommand > 0 then
        queueIndex = queueIndex | modifierMasks.lcmd
    end
    if rf & etevent.rawFlagMasks.deviceLeftControl > 0 then
        queueIndex = queueIndex | modifierMasks.lctrl
    end
    if rf & etevent.rawFlagMasks.deviceLeftShift > 0 then
        queueIndex = queueIndex | modifierMasks.lshift
    end
    if rf & etevent.rawFlagMasks.deviceRightAlternate > 0 then
        queueIndex = queueIndex | modifierMasks.ralt
    end
    if rf & etevent.rawFlagMasks.deviceRightCommand > 0 then
        queueIndex = queueIndex | modifierMasks.rcmd
    end
    if rf & etevent.rawFlagMasks.deviceRightControl > 0 then
        queueIndex = queueIndex | modifierMasks.rctrl
    end
    if rf & etevent.rawFlagMasks.deviceRightShift > 0 then
        queueIndex = queueIndex | modifierMasks.rshift
    end
-- print("activating " .. tostring(queueIndex))
    local foundMatches = {}
    for i, v in ipairs(queuedHotKeys) do
        if i == queueIndex then
            for key, _ in pairs(v) do
                if key._enabled then
                    table.insert(foundMatches, key)
--                     key._hotkey:enable()
                end
            end
        else
            for key, _ in pairs(v) do
                if key._enabled then
                    key._hotkey:disable()
                end
            end
        end
    end

    if #foundMatches > 0 then
        -- enable only the most recently created version for a given _keycode
        -- in case of stacking
        local enabled = {}
        table.sort(foundMatches, function(a, b) return a._creationID > b._creationID end)
        for _, key in ipairs(foundMatches) do
            if not enabled[key._keycode] then
                enabled[key._keycode] = true
                key._hotkey:enable()
            end
        end
    end
end

local _LeftRightHotkeyObjMT = {}
_LeftRightHotkeyObjMT.__index = {
    enable = function(self)
        self._enabled = true
        return self
    end,
    disable = function(self)
        self._enabled = false
        self._hotkey:disable()
        return self
    end,
    delete = function(self)
        self:disable()
        existantHotKeys[self] = nil
        collectgarbage()
        return nil
    end,
    isEnabled = function(self) return self._enabled end,
}
_LeftRightHotkeyObjMT.__tostring = function(self)
    return self._modDesc .. " " .. (keycodes.map[self._keycode] or ("unmapped:" .. tostring(self._keycode)))
end

local convertModifiers = function(specifiedMods)
    local actualMods, queueIndex  = {}, 0

    for _, v in pairs(specifiedMods) do
        queueIndex = queueIndex | (modifierMasks[v] or 0)
        local hotkeyModEquivalant = modiferBase[v]
        if hotkeyModEquivalant then
            table.insert(actualMods, hotkeyModEquivalant)
        else
            queueIndex = 0
            break
        end
    end
    return actualMods, queueIndex
end

local definitionIndex = 0

---------- Spoon Methods ----------

--- LeftRightHotkey:new(mods, key, [message,] pressedfn, releasedfn, repeatfn) -> LeftRightHotkeyObject
--- Method
--- Create a new hotkey with the specified left/right specific modifiers.
---
--- Parameters:
---  * mods - A table containing as elements the keyboard modifiers required, which should be one or more of the following:
---    * "lCmd", "lCommand", or "l⌘" for the left Command modifier
---    * "rCmd", "rCommand", or "r⌘" for the right Command modifier
---    * "lCtrl", "lControl" or "l⌃" for the left Control modifier
---    * "rCtrl", "rControl" or "r⌃" for the right Control modifier
---    * "lAlt", "lOpt", "lOption" or "l⌥" for the left Option modifier
---    * "rAlt", "rOpt", "rOption" or "r⌥" for the right Option modifier
---    * "lShift" or "l⇧" for the left Shift modifier
---    * "rShift" or "r⇧" for the right Shift modifier
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or a raw keycode number
---  * message - (optional) A string containing a message to be displayed via [hs.alert()](hs.alert.html) when the hotkey has been triggered; if omitted, no alert will be shown
---  * pressedfn - A function that will be called when the hotkey has been pressed, or nil
---  * releasedfn - A function that will be called when the hotkey has been released, or nil
---  * repeatfn - A function that will be called when a pressed hotkey is repeating, or nil
---
--- Returns:
---  * a new, initially disabled, hotkey with the specified left/right modifiers.
---
--- Notes:
---  * The modifiers table is adjusted for use when conditionally activating the appropriate hotkeys based on the current modifiers in effect, but the other arguments are passed to [hs.hotkey.new](hs.hotkey.html#new) as is and any caveats or considerations outlined there also apply here.
obj.new = function(self, ...)
    local args = { ... }
    if self ~= obj then
        table.insert(args, 1, self)
        self = obj
    end
    local specifiedMods = normalizeModsTable(args[1])
    local actualMods, queueIndex = convertModifiers(specifiedMods)

    if queueIndex ~= 0 then
        args[1] = actualMods
        for i, v in ipairs(specifiedMods) do
            specifiedMods[i] = v:sub(1,1) .. v:sub(2,2):upper() .. v:sub(3)
        end
        local key     = args[2]
        local keycode = keycodes.map[key]
        if type(key) == "number" then keycode = key end
-- print(queueIndex, "actually " .. finspect(actualMods))
        local newObject = setmetatable({
            _modDesc    = table.concat(specifiedMods, "+"),
            _queueIndex = queueIndex,
            _keycode    = keycode,
            _hotkey     = hotkey.new(table.unpack(args)),
            _enabled    = false,
            _creationID = definitionIndex,
        }, _LeftRightHotkeyObjMT)

        -- used to determine creation order for stacking
        definitionIndex = definitionIndex + 1

        existantHotKeys[newObject] = true
        queuedHotKeys[queueIndex][newObject] = true
        return newObject
    else
        error("you must specifiy one or more of lcmd, rcmd, lshift, rshift, lalt, ralt, lctrl, rctrl", 2)
    end
end

--- LeftRightHotkey:deleteAll(mods, key)
--- Method
--- Deletes all previously set callbacks for a given keyboard combination
---
--- Parameters:
---  * mods - A table containing as elements the keyboard modifiers required, which should be one or more of the following:
---    * "lCmd", "lCommand", or "l⌘" for the left Command modifier
---    * "rCmd", "rCommand", or "r⌘" for the right Command modifier
---    * "lCtrl", "lControl" or "l⌃" for the left Control modifier
---    * "rCtrl", "rControl" or "r⌃" for the right Control modifier
---    * "lAlt", "lOpt", "lOption" or "l⌥" for the left Option modifier
---    * "rAlt", "rOpt", "rOption" or "r⌥" for the right Option modifier
---    * "lShift" or "l⇧" for the left Shift modifier
---    * "rShift" or "r⇧" for the right Shift modifier
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or a raw keycode number
---
--- Returns:
---  * None
obj.deleteAll = function(self, ...)
    local args = { ... }
    if self ~= obj then
        table.insert(args, 1, self)
        self = obj
    end
    local specifiedMods = normalizeModsTable(args[1])
    local _, queueIndex = convertModifiers(specifiedMods)

    if queueIndex ~= 0 then
        local key     = args[2]
        local keycode = keycodes.map[key]
        if type(key) == "number" then keycode = key end

        local foundMatches = {}
        for k, v in pairs(existantHotKeys) do
            if v._queueIndex == queueIndex and v._keycode == keycode then
                table.insert(foundMatches, k)
            end
        end
        -- this is so we don't remove items from existantHotKeys while iterating through it
        for _, v in ipairs(foundMatches) do
            v:delete()
        end
    else
        error("you must specifiy one or more of lcmd, rcmd, lshift, rshift, lalt, ralt, lctrl, rctrl", 2)
    end
end

--- LeftRightHotkey:disableAll(mods, key)
--- Method
--- Disables all previously set callbacks for a given keyboard combination
---
--- Parameters:
---  * mods - A table containing as elements the keyboard modifiers required, which should be one or more of the following:
---    * "lCmd", "lCommand", or "l⌘" for the left Command modifier
---    * "rCmd", "rCommand", or "r⌘" for the right Command modifier
---    * "lCtrl", "lControl" or "l⌃" for the left Control modifier
---    * "rCtrl", "rControl" or "r⌃" for the right Control modifier
---    * "lAlt", "lOpt", "lOption" or "l⌥" for the left Option modifier
---    * "rAlt", "rOpt", "rOption" or "r⌥" for the right Option modifier
---    * "lShift" or "l⇧" for the left Shift modifier
---    * "rShift" or "r⇧" for the right Shift modifier
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or a raw keycode number
---
--- Returns:
---  * None
obj.disableAll = function(self, ...)
    local args = { ... }
    if self ~= obj then
        table.insert(args, 1, self)
        self = obj
    end
    local specifiedMods = normalizeModsTable(args[1])
    local _, queueIndex = convertModifiers(specifiedMods)

    if queueIndex ~= 0 then
        local key     = args[2]
        local keycode = keycodes.map[key]
        if type(key) == "number" then keycode = key end

        for k, v in pairs(existantHotKeys) do
            if v._queueIndex == queueIndex and v._keycode == keycode then
                k:disable() -- we don't need the temp table used in delete since we're just disabling
            end
        end
    else
        error("you must specifiy one or more of lcmd, rcmd, lshift, rshift, lalt, ralt, lctrl, rctrl", 2)
    end
end

--- LeftRightHotkey:bind(mods, key, [message,] pressedfn, releasedfn, repeatfn) -> LeftRightHotkeyObject
--- Method
--- Create and enable a new hotkey with the specified left/right specific modifiers.
---
--- Parameters:
--- Parameters:
---  * mods - A table containing as elements the keyboard modifiers required, which should be one or more of the following:
---    * "lCmd", "lCommand", or "l⌘" for the left Command modifier
---    * "rCmd", "rCommand", or "r⌘" for the right Command modifier
---    * "lCtrl", "lControl" or "l⌃" for the left Control modifier
---    * "rCtrl", "rControl" or "r⌃" for the right Control modifier
---    * "lAlt", "lOpt", "lOption" or "l⌥" for the left Option modifier
---    * "rAlt", "rOpt", "rOption" or "r⌥" for the right Option modifier
---    * "lShift" or "l⇧" for the left Shift modifier
---    * "rShift" or "r⇧" for the right Shift modifier
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or a raw keycode number
---  * message - (optional) A string containing a message to be displayed via [hs.alert()](hs.alert.html) when the hotkey has been triggered; if omitted, no alert will be shown
---  * pressedfn - A function that will be called when the hotkey has been pressed, or nil
---  * releasedfn - A function that will be called when the hotkey has been released, or nil
---  * repeatfn - A function that will be called when a pressed hotkey is repeating, or nil
---
--- Returns:
---  * a new enabled hotkey with the specified left/right modifiers.
---
--- Notes:
---  * This function is just a wrapper that performs `LeftRightHotkey:new(...):enable()`
---  * The modifiers table is adjusted for use when conditionally activating the appropriate hotkeys based on the current modifiers in effect, but the other arguments are passed to [hs.hotkey.bind](hs.hotkey.html#bind) as is and any caveats or considerations outlined there also apply here.
obj.bind = function(...) return obj.new(...):enable() end

--- LeftRightHotkey:start() -> self
--- Method
--- Starts watching for flag (modifier key) change events that can determine if the right or left modifiers have been pressed.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the LeftRightHotkey spoon object
---
--- Notes:
---  * this enables the use of hotkeys created by using this Spoon.
obj.start = function(self)
    -- in case called as function
    if self ~= obj then self = obj end
    if not _flagWatcher then
        _flagWatcher = eventtap.new({ etevent.types.flagsChanged }, flagChangeCallback):start()
    end
    return self
end

--- LeftRightHotkey:stop() -> self
--- Method
--- Stops watching for flag (modifier key) change events that can determine if the right or left modifiers have been pressed.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the LeftRightHotkey spoon object
---
--- Notes:
---  * this will implicitly disable all hotkeys created by using this Spoon -- only those hotkeys which are defined with [hs.hotkey](hs.hotkey.html) directly will still be available.
obj.stop = function(self)
    -- in case called as function
    if self ~= obj then self = obj end
    if _flagWatcher then
        _flagWatcher:stop()
        _flagWatcher = nil
    end
    return self
end

-- Spoon Metadata definition and object return --

-- for debugging purposes, may go away
obj._queuedHotKeys   = queuedHotKeys
obj._existantHotKeys = existantHotKeys

return setmetatable(obj, {
    -- more useful than "table: 0x????????????????"
    __tostring = function(self)
        local result, fieldSize = "", 0
        for i, v in ipairs(metadataKeys) do fieldSize = math.max(fieldSize, #v) end
        for i, v in ipairs(metadataKeys) do
            result = result .. string.format("%-"..tostring(fieldSize) .. "s %s\n", v, self[v])
        end
        return result
    end,
})
