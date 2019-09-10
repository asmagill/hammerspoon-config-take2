--- === BonjourLauncher ===
---
--- List advertised services on your network that match defined templates and provide a list for the user to access them.

-- TODO:
-- * start/stop service detection, resolve, and monitor when chooser show/hide rather then stop/start
-- * document
--   other templates?
-- * filter login in templates to exclude certain advertisements? add filter function seems easiest...
-- *    filter = function(svc) return true/false end, to include/exclude
--   add variables to adjust chooser display mode/colors/etc?

local logger   = require("hs.logger")
local spoons   = require("hs.spoons")
local bonjour  = require("hs.bonjour")
local chooser  = require("hs.chooser")
local fnutils  = require("hs.fnutils")
local image    = require("hs.image")
local toolbar  = require("hs.webview.toolbar")
local inspect  = require("hs.inspect")
local canvas   = require("hs.canvas")
local color    = require("hs.drawing").color
local mouse    = require("hs.mouse")
local hotkey   = require("hs.hotkey")
local urlevent = require("hs.urlevent")

local obj    = {
-- Metadata
    name      = "BonjourLauncher",
    author    = "A-Ron",
    homepage  = "https://github.com/asmagill/hammerspoon-config/tree/master/_Spoons/BonjourLauncher.spoon",
    license   = "MIT - https://opensource.org/licenses/MIT",
    spoonPath = spoons.scriptPath(),
    spoonMeta = "placeholder for _coresetup metadata creation",
}
-- version is outside of obj table definition to facilitate its auto detection by
-- external documentation generation scripts
obj.version   = "0.1"

local metadataKeys = {} ; for k, v in fnutils.sortByKeys(obj) do table.insert(metadataKeys, k) end

local _log = logger.new(obj.name)
obj.logger = _log

obj.__index = obj

---------- Spoon Variables ----------

-- template placeholders for text, subText, url, cmd

-- %address[4|6]?% - the first (IPv4/IPv6) addresses the service resolved to
-- %domain%        - the domain the service belongs to
-- %hostname%      - the hostname advertising the service
-- %name%          - the name of the service
-- %port%          - the port on which the service is provided
-- %txt%           - the text records advertised for the service
-- %txt:<key>%     - the value of the specific key in the text records advertised for the service

--- BonjourLauncher.templates
--- Variable
--- A table specifying the service types which the BonjourLauncher looks for on your network and defines how to display and launch discovered services.
---
--- Notes:
---  * This table should be an array of tables, which each table in the array specifying a service type.
---
---  * Changes to this variable will be reflected the next time the BonjourLauncher chooser window is shown -- if it is currently visible when changes are made, the new changes will *NOT* be reflected in the currently open chooser.
---
---  * Each service type table entry should contain one or more of the following keys:
---    * `type`    - a required string specifying the type of advertisement to search for with this entry. Example service types can be seen in `hs.bonjour.serviceTypes`.
---    * `label`   - an optional string, defaulting to the value for `type`, specifying the label for the toolbar item under which these advertised services are collected in the BonjourLauncher chooser window. May or may not be displayed if you have customeized the toolbar's visual properties.
---    * `image`   - an optional `hs.image` object specifying the image to display for the toolbar item under which these advertised services are collected in the BonjourLauncher chooser window. May or may not be displayed if you have customeized the toolbar's visual properties.
---    * `text`    - an optional string, defaulting to "%name%", specifying the text to be displayed for each advertised service listed in this collection in the BonjourLauncher chooser window.
---    * `subText` - an optional string, specifying the sub-text to be displayed for each advertised service listed in this collection in the BonjourLauncher chooser window.
---    * `filter`  - an optional function which can be used to filter out advertised services which you do not wish to include in this service type collection. The function should accept one parameter, the `hs.bonjour.service` object for the discovered service, and should return `true` if the service is to be included or `false` if the service is to be omitted.
---    * `url`     - The url to open with `hs.urlevent.openURL`. If this is present, `cmd` and `fn` are ignored.
---    * `cmd`     - The command to execute with `hs.execute`. If this is present, `fn` is ignored.
---    * `fn`      - The function to invoke. THis function should expect one argument, the `hs.bonjour.service` object for the selected service. Any return value for the function is ignored.
---
---  * Note that only `type` and one of `url`, `cmd`, or `fn` must be provided -- everything else is optional.
---
---  * If the string values for `text`, `subText`, `url`, and `cmd` contain any of the following substrings, the substring will be replaced as described below:
---    * `%address%`   - Will be replaced with the first address discovered for the service when it is resolved.
---      * `%address4%` - Variant of `%address%` which is replaced with the first IPv4 address or "n/a" if one cannot be found.
---      * `%address6%` - Variant of `%address%` which is replaced with the first IPv6 address or "n/a" if one cannot be found.
---    * `%domain%`    - Will be replaced with the domain the service was found in, usually "local."
---    * `%hostname%`  - Will be replaced with the hostname on which the service is being offered
---    * `%name%`      - Will be replaced with the name of the advertised service.
---    * `%port%`      - Will be replaced with the port number on the machine that the service is provided on.
---    * `%txt:<key>%` - Will be replaced with the value for the specified `<key>` of the text records associated with the service. To see the list of text record key-value pairs for a specific service, you can right click on it while it is being displayed in the BonjourLauncher chooser window (press the `escape` key to clear it).
obj.templates = {
    {
        image   = image.imageFromAppBundle("com.apple.Terminal"), -- optional
        label   = "SSH",                                          -- optional
        type    = "_ssh._tcp.",                                   -- required
        text    = "%name%",                                       -- optional, defaults to "%name%"
        subText = "%hostname%:%port% (%address4%/%address6%)",    -- optional
        url     = "ssh://%hostname%:%port%",                      -- only one of url, cmd, fn required
--         cmd     = "string passed to os.execute",
--         fn      = function(svcObj) end,
    },
    {
        image   = image.imageFromAppBundle("com.apple.Safari"),
        label   = "HTTP",
        type    = "_http._tcp.",
        text    = "%name%",
        subText = "http://%hostname%:%port%/%txt:path%",
        url     = "http://%hostname%:%port%/%txt:path%",
--         cmd     = "string passed to os.execute",
--         fn      = function(svcObj) end,
    },
}

---------- Local Functions ----------

local _chooser
local _toolbar
local _currentlySelected
local _browsers = {}
local _services = {}
local _choicesProvided
local _hotkey
local _tooltip

local finspect = function(...)
    local tmp = table.pack(...)
    tmp.n = nil -- get rid of counter
    if #tmp == 1 and type(tmp[1]) == "table" then tmp = tmp[1] end
    return inspect(tmp, { newline = " ", indent = "" })
end

local stopAndClearBonjourQueries = function()
    for k, v in pairs(_browsers) do
        _browsers[k]:stop()
        _browsers[k] = nil
        for i,v2 in ipairs(_services[k]) do
            v2:stop()
            v2:stopMonitoring()
        end
        _services[k] = nil
    end
    if _hotkey then
        _hotkey:disable()
        _hotkey = nil
    end
    if _tooltip then
        _tooltip:delete()
        _tooltip = nil
    end
end

local bonjourTextRecordMonitorCallback = function(svc, msg, ...)
    if msg == "txtRecord" then
        if _chooser and svc:type() == _currentlySelected then _chooser:refreshChoicesCallback(true) end
    elseif msg == "error" then
        _log.ef("error for service txtRecord monitoring callback: %s", table.pack(...)[1])
    else
        _log.wf("unrecognized message '%s' for service txtRecord monitoring callback: '%s'", msg, finspect(...))
    end
end

local bonjourServiceResolveCallback = function(svc, msg, ...)
    if msg == "resolved" then
--         svc:stop()
        if _chooser and svc:type() == _currentlySelected then _chooser:refreshChoicesCallback(true) end
    elseif msg == "error" then
        _log.ef("error for service resolve callback: %s", table.pack(...)[1])
    else
        _log.wf("unrecognized message '%s' for service resolve callback: '%s'", msg, finspect(...))
    end
end

local bonjourFindServicesCallback = function(b, msg, ...)
    if msg == "service" then
        local state, svc, more = ...
        local foundIdx
        local svcType = svc:type()
        for i,v in ipairs(_services[svcType]) do
            if v == svc then
                foundIdx = i
                break
            end
        end
        if state then
            if not foundIdx then
                table.insert(_services[svcType], svc:resolve(bonjourServiceResolveCallback)
                                                    :monitor(bonjourTextRecordMonitorCallback))
            end
        else
            if foundIdx then
                svc:stop()
                svc:stopMonitoring()
                table.remove(_services[svcType], foundIdx)
            end
        end
        if _chooser and svcType == _currentlySelected then _chooser:refreshChoicesCallback(true) end
    elseif msg == "error" then
        _log.ef("error for find services callback: %s", table.pack(...)[1])
    else
        _log.wf("unrecognized message '%s' for find services callback: %s", msg, finspect(...))
    end
end

local validateCurrentlySelected = function()
    if not _currentlySelected then _currentlySelected = obj.templates[1].type end
    if _toolbar and _currentlySelected ~= _toolbar:selectedItem() then
        _currentlySelected = _toolbar:selectedItem() or obj.templates[1].type
        _toolbar:selectedItem(_currentlySelected)
    end
    if not _browsers[_currentlySelected] then
        _browsers[_currentlySelected] = bonjour.new()
                                               :findServices(_currentlySelected, bonjourFindServicesCallback)
        _services[_currentlySelected] = {}
    end
end

local fillPlaceholders = function(svc, str)
    local result
    if str then
        result = str
        for tag in str:gmatch("%%([%w_: ]+)%%") do
            if tag == "hostname" then   ans = tostring(svc:hostname())
            elseif tag == "domain" then ans = tostring(svc:domain())
            elseif tag == "port" then   ans = tostring(svc:port())
            elseif tag == "name" then   ans = tostring(svc:name())
--             elseif tag == "txt" then
--                 ans = finspect(svc:txtRecord())
            elseif tag:match("^txt:") then
                local key = tag:match(":([%w_ ]+)$")
                if key then
                    ans = (svc:txtRecord() or {})[key] or ""
                else
                    _log.wf("malformed key in tag '%s' found in '%s'", tag, str)
                    ans = "????"
                end
            elseif tag:match("^address[46]?$") then
                local ipv4 = tag:match("4$") and true or false
                local ipv6 = tag:match("6$") and true or false
                ans = "n/a"
                for i,v in ipairs(svc:addresses() or {}) do
                    if ipv4 and v:match("%.") then
                        ans = v
                        break
                    elseif ipv6 and v:match(":") then
                        ans = v
                        break
                    elseif not (ipv6 or ipv4) then
                        ans = v
                        break
                    end
                end
            else
                _log.wf("unrecognized tag '%s' found in '%s'", tag, str)
                ans = "????"
            end
--             print(result, tag, ans)
            ans = ans:gsub("%%", "%%%%")
            result = result:gsub("%%" .. tag .. "%%", ans)
        end
    end
    return result
end

local chooserToolbarCallback = function(tb, ch, id)
    _currentlySelected = id
    tb:selectedItem(_currentlySelected)
    validateCurrentlySelected()
    ch:refreshChoicesCallback(true)
end

local showChooserCallback = function()
    local items = {}
    for i,v in ipairs(obj.templates) do
        if v.type and (v.url or v.cmd or v.fn) then
            table.insert(items, {
                id         = v.type,
                image      = v.image or nil,
                label      = v.label or v.type,
                selectable = true,
                tooltip    = v.type,
            })
        else
            _log.wf("template entry at index %d requires a `type` key and one of `url`, `cmd`, or `fn` -- skipping", i)
        end
    end

    if _toolbar then _toolbar:delete() end -- templates may have changed and this is easier then checking
                                           -- against existing and adding/removing changes
    _toolbar = toolbar.new(obj.name .. "_toolbar", items):setCallback(chooserToolbarCallback)
                                                         :canCustomize(true)
                                                         :autosaves(true)
   _chooser:attachedToolbar(_toolbar)

    chooserToolbarCallback(_toolbar, _chooser, _currentlySelected)
end

local updateChooserChoices = function()
    validateCurrentlySelected()

    local choices = {}
    table.sort(_services[_currentlySelected], function(a,b) return a:name() < b:name() end)
    local template = fnutils.find(obj.templates, function(x) return x.type == _currentlySelected end)
    for k,v in pairs(_services[_currentlySelected]) do
        if not template.filter or (template.filter and template.filter(v)) then
            table.insert(choices, {
                text      = fillPlaceholders(v, template.text or "%name%"),
                subText   = fillPlaceholders(v, template.subText),
                type      = _currentlySelected,
                name      = v:name(),
                txtRecord = v:txtRecord(),
                url       = fillPlaceholders(v, template.url),
                cmd       = fillPlaceholders(v, template.cmd),
                fn        = template.fn and true or false,
            })
        end
    end
    _choicesProvided = choices
    return choices
end

local chooserCompletionCallback = function(choice)
    stopAndClearBonjourQueries()

    if not (choice and next(choice)) then return end

    if choice.url then
        _log.vf([[hs.urlevent.openURL("%s")]], choice.url)
        if not urlevent.openURL(choice.url) then
            _log.wf("unable to open URL '%s'", choice.url)
        end
    elseif choice.cmd then
        _log.vf([[hs.execute("%s")]], choice.cmd)
        local o,s,t,r = hs.execute(choice.cmd)
        if r ~= 0 then
            _log.wf("error executing '%s': rc = %d, exit cause: %s, output = %s", choice.cmd, r, t, o)
        end
    elseif choice.fn then
        local svc, fn
        for i,v in ipairs(_services[choice.type]) do
            if v:name() == choice.name then
                svc = v
                break
            end
        end
        for i,v in ipairs(obj.templates) do
            if v.type == choice.type then
                fn = v.fn
                break
            end
        end
        if svc and fn then
            _log.vf([[fn(%s)]], tostring(svc))
            fn(svc)
        else

        end
    else
        _log.wf("no valid action for '%s'", finspect(choice))
    end
end

local chooserRightClickCallback = function(row)
    if row > 0 then
        local details = _choicesProvided and _choicesProvided[row]
        if details then
            local pos    = mouse.getAbsolutePosition()
            local output = inspect(details.txtRecord)
            _tooltip = canvas.new{ x = pos.x, y = pos.y, h = 100, w = 100 }
            _tooltip[#_tooltip + 1] = {
                type = "rectangle",
                action = "strokeAndFill",
                fillColor = color.x11.yellow,
                strokeColor = color.x11.goldenrod,
            }
            _tooltip[#_tooltip + 1] = {
                type = "text",
                text = output,
                textColor = { alpha = 1 },
            }
            local size   = _tooltip:minimumTextSize(#_tooltip, output)
            _tooltip:size(size):show()
            _hotkey = hotkey.bind({}, "escape", nil, function()
                _hotkey:disable()
                _tooltip:delete()
                _hotkey = nil
                _tooltip = nil
            end)
        end
    end
end

---------- Spoon Methods ----------

-- obj.init = function(self)
--     -- in case called as function
--     if self ~= obj then self = obj end
--
--     return self
-- end

--- BonjourLauncher:start() -> self
--- Method
--- Readys the chooser interface for the BonjourLauncher spoon
---
--- Parameters:
---  * None
---
--- Returns:
---  * the BonjourLauncher spoon object
---
--- Notes:
---  * This method is included to conform to the expected Spoon format; it will automatically be invoked by [BonjourLauncher:show](#show) if it hasn't been already.
obj.start = function(self)
    -- in case called as function
    if self ~= obj then self = obj end

    if not _chooser then
        _chooser = chooser.new(chooserCompletionCallback)
                          :choices(updateChooserChoices)
                          :showCallback(showChooserCallback)
                          :rightClickCallback(chooserRightClickCallback)
    end
    return self
end

--- BonjourLauncher:stop() -> self
--- Method
--- Removes the chooser interface for the NonjourLauncher spoon and any lingering service queries
---
--- Parameters:
---  * None
---
--- Returns:
---  * the BonjourLauncher spoon object
---
--- Notes:
---  * This method is included to conform to the expected Spoon format; in general, it should be unnecessary to invoke this method directly as service queries are cleared any time an item is selected from the chooser winfow or the window closes.
obj.stop = function(self)
    -- in case called as function
    if self ~= obj then self = obj end

    if _chooser then
        self:hide()
        if _toolbar then
            _toolbar:delete()
            _toolbar = nil
        end

        _chooser:delete()
        _chooser = nil
    end

    return self
end


--- BonjourLauncher:show() -> self
--- Method
--- Shows the BonjourLauncher chooser window and begins queries for the currently selected service type.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the BonjourLauncher spoon object
---
--- Notes:
---  * Automatically invokes [BonjourLauncher:start()](#start) if this has not already been done.
---
---  * Service queries are grouped by type and the currently visible items can be selected by clicking on the type icon or label in the chooser toolbar.
obj.show = function(self)
    -- in case called as function
    if self ~= obj then self = obj end

    if not _chooser then
        self:start()
    end

    _chooser:show()

    return self
end

--- BonjourLauncher:hide() -> self
--- Method
--- Hides the BonjourLauncher chooser window and clears any active service queries.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the BonjourLauncher spoon object
obj.hide = function(self)
    -- in case called as function
    if self ~= obj then self = obj end

    if _chooser then
        _chooser:hide()
        stopAndClearBonjourQueries()
    end

    return self
end

--- BonjourLauncher:toggle() -> self
--- Method
--- Toggles the visibility of the BonjourLauncher chooser window.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the BonjourLauncher spoon object
---
--- Botes:
---  * If the chooser window is currently visible, this method will invoke [BonjourLauncher:hide](#hide); otherwise invokes [BonjourLauncher:show](#show).
obj.toggle = function(self)
    -- in case called as function
    if self ~= obj then self = obj end

    if _chooser and _chooser:isVisible() then
        self:hide()
    else
        self:show()
    end

    return self
end

--- BonjourLauncher:bindHotkeys(mapping) -> self
--- Method
--- Binds hotkeys for the BonjourLauncher spoon
---
--- Parameters:
---  * `mapping` - A table containing hotkey modifier/key details for one or more of the following commands:
---    * "show"   - Show the BonjourLauncher chooser window
---    * "hide"   - Hide the BonjourLauncher chooser window
---    * "toggle" - Toggles the visibility of the BonjourLauncher window
---
--- Returns:
---  * the BonjourLauncher spoon object
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
        toggle = self.toggle,
        show   = self.show,
        hide   = self.hide,
    }
    spoons.bindHotkeysToSpec(def, mapping)

    return self
end

return setmetatable(obj, {
    -- cleaner, IMHO, then "table: 0x????????????????"
    __tostring = function(self)
        local result, fieldSize = "", 0
        for i, v in ipairs(metadataKeys) do fieldSize = math.max(fieldSize, #v) end
        for i, v in ipairs(metadataKeys) do
            result = result .. string.format("%-"..tostring(fieldSize) .. "s %s\n", v, self[v])
        end
        return result
    end,
    __index = function(self, key)
        if key == "_debug" then
            return {
                _chooser           = _chooser,
                _toolbar           = _toolbar,
                _currentlySelected = _currentlySelected,
                _browsers          = _browsers,
                _services          = _services,
                _choicesProvided   = _choicesProvided,
                _tooltip           = _tooltip,
                _hotkey            = _hotkey,
            }
        end
    end,
})
