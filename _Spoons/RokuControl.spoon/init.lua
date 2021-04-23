-- This really belongs in a module -- it's background control mostly
-- RokuRemote should be a spoon once this is landed as a module

-- TODO:
--      Finish Documentation
--   -  xml parser or continue using string matches?
--   -      convert existing string matches to use qduXML
--   -  Available apps (optionally with icons)
--   -  current app
--   -  icon for current app
--   -  launch app
--   +  type text
--   -  ignore with persistance?
--   -      list ignored SN
--   -      remove SN from ignore list
--   -      manually adding removes from ignore list
--
--      RokuRemote spoon gives on screen remote like old kodi one; require this spoon

--- === RokuControl ===
---
--- Control Roku devices with Hammerspoon
---
--- This spoon allows the control of Roku devices on your local network using the protocols and specifications as described at https://developer.roku.com/docs/developer-program/debugging/external-control-api.md
---
--- Download: `svn export https://github.com/asmagill/hammerspoon-config/trunk/_Spoons/RokuControl.spoon`

local inspect  = require("hs.inspect")
local timer    = require("hs.timer")
local socket   = require("hs.socket")
local http     = require("hs.http")
local fnutils  = require("hs.fnutils")
local settings = require("hs.settings")
local utf8     = require("hs.utf8")
local image    = require("hs.image")
local spoons   = require("hs.spoons")

local logger   = require("hs.logger")

local obj    = {
-- Metadata
    name      = "RokuControl",
    author    = "A-Ron",
    homepage  = "https://github.com/asmagill/hammerspoon-config/tree/master/_Spoons/RokuControl.spoon",
    license   = "MIT - https://opensource.org/licenses/MIT",
    spoonPath = spoons.scriptPath(),
    spoonMeta = "placeholder for _coresetup metadata creation",
}

-- version is outside of obj table definition to facilitate its auto detection by
-- external documentation generation scripts
obj.version   = "0.1"

local metadataKeys = {} ; for k, v in require("hs.fnutils").sortByKeys(obj) do table.insert(metadataKeys, k) end

local xml     = dofile(obj.spoonPath .. "qduXML.lua")

obj.__index = obj
local _log = logger.new(obj.name)
obj.logger = _log

-- for timers, etc so they don't get collected
local __internals = {}

-- -- discovered/assigned roku devices
-- obj.__devices = setmetatable({}, discoveredMetatable)

-- devices to ignore
obj.__ignored = setmetatable(settings.get(obj.name .. "_ignoredList") or {}, {
    __tostring = function(self)
        local results = ""
        for _, v in ipairs(self) do results = results .. tostring(v) .. "\n" end
        return results
    end
})

-- for spoon level variables -- they are wrapped by obj's __index/__newindex metamethods so they appear
-- as regular variables and are thus documented as such; by doing this we can consolidate data validation
-- in obj's metatable rather than have to test each time they are used
local __spoonVariables = {}

local ssdpQuery = function(queryTime)
    queryTime = queryTime or __spoonVariables.ssdpQueryTime
    return [[
M-SEARCH * HTTP/1.1
HOST: 239.255.255.250:1900
MAN: "ssdp:discover"
MX: ]] .. tostring(queryTime) .. "\n" .. [[
ST: "roku:ecp"
USER-AGENT: Hammerspoon/]] .. hs.processInfo.version .. [[ UPnP/1.1 SSDPDiscover/0.0
]]
end

local discoveredMetatable = {
    __index = function(self, key) end,
    __newindex = function(self, key, value) end,
    __tostring = function(self)
        local result = ""
        for k, v in pairs(self) do
            result = result .. k .. "\t" .. inspect(v, { newline = " ", indent = "", depth = 1 }) .. "\n"
        end
        return result
    end,
}

-- discovered/assigned roku devices
obj.__devices = setmetatable({}, discoveredMetatable)

local cleanUpDiscovery = function(isNormal)
    -- clean up after ourselves
    if __internals.clearQueryTimer then
        __internals.clearQueryTimer:stop()
        __internals.clearQueryTimer = nil
    end
    if __internals.ssdpDiscovery then
        __internals.ssdpDiscovery:close()
        __internals.ssdpDiscovery = nil
        if isNormal  and __internals.seenDevices then
            for k,v in pairs(obj.__devices) do
                if not v.details.manuallyAdded then
                    if not fnutils.contains(__internals.seenDevices, k) then
                        rawset(obj.__devices, k, nil)
                    end
                end
            end
        end
        __internals.seenDevices = nil
    end
end

---------- Spoon Variables ----------

--- RokuControl.ssdpQueryTime
--- Variable
--- Specifies the number of seconds, default 5, the SSDP query for Roku devices on the local network remains active. Must be an integer > 0.
---
--- This is the number of seconds the SSDP query will remain active when [RokuControl:start](#start) is invoked or [RokuControl:discoverDevices](#discoverDevices) is later invoked to update the active list without a parameter.
__spoonVariables.ssdpQueryTime = 10

--- RokuControl.rediscoveryInterval
--- Variable
--- Specifies the number of seconds, default 3600 (1 hour), between automatic discovery checks to determine if new Roku devices have been added to the network or removed from it. Must be an integer > [RokuControl.ssdpQueryTime](#ssdpQueryTime).
---
--- Automatic discovery checks are enabled when [RokuControl:start](#start) is invoked. Changing this value after `start` has been invoked will cause an immediate discovery process and future discovery process will occur at the new interval.
__spoonVariables.rediscoveryInterval = 3600

---------- Spoon Methods ----------

--- RokuControl:availableDevices() -> table
--- Method
--- Returns a table of available Roku devices
---
--- Parameters:
---  * None
---
--- Returns:
---  * a table containing the available Roku devices as key-value pairs where `key` is the devices serial number and `value` is the `rokuDevice object` as defined in the [RokuControl:device](#device) method documentation.
---
--- Notes:
---  * The table returned has a __tostring metamethod which displays the contents of the table as a list of Roku devices with their friendly name, serial number, and IP address so you can use this method in the Hammerspoon conole to see the list of currently known devices.
obj.availableDevices = function(self)
    -- in case called as function
    if self ~= obj then self = obj end

    local results = {}
    for k, v in pairs(self.__devices) do results[k] = self:device(k) end

    return setmetatable(results, {
        __tostring = function(self)
            local items = {}
            for k,v in pairs(self) do
                local item = obj.__devices[k]
                table.insert(items, { item.name, k, item.host .. ":" .. tostring(item.port) })
            end
            table.sort(items, function(a, b) return a[1] < b[1] end)
            local col1, col2, col3 = 0, 0, 0
            for _, v in ipairs(items) do
                col1 = math.max(col1, #v[1])
                col2 = math.max(col2, #v[2])
                col3 = math.max(col2, #v[3])
            end
            local result = ""
            for _, v in ipairs(items) do
                result = result .. string.format("%-" .. tostring(col1) .. "s (%" ..tostring(col2) .. "s) @ %" .. tostring(col3) .. "s\n", v[1], v[2], v[3])
            end
            return result
        end
    })
end

local deviceMetatable = {
    name = function(self) return obj.__devices[self[1]].name end,
    host = function(self) return obj.__devices[self[1]].host end,
    port = function(self) return obj.__devices[self[1]].port end,
    sn   = function(self) return self[1] end,
    url  = function(self, query)
        return "http://" .. self:host() .. ":" .. self:port() .. "/" .. query:match("^/?(.*)$")
    end,

    devInfo = function(self, root)
        local s, b, h = http.get(self:url(root and "/" or "/query/device-info"), {})
        if s == 200 then
            return xml.parseXML(b)
        else
            _log.ef("devInfo query error --  %d -- %s -- %s", s, b, inspect(h, {  newline = " ", indent = "" }))
            return xml.parseXML([[<error status="]] .. tostring(s) .. [[">]] .. b .. [[</error>]])
        end
    end,

-- want to move to this approach using `asTable` but it will take more effort than I want to
-- put forth at the moment...
--
--     devInfo2 = function(self, root)
--         local s, b, h = http.get(self:url(root and "/" or "/query/device-info"), {})
--         if s == 200 then
--             local state, bXML = pcall(xml.parseXML, b)
--             if state then
--                 return bXML:asTable()
--             else
--                 b = bXML
--             end
--         else
--             _log.ef("devInfo query error --  %d -- %s -- %s", s, b, inspect(h, {  newline = " ", indent = "" }))
--         end
--
--         return nil, s, b
--     end,

    headphonesConnected = function(self)
        local info = self:devInfo()
        if info:tag() == "error" then
            return nil, info["status"], info:value()
        else
            return tostring(xml.entityValue(info("headphones-connected"), 1)):upper() == "TRUE"
        end
    end,

    isTV = function(self) return obj.__devices[self[1]].details.isTV end,
    powerIsOn = function(self) return self:devInfo()("power-mode")[1]:value() == "PowerOn" end,
    supportsFindRemote = function(self) return obj.__devices[self[1]].details.supportsFindRemote end,
    supportsHeadphones = function(self) return obj.__devices[self[1]].details.supportsHeadphones end,


    remoteButtons = function(self)
        local buttonArray = {
            "Home",
            "Rev",
            "Fwd",
            "Play",
            "Select",
            "Left",
            "Right",
            "Down",
            "Up",
            "Back",
            "InstantReplay",
            "Info",
            "Backspace",
            "Search",
            "Enter",
            "A",
            "B",
        }

        if self:supportsFindRemote() then
            table.insert(buttonArray, "FindRemote")
        end

        if self:isTV() then
            table.insert(buttonArray, "ChannelUp")
            table.insert(buttonArray, "ChannelDown")
            table.insert(buttonArray, "VolumeDown")
            table.insert(buttonArray, "VolumeMute")
            table.insert(buttonArray, "VolumeUp")
            table.insert(buttonArray, "InputTuner")
            table.insert(buttonArray, "InputHDMI1")
            table.insert(buttonArray, "InputHDMI2")
            table.insert(buttonArray, "InputHDMI3")
            table.insert(buttonArray, "InputHDMI4")
            table.insert(buttonArray, "InputAV1")

-- ECP docs only mention "PowerOff", but a little googling found forum posts mentioning "PowerOn"
-- and "Power", so, maybe new additions? At any rate, it works for the one TV I have sporadic access to
            table.insert(buttonArray, "PowerOff")
            table.insert(buttonArray, "PowerOn")
            table.insert(buttonArray, "Power")
        end
        if self:supportsHeadphones() then
            if not fnutils.contains(buttonArray, "VolumeDown") then
                table.insert(buttonArray, "VolumeDown")
            end
            if not fnutils.contains(buttonArray, "VolumeUp") then
                table.insert(buttonArray, "VolumeUp")
            end
        end

        return setmetatable(buttonArray, {
            __tostring = function(self)
                local results = ""
                for _,v in ipairs(buttonArray) do
                    results = results .. v .. "\n"
                end
                return results
            end
        })
    end,

    remote = function(self, button, state, skipCheck)
        local action = (type(state) == "nil" and "keypress") or (state and "keydown" or "keyup")

        button = tostring(button)

        local availableButtons = self:remoteButtons()

        if not skipCheck then
            button = button:upper()
            local idx = 0
            for i,v in ipairs(availableButtons) do
                if v:upper() == button then
                    idx = i
                    break
                end
            end

            if idx > 0 then
                button = availableButtons[idx]
            else
                error("invalid button specified: " .. button .. " not recognized")
            end
        end

        http.asyncPost(
            "http://" .. self:host() .. ":" .. self:port() .. "/" .. action .. "/" .. tostring(button),
            "",
            {},
            function(s, b, r)
                if s ~= 200 then
                    -- skip it if it's volume related and the headphones aren't attached
                    if not (button:match("^Volume") and not self:headphonesConnected()) then
                        _log.ef("remote button error: %d -- %s -- %s", s, b, inspect(h, {  newline = " ", indent = "" }))
                    end
                end
            end)
        return self
    end,

    type = function(self, what)
        if type(what) ~= "nil" then
            what = utf8.fixUTF8(tostring(what))
            for c in what:gmatch(utf8.charpattern) do
                local literal = ""
                for _, v in ipairs({ string.byte(c, 1, #c) }) do
                    literal = literal .. string.format("%%%02X", v)
                end
                self:remote("Lit_" .. literal, nil, true)
            end
        end
        return self
    end,

    ignore = function(self)
        local SN = self:sn()
        -- invalidate device in case it's stored in another variable somewhere
        rawset(obj.__devices, SN, nil)
        self[1] = nil
        setmetatable(self, nil)
        table.insert(obj.__ignored, SN)
        settings.set(obj.name .. "_ignoredList", obj.__ignored)
        return nil
    end,

    availableApps = function(self, withImages)
        local results = {}
        local s, b, r = http.get(self:url("/query/apps"), {})
        if s == 200 then
            for _, v in ipairs(xml.parseXML(b)("app")) do
                local id = v.id
                local thisApp = { v:value(), {} }
                for k, v2 in pairs(v) do
                    thisApp[2][k] = v2
                end
                if withImages then
                    thisApp[2]["image"] = image.imageFromURL(self:url("/query/icon/") .. tostring(id))
                end
                table.insert(results, thisApp)
            end
            table.sort(results, function(a, b) return a[1]:upper() < b[1]:upper() end)
        else
            _log.ef("availableApps error: %d -- %s -- %s", s, b, inspect(h, {  newline = " ", indent = "" }))
        end
        return setmetatable(results, {
            __tostring = function(self)
                local results = ""
                local col = 0
                for _, v in ipairs(self) do col = math.max(col, #v[1]) end
                for _, v in ipairs(self) do
                    results = results .. string.format("%-" .. tostring(col) .. "s (%s)\n", v[1], v[2].id)
                end
                return results
            end,
        })
    end,

    deviceImage = function(self)
        local info = self:devInfo(true)
        if info:tag() == "error" then
            return nil, info["status"], info:value()
        else
            -- build in a way that doesn't break if somethings missing
            local imgURL = info("device")[1]
            imgURL = imgURL and imgURL("iconList")[1]
            imgURL = imgURL and imgURL("icon")[1]
            imgURL = imgURL and imgURL("url")[1]
            imgURL = imgURL and imgURL:value()
            if imgURL then
                img = image.imageFromURL(self:url("/" .. imgURL))
            end
        end
        return img
    end,

    currentApp = function(self)
        local result
        local s, b, r = http.get(self:url("/query/active-app"), {})
        if s == 200 then
            result = xml.parseXML(b)("app")[1]:value()
        else
            _log.ef("currentApp error: %d -- %s -- %s", s, b, inspect(h, {  newline = " ", indent = "" }))
        end
        return result
    end,

    currentAppID = function(self)
        local result
        local s, b, r = http.get(self:url("/query/active-app"), {})
        if s == 200 then
            result = xml.parseXML(b)("app")[1].id
        else
            _log.ef("currentApp error: %d -- %s -- %s", s, b, inspect(h, {  newline = " ", indent = "" }))
        end
        return result
    end,

    currentAppIcon = function(self)
        local result
        local s, b, r = http.get(self:url("/query/active-app"), {})
        if s == 200 then
            local id = xml.parseXML(b)("app")[1].id
            if id then
                result = image.imageFromURL(self:url("/query/icon/") .. id)
            end
        else
            _log.ef("currentAppIcon error: %d -- %s -- %s", s, b, inspect(h, {  newline = " ", indent = "" }))
        end
        return result
    end,

    launch = function(self, id, allowInstall)
        local apps = self:availableApps()
        local isLaunch = false
        id = tostring(id)
        for _,v in ipairs(apps) do
            if id == v[1] or id == v[2].id then
                id = v[2].id
                isLaunch = true
                break
            end
        end
        if isLaunch then
            http.asyncPost(
                "http://" .. self:host() .. ":" .. self:port() .. "/launch/" .. id,
                "",
                {},
                function(s, b, r)
                    if s ~= 200 then
                        _log.ef("launch error: %d -- %s -- %s", s, b, inspect(h, {  newline = " ", indent = "" }))
                    end
                end
            )
        elseif allowInstall then
            http.asyncPost(
                "http://" .. self:host() .. ":" .. self:port() .. "/install/" .. id,
                "",
                {},
                function(s, b, r)
                    if s ~= 200 then
                        _log.ef("install error: %d -- %s -- %s", s, b, inspect(h, {  newline = " ", indent = "" }))
                    end
                end
            )
        else
            _log.wf("id %s not recognized for launch and allowInstall flag not set", id)
        end
        return self
    end,

    __tostring = function(self) return obj.name .. ".device: " .. self:sn() end,
    __eq = function(a, b) return a:sn() == b:sn() end,
}
deviceMetatable.__index = deviceMetatable


obj.device = function(self, id)
    -- in case called as function
    if self ~= obj then self, id = obj, self end

    local deviceSN, devObject
    for k, v in pairs(self.__devices) do
        if id == k or id == v.name or id == v.host or id == (v.host .. ":" .. tostring(v.port)) then
            deviceSN = k
            break
        end
    end

    if deviceSN then devObject = setmetatable({ deviceSN }, deviceMetatable) end

    return devObject
end

obj.ignore = function(self, sn)
    -- in case called as function
    if self ~= obj then self, sn = obj, self end
    sn = tostring(sn) -- just in case

    if fnutils.contains(self.__ignored, sn) then
        _log.f("%s already in ignore list")
    else
        table.insert(self.__ignored, sn)
        settings.set(obj.name .. "_ignoredList", self.__ignored)

        local dev = obj.__devices[sn]
        if dev then
            -- invalidate device in case it's stored in another variable somewhere
            rawset(obj.__devices, sn, nil)
            dev[1] = nil
            setmetatable(dev, nil)
        end
    end
    return self
end

obj.unignore = function(self, sn)
    -- in case called as function
    if self ~= obj then self, sn = obj, self end
    sn = tostring(sn) -- just in case

    if fnutils.contains(self.__ignored, sn) then
        local idx = fnutils.indexOf(self.__ignored, sn)
        table.remove(self.__ignored, idx)
        settings.set(obj.name .. "_ignoredList", self.__ignored)
    else
        _log.f("%s not currently in ignore list")
    end
    return self
end

obj.ignoreList = function(self)
    -- in case called as function
    if self ~= obj then self = obj, self end

    return self.__ignored
end

--- RokuControl:addDevice(host, [port]) -> self
--- Method
--- Manually add the specified Roku device to the list of available Roku devices
---
--- Parameters:
---  * `host` - a string containing the ip address of the Roku device to add
---  * `port` - an optional integer, default 8060, specifying the port number of the Roku device to communicate on.
---
--- Returns:
---  * the RokuControl spoon object
---
--- Notes:
---  * An initial query for information is made to the specified IP address; if the device does not respond with a recognized Roku header, the specified entry will not be added to the available Roku device list and an error will be logged to the Hammerspoon console.
---
---  * A device which has been manually added and successfully identified as a valid Roku device will not be removed as inactive during periodic discovery checks, even if it does not respond during the rediscovery check.
---    * you can "lock in" a discovered device by performing this method after the device's initial discovory; useful if the device seems to sometimes be too slow in its responses to discovery queries.
---    * to remove a manually added device from the list of available Roku devices, you must use the `rokuDevice object` `ignore` method as defined in the [RokuControl:device](#device) documentation.

-- headers should not be provided when this method is invoked to manually add a device; it is used to
-- track the ssdp query results, mainly for debugging right now, but maybe in case I decide to add
-- support for tracking the notify messages ROKU devices send periodically to enforce the cache timeout
obj.addDevice = function(self, host, port, headers)
    -- in case called as function
    if self ~= obj then self, host, port, headers = obj, self, host, port end
    port = tonumber(port) or 8060
    if type(header) ~= "table" then header = nil end -- should only be provided by discoverDevices anyways

    local url = "http://" .. host .. ":" .. tostring(port) .. "/query/device-info"
    http.asyncGet(url, {}, function(s, b, h)
        if s == 200 then
            local data = xml.parseXML(b)
            local serialNumber = data("serial-number")[1]:value() -- b:match("<serial%-number>(.+)</serial%-number>")
            if fnutils.contains(self.__ignored, serialNumber) then
                if header then
                    _log.f("%s is in ignore list; ignoring during discovery", serialNumber)
                    return
                else
                    _log.f("%s is in ignore list; removing due to manual device addition", serialNumber)
                    local idx = fnutils.indexOf(self.__ignored, serialNumber)
                    table.remove(self.__ignored, idx)
                    settings.set(obj.name .. "_ignoredList", self.__ignored)
                end
            end

            if not self.__devices[serialNumber] then -- if it already exists, don't replace it
                rawset(self.__devices, serialNumber, { details = {} })
            end
            local entry = self.__devices[serialNumber]
            entry.host = host
            entry.port = port

            local name = xml.entityValue(data("user-device-name"), 1)     or
                         xml.entityValue(data("friendly-device-name"), 1) or
                         xml.entityValue(data("friendly-model-name"), 1)  or
                         xml.entityValue(data("default-device-name"), 1)  or
                         serialNumber

            -- things that don't change (well, at least not often enough to be queried each time we care; update during discovery, that's often enough)
            entry.name = name
            if not headers then
                entry.details.manuallyAdded = true
            else
                entry.details.ssdpDiscovery = headers
            end
            entry.details.isTV = tostring(xml.entityValue(data("is-tv"), 1)):upper() == "TRUE"
            entry.details.supportsFindRemote = tostring(xml.entityValue(data("supports-find-remote"), 1)):upper() == "TRUE"
            entry.details.supportsHeadphones = tostring(xml.entityValue(data("supports-private-listening"), 1)):upper() == "TRUE"

        else
            _log.ef("Unable to reach Roku device at %s: status = %d, msg = %s", host, s, b)
        end
    end)
    return self
end

--- RokuControl:discoverDevices([queryTime]) -> self
--- Method
--- Starts discovery of Roku devices on your local network for the specified number of seconds.
---
--- Parameters:
---  * `queryTime` - the number of seconds to wait for Roku devices to respond to the discovery request. Defaults to the value specified by [RokuControl.ssdpQueryTime](#ssdpQueryTime).
---
--- Returns:
---  * the RokuControl spoon object
---
--- Notes:
---  * if a discovery process is already in progress, this method has no effect.
---
---  * once [RokuControl:start](#start) has been invoked, this method will be invoked automatically at the interval specified by [RokuControl.rediscoveryInteerval](#rediscoveryInterval) (default 1 hour) to determine if new devices have been added or if existing devices have been removed from your local network.
---
---  * you can invoke this method directly to force an update prior to the scheduled checks.
---  * if you invoke this method directly *without* first invoking [RokuControl:start](#start) then no rediscovery check will be scheduled -- it will perform a one time query that will not update the list if your network changes or devices are added or removed from your network.
obj.discoverDevices = function(self, queryTime)
    -- in case called as function
    if self ~= obj then self, queryTime = obj, self end
    queryTime = queryTime or __spoonVariables.ssdpQueryTime

    if not __internals.ssdpDiscovery then
        __internals.seenDevices = {}
        __internals.ssdpDiscovery = socket.udp.server(1900, function(data, addr)
            local status, headerTxt = data:match("^(HTTP/[%d%.]+ 200 OK)[\r\n]+(.*)$")
            if status then
                local headers = {}
                for _,v in pairs(fnutils.split(headerTxt, "[\r\n]+")) do
                    if v ~= "" then
                        local key, value = v:match("^([^:]+): ?(.*)$")
    --                     print("'" .. v .. "'", "'" .. tostring(key) .. "'", "'" .. tostring(value) .. "'")
                        key = key:upper() -- spec says key should be case insensitive
                        headers[key] = value
                    end
                end
                if headers["USN"] and headers["USN"]:match("^uuid:roku:ecp:") then
                    local serial = headers["USN"]:match("^uuid:roku:ecp:(.*)$")
                    local host, port = headers["LOCATION"]:match("^http://([%d%.]+):(%d+)/$")
                    -- if a udp response is queued but clearQueryTimer callback is queued first
                    -- seenDevices may disappear... its ok to add the Device and skip seenDevices
                    -- since it's for clearing out things we *no longer* see..
                    if __internals.seenDevices then
                        table.insert(__internals.seenDevices, serial)
                    end
                    obj:addDevice(host, port, headers)
                end
            end
        end):receive()
        __internals.ssdpDiscovery:send(ssdpQuery(queryTime), "239.255.255.250", 1900) -- multicast udp ssdp m-search
        __internals.clearQueryTimer = timer.doAfter(queryTime, function()
            cleanUpDiscovery(true)
        end)
    end
    return self
end

-- not really needed, so don't bother defining init
-- obj.init = function(self)
--     -- in case called as function
--     if self ~= obj then self = obj end
--
--     return self
-- end

--- RokuControl:start() -> self
--- Method
--- Starts discovery of Roku devices on your local network and monitors for device response for the number of seconds specified by [RokuControl.ssdpQueryTime](#ssdpQueryTime) and schedules rediscovery checks at the interval specified by [RokuControl.rediscoveryInterval](#rediscoveryInterval)
---
--- Parameters:
---  * None
---
--- Returns:
---  * the RokuControl spoon object
---
--- Notes:
---  * if a discovery process is already in progress, this method has no effect.
obj.start = function(self)
    -- in case called as function
    if self ~= obj then self = obj end

    if not __internals.ssdpDiscovery then
        obj:discoverDevices()
    end

    if not __internals.rediscoveryCheck then
        local rediscoveryFunction
        rediscoveryFunction = function()
            obj:discoverDevices()
            -- probably overkill, but I've seen some wierd timer race conditions
            if __internals.rediscoveryCheck then
                __internals.rediscoveryCheck:stop()
                __internals.rediscoveryCheck = nil
            end
            __internals.rediscoveryCheck = timer.doAfter(__spoonVariables.rediscoveryInterval, rediscoveryFunction)
        end
        __internals.rediscoveryCheck = timer.doAfter(__spoonVariables.rediscoveryInterval, rediscoveryFunction)
    end
    return self
end

--- RokuControl:stop() -> self
--- Method
--- Stops the discovery of Roku devices on your local network (if currently active) and disables rediscovery checks.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the RokuControl spoon object
---
--- Notes:
---  * generally you should not need to invoke this method as discovery will terminate itself automatically after the number of seconds specified by [RokuControl.ssdpQueryTime](#ssdpQueryTime).
---
---  * has no effect if discovery is not currently in progress.
obj.stop = function(self)
    -- in case called as function
    if self ~= obj then self = obj end

    if __internals.rediscoveryCheck then
        __internals.rediscoveryCheck:stop()
        __internals.rediscoveryCheck = nil
    end
    cleanUpDiscovery()
    return self
end

--- RokuControl:bindHotkeys(mapping) -> self
--- Method
--- Binds hotkeys for the RokuControl spoon
---
--- Parameters:
---  * `mapping` - A table containing hotkey modifier/key details for one or more of the following commands:
---    * "start"    - start initial discovery of Roku devices on the local network and schedule periodic checks
---    * "stop"     - stop discovery (if active) and periodic checks for Roku devices on the local network
---    * "discover" - perform an immediate discovery of Roku devices to add newly discovered devices and remove stale entries.
---
--- Returns:
---  * the RokuControl spoon object
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
        start    = self.start,
        stop     = self.stop,
        discover = self.discoverDevices,
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

    -- I find it's easier to validate variables once as they're being set then to have to add
    -- a bunch of code everywhere else to verify that the variable was set to a valid/useful
    -- value each and every time I want to use it. Plus the user sees an error immediately
    -- rather then some obscure sort of halfway working until some special combination of things
    -- occurs... (ok, ok, it only reduces those situations but doesn't eliminate them entirely...)

    __index = function(self, key)
        return __spoonVariables[key]
    end,
    __newindex = function(self, key, value)
        local errMsg = nil
        if key == "ssdpQueryTime" then
            if type(value) == "number" and math.type(value) == "integer" and value > 0 then
                __spoonVariables[key] = value
            else
                errMsg = "ssdpQueryTime must be an integer > 0"
            end
        elseif key == "rediscoveryInterval" then
            if type(value) == "number" and math.type(value) == "integer" and value > __spoonVariables["ssdpQueryTime"] then
                __spoonVariables[key] = value
                if __internals.rediscoveryCheck then
                    __internals.rediscoveryCheck:fire()
                end
            else
                errMsg = "rediscoveryInterval must be an integer > ssdpQueryTime"
            end

        else
            errMsg = tostring(key) .. " is not a recognized paramter of RokuControl"
        end

        if errMsg then error(errMsg, 2) end
    end,

    -- for debugging purposes; users should never need to see these directly
    __internals = __internals,
    __spoonVariables = __spoonVariables,
})
