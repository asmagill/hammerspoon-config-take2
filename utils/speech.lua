--
-- hold down fn, even when on, or command is ignored (minimizes false positives in noisy
-- environments.)
--
local module, placeholder = {}, {}

local speech   = require("hs.speech")
local listener = speech.listener
local fnutils  = require("hs.fnutils")
local log      = require("hs.logger").new("mySpeech","warning")
local settings = require("hs.settings")
local eventtap = require("hs.eventtap")
local watchable = require"hs.watchable"

local window      = require"hs.window"

-- local hue   = require("hs._asm.hue")
local timer = require("hs.timer")

local commands = {}
local title    = "Hammerspoon"
local listenerCallback = function(listenerObj, text)
    if eventtap.checkKeyboardModifiers().fn then
        if commands[text] then
            commands[text]()
        else
            log.wf("Unrecognized command '%s' received", text)
        end
    else
        log.vf("FN not depressed -- ignoring command '%s'", text)
    end
end

local updateCommands = function()
    if module.recognizer then
        local cmdList = {}
        for k,v in fnutils.sortByKeys(commands) do
            table.insert(cmdList, k)
        end
        module.recognizer:commands(cmdList)
    end
end

module.log = log
module.commands = commands

module.watchables = watchable.new("utils.speech")
module.watchables.isListening = false

module.add = function(text, func)
    assert(type(text) == "string", "command must be a string")
    assert(type(func) == "function", "action must be a function")

    if commands[text] then
        error("Command '"..text.."' is already registered", 2)
    end
    commands[text] = func

    updateCommands()
    return placeholder
end

module.remove = function(text)
    assert(type(text) == "string", "command must be a string")

    if commands[text] then
        commands[text] = nil
    else
        error("Command '"..text.."' is not registered", 2)
    end

    updateCommands()
    return placeholder
end

module.start = function()
    updateCommands() -- should be current, but just in case
    module.recognizer:title(title):start()
    settings.set("_asm.listener", true)
    if (module.listenLabel) then
        local screen = require("hs.screen").primaryScreen():fullFrame()
        module.listenLabel:show():setFrame{
            x = screen.x + 5, y = screen.y + screen.h - 21,
            h = 14, w = 150
        }
    end
    module.watchables.isListening = true
    return placeholder
end

module.stop = function()
    module.recognizer:title("Disabled: "..title):stop()
    if (module.listenLabel) then module.listenLabel:hide() end
    module.watchables.isListening = false
    return placeholder
end

module.isListening = function()
    if module.recognizer then
        return module.recognizer:isListening()
    else
        return nil
    end
end

module.disableCompletely = function()
    if module.recognizer then
        module.recognizer:delete()
    end
    module.recognizer = nil
    setmetatable(placeholder, nil)
    if (module.listenLabel) then
        module.listenLabel = module.listenLabel:delete()
    end
    settings.set("_asm.listener", false)
    module.watchables.isListening = false
end

module.init = function()
    if module.recognizer then
        error("Listener already initialized", 2)
    end
    module.recognizer = listener.new(title):setCallback(listenerCallback)
                                    :foregroundOnly(false)
                                    :blocksOtherRecognizers(false)
    local screen = require("hs.screen").primaryScreen():fullFrame()
    module.listenLabel = require("hs.drawing").text({
                                    x = screen.x + 5, y = screen.y + screen.h - 21,
                                    h = 14, w = 150
                                }, require("hs.styledtext").new("Hold FN while speaking...", {
                                    font = { name = "Menlo-Italic", size = 10 },
                                    color = { list = "Crayons", name = "Sky" },
                                    paragraphStyle = { lineBreak = "clip" }
                                })):setBehaviorByLabels{"canJoinAllSpaces"}
                                :setLevel("popUpMenu")
                                :show()

    return setmetatable(placeholder,  {
        __index = function(_, k)
            if module[k] then
                if type(module[k]) ~= "function" then return module[k] end
                return function(_, ...) return module[k](...) end
            else
                return nil
            end
        end,
        __tostring = function(_) return module.recognizer:title() end,
        __pairs = function(_) return pairs(module) end,
    })
end

placeholder.init = function() return module.init() end

module.add("Hammerspoon Console", hs.openConsole)
module.add("System Console", function() require("hs.application").launchOrFocus("Console") end)
-- module.add("Open Editor", function() require("hs.application").launchOrFocus("BBEdit") end)
-- module.add("Open Browser", function() require("hs.application").launchOrFocus("Safari") end)
-- module.add("Open SmartGit", function() require("hs.application").launchOrFocus("SmartGit") end)
-- module.add("Open Mail", function() require("hs.application").launchOrFocus("Mail") end)
module.add("Terminal", function() require("hs.application").launchOrFocus("Terminal") end)

local extraCommandsTime = 10

-- local lightsOnFunction
-- lightsOnFunction = function()
--     module.remove("Lights")
--     module.add("Lights", function() end)
-- 
--     module.add("On", function()
--         for i, v in ipairs(hue.default:paths("lights", { on = false })) do hue.default:put(v .. "/state", { on = true }) end
--         hue.default:put(hue.default:paths("lights", { type = "color" }, true)[1] .. "/state", { effect="none" })
--         hue.default:put(hue.default:paths("lights", { type = "color" }, true)[1] .. "/state", { ct = 366 })
--         module._lightTimer:setNextTrigger(extraCommandsTime)
--     end)
--     module.add("Off", function()
--         for i, v in ipairs(hue.default:paths("lights", { on = true })) do hue.default:put(v .. "/state", { on = false }) end
--         module._lightTimer:setNextTrigger(extraCommandsTime)
--     end)
--     module.add("Dimmer", function()
--         for i, v in ipairs(hue.default:paths("lights", { on = true })) do hue.default:put(v .. "/state", { bri_inc = -64 }) end
--         module._lightTimer:setNextTrigger(extraCommandsTime)
--     end)
--     module.add("Brighter", function()
--         for i, v in ipairs(hue.default:paths("lights", { on = true })) do hue.default:put(v .. "/state", { bri_inc = 64 }) end
--         module._lightTimer:setNextTrigger(extraCommandsTime)
--     end)
--     module.add("Night Mode", function()
--         for i, v in ipairs(hue.default:paths("lights", { on = true })) do hue.default:put(v .. "/state", { on = false }) end
--         hue.default:put(hue.default:paths("lights", { type = "color" }, true)[1] .. "/state", { on = true, bri = 32, sat = 254, effect="colorloop" })
--         module._lightTimer:setNextTrigger(extraCommandsTime)
--     end)
--     module._lightTimer = timer.doAfter(extraCommandsTime, function()
--         module._lightTimer:stop()
--         module._lightTimer = nil
--         module.remove("Lights")
--         module.add("Lights", lightsOnFunction)
-- 
--         module.remove("On")
--         module.remove("Off")
--         module.remove("Dimmer")
--         module.remove("Brighter")
--         module.remove("Night Mode")
--     end)
-- end
-- 
-- module.add("Lights", lightsOnFunction)

module.add("Re-Load Hammerspoon", hs.reload)
module.add("Re-Launch Hammerspoon", _asm.relaunch)
module.add("Toggle Command List", function()
    local axuielement = require"hs._asm.axuielement"
    local dictationWindows = fnutils.ifilter(window.allWindows(), function(_)
        return _:role() == "AXButton" and _:application():name() == "Dictation"
    end)
    local target = (#dictationWindows == 1) and dictationWindows[1]
                   or fnutils.find(dictationWindows, function(_) return _:subrole() == "AXCloseButton" end)
    axuielement.windowElement(target):doPress()
end)

-- module.add("Stop Listening", module.stop)
module.add("Go away for a while", module.disableCompletely)

if settings.get("_asm.listener") then placeholder.init():start() end

return placeholder
