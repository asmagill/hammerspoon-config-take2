-- simple hotkey to allow creating a new empty text file and opening it when a finder window is focused

local axuielement = require("hs.axuielement")
local dialog      = require("hs.dialog")
local fs          = require("hs.fs")
local application = require("hs.application")
local hotkey      = require("hs.hotkey")

local module = {}

-- adjust as you see fit
local placeholderText = ".txt"
local modifiers, key  = { "cmd", "alt", "ctrl" }, "t"

-- now to the prime attraction:
local createNewEmptyFile = function()
    local focusedApp = application.frontmostApplication()
    -- without this, dialogs won't take keyboard focus without clicking on them first
    application.launchOrFocus("Hammerspoon")

    -- make sure a window is focused
    local win = axuielement.applicationElement("Finder").AXFocusedWindow
    if not (win and win.AXTitle) then
        dialog.blockAlert("No window is currently focused in the Finder", "")
        focusedApp:activate() -- return focus from whence we came
        return
    end

    -- make sure we can get a path for the window
    local path = win:childrenWithRole("AXStaticText")[1].AXValue
    if not path:match("^/") then
        dialog.blockAlert("Can't create file in focused window", "")
        focusedApp:activate() -- return focus from whence we came
        return
    end

    -- prompt for filename
    local btn, file = dialog.textPrompt("New file to create:", "", placeholderText, "OK", "Cancel")
    -- but return if they cancel or don't type in anything
    if btn ~= "OK" or file == "" or file == placeholderText then
        focusedApp:activate() -- return focus from whence we came
        return
    end

    -- make sure file doesn't already exist
    local status, err = fs.touch(path .. "/" .. file)
    if not status and err ~= "No such file or directory" then
        dialog.blockAlert("Error checking to see if file exists:", err)
        focusedApp:activate() -- return focus from whence we came
        return
    end

    if not status then
        -- create new empty file
        local f = io.open(path .. "/" .. file, "w")
        if not f then
            dialog.blockAlert("Unable to create new file", "")
            focusedApp:activate() -- return focus from whence we came
            return
        end
        f:close()
    end

    -- now open it in default editor
    hs.open(path .. "/" .. file)
end

module._hotkey = hotkey.new(modifiers , key, createNewEmptyFile)

-- I like labels better than numbers... easier to tell what they mean at a glance
local intToEvent = function(num)
    local answer = "unknown: " .. tostring(num)
    for k,v in pairs(application.watcher) do
        if type(v) == "number" and v == num then
            answer = k
            break
        end
    end
    return answer
end

-- only activate hotkey within Finder and deactivate it again when we leave
module._appWatcher = application.watcher.new(function(name, event, obj)
    event = intToEvent(event)
    if name == "Finder" then
        if event == "activated" then
            module._hotkey:enable()
        elseif event == "deactivated" then
            module._hotkey:disable()
        end
    end
end):start()

return module
