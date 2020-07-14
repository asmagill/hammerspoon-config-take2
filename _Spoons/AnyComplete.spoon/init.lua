--- === AnyComplete ===
---
--- Provides autocomplete functionality anywhere you can type in text.
---
--- Based heavily on Nathan Cahill's code at https://github.com/nathancahill/Anycomplete and some of the enhancement requests.

-- TODO:
--   look up Google and DDG's Terms of Service for this API and see what the query limits should be

local logger      = require("hs.logger")
local spoons      = require("hs.spoons")
local application = require("hs.application")
local chooser     = require("hs.chooser")
local http        = require("hs.http")
local hotkey      = require("hs.hotkey")
local eventtap    = require("hs.eventtap")
local pasteboard  = require("hs.pasteboard")
local alert       = require("hs.alert")
local json        = require("hs.json")
local fnutils     = require("hs.fnutils")
local canvas      = require("hs.canvas")
local inspect     = require("hs.inspect")
local timer       = require("hs.timer")

-- not in core yet, so conditionally load it
local axuielement = package.searchpath("hs.axuielement", package.path) and require("hs.axuielement")

local obj    = {
-- Metadata
    name      = "AnyComplete",
    author    = "A-Ron / Nathan Cahill",
    homepage  = "https://github.com/Hammerspoon/Spoons",
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

-- spoon vars are stored in _internals so we can validate them immediately upon change with the modules __newindex matamethod (see end of file) rather than get a delayed error because the value is the wrong type

local _internals = {}

local _chooser
local _canvas
local _currentApp
local _hotkeys           = {}
local _lastKeypressTimer
local _currentChoices    = {}

local updateChooserChoices = function(choices)
    _currentChoices = choices
    _chooser:choices(_currentChoices)
end

local chooserCallback = function(choice)
    if choice then
        _chooser:query("")
        updateChooserChoices({})
        if eventtap.checkKeyboardModifiers().shift then
            -- holding shift as they choose so load in search page instead
            local queryString = http.encodeForQuery(choice.text)
            local queryURL = _internals.queryDefinitions[_internals.querySite].searchQuery
            hs.execute([[open "]] .. string.format(queryURL, queryString) .. [["]])
        else
            if _currentApp then _currentApp:activate() end
            eventtap.keyStrokes(choice.text)
        end
    end
end

local updateChooser = function()
    local queryString = _chooser:query()

    if #queryString == 0 then
        updateChooserChoices({})
    else
        queryString = http.encodeForQuery(queryString)
        local queryURL = _internals.queryDefinitions[_internals.querySite].acQuery
        http.asyncGet(string.format(queryURL, queryString), nil, function(s, b, h)
            if s == 200 then
                if b then
                    local newChoices = _internals.queryDefinitions[_internals.querySite].acParser(b)
                    if newChoices then
                        updateChooserChoices(newChoices)
                    end
                end
            else
                _log.wf("http response code %d; headers: %s; content: %s", s, inspect(h), tostring(b))
            end
        end)
    end
end

local queryChangedCallback = function()
    if _internals.queryDebounce == 0 then
        updateChooser()
    else
        local currentTime = timer.secondsSinceEpoch()
        if _lastKeypressTimer then _lastKeypressTimer:stop() end
        _lastKeypressTimer = timer.doAfter(_internals.queryDebounce, function()
            _lastKeypressTimer = nil
            updateChooser()
        end)
    end
end

local showCallback = function()
    -- not in core yet, so skip canvas frame with title if we can't get the frame with axuielement
    if axuielement then
        -- it seems if the chooser is double triggered, it never calls the callback or hide for the initial one
        if _canvas then
            _canvas:delete()
            _canvas = nil
        end
        local _hammerspoon = axuielement.applicationElementForPID(hs.processInfo.processID)
        for i,v in ipairs(_hammerspoon) do
            if v.AXTitle == "Chooser" then
                -- because of window shadow for chooser, can't perfectly match up lines, so draw canvas
                -- slightly larger and make it look like the chooser is part of the canvas
                local chooserFrame = v.AXFrame
                _canvas = canvas.new{
                    x = chooserFrame.x - 5,
                    y = chooserFrame.y - 22,
                    h = chooserFrame.h + 27,
                    w = chooserFrame.w + 10
                }:show():level(canvas.windowLevels.mainMenu + 3):orderBelow()
                _canvas[#_canvas + 1] = {
                    type        = "rectangle",
                    action      = "strokeAndFill",
                    strokeColor = { list = "System", name = "controlBackgroundColor" },
                    strokeWidth = 1.5,
                    fillColor   = { list = "System", name = "windowBackgroundColor" },
                }
                _canvas[#_canvas + 1] = {
                    type          = "text",
                    frame         = { x = 0, y = 0, h = 22, w = chooserFrame.w + 10  },
                    text          = _internals.queryDefinitions[_internals.querySite].title,
                    textColor     = { list="System", name = "textColor" },
                    textSize      = 16,
                    textAlignment = "center",
                }
                break
            end
        end
        if #_canvas == 0 then
            _log.i("unable to identify chooser window element for drawing frame")
            _canvas = nil
        end

        _currentApp = application.frontmostApplication()
    end

    -- setup hotkeys
    _hotkeys.tab = hotkey.bind('', 'tab', function()
        local item = _currentChoices[_chooser:selectedRow()]
        -- If no row is selected, but tab was pressed
        if not item then return end

        _chooser:query(item.text)
        updateChooserChoices({})
        if _lastKeypressTimer then
            _lastKeypressTimer:stop()
            _lastKeypressTimer = nil
        end
        updateChooser()
    end)

    _hotkeys.copy = hotkey.bind('cmd', 'c', function()
        local item = _currentChoices[_chooser:selectedRow()]
        if item then
            _chooser:hide()
            pasteboard.setContents(item.text)
            alert.show("Copied to clipboard", 1)
        else
            alert.show("No search result to copy", 1)
        end
    end)

end

local hideCallback = function()
    if _canvas then
        _canvas:delete()
        _canvas = nil
    end
    if _lastKeypressTimer then
        _lastKeypressTimer:stop()
        _lastKeypressTimer = nil
    end
    for k,v in pairs(_hotkeys) do
        v:delete()
        _hotkeys[k] = nil
    end
    _currentApp = nil
end

local clearBackgroundTasks = hideCallback

---------- Spoon Variables ----------

--- AnyComplete.querySite
--- Variable
--- A string specifying the key for the site definition to use when performing web queries for autocompletion possibilities. Defaults to "duckduckgo"
---
--- Notes:
---  * the string must match the key of a definition in [AnyComplete.queryDefinitions](#queryDefinitions) and assiging a new value will generate an error if the definition does not exist -- make sure to add your customizations to `AnyComplete.queryDefinitions` before setting this to a value other than one of the built in defaults.
_internals.querySite = "duckduckgo"

--- AnyComplete.queryDebounce
--- Variable
--- A number specifying the amount of time in seconds that the keyboard must be idle before performing a new query for possibilit completions. Set to 0 to perform a query after every keystroke. Defaults to 0.3.
---
--- Notes:
---  * it has been suggested by some of the issues posted at https://github.com/nathancahill/Anycomplete that Google may rate limit or even block your IP address if it detects too many queries in a short period of time. This has not been confirmed in any terms of service, nor is there any detail as to how may queries over what period of time is considered "too many", but this variable is provided as a way of reducing the number of queries performed.
_internals.queryDebounce = 0.3

--- AnyComplete.queryDefinitions[]
--- Variable
--- A table containing site definitions for completion queries.
---
--- This table contains key-value pairs defining the site defintions for completion queries. Each key is a string specifying the shorthand name for a completion site, and each value is a table containing the following key-value pairs:
---  * `title`       - a string specifying the title to display at the top of the choosers during completion lookup
---  * `acQuery`     - a string specifying the URL for perfoming the actual completion query. Use `%s` as a placeholder to specify where the current value in the chooser query field should be inserted.
---  * `searchQuery` - a string specifying the URL to use when the user wants to open a web page with the search results for the entry specified, triggered by holding down the shift key when making your selection.
---  * `acParser`    - a function which takes as its sole argument the results from the http query and returns a chooser table where each entry is a table of the form `{ text = "possibility" }`.
---
--- Notes:
---  * definitions for Google ("google") and DuckDuckGo ("duckduckgo") are already defined.
_internals.queryDefinitions = {
    google = {
        title       = "Google AutoComplete Suggestions",
        acQuery     = "https://suggestqueries.google.com/complete/search?client=firefox&q=%s",
        searchQuery = "https://www.google.com/#q=%s",
        acParser    = function(requestResults)
            local ok, results = pcall(function() return json.decode(requestResults) end)
            if not ok then return end

            return fnutils.imap(results[2], function(entry)
                return {
                    text = entry,
                }
            end)
        end,
    },
    duckduckgo = {
        title       = "DuckDuckGo AutoComplete Suggestions",
        acQuery     = "https://duckduckgo.com/ac/?q=%s",
        searchQuery = "https://duckduckgo.com/?q=%s",
        acParser    = function(requestResults)
            local ok, results = pcall(function() return json.decode(requestResults) end)
            if not ok then return end

            return fnutils.imap(results, function(entry)
                return {
                    text = entry["phrase"],
                }
            end)
        end,
    },
}

---------- Spoon Methods ----------

-- obj.init = function(self)
--     -- in case called as function
--     if self ~= obj then self = obj end
--
--     return self
-- end

--- AnyComplete:start() -> self
--- Method
--- Readys the chooser interface for the AnyComplete spoon
---
--- Parameters:
---  * None
---
--- Returns:
---  * the AnyComplete spoon object
---
--- Notes:
---  * This method is included to conform to the expected Spoon format; it will automatically be invoked by [AnyComplete:show](#show) if necessary.
obj.start = function(self)
    -- in case called as function
    if self ~= obj then self = obj end
    if not _chooser then
        _chooser = chooser.new(chooserCallback)
                          :queryChangedCallback(queryChangedCallback)
                          :showCallback(showCallback)
                          :hideCallback(hideCallback)
    end
    return self
end

--- AnyComplete:stop() -> self
--- Method
--- Removes the chooser interface for the NonjourLauncher spoon and any lingering service queries
---
--- Parameters:
---  * None
---
--- Returns:
---  * the AnyComplete spoon object
---
--- Notes:
---  * This method is included to conform to the expected Spoon format; in general, it should be unnecessary to invoke this method directly.
obj.stop = function(self)
    -- in case called as function
    if self ~= obj then self = obj end

    if _chooser then
        obj:hide()
        _chooser:delete()
        _chooser = nil
    end
    return self
end

--- AnyComplete:show() -> self
--- Method
--- Shows the AnyComplete chooser window.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the AnyComplete spoon object
---
--- Notes:
---  * Automatically invokes [AnyComplete:start()](#start) if this has not already been done.
obj.show = function(self)
    -- in case called as function
    if self ~= obj then self, st = obj, self end

    if not _chooser then obj:start() end

    if not _chooser:isVisible() then
        _chooser:show()

    end
    return self
end

--- AnyComplete:hide() -> self
--- Method
--- Hides the AnyComplete chooser window.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the AnyComplete spoon object
obj.hide = function(self)
    -- in case called as function
    if self ~= obj then self = obj end

    if _chooser then
        if _chooser:isVisible() then
            _chooser:hide()
            clearBackgroundTasks()
        end
    end
    return self
end

--- AnyComplete:toggle() -> self
--- Method
--- Toggles the visibility of the AnyComplete chooser window.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the AnyComplete spoon object
---
--- Notes::
---  * If the chooser window is currently visible, this method will invoke [AnyComplete:hide](#hide); otherwise invokes [AnyComplete:show](#show).
obj.toggle = function(self)
    -- in case called as function
    if self ~= obj then self, st = obj, self end

    if _chooser and _chooser:isVisible() then
        self:hide()
    else
        self:show()
    end

    return self
end

--- AnyComplete:bindHotkeys(mapping) -> self
--- Method
--- Binds hotkeys for the AnyComplete spoon
---
--- Parameters:
---  * `mapping` - A table containing hotkey modifier/key details for one or more of the following commands:
---    * "show"   - Show the AnyComplete chooser window
---    * "hide"   - Hide the AnyComplete chooser window
---    * "toggle" - Toggles the visibility of the AnyComplete window
---
--- Returns:
---  * the AnyComplete spoon object
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
                _canvas            = _canvas,
                _currentApp        = _currentApp,
                _hotkeys           = _hotkeys,
                _lastKeypressTimer = _lastKeypressTimer,
                _internals         = _internals,
                _currentChoices    = _currentChoices,
            }
        else
            return _internals[key]
        end
    end,
    __newindex = function(self, key, value)
        local errorString = nil
        if key == "queryDebounce" then
            if type(value) == "number" and value >= 0 then
                _internals.queryDebounce = value
            else errorString = "must be a positive number or 0" end
        elseif key == "querySite" then
            if type(value) == "string" and _internals.queryDefinitions[value] then
                _internals.querySite = value
            else
                local keysString = ""
                for k, _ in pairs(_internals.queryDefinitions) do
                    keysString = keysString + k .. ", "
                end
                keysString = keysString:match("^(.*), $") or keysString
                errorString = string.format("must be a string matching a AnyComplete.queryDefinition key (%s)", keysString)
            end
        elseif key == "queryDefinitions" then
            errorString = "you cannot replace the queryDefinition table; add or remove entries with AnyComplete[name] = <definition>"
        else errorString = "is unrecognized" end

        if errorString then error(string.format("%s.%s %s", obj.name, key, errorString)) end
    end,
})
