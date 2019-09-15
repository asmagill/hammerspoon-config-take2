--- === BonjourLauncher ===
---
--- List advertised services on your network that match defined templates and provide a list for the user to access them.

-- TODO:
-- * start/stop service detection, resolve, and monitor when chooser show/hide rather then stop/start
-- * document
-- * filter login in templates to exclude certain advertisements? add filter function seems easiest...
-- *    filter = function(svc) return true/false end, to include/exclude
-- * wrapper for templates variable so you can see current settings via tostring?
--
-- * add `disabled` field to templates?
-- * add `hidden` field to templates to create lists which aren't in toolbar by default (but are still enabled)?
-- *   make note in documentation that this may be ignored if they have customized the toolbar
--
-- * add `type` arg to `:show` which pulls up/switches to specified type, even if it's currently hiddem?
-- * add `show/toggle_xxx_xxx` psuedo function to bindKeys for assigning way to move chooser to specific page automatically?
--
-- * document psuedo mappings
-- * document hidden and disabled keys
--
-- * add variables to adjust chooser display mode/colors/etc?
--   variable for allow customization?
--   allow toolbar spacer items in templates? if so, maybe remove customization?
--
-- * reorder actions in template: `fn`, then `url` then `cmd`
-- *    if `fn` then invoke with fn(svc, chooserRecord) so `fn` can determine if it should use
-- *        `cmd` or `url` or do its own thing based on txtRecords, etc.
--
-- * put entire template entry into chooser record? that way user fields get passed in as well
-- *     do field substitution on all (user) records of type string (other than type and label)?
-- *     add to `filter` fn as well?
--
--   hotkeys to move left/right in toolbar?
--
-- - other templates?
--   * vnc (_rfb._tcp.)
--
--   rewrite companion spoon BonjourBrowser for discovery/investigation
--      current approach is buggy/incomplete/inefficient... in a word, ugly
--      add method to export table ready for adding to templates based on selection?

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

---------- Local Functions And Variables ----------

local _chooser
local _toolbar
local _currentlySelected
local _browsers = {}
local _services = {}
local _hotkey
local _tooltip

-- figure out default rows and width so setting the spoon variable to nil will reset it
_chooser = chooser.new(function() end)
local _defaultRows  = _chooser:rows()
local _defaultWidth = _chooser:width()
_chooser:delete()
_chooser = nil

local finspect = function(...)
    local tmp = table.pack(...)
    tmp.n = nil -- get rid of counter
    if #tmp == 1 and type(tmp[1]) == "table" then tmp = tmp[1] end
    return inspect(tmp, { newline = " ", indent = "" })
end

local clearToolTipAndHotKey = function()
    if _hotkey then
        _hotkey:disable()
        _hotkey = nil
    end
    if _tooltip then
        _tooltip:delete()
        _tooltip = nil
    end
end

local stopAndClearBonjourQueries = function()
    clearToolTipAndHotKey()
    for k, v in pairs(_browsers) do
        _browsers[k]:stop()
        _browsers[k] = nil
        for i,v2 in ipairs(_services[k]) do
            v2:stop()
            v2:stopMonitoring()
        end
        _services[k] = nil
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
    clearToolTipAndHotKey()
    _currentlySelected = id
    tb:selectedItem(_currentlySelected)
    validateCurrentlySelected()
    ch:refreshChoicesCallback(true)
end

local showChooserCallback = function()
    local items = {}
    for i,v in ipairs(obj.templates) do
        if not v.disabled then
            if v.type and (v.url or v.cmd or v.fn) then
                table.insert(items, {
                    id         = v.type,
                    image      = v.image or nil,
                    label      = v.label or v.type,
                    selectable = true,
                    tooltip    = v.type,
                    default    = not v.hidden,
                })
            else
                _log.wf("template entry at index %d requires a `type` key and one of `url`, `cmd`, or `fn` -- skipping", i)
            end
        end
    end

    if _toolbar then _toolbar:delete() end -- templates may have changed and this is easier then checking
                                           -- against existing and adding/removing changes
    _toolbar = toolbar.new(obj.name .. "_toolbar", items):setCallback(chooserToolbarCallback)
                                                         :canCustomize(true)
                                                         :autosaves(true)
   _chooser:attachedToolbar(obj.displayToolbar and _toolbar or nil)

    chooserToolbarCallback(_toolbar, _chooser, _currentlySelected)
end

local updateChooserChoices = function()
    validateCurrentlySelected()

    local choices = {}
    table.sort(_services[_currentlySelected], function(a,b) return a:name() < b:name() end)
    local template = fnutils.find(obj.templates, function(x) return x.type == _currentlySelected end)

    _chooser:fgColor(template.textColor or obj.textColor or { list = "System", name = "secondaryLabelColor" })
            :subTextColor(template.subTextColor or obj.subTextColor or { list = "System", name = "tertiaryLabelColor" })

    for k,v in pairs(_services[_currentlySelected]) do
        local entry = {}
        entry.type    = _currentlySelected
        entry.fn      = template.fn and true or false
        entry._name_  = v:name()
        entry._txt_   = v:txtRecord()

        for k2, v2 in pairs(template) do
            if (k2 ~= "type" and not k2:match("^_%w+_$")) and type(v2) == "string" then
                entry[k2] = fillPlaceholders(v, v2)
            end
        end
        if not entry.text then entry.text = fillPlaceholders(v, "%name%") end

        if not template.filter or (template.filter and template.filter(v, entry)) then
            table.insert(choices, entry)
        end
    end
    return choices
end

local chooserCompletionCallback = function(choice)
    if choice and next(choice) then
        if choice.fn then
            local svc, fn
            for i,v in ipairs(_services[choice.type]) do
                if v:name() == choice._name_ then
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
                _log.vf("invoking function for %s", svc:name())
                fn(svc, choice)
            else
                _log.wf("unable to resolve either svc or fn for %s", finspect(choice))
            end
        elseif choice.url then
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
        else
            _log.wf("no valid action for '%s'", finspect(choice))
        end
    end
    stopAndClearBonjourQueries()
end

local chooserRightClickCallback = function(row)
    if row > 0 then
        local details = _chooser:selectedRowContents(row)
        if next(details) then
            clearToolTipAndHotKey()
            local pos    = mouse.getAbsolutePosition()
            local output = inspect(details._txt_)
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
            _hotkey = hotkey.bind({}, "escape", nil, clearToolTipAndHotKey)
        end
    end
end

---------- Spoon Variables ----------

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
---    * `type`         - a required string specifying the type of advertisement to search for with this entry. Example service types can be seen in `hs.bonjour.serviceTypes`.
---    * `label`        - an optional string, defaulting to the value for `type`, specifying the label for the toolbar item under which these advertised services are collected in the BonjourLauncher chooser window. May or may not be displayed if you have customeized the toolbar's visual properties.
---    * `image`        - an optional `hs.image` object specifying the image to display for the toolbar item under which these advertised services are collected in the BonjourLauncher chooser window. May or may not be displayed if you have customeized the toolbar's visual properties.
---
---    * `text`         - an optional string, defaulting to "%name%", specifying the text to be displayed for each advertised service listed in this collection in the BonjourLauncher chooser window.
---    * `subText`      - an optional string, specifying the sub-text to be displayed for each advertised service listed in this collection in the BonjourLauncher chooser window.
---    * `filter`       - an optional function which can be used to filter out advertised services which you do not wish to include in the chooser window. The function should expect two parameters, the `hs.bonjour.service` object for the discovered service and a table containing all of the key-value pairs of the service template with values expanded to describe what is known about this specific service. The filter function should return `true` if the service is to be included or `false` if the service is to be omitted.
---
---    * `fn`           - The function to invoke. This function should expect two arguments, the `hs.bonjour.service` object for the selected service and a table containing all of the key-value pairs of the service template with values expanded to describe what is known about this specific service. Any return value for the function is ignored. If this is present, `url` and `cmd` will be ignored by the default handler, though they may be accessed through the second argument to the function.
---    * `url`          - The url to open with `hs.urlevent.openURL`. If this is present, `cmd` is ignored.
---    * `cmd`          - The command to execute with `hs.execute`.
---
---    * `hidden`       - an optional boolean, default false, that can be used to specify that the service list should not be displayed in the toolbar by default. You can still access these service types by specifying them as arguments to the [BonjourLauncher:show](#show) or [BonjourLauncher:toggle](#toggle) methods, or by creating a psuedo-key for the service type with [BonjourLauncher:bindHotkeys](#bindHotkeys). If the user customizes the toolbar by right-clicking on it, they can add this service to the toolbar, but it won't be in the default list.
---    * `disabled`      - an optional boolean, default false, specifying that this service should be skipped entirely is not available for viewing by any means.
---
---    * `textColor`    - an optional color table as defined in the `hs.drawing.color` module documentation to be used for the text displayed for each discovered service when this template is being displayed in the BonjourLauncher chooser. If not present, the color specified for [BonjourLauncher.textColor](#textColor) will be used.
---    * `subTextColor` - an optional color table as defined in the `hs.drawing.color` module documentation to be used for the sub-text displayed for each discovered service when this template is being displayed in the BonjourLauncher chooser. If not present, the color specified for [BonjourLauncher.subTextColor](#subTextColor) will be used.
---
---    * Additional key-value pairs do not have special meaning for this spoon but kay-value pairs with a string for the value will be included in the second argument passwd to `fn`, if present.
---
---  * Note that only `type` and one of `url`, `cmd`, or `fn` must be provided -- everything else is optional.
---
---  * For all keys, except for `type` and `label`, in the template definition which have string values, the following substring patterns will be matched and replaced as described below:
---    * `%address%`   - Will be replaced with the first address discovered for the service when it is resolved.
---      * `%address4%` - Variant of `%address%` which is replaced with the first IPv4 address or "n/a" if one cannot be found.
---      * `%address6%` - Variant of `%address%` which is replaced with the first IPv6 address or "n/a" if one cannot be found.
---    * `%domain%`    - Will be replaced with the domain the service was found in, usually "local."
---    * `%hostname%`  - Will be replaced with the hostname on which the service is being offered
---    * `%name%`      - Will be replaced with the name of the advertised service.
---    * `%port%`      - Will be replaced with the port number on the machine that the service is provided on.
---    * `%txt:<key>%` - Will be replaced with the value for the specified `<key>` of the text records associated with the service, or an empty string if no such key is present. To see the list of text record key-value pairs for a specific service, you can right click on it while it is being displayed in the BonjourLauncher chooser window (press the `escape` key to clear it).
obj.templates = setmetatable({}, {
    _templates = {},
    __index    = function(self, key) return getmetatable(self)._templates[key] end,
    __len      = function(self) return #getmetatable(self)._templates end,
    __tostring = function(self) return inspect(getmetatable(self)._templates) end,
    __newindex = function(self, key, value)
        local _templates = getmetatable(self)._templates
        if math.type(key) ~= "integer" then
            error(string.format("%s.templates: invalid index; expectd integer", obj.name))
        end
        if key < 1 or key > (#_templates + 1) then
            error(string.format("%s.templates: index out of range; expected index between 1 and %d inclusive", obj.name, #_templates + 1))
        end
        local valueGood = (type(value) == "nil" and key >= #_templates) or (type(value) == "table")
        if valueGood then
            _templates[key] = value
        elseif type(value) == "nil" then
            error(string.format("%s.templates: value of nil only assignable to end of templates array; use table.remove to clear other entries", obj.name))
        else --if type(value) ~= "table" then
            error(string.format("%s.templates: value must be a table or nil", obj.name))
        end
    end,
    __pairs    = function(self)
        local _templates = getmetatable(self)._templates
        return function(_, k)
            local v
            k, v = next(_templates, k)
            return k, v
        end, self, nil
    end,
})

obj.templates[#obj.templates + 1] = {
    image   = image.imageFromAppBundle("com.apple.Safari"),
    label   = "HTTP",
    type    = "_http._tcp.",
    text    = "%name%",
    subText = "http://%hostname%:%port%/%txt:path%",
    url     = "http://%hostname%:%port%/%txt:path%",
--     cmd     = "string passed to os.execute",
--     fn      = function(svcObj) end,
}

obj.templates[#obj.templates + 1] = {
    image   = image.imageFromAppBundle("com.apple.Terminal"), -- optional
    label   = "SSH",                                          -- optional
    type    = "_ssh._tcp.",                                   -- required
    text    = "%name%",                                       -- optional, defaults to "%name%"
    subText = "%hostname%:%port% (%address4%/%address6%)",    -- optional
    hidden  = true,
    url     = "ssh://%hostname%:%port%",                      -- only one of url, cmd, fn required
--     cmd     = "string passed to os.execute",
--     fn      = function(svcObj) end,
}

obj.templates[#obj.templates + 1] = {
    image   = image.imageFromName("NSNetwork"),
    label   = "SMB",
    type    = "_smb._tcp.",
    text    = "%name%",
    subText = "smb://%hostname%:%port%",
    hidden  = true,
    url     = "smb://%hostname%:%port%",
--     cmd     = "string passed to os.execute",
--     fn      = function(svcObj) end,
}


obj.templates[#obj.templates + 1] = {
    image   = canvas.new{ h = 128, w = 128 }:appendElements(
                              { type="image", image = image.imageFromName("NSNetwork") },
                              { type="image", image = image.imageFromName("NSTouchBarColorPickerFont") }
              ):imageFromCanvas(),
    label   = "AFP",
    type    = "_afpovertcp._tcp.",
    text    = "%name%",
    subText = "afp://%hostname%:%port%",
    hidden  = true,
    url     = "afp://%hostname%:%port%",
--     cmd     = "string passed to os.execute",
--     fn      = function(svcObj) end,
}

-- Raspberry PI machines running Raspbian linux have RealVNC server installed to
-- provide remote access to the desktop, but this uses an encryption scheme not
-- understood by Apples Screen Sharing app. To allow us to programtically determine
-- when to use the RealVNC viewer instead of the default, you will need to create the
-- file /etc/avahi/services/vnc.service on the Raspberry Pi with the following contents:
--
--     <?xml version="1.0" standalone='no'?>
--     <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
--     <service-group>
--       <name replace-wildcards="yes">%h</name>
--       <service>
--         <type>_rfb._tcp</type>
--         <port>5900</port>
--         <txt-record>RealVNC=True</txt-record>
--       </service>
--     </service-group>
--
obj.templates[#obj.templates + 1] = {
    image   = image.imageFromAppBundle("com.apple.ScreenSharing"),
    label   = "VNC",
    type    = "_rfb._tcp.",
    text    = "%name%",
    subText = "vnc://%hostname%:%port%",
    hidden  = true,
    url     = "vnc://%hostname%:%port%", -- used in fn when RealVNC not set ; see below
    cmd     = "open -a \"VNC Viewer\" --args %hostname%:%port%", -- used in fn when RealVNC set; see below
    fn      = function(svc, choice)
        local tr = svc:txtRecord()
        if tr and tr.RealVNC then
            hs.execute(choice.cmd)
        else
            urlevent.openURL(choice.url)
        end
    end,
}

-- spoon vars, except for templates, are stored here so we can validate and implement them immediately upon change with the modules __newindex matamethod (see end of file)

local _internals = {}

--- BonjourLauncher.displayToolbar
--- Variable
--- Whether or not to display a toolbar at the top of the BonjourLauncher chooser window. Defaults to true.
---
--- This boolean variable determines if the toolbar which allows changing the currently visible service type is displayed when the BonjourLauncher chooser window is presented. If you set this to `false` then you will only be able to change the currently visible services with the [BonjourLauncher:show(serviceType)](#show) and [BonjourLauncher:toggle(serviceType)](#toggle) methods.
_internals.displayToolbar = true

--- BonjourLauncher.rows
--- Variable
--- The number of rows to display when the chooser is visible. Defaults to 10.
---
--- Set this variable to an integer to specify the number of rows of choices to display when the BonjourLauncher chooser window is visible. Set it to `nil` to revert to the default.
_internals.rows = _defaultRows

--- BonjourLauncher.width
--- Variable
--- The width of the BonjourLauncher chooser window as a percentage of the screen size. Defaults to 40.
---
--- Set this variable to a numeric value between 1 and 100 to specify the percentage of screen the screen's width the BonjourLauncher window should occupy when visible. Set it to `nil` to revert to the default.
_internals.width = _defaultWidth

--- BonjourLauncher.textColor
--- Variable
--- Sets the color of the primary text for each service listed in the BonjourLauncher chooser window. Defaults to nil.
---
--- This should be a table representing a color as defined by the `hs.drawing.color` module documentation, or nil to revert to the `hs.chooser` module default.
---
--- You can override this on a per template basis by including the `textColor` field in the service type definition. See [BonjourLauncher.templates](#templates).
_internals.textColor = nil

--- BonjourLauncher.subTextColor
--- Variable
--- Sets the color of the subText for each service listed in the BonjourLauncher chooser window. Defaults to nil.
---
--- This should be a table representing a color as defined by the `hs.drawing.color` module documentation, or nil to revert to the `hs.chooser` module default.
---
--- You can override this on a per template basis by including the `subTextColor` field in the service type definition. See [BonjourLauncher.templates](#templates).
_internals.subTextColor = nil

--- BonjourLauncher.darkMode
--- Variable
--- Set whether the BonjourLauncher chooser window should apoear dark themed, aqua themed (light) or track the current system settings for Dark mode. Defaults to nil.
---
--- This should be a boolean specifying whether the BonjourLauncher chooser window should appear in dark mode (true) or not (false). If set to `nil`, the chooser will track the current system settings for Dark mode.
_internals.darkMode = nil

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
                          :placeholderText("type here to filter results")
                          :rows(_internals.rows + (_internals.displayToolbar and 2 or 0))
                          :width(_internals.width)
                          :bgDark(_internals.darkMode)
                          :fgColor(_internals.textColor or { list = "System", name = "secondaryLabelColor" })
                          :subTextColor(_internals.subTextColor or { list = "System", name = "tertiaryLabelColor" })
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

--- BonjourLauncher:show([serviceType]) -> self
--- Method
--- Shows the BonjourLauncher chooser window and begins queries for the currently selected service type.
---
--- Parameters:
---  * `serviceType` - an optional string specifying the service type to show in the chooser window. Defaults to the last selected service type previously viewed or the first one defined in [BonjourLauncher.templates](#templates) if this is the first invocation.
---
--- Returns:
---  * the BonjourLauncher spoon object
---
--- Notes:
---  * Automatically invokes [BonjourLauncher:start()](#start) if this has not already been done.
---
---  * Service queries are grouped by type and the currently visible items can be selected by clicking on the type icon or label in the chooser toolbar.
obj.show = function(self, st)
    -- in case called as function
    if self ~= obj then self, st = obj, self end

    if not _chooser then
        self:start()
    end

    if st then
        st = tostring(st)
        local found = false
        for i,v in ipairs(obj.templates) do
            if not v.disabled and v.type == st then
                _currentlySelected = st
                found = true
                break
            end
        end
        if not found then
            _log.wf([[%s:start("%s") - type specification not found; ignoring]], obj.name, st)
        end
    end

    if _chooser:isVisible() then
        chooserToolbarCallback(_toolbar, _chooser, _currentlySelected)
    else
        _chooser:show()
    end

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

--- BonjourLauncher:toggle([serviceType]) -> self
--- Method
--- Toggles the visibility of the BonjourLauncher chooser window.
---
--- Parameters:
---  * `serviceType` - an optional string specifying the service type to show or switch to in the chooser window, if the window is already open and the service type currently on display differs.
---
--- Returns:
---  * the BonjourLauncher spoon object
---
--- Notes::
---  * If the chooser window is currently visible, this method will invoke [BonjourLauncher:hide](#hide); otherwise invokes [BonjourLauncher:show](#show).
obj.toggle = function(self, st)
    -- in case called as function
    if self ~= obj then self, st = obj, self end

    if _chooser and _chooser:isVisible() then
        if st and tostring(st) ~= _currentlySelected then
            self:show(st)
        else
            self:hide()
        end
    else
        self:show(st)
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
---
---  * Psuedo keys for `show` and `toggle` are also supported which can be used to generate hotkeys which will take you to a specific list of services when the BonjourLauncher chooser is displayed. The format of these psuedo keys is "<function><serviceType>"; for example:
---
---         BonjourLauncher:bindHotkeys({
---             -- create a general toggle hotkey
---             "toggle" = { { "cmd", "ctrl", "alt"}, "=" },
---             -- create a hotkey which will open the chooser to the SSH display, or
---             -- change to it if another service type is currently being viewed. If the
---             -- SSH display is currently being viewed, closes the chooser window (i.e.
---             -- "toggle")
---             ["toggle_ssh._tcp."] = { { "cmd", "ctrl", "alt" }, "s" }
---         })
---
obj.bindHotkeys = function(self, mapping)
    -- in case called as function
    if self ~= obj then self, mapping = obj, self end

    local def = {
        toggle = self.toggle,
        show   = self.show,
        hide   = self.hide,
    }

    for k,v in pairs(mapping) do
        local fn, st = k:match("^(%w+)(_[%w%._]+)$")
        if fn and st then
            if fn == "toggle" then def[k] = function() obj:toggle(st) end end
            if fn == "show" then def[k] = function() obj:show(st) end end
        end
    end

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
                _tooltip           = _tooltip,
                _hotkey            = _hotkey,
            }
        else
            return _internals[key]
        end
    end,
    __newindex = function(self, key, value)
        local errorString = nil
        if key == "displayToolbar" then
            if type(value) == "boolean" or type(value) == "nil" then
                _internals.displayToolbar = value
                if _chooser and _toolbar then
                    _chooser:attachedToolbar(_internals.displayToolbar and _toolbar or nil)
                            :rows(_internals.rows + (_internals.displayToolbar and 2 or 0))
                end
            else errorString = "must be a boolean or nil" end
        elseif key == "rows" then
            if type(value) == "nil" or (math.type(value) == "integer" and value > 0) then
                _internals.rows = value or _defaultRows
                if _chooser then
                    _chooser:rows(_internals.rows + (_internals.displayToolbar and 2 or 0))
                end
            else errorString = "must be an integer > 0" end
        elseif key == "width" then
            if type(value) == "nil" or (type(value) == "number" and value > 0) then
                _internals.width = value or _defaultWidth
                if _chooser then _chooser:width(_internals.width) end
            else errorString = "must be a number > 0.0" end
        elseif key == "textColor" then
            if type(value) == "table" or type(value) == "nil" then
                _internals.textColor = value
                if _chooser then _chooser:fgColor(_internals.textColor or { list = "System", name = "secondaryLabelColor" }) end
            else errorString = "must be a table representing a color (see hs.drawing.color) or nil" end
        elseif key == "subTextColor" then
            if type(value) == "table" or type(value) == "nil" then
                _internals.subTextColor = value
                if _chooser then _chooser:subTextColor(_internals.subTextColor or { list = "System", name = "tertiaryLabelColor" }) end
            else errorString = "must be a table representing a color (see hs.drawing.color) or nil" end
        elseif key == "darkMode" then
            if type(value) == "boolean" or type(value) == "nil" then
                _internals.darkMode = value
                if _chooser then _chooser:bgDark(_internals.darkMode) end
            else errorString = "must be a boolean or nil" end
        else errorString = "is unrecognized" end

        if errorString then error(string.format("%s.%s %s", obj.name, key, errorString)) end
    end,
})