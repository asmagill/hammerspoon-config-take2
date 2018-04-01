local module = {}

local iokit = require("hs._asm.iokit")

module.host = {
    idleTime = function()
        local hid = iokit.servicesForClass("IOHIDSystem")[1]
        local idle = hid:properties().HIDIdleTime
        if type(idle) == "string" then idle = string.unpack("J", idle) end
        return idle >> 30
    end,

    vramSize = function()
        local results = {}
        local pci = iokit.servicesForClass("IOPCIDevice")
        for i,v in ipairs(pci) do
            local ioname = v:searchForProperty("IOName")
            if ioname and ioname == "display" then
                local model = v:searchForProperty("model")
                if model then
                    local inBytes = true
                    local vramSize = v:searchForProperty("VRAM,totalsize")
                    if not vramSize then
                        inBytes = false
                        vramSize = v:searchForProperty("VRAM,totalMB")
                    end
                    if vramSize then
                        if type(vramSize) == "string" then vramSize = string.unpack("J", vramSize) end
                        if inBytes then vramSize = vramSize >> 20 end
                    else
                        vramSize = -1
                    end
                    results[model] = vramSize
                end
            end
        end
        return results
    end,
}

module.usb = {
    attachedDevices = function()
        local usb = iokit.servicesForClass("IOUSBDevice")
        local results = {}
        for i,v in ipairs(usb) do
            local properties = v:properties()
            table.insert(results, {
                productName = properties["USB Product Name"],
                vendorName  = properties["USB Vendor Name"],
                productID   = properties["idProduct"],
                vendorID    = properties["idVendor"],
            })
        end
        return results
    end,
}

module.battery = {
    amperage = function()
        local bat = iokit.servicesForClass("AppleSmartBattery")[1]
        return bat:properties().Amperage
    end,
    capacity = function()
        local bat = iokit.servicesForClass("AppleSmartBattery")[1]
        return bat:properties().CurrentCapacity
    end,
    cycles = function()
        local bat = iokit.servicesForClass("AppleSmartBattery")[1]
        return bat:properties().CycleCount
    end,
    designCapacity = function()
        local bat = iokit.servicesForClass("AppleSmartBattery")[1]
        return bat:properties().DesignCapacity
    end,
    getAll = function()
        local results = {}
        for k,v in pairs(module.battery) do
            if k ~= "getAll" then
                local ans = v()
                if type(ans) == "nil" then ans = "n/a" end
                results[k] = ans
            end
        end
        return results
    end,
--     health
--     healthCondition
    isCharged = function()
        local bat = iokit.servicesForClass("AppleSmartBattery")[1]
        return bat:properties().FullyCharged
    end,
    isCharging = function()
        local bat = iokit.servicesForClass("AppleSmartBattery")[1]
        return bat:properties().IsCharging
    end,
--     isFinishingCharge
    maxCapacity = function()
        local bat = iokit.servicesForClass("AppleSmartBattery")[1]
        return bat:properties().MaxCapacity
    end,
--     name
--     otherBatteryInfo
    percentage = function()
        local cur, max =  module.battery.capacity(), module.battery.maxCapacity()
        if type(cur) == "number" and type(max) == "number" then
            return (cur / max) * 100
        else
            return nil
        end
    end,
--     powerSource
--     privateBluetoothBatteryInfo
--     psuSerial
    timeRemaining = function()
        local bat = iokit.servicesForClass("AppleSmartBattery")[1]
        return bat:properties().TimeRemaining
    end,
--     timeToFullCharge
    voltage = function()
        local bat = iokit.servicesForClass("AppleSmartBattery")[1]
        return bat:properties().Voltage
    end,
    watts = function()
        local amp, volt =  module.battery.amperage(), module.battery.voltage()
        if type(amp) == "number" and type(volt) == "number" then
            return amp * volt / 1000000
        else
            return nil
        end
    end,
}
return module
