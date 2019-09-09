--- === BonjourLauncher ===
---
--- List advertised services on your network that match defined templates and provide a list for the user to access them.

-- TODO:
--   start/stop service detection, resolve, and monitor when chooser show/hide rather then stop/start to minimize impact on system
--   document
--   other templates?

local logger  = require("hs.logger")
local spoons  = require("hs.spoons")
local bonjour = require("hs.bonjour")
local chooser = require("hs.chooser")
local fnutils = require("hs.fnutils")
local image   = require("hs.image")
local toolbar = require("hs.webview.toolbar")
local inspect = require("hs.inspect")

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

local finspect = function(...)
    local tmp = table.pack(...)
    tmp.n = nil -- get rid of counter
    if #tmp == 1 and type(tmp[1]) == "table" then tmp = tmp[1] end
    return inspect(tmp, { newline = " ", indent = "" })
end

local fillPlaceholders = function(svc, str)
    local result
    if str then
        result = str
        for tag in str:gmatch("%%([%w_:]+)%%") do
            if tag == "hostname" then   ans = tostring(svc:hostname())
            elseif tag == "domain" then ans = tostring(svc:domain())
            elseif tag == "port" then   ans = tostring(svc:port())
            elseif tag == "name" then   ans = tostring(svc:name())
            elseif tag == "txt" then
                ans = finspect(svc:txtRecord())
            elseif tag:match("^txt:") then
                local key = tag:match(":([%w_]+)$")
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
    ch:refreshChoicesCallback()
end

local showChooserCallback = function()
    if _toolbar then _toolbar:delete() end -- recreate it because obj.template may have changed
    _toolbar = toolbar.new(obj.name .. "_toolbar"):setCallback(chooserToolbarCallback)
    _chooser:attachedToolbar(_toolbar)

    local items = {}
    for k,v in ipairs(obj.templates) do
        table.insert(items, {
            id         = v.type,
            image      = v.image or nil,
            label      = v.label or v.type,
            selectable = true,
        })
    end
    local tbItems = _toolbar:allowedItems()
    for i,v in ipairs(items) do
        if fnutils.contains(tbItems, v.id) then
            _toolbar:modifyItem(v)
        else
            _toolbar:addItems(v)
        end
        _toolbar:insertItem(v.id, i)
    end
    chooserToolbarCallback(_toolbar, _chooser, _currentlySelected)
end

local updateChooserChoices = function()
    local choices = {}
    if not _currentlySelected then _currentlySelected = obj.templates[1].type end
    table.sort(_services[_currentlySelected], function(a,b) return a:name() < b:name() end)
    local template = fnutils.find(obj.templates, function(x) return x.type == _currentlySelected end)
    for k,v in pairs(_services[_currentlySelected]) do
        table.insert(choices, {
            text    = fillPlaceholders(v, template.text or "%name%"),
            subText = fillPlaceholders(v, template.subText),
            type    = _currentlySelected,
            name    = v:name(),
            url     = fillPlaceholders(v, template.url),
            cmd     = fillPlaceholders(v, template.cmd),
            fn      = template.fn and true or false,
        })
    end
    return choices
end

local chooserCompletionCallback = function(choice)
    if not (choice and next(choice)) then return end

    if choice.url then
        _log.f("open %s", choice.url)
        hs.execute("open " .. choice.url)
    elseif choice.cmd then
        _log.f([[hs.execute("%s")]], choice.cmd)
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
        if svc and fn then fn(svc) end
    else
        _log.wf("no valid action for '%s'", finspect(choice))
    end
end

local bonjourTextRecordMonitorCallback = function(svc, msg, ...)
    if msg == "txtRecord" then
        if _chooser and svc:type() == _currentlySelected then _chooser:refreshChoicesCallback() end
    elseif msg == "error" then
        _log.ef("error for service txtRecord monitoring callback: %s", table.pack(...)[1])
    else
        _log.wf("unrecognized message '%s' for service txtRecord monitoring callback: '%s'", msg, finspect(...))
    end
end

local bonjourServiceResolveCallback = function(svc, msg, ...)
    if msg == "resolved" then
        svc:stop()
        if _chooser and svc:type() == _currentlySelected then _chooser:refreshChoicesCallback() end
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
        if _chooser and svcType == _currentlySelected then _chooser:refreshChoicesCallback() end
    elseif msg == "error" then
        _log.ef("error for find services callback: %s", table.pack(...)[1])
    else
        _log.wf("unrecognized message '%s' for find services callback: %s", msg, finspect(...))
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
--- Start
---
--- Parameters:
---  * None
---
--- Returns:
---  * the BonjourLauncher spoon object
obj.start = function(self)
    -- in case called as function
    if self ~= obj then self = obj end

    if not _chooser then
        _chooser = chooser.new(chooserCompletionCallback)
                          :choices(updateChooserChoices)
                          :showCallback(showChooserCallback)
    end
    local seen = {}
    for i, v in ipairs(obj.templates) do
        table.insert(seen, v.type)
        if not _browsers[v.type] then
            _browsers[v.type] = bonjour.new():findServices(v.type, bonjourFindServicesCallback)
            _services[v.type] = {}
        end
    end
    for k, v in pairs(_browsers) do
        if not fnutils.contains(seen, k) then
            _browsers[k]:stop()
            _browsers[k] = nil
            for i,v2 in ipairs(_services[k]) do
                v2:stop():stopMonitoring()
            end
            _services[k] = nil
        end
    end
    return self
end

obj.restart = obj.start

--- BonjourLauncher:stop() -> self
--- Method
--- Stop
---
--- Parameters:
---  * None
---
--- Returns:
---  * the BonjourLauncher spoon object
obj.stop = function(self)
    -- in case called as function
    if self ~= obj then self = obj end

    if _toolbar then
        _toolbar:delete()
        _toolbar = nil
    end
    if _chooser then
        _chooser:delete()
        _chooser = nil
    end
    for k, v in pairs(_browsers) do
        _browsers[k]:stop()
        _browsers[k] = nil
        for i,v2 in ipairs(_services[k]) do
            v2:stop()
            v2:stopMonitoring()
        end
        _services[k] = nil
    end

    return self
end


--- BonjourLauncher:show() -> self
--- Method
--- Show
---
--- Parameters:
---  * None
---
--- Returns:
---  * the BonjourLauncher spoon object
obj.show = function(self)
    -- in case called as function
    if self ~= obj then self = obj end

    if _chooser then _chooser:show() end

    return self
end

--- BonjourLauncher:hide() -> self
--- Method
--- Hide
---
--- Parameters:
---  * None
---
--- Returns:
---  * the BonjourLauncher spoon object
obj.hide = function(self)
    -- in case called as function
    if self ~= obj then self = obj end

    if _chooser then _chooser:hide() end

    return self
end

--- BonjourLauncher:toggle() -> self
--- Method
--- Toggle
---
--- Parameters:
---  * None
---
--- Returns:
---  * the BonjourLauncher spoon object
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
---    * "start"  -
---    * "stop"   -
---    * "show"   -
---    * "hide"   -
---    * "toggle" -
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
        start  = self.start,
        stop   = self.stop,
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
            }
        end
    end,
})
