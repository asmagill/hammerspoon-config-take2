
-- vastly in need of a rewrite --

local module = {
--[=[
    _NAME        = 'battery',
    _VERSION     = '',
    _URL         = 'https://github.com/asmagill/hammerspoon_config',
    _DESCRIPTION = [[

          Battery Status

          I already had a plan in mind, but the visual design is influenced by code found at
          http://applehelpwriter.com/2014/08/25/applescript-make-your-own-battery-health-meter/
    ]],
    _TODO        = [[

       [x] issue warning for low battery?  System doesn't if we hide its icon...
       [ ] change menu title to icon with color change for battery state?
              awaiting way to composite drawing objects...

    ]],
    _LICENSE     = [[ See README.md ]]
--]=]
}

-- local menubar    = require("hs.menubar")
-- local menubar    = require("hs._asm.guitk.menubar")
local menubar    = require("hs.menubar")
local utf8       = require("hs.utf8")
local battery    = require("hs.battery")
local fnutils    = require("hs.fnutils")
local styledtext = require("hs.styledtext")
local timer      = require("hs.timer")
local host       = require("hs.host")
local canvas     = require("hs.canvas")

local onAC       = utf8.codepointToUTF8(0x1F50C) -- plug
local onBattery  = utf8.codepointToUTF8(0x1F50B) -- battery

local menuUserData = nil
local currentPowerSource = ""

local batteryPowerSource = function() return battery.powerSource() or "no battery" end

local updateMenuTitle = function()
    if menuUserData then
        local titleText = (batteryPowerSource() == "AC Power") and onAC or onBattery
        local additionalTitleText

        local amp = battery.amperage()
        if amp then
            local text = string.format("%+d\n", amp)

            local timeValue = -999
            if batteryPowerSource() == "AC Power" then
                timeValue = battery.timeToFullCharge()
            else
                timeValue = battery.timeRemaining()
            end
    -- print(timeValue)
            text = text ..((timeValue < 0) and "???" or
                    string.format("%d:%02d", math.floor(timeValue/60), timeValue%60))

            local titleColor = { white = (host.interfaceStyle() == "Dark") and 1 or 0 }
            additionalTitleText = styledtext.new(text,  {
                font = {
                    name = "Menlo",
                    size = 9
                },
                color = titleColor,
                paragraphStyle = {
                    alignment = "center",
                },
            })
        end

--         local c = canvas.new{ x = 0, y = 0, h = 0, w = 0 }
--         c:frame(c:minimumTextSize(titleText))
--         c[1] = { type = "text", text = titleText }
--         menuUserData:setIcon(c:imageFromCanvas())
--         c = nil
        menuUserData:setTitle(titleText)
        if additionalTitleText then
            -- Big Sur+ forces a common text baseline for titles which
            -- causes multi-line text to push upper liness off top of
            -- menubar; this converts it to an image which is allowed
            -- the full menubar height for display
            local c = canvas.new{ x = 0, y = 0, h = 0, w = 0 }
            c:frame(c:minimumTextSize(additionalTitleText))
            c[1] = { type = "text", text = additionalTitleText }
            menuUserData:setIcon(c:imageFromCanvas()):imagePosition(3)
            c = nil
        else
            menuUserData:setIcon(nil):imagePosition(0)
        end
    end
end

local powerSourceChangeFN = function(justOn)
    local newPowerSource = batteryPowerSource()
    if menuUserData then updateMenuTitle() end
    if newPowerSource ~= "no battery" then
        local test = {
            percentage = battery.percentage(),
            onBattery = batteryPowerSource() == "Battery Power",
            timeRemaining = battery.timeRemaining(),
            timeStamp = os.time()
        }

        if currentPowerSource ~= newPowerSource then
            currentPowerSource = newPowerSource
    --         if menuUserData then
    --             if currentPowerSource == "AC Power" then
    --                 menuUserData:setTitle(onAC)
    --             else
    --                 menuUserData:setTitle(onBattery)
    --             end
    --         end
        end
    end
end

-- local powerWatcher = battery.watcher.new(powerSourceChangeFN)

local rawBatteryData
rawBatteryData = function(tbl)
    local data = {}
    local rawStyle = {
        font  = { name = "Menlo", size = 10 },
        -- apparently a true white based color gets automatically adjusted based on enabled
        -- status, but an RGB white doesn't; this is more visible, especially when in Dark mode
        color = { blue = .5, green = .5, red = .5 }
    }
    for i,v in fnutils.sortByKeys(tbl) do
        if type(v) ~= "table" then
            table.insert(data, {
                title = styledtext.new(i .. " = " .. tostring(v), rawStyle),
                disabled = true,
            })
        elseif next(v) then
            table.insert(data, {
                title = styledtext.new(i, rawStyle),
                menu = rawBatteryData(v),
                disabled = false,
            })
        end
    end

    return data
end

local displayBatteryData = function(modifier)
    local menuTable = {}
    updateMenuTitle()
    if batteryPowerSource() == "no battery" then
        table.insert(menuTable, { title = onAC .. "  No Battery" })
    else
        local pwrIcon = (batteryPowerSource() == "AC Power") and onAC or onBattery
        table.insert(menuTable, { title = pwrIcon .. "  " .. (
                (battery.isCharged()  and "Fully Charged") or
                (battery.isCharging() and (battery.isFinishingCharge() and "Finishing Charge" or "Charging")) or (battery._powerSources()[1]["Optimized Battery Charging Engaged"] and "On Hold" or "On Battery")
            )
        })
    end

    table.insert(menuTable, { title = "-" })

    table.insert(menuTable, {
        title = utf8.codepointToUTF8(0x26A1) .. "  Current Charge: " ..
            string.format("%.2f%%", (battery.percentage() or "n/a"))
    })

    local timeTitle, timeValue = utf8.codepointToUTF8(0x1F552) .. "  ", nil
    if batteryPowerSource() == "AC Power" then
        timeTitle = timeTitle .. "Time to Full: "
        timeValue = battery.timeToFullCharge()
    else
        timeTitle = timeTitle .. "Time Remaining: "
        timeValue = battery.timeRemaining()
    end

    if timeValue then
        table.insert(menuTable, { title = timeTitle ..
            ((timeValue < 0) and "...calculating..." or
            string.format("%2d:%02d", math.floor(timeValue/60), timeValue%60))
        })
    else
        table.insert(menuTable, { title = timeTitle .. "n/a"
        })
    end

    local maxCapacity, designCapacity = battery.maxCapacity(), battery.designCapacity()
    table.insert(menuTable, {
        title = utf8.codepointToUTF8(0x1F340) .. "  Battery Health: " ..
            (maxCapacity and designCapacity and string.format("%.2f%%", 100 * maxCapacity/designCapacity) or "n/a")
    })

    table.insert(menuTable, {
        title = utf8.codepointToUTF8(0x1F300) .. "  Cycles: ".. (battery.cycles() or "n/a")
    })

    local healthCondition = battery.healthCondition()
    if healthCondition then
        table.insert(menuTable, {
            title = utf8.codepointToUTF8(0x26A0) .. "  " .. healthCondition
        })
    end

    table.insert(menuTable, { title = "-" })

    table.insert(menuTable, { title = "Raw Battery Data...", menu = rawBatteryData(battery.getAll()) })

    return menuTable
end

--module.menuUserdata = menuUserData -- for debugging, may remove in the future

module.start = function()
--     menuUserData, currentPowerSource = menubar.new(), ""
    menuUserData, currentPowerSource = menubar.new(), ""

    powerSourceChangeFN(true)
--     powerWatcher:start()

    menuUserData:setMenu(displayBatteryData)

--     module.menuTitleChanger = timer.doEvery(5, updateMenuTitle)
    module.menuTitleChanger = timer.doEvery(5, powerSourceChangeFN)
    module.menuUserdata = menuUserData -- for debugging, may remove in the future
    return module
end

module.stop = function()
--     powerWatcher:stop()
    module.menuTitleChanger:stop()
    module.menuTitleChanger = nil
    menuUserData = menuUserData:delete()
    return module
end

module = setmetatable(module, {
    __gc = function(self)
--         if powerWatcher then powerWatcher:stop() end
        if module.menuTitleChanger then module.menuTitleChanger:stop() end
    end,
})

-- module.powerWatcher = powerWatcher

return module.start()
