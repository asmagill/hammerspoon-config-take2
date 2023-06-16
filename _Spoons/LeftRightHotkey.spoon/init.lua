--- === LeftRightHotkey ===
---
--- This spoon addresses a limitation within the `hs.hotkey` module that allows the creation of hotkeys bound to specific left or right keyboard modifiers while leaving the other side free.
---
--- This is accomplished by creating unactivated hotkeys for each definition and using an `hs.eventtap` watcher to detect when modifier keys are pressed and conditionally activating only those hotkeys which correspond to the left or right modifiers currently active as specified by the `bind` and `new` methods of this spoon.
---
--- The `LeftRightHotkeyObject` that is returned by [LeftRightHotkey:new](#new) and [LeftRightHotkey:bind](#bind) supports the following methods in a manner similar to the `hs.hotkey` equivalents:
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
    for i, v in ipairs(queuedHotKeys) do
        if i == queueIndex then
            for key, _ in pairs(v) do
              if key._enabled then
                  key._hotkey:enable() end
              end
        else
            for key, _ in pairs(v) do
                if key._enabled then
                    key._hotkey:disable()
                end
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
    return self._description
end

---------- Spoon Methods ----------

obj.queuedHotKeys = queuedHotKeys
obj.existantHotKeys = existantHotKeys

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
---    * "lAlt", "lOpt", "lOption" or "l⌥" for the Option left modifier
---    * "rAlt", "rOpt", "rOption" or "r⌥" for the Option right modifier
---    * "lShift" or "l⇧" for the left Shift modifier
---    * "rShift" or "r⇧" for the right Shift modifier
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or a raw keycode number
---  * message - (optional) A string containing a message to be displayed via `hs.alert()` when the hotkey has been triggered; if omitted, no alert will be shown
---  * pressedfn - A function that will be called when the hotkey has been pressed, or nil
---  * releasedfn - A function that will be called when the hotkey has been released, or nil
---  * repeatfn - A function that will be called when a pressed hotkey is repeating, or nil
---
--- Returns:
---  * a new, initially disabled, hotkey with the specified left/right modifiers.
---
--- Notes:
---  * The modifiers table is adjusted for use when conditionally activating the appropriate hotkeys based on the current modifiers in effect, but the other arguments are passed to `hs.hotkey.new` as is and any caveats or considerations outlined there also apply here.
obj.new = function(self, ...)
    local args = { ... }
    if self ~= obj then
        table.insert(args, 1, self)
        self = obj
    end
    local specMods = normalizeModsTable(args[1])
    local actMods, queueIndex  = {}, 0

    for _, v in pairs(specMods) do
        queueIndex = queueIndex | (modifierMasks[v] or 0)
        local hotkeyModEquivalant = modiferBase[v]
        if hotkeyModEquivalant then
            table.insert(actMods, hotkeyModEquivalant)
        else
            queueIndex = 0
            break
        end
    end

    if queueIndex ~= 0 then
        args[1] = actMods
        for i, v in ipairs(specMods) do
            specMods[i] = v:sub(1,1) .. v:sub(2,2):upper() .. v:sub(3)
        end
        local key = args[2]
        if type(key) == "number" then
            key = keycodes.map[key] or "unmapped:" .. tostring(key)
        end
-- print(queueIndex, "actually " .. finspect(actMods))
        local newObject = setmetatable({
            _description = table.concat(specMods, "+") .. " " .. key .. " hotkey",
            _hotkey = hotkey.new(table.unpack(args)),
            _enabled = false,
        }, _LeftRightHotkeyObjMT)

        existantHotKeys[newObject] = true
        queuedHotKeys[queueIndex][newObject] = true
        return newObject
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
---    * "lAlt", "lOpt", "lOption" or "l⌥" for the Option left modifier
---    * "rAlt", "rOpt", "rOption" or "r⌥" for the Option right modifier
---    * "lShift" or "l⇧" for the left Shift modifier
---    * "rShift" or "r⇧" for the right Shift modifier
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or a raw keycode number
---  * message - (optional) A string containing a message to be displayed via `hs.alert()` when the hotkey has been triggered; if omitted, no alert will be shown
---  * pressedfn - A function that will be called when the hotkey has been pressed, or nil
---  * releasedfn - A function that will be called when the hotkey has been released, or nil
---  * repeatfn - A function that will be called when a pressed hotkey is repeating, or nil
---
--- Returns:
---  * a new enabled hotkey with the specified left/right modifiers.
---
--- Notes:
---  * This function is just a wrapper that performs `LeftRightHotkey:new(...):enable()`
---  * The modifiers table is adjusted for use when conditionally activating the appropriate hotkeys based on the current modifiers in effect, but the other arguments are passed to `hs.hotkey.bind` as is and any caveats or considerations outlined there also apply here.
obj.bind = function(...) return obj.new(...):enable() end

--- LeftRightHotkey:start() -> self
--- Method
--- Starts the processing or displays for the LeftRightHotkey spoon
---
--- Parameters:
---  * None
---
--- Returns:
---  * the LeftRightHotkey spoon object
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
--- Stops the processing and/or removes the displays generated by the LeftRightHotkey spoon
---
--- Parameters:
---  * None
---
--- Returns:
---  * the LeftRightHotkey spoon object
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
