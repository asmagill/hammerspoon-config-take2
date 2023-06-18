--
-- Basically a canvasified version of my earlier drawing based one...
-- Really need to re-write taking advantage of percentages so legend
-- doesn't have to be redrawn each time, but it seems responsive enough
-- that I'm not going to lose sleep for now...

-- see also _keys/wifiSNR.lua
--
-- and document both, you malodorous pig fart... maybe wrap them up in a nice spoon
-- so others don't go blind trying to understand your spaghetti logic?
--

local screen     = require("hs.screen")
local canvas     = require("hs.canvas")
local wifi       = require("hs.wifi")
local fnutils    = require("hs.fnutils")
local timer      = require("hs.timer")
local styledtext = require("hs.styledtext")
local location   = require("hs.location")

local module = {}

-- https://en.wikipedia.org/wiki/List_of_WLAN_channels
module.wifiFrequencies = ls.makeConstantsTable{
    ["2GHz"] = {
         [1] = 2412,           [2] = 2417,          [3] = 2422,
         [4] = 2427,           [5] = 2432,          [6] = 2437,
         [7] = 2442,           [8] = 2447,          [9] = 2452,
        [10] = 2457,          [11] = 2462,         [12] = 2467,
        [13] = 2472,          [14] = 2484,
    },
    ["5GHz"] = {
          [7] = 5035,          [8] = 5040,          [9] = 5045,
         [11] = 5055,         [12] = 5060,         [16] = 5080,
         [34] = 5170,         [36] = 5180,         [38] = 5190,
         [40] = 5200,         [42] = 5210,         [44] = 5220,
         [46] = 5230,         [48] = 5240,         [50] = 5250,
         [52] = 5260,         [54] = 5270,         [56] = 5280,
         [58] = 5290,         [60] = 5300,         [62] = 5310,
         [64] = 5320,        [100] = 5500,        [102] = 5510,
        [104] = 5520,        [106] = 5530,        [108] = 5540,
        [110] = 5550,        [112] = 5560,        [114] = 5570,
        [116] = 5580,        [118] = 5590,        [120] = 5600,
        [122] = 5610,        [124] = 5620,        [126] = 5630,
        [128] = 5640,        [132] = 5660,        [134] = 5670,
        [136] = 5680,        [138] = 5690,        [140] = 5700,
        [142] = 5710,        [144] = 5720,        [149] = 5745,
        [151] = 5755,        [153] = 5765,        [155] = 5775,
        [157] = 5785,        [159] = 5795,        [161] = 5805,
        [165] = 5825,        [183] = 4915,        [184] = 4920,
        [185] = 4925,        [187] = 4935,        [188] = 4940,
        [189] = 4945,        [192] = 4960,        [196] = 4980,
    },
}

-- observers to notify when wifi information is updated
local observers = {}

-- function which notifies watching observers
local notifyObservers
notifyObservers = function(results)
    module.lastScanTime = timer.secondsSinceEpoch()
    if module.backgroundScanner then
        -- we're supposed to be running, so notify observers and renew scan
        -- also check to see if we need to auto-stop
        local somebodyIsWatching = false
        for i,v in ipairs(observers) do
            if v.isWatching then
                somebodyIsWatching = true
                v:updateWifiData(results)
            end
        end
        if somebodyIsWatching then
            if module.delayTimer and module.delayTimer > 0 then
                module.scanDelayTimer = timer.doAfter(module.delayTimer, function()
                    if module.backgroundScanner then
                        module.backgroundScanner = wifi.backgroundScan(notifyObservers)
                    end
                    module.scanDelayTimer = nil
                end)
            else
                module.backgroundScanner = wifi.backgroundScan(notifyObservers)
            end
        else
            module.backgroundScanner = nil
        end
    end
end

local calculateXOffsets = function(self)
    local results = {}
    local availableWidth = self.frame.w - self.padding * 2
--     print(availableWidth)
    local minFreq, maxFreq = math.huge, 0
    for i, v in pairs(self.channelList) do
        local f = module.wifiFrequencies[self.band][v]
        if f < minFreq then minFreq = f end
        if f > maxFreq then maxFreq = f end
    end
    local multiplier = availableWidth / (maxFreq - minFreq)
    results["multiplier"] = multiplier

    for i, v in ipairs(self.channelList) do
        local f = module.wifiFrequencies[self.band][v]
        results[v] = (f - minFreq) * multiplier
    end

    return results
end

local variablesThatCauseUpdates = {
    frame              = {},
    padding            = 20,
    colorList          = {
        { red = 1.0, green = 1.0, blue = 1.0 },
        { red = 1.0, green = 1.0, blue = 0.5 },
        { red = 1.0, green = 1.0, blue = 0.0 },
        { red = 1.0, green = 0.5, blue = 1.0 },
        { red = 1.0, green = 0.5, blue = 0.5 },
        { red = 1.0, green = 0.5, blue = 0.0 },
        { red = 1.0, green = 0.0, blue = 1.0 },
        { red = 1.0, green = 0.0, blue = 0.5 },
        { red = 1.0, green = 0.0, blue = 0.0 },
        { red = 0.5, green = 1.0, blue = 1.0 },
        { red = 0.5, green = 1.0, blue = 0.5 },
        { red = 0.5, green = 1.0, blue = 0.0 },
        { red = 0.5, green = 0.5, blue = 1.0 },
        { red = 0.5, green = 0.5, blue = 0.5 },
        { red = 0.5, green = 0.5, blue = 0.0 },
        { red = 0.5, green = 0.0, blue = 1.0 },
        { red = 0.5, green = 0.0, blue = 0.5 },
        { red = 0.5, green = 0.0, blue = 0.0 },
        { red = 0.0, green = 1.0, blue = 1.0 },
        { red = 0.0, green = 1.0, blue = 0.5 },
        { red = 0.0, green = 1.0, blue = 0.0 },
        { red = 0.0, green = 0.5, blue = 1.0 },
        { red = 0.0, green = 0.5, blue = 0.5 },
        { red = 0.0, green = 0.5, blue = 0.0 },
        { red = 0.0, green = 0.0, blue = 1.0 },
        { red = 0.0, green = 0.0, blue = 0.5 },
        { red = 0.0, green = 0.0, blue = 0.0 },
    },
    showNames          = true,
    highlightJoined    = true,
    networkPersistence = 2,
    drawingLevel       = canvas.windowLevels.popUpMenu,
}

local tableCopy -- assumes no looping, good enough for our purposes
tableCopy = function(inTable)
    local outTable = {}
    for k, v in pairs(inTable) do
        outTable[k] = (type(v) == "table") and tableCopy(v) or v
    end
    return outTable
end

local objectMT
objectMT = {
    __methodIndex = {},
    __internalData = setmetatable({}, { __mode = "k" }),
    __publicData   = setmetatable({}, { __mode = "k" }),

    __newindex = function(self, k, v)
        if variablesThatCauseUpdates[k] == nil then
            rawset(self, k, v)
        else
            objectMT.__publicData[self][k] = v
            if k == "frame" then self.canvas:frame(v) end
            if k == "frame" or k == "padding" then
                objectMT.__internalData[self].channelXoffsets = calculateXOffsets(self)
            end
            self:updateCanvas()
        end
    end,
    __pairs = function(self)
        local keys, k, v = {}, nil, nil
        repeat
            k, v = next(self, k)
            if k then keys[k] = true end
        until not k
        for k, v in pairs(objectMT.__publicData[self]) do
            keys[k] = true
        end
        return function(_, k)
                local v
                k, v = next(keys, k)
                if k then v = _[k] end
                return k, v
            end, self, nil
    end,
    __gc = function(self)
        self:delete()
    end,
    __index = function(_, k)
        if objectMT.__methodIndex[k] then return objectMT.__methodIndex[k] end
        if objectMT.__publicData[_][k] then return objectMT.__publicData[_][k] end
        for k2, v in pairs(objectMT.__publicData[_]) do
            if type(k2) ~= "function" then
                if k == "set" .. k2:sub(1,1):upper() .. k2:sub(2) then
                    return function(self, v)
                        self[k2] = v
                        return self
                    end
                end
            end
        end
        return nil
    end,
}

objectMT.__methodIndex.stop = function(self)
    self.isWatching = false
    return self
end

objectMT.__methodIndex.start = function(self)
    self.isWatching = true
    module.startObserving() -- auto start when an instance of us starts
    return self
end

objectMT.__methodIndex.show = function(self)
    self.canvas:show()
    objectMT.__internalData[self].isVisible = true
    return self
end

objectMT.__methodIndex.hide = function(self)
    self.canvas:hide()
    objectMT.__internalData[self].isVisible = nil
    return self
end

objectMT.__methodIndex.visible = function(self)
    return objectMT.__internalData[self].isVisible or false
end

objectMT.__methodIndex.delete = function(self)
    local index = 0
    for i, v in ipairs(observers) do
        if self == v then
            index = i
            break
        end
    end
    if index ~= 0 then
        table.remove(observers, index)
    end
    self.isWatching = false
    self.canvas = self.canvas:delete() -- delete return none aka nil
    if objectMT.__internalData[self] then
       objectMT.__internalData[self].channelXoffsets = {}
       objectMT.__internalData[self].seenNetworks = {}
    end
    return nil
end

objectMT.__methodIndex.updateWifiData = function(self, latestScan)
-- apparently macOS got more sensitive about scanning too often sometime after Yosemite,
-- so we alternate between valid data and an error string... just skip it when its not
-- a table containing useful data
    if type(latestScan) == "table" then
        local iface = wifi.interfaceDetails()
        for k, v in pairs(objectMT.__internalData[self].seenNetworks) do
            v.lastSeen = v.lastSeen + 1
        end
        for i, v in ipairs(latestScan) do
            if v.wlanChannel.band == self.band then
                local label = tostring(v.bssid) .. "_" .. tostring(v.ssid) .. "-" .. tostring(v.wlanChannel.number)
                if objectMT.__internalData[self].seenNetworks[label] then
                    objectMT.__internalData[self].seenNetworks[label].signal   = v.rssi
                    objectMT.__internalData[self].seenNetworks[label].lastSeen = 0
                    objectMT.__internalData[self].seenNetworks[label].joined   = nil
                else
                    local colorNumber = objectMT.__internalData[self].colorNumberForLabels[label]
                    if not colorNumber then
                        colorNumber = objectMT.__internalData[self].lastColorAssigned + 1
                        objectMT.__internalData[self].lastColorAssigned = colorNumber
                        objectMT.__internalData[self].colorNumberForLabels[label] = colorNumber
                    end
                    objectMT.__internalData[self].seenNetworks[label] = {
                        name        = v.ssid,
                        channel     = v.wlanChannel.number,
                        width       = tonumber(v.wlanChannel.width:match("^(%d+)MHz")),
                        signal      = v.rssi,
                        lastSeen    = 0,
                        colorNumber = colorNumber,
                    }
                end
                if (iface.wlanChannel.band   == v.wlanChannel.band) and
                   (iface.wlanChannel.number == v.wlanChannel.number) and
                   (iface.wlanChannel.width  == v.wlanChannel.width) and
                   (iface.bssid              == v.bssid) then
                      objectMT.__internalData[self].seenNetworks[label].joined = true
                end
            end
        end
        if type(self.networkPersistence) == "number" then
            for k, v in pairs(objectMT.__internalData[self].seenNetworks) do
                if v.lastSeen > self.networkPersistence then
                    objectMT.__internalData[self].seenNetworks[k] = nil
                end
            end
        end
        self.lastScanTime = module.lastScanTime
        self:updateCanvas()
--     else
--         print("++ error retrieving wifi data: ", latestScan)
    end
    return self
end

objectMT.__methodIndex.updateCanvas = function(self)
    self.canvas:level(self.drawingLevel)
    while #self.canvas > 1 do self.canvas:removeElement() end

    -- legend
    for k, v in fnutils.sortByKeyValues(objectMT.__internalData[self].channelXoffsets) do
        if type(k) ~= "string" then
            local channelLabel = styledtext.new(tostring(k), {
                font = {
                    name = "Menlo",
                    size = 10
                },
                color = { white = 0.0 },
            })
            local size = self.canvas:minimumTextSize(channelLabel)
            self.canvas:appendElements{
                type  = "text",
                frame = {
                    x = self.padding + v - size.w / 2,
                    y = self.frame.h - self.padding - size.h / 2,
                    h = size.h,
                    w = size.w,
                },
                text  = channelLabel,
            }
        end
    end

    -- last updated tag
    local luaTime = math.floor(self.lastScanTime or 0.0)
    local fract   = (self.lastScanTime or 0.0) - luaTime
    local textLabel = styledtext.new("Last Updated: " .. os.date("%x %T", luaTime) .. tostring(fract):sub(2, 5), {
        font = {
                name = "Menlo-Italic",
                size = 10
            },
            color = { white = 0.0 },
        })
    local textLabelBox = self.canvas:minimumTextSize(textLabel)
    self.canvas:appendElements{
        type  = "text",
        frame = {
            x = self.frame.w - (textLabelBox.w + 4),
            y = self.frame.h - (textLabelBox.h + 3),
            h = textLabelBox.h,
            w = textLabelBox.w,
        },
        text  = textLabel,
    }

    -- arcs and labels
    self.canvas:appendElements{
        type   = "rectangle",
        action = "clip",
        frame  = {
            x = self.padding,
            y = self.padding,
            h = self.frame.h - self.padding * 2,
            w = self.frame.w - self.padding * 2,
        },
    }
    for k, v in pairs(objectMT.__internalData[self].seenNetworks) do
        local bssid, ssid, channel = k:match("^([0-9a-fA-F:]+)_(.*)-(%d+)$")
        local strokeWidth = (v.lastSeen == 0) and 3 or 1
        local width = v.width * objectMT.__internalData[self].channelXoffsets["multiplier"]
        local color = self.colorList[1 + (v.colorNumber - 1) % #self.colorList]
        local signal = (120 + v.signal) * (self.frame.h - self.padding * 2) / 120
        self.canvas:appendElements{
            type        = "ellipticalArc",
            action      = v.joined and "strokeAndFill" or "stroke",
            strokeColor = color,
            fillColor   = { white = 1.0, alpha = 0.2 },
            strokeWidth = strokeWidth,
            arcRadii    = false,
            startAngle  = -90,
            endAngle    = 90,
            frame       = {
                x = self.padding + objectMT.__internalData[self].channelXoffsets[v.channel] - width / 2,
                y = self.frame.h - (signal + self.padding * 2),
                h = signal * 2,
                w = width,
            },
        }
        if self.showNames then
            local labelString = styledtext.new(ssid, {
                font = {
                        name = "Menlo",
                        size = 10
                    },
                    color = color,
                })
            local labelBox = self.canvas:minimumTextSize(labelString)
            local labelFrame = {
                x = self.padding + objectMT.__internalData[self].channelXoffsets[v.channel] - labelBox.w / 2,
                y = self.frame.h - (self.padding * 2 + (signal + labelBox.h) / 2),
                h = labelBox.h,
                w = labelBox.w,
            }
            if labelFrame.x < self.padding then labelFrame.x = self.padding end
            if (labelFrame.x + labelFrame.w) > (self.frame.w - self.padding) then
                labelFrame.x = self.frame.w - self.padding - labelFrame.w
            end
            self.canvas:appendElements{
                type  = "text",
                frame = labelFrame,
                text  = labelString,
            }
        end
    end
end

module.new = function(band, frame)
    location.start() -- ensure bssid is available

    if type(band) == "table" and frame == nil then
        band, frame = nil, band
    end
    band = module.wifiFrequencies[band] and band or "2GHz"
    if not frame then
        local screenFrame = screen.mainScreen():fullFrame()
        frame = {
            x = screenFrame.x + screenFrame.w * 1/10,
            y = screenFrame.y + screenFrame.h * 1/3,
            h = screenFrame.h * 1/3,
            w = screenFrame.w * 8/10,
        }
    end

    -- get supported channels for specified band
    local channelList = {}
    local supportedChannels = wifi.interfaceDetails().supportedChannels
    if not supportedChannels then
        wifi.availableNetworks() -- blocking, so only do if necessary
        supportedChannels = wifi.interfaceDetails().supportedChannels
    end
    -- channel may be listed multiple times if it supports multiple bandwidths
    local seenChannels = {}
    for k, v in ipairs(supportedChannels) do
        if v.band == band and not seenChannels[v.number] then
            table.insert(channelList, v.number)
            seenChannels[v.number] = true
        end
    end

    local object = setmetatable({
        channelList = channelList,
        band        = band,
        isWatching  = false,
        canvas      = canvas.new(frame):insertElement{
            type             = "rectangle",
            action           = "strokeAndFill",
            strokeWidth      = 5,
            fillColor        = { alpha = .7, white = .5 },
            strokeColor      = { alpha = .5 },
            roundedRectRadii = { xRadius = 10, yRadius = 10 },
        }:behavior{"canJoinAllSpaces"},
    }, objectMT)

    objectMT.__internalData[object] = {
        channelXoffsets      = {},
        seenNetworks         = {},
        lastColorAssigned    = 0,
        colorNumberForLabels = {},
    }

    objectMT.__publicData[object] = tableCopy(variablesThatCauseUpdates)
    objectMT.__publicData[object].frame = object.canvas:frame()

    table.insert(observers, object)

    objectMT.__internalData[object].channelXoffsets = calculateXOffsets(object)

    return object
end

module.startObserving = function()
    if not module.backgroundScanner then
        module.backgroundScanner = wifi.backgroundScan(notifyObservers)
    end
end

module.stopObserving = function()
    if module.backgroundScanner then
        -- we can't send the backgroundScanner a stop message, but this being nil will keep notifyObservers from respawning another scan
        module.backgroundScanner = nil
    end
end

module.delayTimer = 5

return module
