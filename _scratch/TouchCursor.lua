--- === TouchCursor ===
--- Speed up text edits and navigations by using the space bar
--- as a modifier key (but still lets you type spaces).
--- Allowing you to use letter keys as up, down, left, right,
--- delete, return, home, and end so your hands can comfortably
--- stay within the range of the letter keys.

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "TouchCursor"
obj.version = "0.1"
obj.author = "Kevin Li <kevinli020508@gmail.com>"
obj.homepage = "https://github.com/AlienKevin/touchcursor-macos"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.spaceDown = false
obj.normalKey = ""
obj.produceSpace = true
obj.modifiersDown = {}

-- Source: https://stackoverflow.com/a/641993/6798201
function table.shallowCopy(t)
    local t2 = {}
    for k,v in pairs(t) do
      t2[k] = v
    end
    return t2
end

-- listen to keypress on modifiers
obj._flagWatcher = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, function(event)
    obj.modifiersDown = event:getFlags()
    print("obj.modifiersDown[\"ctrl\"] " .. tostring(obj.modifiersDown["ctrl"]))
    print("obj.modifiersDown[\"shift\"] " .. tostring(obj.modifiersDown["shift"]))
end):start()

function obj:init()
    self._downWatcher = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
        local currKey = hs.keycodes.map[event:getKeyCode()]
        -- print(currKey .. " is down".." normalKey is " .. normalKey)
        if currKey == self.normalKey then
            if self.normalKey == "space" then
                -- print("generate space up")
                hs.eventtap.event.newKeyEvent("space", false):post()
            end
            return false
        end
        if currKey == "space" then
            self.spaceDown = true
            self.produceSpace = true
            return true
        end
        if self.spaceDown then
            local keyTable = {
                ["i"] = "up",
                ["j"] = "left",
                ["k"] = "down",
                ["l"] = "right",
                ["p"] = "delete",
                ["o"] = "end",
                ["u"] = "home",
                ["h"] = "return",
                ["m"] = "d"
            }
            local newKey = keyTable[currKey]
            local newModifiers = table.shallowCopy(obj.modifiersDown)
            if newKey ~= nil then
                self.produceSpace = false
                self.normalKey = newKey
                -- print("newModifiers[\"ctrl\"] " .. tostring(newModifiers["ctrl"]))
                -- print("newModifiers[\"shift\"] " .. tostring(newModifiers["shift"]))
                if currKey == "m" then
                    newModifiers["ctrl"] = true
                end
                hs.eventtap.event.newKeyEvent(newKey, true):setFlags(newModifiers):post()
                if currKey == "m" then
                    newModifiers["ctrl"] = false
                end
                hs.eventtap.event.newKeyEvent(newKey, false):setFlags(newModifiers):post()
                return true
            end
        end
        return false
    end):start()

    self._upwatcher = hs.eventtap.new({ hs.eventtap.event.types.keyUp }, function(event)
        local currKey = hs.keycodes.map[event:getKeyCode()]
        -- print(currKey .. " is up".." normalKey is " .. normalKey)
        if currKey == self.normalKey then
            self.normalKey = ""
            return false
        end
        if currKey == "space" then
            self.spaceDown = false
            self.normalKey = ""
            if self.produceSpace then
                self.normalKey = "space"
                -- print("generate space down")
                hs.eventtap.event.newKeyEvent("space", true):post()
                return true
            end
        end
        return false
    end):start()
end

return obj
