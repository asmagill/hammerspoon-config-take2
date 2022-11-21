--- === MenuOfFiles ===
---
--- Provides a menu of files in specified folders matching a given criteria.
---
--- Download: `svn export https://github.com/asmagill/hammerspoon-config-take2/trunk/_Spoons/MenuOfFiles.spoon`

local spoons  = require("hs.spoons")
local log     = require("hs.logger").new("MenuOfFiles", settings.get("MenuOfFiles_logLevel") or "warning")

local pathwatcher = require("hs.pathwatcher")
local luafs       = require("hs.fs")
local menubar     = require("hs.menubar")
local application = require("hs.application")
local eventtap    = require("hs.eventtap")
local stext       = require("hs.styledtext")
local image       = require("hs.image")
local inspect     = require("hs.inspect")

local obj    = {
-- Metadata
    name      = "MenuOfFiles",
    author    = "A-Ron",
    homepage  = "https://github.com/asmagill/hammerspoon-config-take2/tree/master/_Spoons/MenuOfFiles.spoon",
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

--- MenuOfFiles.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the log level for the messages coming from the Spoon.
---
--- Notes:
---  * You can set the default logging level when the spoon loads with `hs.settings.set("MenuOfFiles_logLevel", lvl)` where `lvl` is either a number between 0 and 5 inclusive, or a string specifying one of the following: 'nothing', 'error', 'warning', 'info', 'debug', or 'verbose'
---  * See `hs.logger` for more information.
obj.logger = log


---------- Local Functions And Variables ----------

-- spoon vars are stored in _internals so we can validate them immediately upon change
-- with the spoon's __newindex matamethod (see end of file) rather than get a delayed
-- error because the value is the wrong type
--
-- Note that anything with a key in _internals that starts with an underscore is considered
-- private and is hidden by the __index metamethod defined for the spoon at the end.
local _internals = {}

_internals._menus = {}

-- for debugging purposes, should usually be commented out
-- obj._internals = _internals

local l_updateMenuView = function(self)
    if self._menu then
        local appearance = self._appearance or (self._icon and "icon" or "label")

        if appearance == "icon" and self._icon then
            if self._menu:setIcon(self._icon) then
                self._menu:setTitle(nil)
            else
                self._menu:setTitle(self._label or self._name)
                self._menu:setIcon(nil)
            end
        else
            self._menu:setIcon(nil)
            self._menu:setTitle(self._label or self._name)
            if self.menuView == "both" and self._icon then
                self._menu:setIcon(self._icon)
            end
        end
    end
end

-- local l_changeWatcher = function(self, paths)
-- end

-- local l_doFileListMenu = function(self, mods)
-- end

-- local l_sortMenuItems = function(self)
-- end

-- local l_populateMenu = function(self)
-- end

---------- Individual Menu Metatable and Methods ----------

local _menu_mt = {}

_menu_mt.show = function(self)
    if not self._menu then
        self._menu         = menubar.new()
        self._menuData     = nil
        self._pathWatchers = {}

        local paths = type(self._menuDirectories) == "string" and
                      { self._menuDirectories } or self._menuDirectories

        for _, v in pairs(paths) do
            local entries = type(v) == "string" and { v } or v
            for _, v2 in pairs(entries) do
                table.insert(self._pathWatchers, pathwatcher.new(v2, function(pathChanges)
                    l_changeWatcher(self, pathChanges)
                end):start())
            end
        end
        l_updateMenuView(self)
        self._menu:setMenu(function(mods) return l_doFileListMenu(self, mods) end)
    end
    self._visible = true
    return self
end

_menu_mt.hide = function(self, forStop)
    if self._menu then
        for _, v in ipairs(self._pathWatchers) do v:stop() end
        self._menu:delete()

        self._menu         = nil
        self._menuData     = nil
        self._pathWatchers = nil
    end
    if not forStop then self._visible = false end
    return self
end

_menu_mt.delete = function(self)
    self:hide()
    _internals._menus[self._name] = nil
    setmetatable(self, nil)
end

_menu_mt.appearance = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        return self._appearance or "icon"
    elseif args.n == 1 and (fnutils.contains({ "icon", "label", "both" }, args[1]) or
                            type(args[1]) == "nil") then
        self._appearance = args[1]
        l_updateMenuView(self)
        return self
    else
        return error("expected a single argument of type string: 'icon', 'label', or 'both'", 2)
    end
end

_menu_mt.subFolderTreatment = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        return self._subFolderTreatment or "mixed"
    elseif args.n == 1 and (fnutils.contains({ "ignore", "before", "mixed", "after" }, args[1])  or
                            type(args[1]) == "nil") then
        local needRepopulate = args[1] == "ignore" or self._subFolderTreatment == "ignore"
        self._subFolderTreatment = args[1]
        if needRepopulate then
            self._menuData = nil
        else
            l_sortMenuItems(self)
        end
        return self
    else
        return error("expected a single argument of type string: 'ignore', 'before', 'mixed', or 'after'", 2)
    end
end

_menu_mt.icon = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        return self._icon
    elseif args.n == 1 and (type(args[1]) == "string" or
                            type(args[1]) == "nil" or
                            getmetatable(args[1]) == hs.getObjectMetatable("hs.image")) then
        self._icon = args[1]
        l_updateMenuView(self)
        return self
    else
        return error("expected a single argument of type string or an hs.image object", 2)
    end
end

menu_mt.label = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        return self._label or self._name
    elseif args.n == 1 and (type(args[1]) == "string" or
                            type(args[1]) == "nil") then
        self._label = args[1]
        l_updateMenuView(self)
        return self
    else
        return error("expected a single argument of type string", 2)
    end
end

menu_mt.subFolderDepth = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        return self._subFolderDepth or 10
    elseif args.n == 1 and (math.type(args[1]) == "integer" or
                            type(args[1]) == "nil") then
        self._subFolderDepth = args[1]
        self._menuData = nil
        return self
    else
        return error("expected a single argument of type integer", 2)
    end
end

menu_mt.logWarnings = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        if type(self._logWarnings) == "boolean" then
            return self._logWarnings
        else
            return true
        end
    elseif args.n == 1 and (type(args[1]) == "boolean" or
                            type(args[1]) == "nil") then
        self._logWarnings = args[1]
        return self
    else
        return error("expected a single argument of type boolean", 2)
    end
end

menu_mt.pruneEmptyDirectories = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        if type(self._pruneEmptyDirectories) == "boolean" then
            return self._pruneEmptyDirectories
        else
            return true
        end
    elseif args.n == 1 and (type(args[1]) == "boolean" or
                            type(args[1]) == "nil") then
        self._pruneEmptyDirectories = args[1]
        self._menuData = nil
        return self
    else
        return error("expected a single argument of type boolean", 2)
    end
end

menu_mt.includeItemImages = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        if type(self._includeItemImages) == "boolean" then
            return self._includeItemImages
        else
            return true
        end
    elseif args.n == 1 and (type(args[1]) == "boolean" or
                            type(args[1]) == "nil") then
        self._includeItemImages = args[1]
        self._menuData = nil
        return self
    else
        return error("expected a single argument of type boolean", 2)
    end
end

menu_mt.itemImageSize = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        return self._itemImageSize or 18
    elseif args.n == 1 and (type(args[1]) == "number" or
                            type(args[1]) == "nil") then
        self._itemImageSize = args[1]
        self._menuData = nil
        return self
    else
        return error("expected a single argument of type number", 2)
    end
end

_menu_mt.controlMenuButton = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        return self._subFolderTreatment or "right"
    elseif args.n == 1 and (fnutils.contains({ "right", "middle", "none" }, args[1])  or
                            type(args[1]) == "nil") then
        self._subFolderTreatment = args[1]
        return self
    else
        return error("expected a single argument of type string: 'right', 'middle', or 'none'", 2)
    end
end

-- _menu_mt.controlMenu (mods table)
-- _menu_mt.selectFileFunction (function)
-- _menu_mt.selectFolderFunction (function)
-- _menu_mt.menuDirectories (string/table)
-- _menu_mt.matchCriteria (string/function)

_menu_mt.populate = function(self)
    l_populateMenu(self)
    return self
end

_menu_mt.__index = _menu_mt
_menu_mt.__gc    = _menu_mt.delete

_menu_mt.__tostring = function(self)
    return obj.name .. ".menu: " .. self._name .. " (" .. self._tableAddress .. ")"
end

---------- Spoon Variables ----------

-- The following are wrapped by obj's __index/__newindex metamethods (see end of file)so
-- they appear to work like regular variables and are thus documented as such

-- --- MenuOfFiles.some_config_param
-- --- Variable
-- --- Some configuration parameter
-- _internals.some_config_param = true


---------- Spoon Methods ----------

-- --- MenuOfFiles:init() -> self
-- --- Method
-- --- Performs any necessary initialization for the MenuOfFiles spoon
-- ---
-- --- Parameters:
-- ---  * None
-- ---
-- --- Returns:
-- ---  * the MenuOfFiles spoon object
-- ---
-- --- Notes:
-- ---  * This method is invoked by `hs.loadSpoon` when the spoon is loaded for the first time and it should not normally be necessary for the user to invoke this function directly.
-- ---  * This method should do any initial setup that might be required upon loading the spoon, but should *not* actually start any processes or generate any displays -- that should be handled by [MenuOfFiles:start](#start) when the user chooses.
-- obj.init = function(self)
--     -- in case called as function
--     if self ~= obj then self = obj end
--
--     return self
-- end

function addMenu = function(self, name)
    -- in case called as function
    if self ~= obj then self, name = obj, self end
    name = tostring(name)

    if not _internals._menus[name] then
        local tmp = {
            _name    = name,
            _visible = false
        }
        tmp._tableAddress = tostring(tmp):match(" (.*)$")

        _internals._menus[name] = setmetatable(tmp, _menu_mt)
        return _internals._menus[name]
    else
        return error("menu with that name already exists", 2)
    end
end

function deleteMenu = function(self, name)
    -- in case called as function
    if self ~= obj then self, name = obj, self end
    local menu = _internals._menus[name]
    if menu then
        return menu:delete()
    else
        return error("no menu with that name exists", 2)
    end
end

function getMenu = function(self, name)
    -- in case called as function
    if self ~= obj then self, name = obj, self end
    return _internals._menus[name]
end

function getMenuNamesList = function(self)
    -- in case called as function
    if self ~= obj then self = obj end
    local tmp = {}
    for k,_ in pairs(_internals._menus) do table.insert(tmp, k) end
    table.sort(tmp)
    return setmetatable(tmp, { __tostring = inspect })
end

function showMenu = function(self, name)
    -- in case called as function
    if self ~= obj then self, name = obj, self end
    local menu = _internals._menus[name]
    if menu then
        return menu:show()
    else
        return error("no menu with that name exists", 2)
    end
end

function hideMenu = function(self, name)
    -- in case called as function
    if self ~= obj then self, name = obj, self end
    local menu = _internals._menus[name]
    if menu then
        return menu:hide()
    else
        return error("no menu with that name exists", 2)
    end
end


--- MenuOfFiles:start() -> self
--- Method
--- Starts the processing or displays for the MenuOfFiles spoon
---
--- Parameters:
---  * None
---
--- Returns:
---  * the MenuOfFiles spoon object
obj.start = function(self)
    -- in case called as function
    if self ~= obj then self = obj end
    for _,v in pairs(_internals._menus) do
        if v._visible then
            v:show()
        end
    end
    return self
end

--- MenuOfFiles:stop() -> self
--- Method
--- Stops the processing and/or removes the displays generated by the MenuOfFiles spoon
---
--- Parameters:
---  * None
---
--- Returns:
---  * the MenuOfFiles spoon object
obj.stop = function(self)
    -- in case called as function
    if self ~= obj then self = obj end
    for _,v in pairs(_internals._menus) do
        if v._visible then
            v:hide(true)
        end
    end
    return self
end

--- MenuOfFiles:bindHotkeys(mapping) -> self
--- Method
--- Binds hotkeys for the MenuOfFiles spoon
---
--- Parameters:
---  * `mapping` - A table containing hotkey modifier/key details for one or more of the following commands:
---    * "start"  - start monitoring the defined corners
---    * "stop"   - stop monitoring the defined corners
---
--- Returns:
---  * the MenuOfFiles spoon object
---
--- Notes:
---  * the `mapping` table is a table of one or more key-value pairs of the format `command = { { modifiers }, key }` where:
---    * `command`   - is one of the commands listed above
---    * `modifiers` - is a table containing keyboard modifiers, as specified in `hs.hotkey.bind()`
---    * `key`       - is a string containing the name of a keyboard key, as specified in `hs.hotkey.bind()`
obj.bindHotkeys = function(self, mapping)
    -- in case called as function
    if self ~= obj then self, mapping = obj, self end

    local def = {
        start  = obj.start,
        stop   = obj.stop,
    }
    spoons.bindHotkeysToSpec(def, mapping)

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

    -- I find it's easier to validate variables once as they're being set then to have to add
    -- a bunch of code everywhere else to verify that the variable was set to a valid/useful
    -- value each and every time I want to use it. Plus the user sees an error immediately
    -- rather then some obscure sort of halfway working until some special combination of things
    -- occurs... (ok, ok, it only reduces those situations but doesn't eliminate them entirely...)

    __index = function(self, key)
        -- variables stored in _internals that start with an underscore are considered private
        if not tostring(key):match("^_") then
            return _internals[key]
        else
            return nil
        end
    end,

    -- handle variable validation here so we don't need to within each method that uses them
    __newindex = function(self, key, value)
        local errMsg = nil
--        if key == "some_config_param" then
--            if type(value) == "boolean" then
--                _internals.some_config_param = value
--            else
--                errMsg = "some_config_param must be a boolean")
--            end
--        elseif key == "... parameter 2 ..." then
--
--        else
            errMsg = tostring(key) .. " is not a recognized paramter of " .. obj.name
--        end

        if errMsg then error(errMsg, 2) end
    end
})
