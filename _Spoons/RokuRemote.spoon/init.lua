-- TODO:
--    recode -- some of this is a little on the ugly side, and there are better ways to do somethings now...
--        redo menu code?
--        move eventtaps to coroutines (for move at least, others?)
--        obj __newindex for settings
--
--    document both spoons
--
-- +  add _Settings menu
-- +  A/B (at least as keybindings?)
-- +  implement keyboard support
-- +  FindRemote useful?
-- +  add device image to _Device menu and display?
--    tooltip on hover over buttons?
--        add setting to suppress
--  ? Search?
--
--    add more keyboard equivalents?
--        editable through setting?

--- === RokuRemote ===
---
--- Provides an on screen remote control for controlling Roku devices.
---
--- Requires the RokuControl spoon.
---
--- Download: `svn export https://github.com/asmagill/hammerspoon-config/trunk/_Spoons/RokuControl.spoon`

local screen     = require("hs.screen")
local canvas     = require("hs.canvas")
local geometry   = require("hs.geometry")
local settings   = require("hs.settings")
local hotkey     = require("hs.hotkey")
local fnutils    = require("hs.fnutils")
local mouse      = require("hs.mouse")
local menu       = require("hs.menubar")
local stext      = require("hs.styledtext")
local timer      = require("hs.timer")
local host       = require("hs.host")
local image      = require("hs.image")
local caffeinate = require("hs.caffeinate")
local eventtap   = require("hs.eventtap")
local spoons     = require("hs.spoons")
local dialog     = require("hs.dialog")
local alert      = require("hs.alert")
local keycodes   = require("hs.keycodes")

local events     = eventtap.event.types

local roku     = hs.loadSpoon("RokuControl")

local logger   = require("hs.logger")

local obj    = {
-- Metadata
    name      = "RokuRemote",
    author    = "A-Ron",
    homepage  = "https://github.com/asmagill/hammerspoon-config/tree/master/_Spoons/RokuRemote.spoon",
    license   = "MIT - https://opensource.org/licenses/MIT",
    spoonPath = spoons.scriptPath(),
    spoonMeta = "placeholder for _coresetup metadata creation",
}

-- version is outside of obj table definition to facilitate its auto detection by
-- external documentation generation scripts
obj.version   = "0.1"

local metadataKeys = {} ; for k, v in require("hs.fnutils").sortByKeys(obj) do table.insert(metadataKeys, k) end

obj.__index = obj
local _log = logger.new(obj.name)
obj.logger = _log

obj._layout = dofile(obj.spoonPath .. "layout.lua")

-- for timers, etc so they don't get collected
local __internals = {
    timers       = {},
    cachedImages = {},
--     keyRepeating = {},
    menus        = {
        _Launch   = menu.new():removeFromMenuBar(),
        _Device   = menu.new():removeFromMenuBar(),
        _Move     = menu.new():removeFromMenuBar(),
        _Settings = menu.new():removeFromMenuBar(),
    }
}

---------- Spoon Variables ----------

local startingPosition = settings.get(obj.name .. "_position") or "LR"

-- for spoon level variables -- they are wrapped by obj's __index/__newindex metamethods so they appear
-- as regular variables and are thus documented as such; by doing this we can consolidate data validation
-- in obj's metatable rather than have to test each time they are used
local __spoonVariables = {
    position         = startingPosition,
    remoteColor      = settings.get(obj.name .. "_remoteColor")      or { white = .25, alpha = .75 },
    buttonFrameColor = settings.get(obj.name .. "_buttonFrameColor") or { white = 0 },
    buttonHoverColor = settings.get(obj.name .. "_buttonHoverColor") or { red = 1, green = 1, alpha = .5 },
    buttonClickColor = settings.get(obj.name .. "_buttonClickColor") or { red = 1, green = 1, alpha = .75 },
    autoDim          = settings.get(obj.name .. "_autoDim")          or true,
    enableKeys       = settings.get(obj.name .. "_enableKeys")       or true,
    inactiveAlpha    = settings.get(obj.name .. "_inactiveAlpha")    or .25,
    activeAlpha      = settings.get(obj.name .. "_activeAlpha")      or .75,
    keyEquivalents   = settings.get(obj.name .. "_keyEquivalents")   or {
        Play   = { {},        "space",      },
        Select = { {},        "return",     },
        Left   = { {},        "left",  true },
        Right  = { {},        "right", true },
        Up     = { {},        "up",    true },
        Down   = { {},        "down",  true },
        Home   = { { "cmd" }, "h",          },
        Back   = { { "cmd" }, "b",          },
        A      = { {},        "a"           },
        B      = { {},        "b"           },
    }
}

---------- Local Functions ----------

local keysEnabled = false

local suppressAutoDim = false

local goDark = function()
    if __internals._rCanvas then
        if not suppressAutoDim and __spoonVariables.autoDim then
            for i = 2, #__internals._rCanvas,1  do
                __internals._rCanvas[i].action = "skip"
            end
            __internals._rCanvas["background"].fillColor.alpha = __spoonVariables.inactiveAlpha
        end

        -- reset hover coloring even if we're not supposed to autoDim
        for i = 2, #__internals._rCanvas,1  do
            if __internals._rCanvas[i].trackMouseEnterExit then
                __internals._rCanvas[i].fillColor = { alpha = 0 }
            end
        end

        if keysEnabled then __internals._modalKeys:exit() end
    end
end

local updateRemoteColors = function()
    __internals._rCanvas["background"].fillColor = __spoonVariables.remoteColor

    for i = 1, #__internals._rCanvas, 1 do
        local entry = __internals._rCanvas[i]
        if not entry.id:match("_text$") and not
               fnutils.contains({ "background", "_Close", "_Move", "_Settings" }, entry.id) then
            entry.strokeColor = __spoonVariables.buttonFrameColor
        end
    end
end

local updateRemoteCanvas = function()
    if __internals._rCanvas then
        if __internals._rCanvas:isShowing() then
            local mousePos = mouse.absolutePosition()
            if geometry.inside(mousePos, __internals._rCanvas:frame()) then
                __internals._rCanvas["background"].fillColor.alpha = __spoonVariables.activeAlpha

                local availableButtons = __internals._rDevice and __internals._rDevice:remoteButtons() or {}
                for k,v in pairs(obj._layout.buttons) do
                    local theChar = v.char
                    if type(theChar) == "function" then
                        theChar = theChar(__internals._rDevice)
                        __internals._rCanvas[k .. "_text"].text = theChar
                    end
                    if v.enabled then
                        __internals._rCanvas[k].action = v.canvasFrameAction or "strokeAndFill"
                        if theChar then
                            __internals._rCanvas[k .. "_text"].action = v.canvasTextAction  or "stroke"
                        end
                        if v.image then
                            __internals._rCanvas[k .. "_image"].action = v.canvasImageAction or "stroke"
                        end

--                         if k == "_Close" then
--                         elseif k == "_Move" then
--                         elseif k == "_Settings" then

                        if k == "_Device" then
                            if __internals._rDevice then
                                if not __internals._rDeviceImage then
                                    local img     = __internals._rDevice:deviceImage()
                                    local imgSize = nil
                                    if img then
                                        imgSize = img:size()
                                        img = img:size({
                                            h = obj._layout.buttonSize,
                                            w = obj._layout.buttonSize * imgSize.w / imgSize.h,
                                        })
                                    else
                                        img = true
                                    end
                                    __internals._rDeviceImage = img

                                    local fullFrame = __internals._rCanvas[k].frame_raw
                                    -- it's not a "real" table but a canvas construct that allows direct modification
                                    -- so assignment below will fail without this
                                    fullFrame = { x = fullFrame.x, y = fullFrame.y, w = fullFrame.w, h = fullFrame.h }
                                    if img == true then -- no device image available
                                        __internals._rCanvas[k .. "_text"].frame   = fullFrame
                                        __internals._rCanvas[k .. "_image"].frame  = fullFrame
                                        __internals._rCanvas[k .. "_image"].action = "skip"
                                        __internals._rCanvas[k .. "_image"].image  = nil
                                    else
                                        local imageWidth = obj._layout.buttonSize * imgSize.w / imgSize.h
                                        local textFrame = {
                                            x = fullFrame.x + imageWidth,
                                            y = fullFrame.y,
                                            h = obj._layout.buttonSize,
                                            w = fullFrame.w - imageWidth,
                                        }
                                        local imageFrame = {
                                            x = fullFrame.x,
                                            y = fullFrame.y,
                                            h = obj._layout.buttonSize,
                                            w = imageWidth,
                                        }
                                        __internals._rCanvas[k .. "_text"].frame   = textFrame
                                        __internals._rCanvas[k .. "_image"].frame  = imageFrame
                                        __internals._rCanvas[k .. "_image"].image  = img
                                    end
                                end
                                __internals._rCanvas[k .. "_text"].text = stext.new(__internals._rDevice:name(), {
                                                                              font           = {
                                                                                  name = "Menlo",
                                                                                  size = 14
                                                                              },
                                                                              paragraphStyle = {
                                                                                  lineBreak = "truncateTail",
                                                                              },
                                                                              color          = { white = 1 },
                                                                          })
                            else
                                __internals._rCanvas[k .. "_text"].text = theChar
                            end
                        elseif k == "_Active" then
                            if __internals._rDevice then
                                local appID = __internals._rDevice:currentAppID()
                                local icon = appID and __internals.cachedImages[appID]
                                if appID and not icon then
                                    icon = __internals._rDevice:currentAppIcon()
                                    if icon then
                                        __internals.cachedImages[appID] = icon:size{ h = 32, w = 64 }
                                    end
                                end

                                if not icon then
                                    local iconCanvas = canvas.new(__internals._rCanvas[k].frame_raw)
                                    local text = stext.new(__internals._rDevice:currentApp(), {
                                        font = { name = "Menlo", size = 18 },
                                        paragraphStyle = { alignment = "center", lineBreak = "truncateTail", allowsTighteningForTruncation = false },
                                        color = { white = 1 },
                                    })
                                    local textFrame = iconCanvas:minimumTextSize(text)
                                    local iconFrame = iconCanvas:frame()
                                    textFrame.x = (iconFrame.w - textFrame.w) / 2
                                    textFrame.y = (iconFrame.h - textFrame.h) / 2
                                    if textFrame.x < 0 then
                                        textFrame.x = 0
                                        textFrame.w = iconFrame.w
                                    end
                                    if textFrame.y < 0 then
                                        textFrame.y = 0
                                        textFrame.h = iconFrame.h
                                    end

                                    iconCanvas[1] = {
                                        type  = "text",
                                        frame = textFrame,
                                        text  = text,
                                    }
                                    icon = iconCanvas:imageFromCanvas()
                                    iconCanvas:delete()
                                end
                                __internals._rCanvas[k .. "_image"].image  = icon
                            else -- this one's actually hidden when no device has been selected
                                __internals._rCanvas[k].action             = "skip"
                                __internals._rCanvas[k .. "_image"].action = "skip"
                            end
                        else
                            if not v.alwaysDisplay then
                                local visible = __internals._rDevice                                     and
                                                (k:match("^_") or fnutils.contains(availableButtons, k)) and
                                                (not v.active or v.active(__internals._rDevice))

                                if not visible then
                                    __internals._rCanvas[k].action = "skip"
                                    if theChar then
                                        __internals._rCanvas[k .. "_text"].action = "skip"
                                    end
                                    if v.image then
                                        __internals._rCanvas[k .. "_image"].action = "skip"
                                    end
                                end
                            end
                        end
                    end
                end
                if #availableButtons > 0 and __spoonVariables.enableKeys and not keysEnabled then
                    __internals._modalKeys:enter()
                end
            else
                goDark()
            end
        end
    end
end

local doDelayedUpdate = function(when)
    local uuid = host.uuid()
    __internals.timers[uuid] = timer.doAfter(when, function()
        updateRemoteCanvas()
        -- a little paranoid, but I've seen wierd timer race conditions
        __internals.timers[uuid]:stop()
        __internals.timers[uuid] = nil
    end)
end

local updateRealPosition = function(position)
    position = position or __spoonVariables.position
    if type(position) == "string" then
        local sz = {
            w = (obj._layout.gridSize.w + 1) * obj._layout.buttonSize,
            h = (obj._layout.gridSize.h + 1.5) * obj._layout.buttonSize,
        }
        local sff = screen.mainScreen():fullFrame()
        local sf  = screen.mainScreen():frame()
        -- we want to consider the menu, but ignore the dock, so...
        local mh = sf.y - sff.y
        sff.y, sff.h = sff.y + mh, sff.h - mh

        local x, y

        if position == "UL" then
            x = sff.x + obj._layout.buttonSize / 2
            y = sff.y + obj._layout.buttonSize / 2
        elseif position == "UR" then
            x = sff.x + sff.w - (sz.w + obj._layout.buttonSize / 2)
            y = sff.y + obj._layout.buttonSize / 2
        elseif position == "LL" then
            x = sff.x + obj._layout.buttonSize / 2
            y = sff.y + sff.h - (sz.h + obj._layout.buttonSize / 2)
        else -- if position == "LR" then -- default
            x = sff.x + sff.w - (sz.w + obj._layout.buttonSize / 2)
            y = sff.y + sff.h - (sz.h + obj._layout.buttonSize / 2)
        end
        __spoonVariables.position = { x = x, y = y }
    end
end

local colorPickerWarningSeen = false
local _cover

local remoteMouseCallback = function(c, m, id, x, y)
    if id == "background" then
        if m == "mouseEnter" then
            updateRemoteCanvas()
        elseif m == "mouseExit" then
            -- we get a mouseExit when entering a button, so don't dim unless we're really
            -- leaving the remote
            if not geometry.inside({ x = x, y = y }, c[id].frame_raw) then
                updateRemoteCanvas()
            end
        end
    else
        local buttonDef = obj._layout.buttons[id]
        if m == "mouseEnter" then
            c[id].fillColor = __spoonVariables.buttonHoverColor
        elseif m == "mouseExit" then
            c[id].fillColor = { alpha = 0 }
        else
            if buttonDef.active and not buttonDef.active(__internals._rDevice) then return end

            -- for all buttons which callback

            if m == "mouseUp" then
                c[id].fillColor = __spoonVariables.buttonHoverColor
                if buttonDef.triggerUpdate then doDelayedUpdate(.1) end
            elseif m == "mouseDown" then
                c[id].fillColor = __spoonVariables.buttonClickColor
            end

            -- now do specific button things

            if not id:match("^_") then

                if m == "mouseUp" then
                    if buttonDef.sendUpDown then
                        __internals._rDevice:remote(id, false)
                    else
                        __internals._rDevice:remote(id)
                    end
                elseif m == "mouseDown" then
                    if buttonDef.sendUpDown then
                        __internals._rDevice:remote(id, true)
                    end
                end

            elseif id == "_Device" then
                if m == "mouseDown" then
                    local popup = {}
                    for k,v in pairs(roku:availableDevices()) do
                        local img = v:deviceImage()
                        if img then
                            local imgSize = img:size()
                            img = img:setSize({
                                h = obj._layout.buttonSize,
                                w = obj._layout.buttonSize * imgSize.w / imgSize.h,
                            })
                        end
                        table.insert(popup, {
                            title   = v:name(),
                            image   = img,
                            checked = (v == __internals._rDevice),
                            fn      = function(...)
                                obj:selectDevice(v:sn())
                                doDelayedUpdate(.1)
                            end,
                        })
                    end
                    table.sort(popup, function(a,b) return a.title < b.title end)
                    table.insert(popup, { title = "-" })
                    table.insert(popup, {
                        title = "Rescan network",
                        fn    = function(...)
                                    roku:discoverDevices()
                                    doDelayedUpdate(.1)
                                end,
                    })
                    local frame = __internals._rCanvas[id].frame_raw
                    local topLeft = __internals._rCanvas:topLeft()
                    -- allow arrow keys to be used in the pop-up menu
                    if __spoonVariables.enableKeys and keysEnabled then __internals._modalKeys:exit() end
                    __internals.menus[id]:setMenu(popup):popupMenu({
                        x = frame.x + topLeft.x,
                        y = frame.y + topLeft.y + frame.h
                    }, true)
                    -- they should get restarted during update for mouseUp or upon re-entry if mouse outside
                    doDelayedUpdate(.1) -- in case they release outside of the menu
                end
            elseif id == "_Launch" then
                if m == "mouseDown" then
                    local popup = {}
                    local currentApp = __internals._rDevice:currentApp()
                    for _,v in ipairs(__internals._rDevice:availableApps()) do
                        local icon = __internals.cachedImages[v[2].id]
                        if not icon then
                            icon = image.imageFromURL(__internals._rDevice:url("/query/icon/") .. v[2].id)
                            __internals.cachedImages[v[2].id] = icon:size{ h = 32, w = 64 }
                        end
                        table.insert(popup, {
                            title   = v[1],
                            checked = (v[1] == currentApp),
                            image   = icon,
                            fn      = function(...)
                                __internals._rDevice:launch(v[2].id)
                                doDelayedUpdate(.1)
                            end,
                        })
                    end
                    table.sort(popup, function(a,b) return a.title < b.title end)

                    local frame = __internals._rCanvas[id].frame_raw
                    local topLeft = __internals._rCanvas:topLeft()
                    -- allow arrow keys to be used in the pop-up menu
                    if __spoonVariables.enableKeys and keysEnabled then __internals._modalKeys:exit() end
                    __internals.menus[id]:setMenu(popup):popupMenu({
                        x = frame.x + topLeft.x,
                        y = frame.y + topLeft.y + frame.h
                    }, true)
                    -- they should get restarted during update for mouseUp or upon re-entry if mouse outside
                    doDelayedUpdate(.1) -- in case they release outside of the menu
                end
            elseif id == "_Settings" then
                if m == "mouseDown" then
                    local commands = {}
                    for _, v in ipairs(buttonDef.menu) do
                        if not v[3] then
                            table.insert(commands, { title = v[1], disabled = true })
                        elseif v[3] == "boolean" then
                            table.insert(commands, {
                                title    = v[1],
                                fn       = function(...)
                                    __spoonVariables[v[2]] = not __spoonVariables[v[2]]
                                    doDelayedUpdate(.1)
                                end,
                                checked = __spoonVariables[v[2]] and true or false,
                            })
                        elseif v[3] == "color" then
                            table.insert(commands, {
                                title = v[1],
                                fn    = function(...)
                                    if not colorPickerWarningSeen then
                                        colorPickerWarningSeen = true
                                        dialog.blockAlert("", "Hold the command key when closing the color picker to revert to the previous color")
                                    end
                                    local originalColor = __spoonVariables[v[2]]
                                    suppressAutoDim = true
                                    dialog.color.mode("RGB")
                                    dialog.color.showsAlpha(true)
                                    dialog.color.color(__spoonVariables[v[2]])
                                    dialog.color.callback(function(c, closed)
                                        __spoonVariables[v[2]] = c
                                        if closed then
                                            dialog.color.callback(nil)
                                            if eventtap.checkKeyboardModifiers().cmd then
                                                __spoonVariables[v[2]] = originalColor
                                            end
                                            suppressAutoDim = false
                                        end
                                        updateRemoteColors()
                                    end)
                                    dialog.color.show()
                                end
                            })
                        elseif v[3] == "number" then
                            table.insert(commands, {
                                title = v[1],
                                fn    = function(...)
                                    local status, value = dialog.textPrompt(v[1], string.format("Enter a number between %.1f anf %.1f", v[4][1], v[4][2]), tostring(__spoonVariables[v[2]]), "OK", "Cancel")
                                    if status == "OK" then
                                        local newNum = tonumber(value) or __spoonVariables[v[2]]
                                        if newNum >= v[4][1] and newNum <= v[4][2] then
                                            __spoonVariables[v[2]] = newNum
                                        end
                                    end
                                    updateRemoteCanvas()
                                end
                            })
                        else
                            _log.wf("handler for type %s not found", v[3])
                            table.insert(commands, { title = v[1], disabled = true })
                        end
                    end

                    table.insert(commands, { title = "-", disabled = true })
                    table.insert(commands, {
                        title = "Save Settings",
                        fn    = function(...)
                            obj:saveSettings()
                            alert("Settings Saved")
                        end
                    })
                    table.insert(commands, {
                        title = "Clear Saved Settings",
                        fn    = function(...)
                            obj:clearSavedSettings()
                            alert("Saved Settings Cleared")
                        end
                    })

                    local frame = __internals._rCanvas[id].frame_raw
                    local topLeft = __internals._rCanvas:topLeft()
                    -- allow arrow keys to be used in the pop-up menu
                    if __spoonVariables.enableKeys and keysEnabled then __internals._modalKeys:exit() end
                    __internals.menus[id]:setMenu(commands):popupMenu({
                        x = frame.x + topLeft.x,
                        y = frame.y + topLeft.y + frame.h
                    }, true)
                    -- they should get restarted during update for mouseUp or upon re-entry if mouse outside
                    doDelayedUpdate(.1) -- in case they release outside of the menu
                end
            elseif id == "_Keyboard" then
                if m == "mouseUp" and not _cover then
                    local sf = screen.mainScreen():fullFrame()
                    local message = "Keyboard redirecting to " .. __internals._rDevice:name() .. "\n" ..
                                    "Press the Escape key to release."
                    message = stext.new(message, {
                        font = { name = "Menlo", size = 48 },
                        paragraphStyle = { alignment = "center" },
                        color = { white = 1 },
                    })
                    _cover = canvas.new(sf):level(canvas.windowLevels.popUpMenu)
                                           :bringToFront(true)
                                           :show()
                    -- this is just to intercept mouse buttons that might trigger other remote actions
                    _cover:canvasMouseEvents(true, true):mouseCallback(function(...) end)

                    local textSize = _cover:minimumTextSize(message)
                    _cover[#_cover +1] = {
                        type      = "rectangle",
                        action    = "fill",
                        fillColor = { white = .25, alpha = .75 },
                    }
                    _cover[#_cover + 1] = {
                        type          = "text",
                        frame         = {
                            x = sf.x + (sf.w - textSize.w) / 2,
                            y = sf.y + (sf.h - textSize.h) / 2,
                            w = textSize.w,
                            h = textSize.h,
                        },
                        text          = message,
                    }

                    local encodeAnyways = {
                        "$", "&", "+", ",", "/", ":", ";", "=", "?", "@", " ", "\"", "<",
                        ">", "#", "%", "{", "}", "|", "\\", "^", "~", "[", "]", "`"
                    }
                    local specialMappings = {
                        [keycodes.map["left"]]     = "Left",
                        [keycodes.map["right"]]    = "Right",
                        [keycodes.map["up"]]       = "Up",
                        [keycodes.map["down"]]     = "Down",
                        [keycodes.map["return"]]   = "Select",
                        [keycodes.map["padenter"]] = "Enter",
                        [keycodes.map["delete"]]   = "Backspace",
                    }
                    -- the mac will send multiple keyDown events if you hold (repeat) but we want
                    -- to leave that to the Roku, so record downs and eat extra downs before the
                    -- corresponding up
                    local alreadyDown = {}

                    local _watcher
                    _watcher = eventtap.new({ events.keyUp, events.keyDown }, function(e)
                        local dwn = (e:getType() == events.keyDown)
                        local kc  = e:getKeyCode()
                        local ky  = e:getUnicodeString()
                        local seq = { string.byte(ky, 1, #ky) }
                        local txt

                        if kc == keycodes.map.escape then
                            _watcher:stop()
                            _watcher = nil
                            _cover:delete()
                            _cover = nil ;
                        else
                            txt = specialMappings[kc]
                            if kc == keycodes.map["return"] and eventtap.checkKeyboardModifiers().cmd then
                                txt = "Enter"
                            end
                            if not txt then
                                if #seq == 1 and seq[1] > 31 and seq[1] < 127 and not fnutils.contains(encodeAnyways, ky) then
                                    txt = "Lit_" .. ky
                                else
                                    txt = "Lit_"
                                    for _, v in ipairs(seq) do
                                        txt = txt .. string.format("%%%0x", v):upper()
                                    end
                                end
                            end

                            if not (dwn and alreadyDown[kc]) then
                                alreadyDown[kc] = dwn or nil
                                __internals._rDevice:remote(txt, dwn, true)
                            end
                        end
                        return true
                    end):start()
                end
            elseif id == "_Close" then
                if m == "mouseUp" then obj:hide() end
            elseif id == "_Move" then
                if m == "mouseDown" then
                    if eventtap.checkMouseButtons().right or eventtap.checkKeyboardModifiers().ctrl then
                        local tl = __internals._rCanvas:topLeft()
                        local sz = __internals._rCanvas:size()
                        local popup = {
                            {
                                title = "Move to",
                                menu = {
                                    {
                                        title = "Upper Left",
                                        fn    = function(...)
                                            updateRealPosition("UL")
                                            __internals._rCanvas:topLeft(__spoonVariables.position)
                                            doDelayedUpdate(.1)
                                        end,
                                    }, {
                                        title = "Upper Right",
                                        fn    = function(...)
                                            updateRealPosition("UR")
                                            __internals._rCanvas:topLeft(__spoonVariables.position)
                                            doDelayedUpdate(.1)
                                        end,
                                    }, {
                                        title = "Lower Left",
                                        fn    = function(...)
                                            updateRealPosition("LL")
                                            __internals._rCanvas:topLeft(__spoonVariables.position)
                                            doDelayedUpdate(.1)
                                        end,
                                    }, {
                                        title = "Lower Right",
                                        fn    = function(...)
                                            updateRealPosition("LR")
                                            __internals._rCanvas:topLeft(__spoonVariables.position)
                                            doDelayedUpdate(.1)
                                        end,
                                    }
                                }
                            }, {
                                title = "-",
                            }, {
                                title = "Save as Start Position",
                                menu = {
                                    {
                                        title = "Current Position",
                                        fn    = function(...)
                                            settings.set(obj.name .. "_position", tl)
                                            alert("Location Saved")
                                        end,
                                    }, {
                                        title = "-",
                                    }, {
                                        title   = "Upper Left",
                                        checked = startingPosition == "UL",
                                        fn      = function(...)
                                            settings.set(obj.name .. "_position", "UL")
                                            startingPosition = "UL"
                                            alert("Location Saved")
                                        end,
                                    }, {
                                        title   = "Upper Right",
                                        checked = startingPosition == "UR",
                                        fn      = function(...)
                                            settings.set(obj.name .. "_position", "UR")
                                            startingPosition = "UR"
                                            alert("Location Saved")
                                        end,
                                    }, {
                                        title   = "Lower Left",
                                        checked = startingPosition == "LL",
                                        fn      = function(...)
                                            settings.set(obj.name .. "_position", "LL")
                                            startingPosition = "LL"
                                            alert("Location Saved")
                                        end,
                                    }, {
                                        title   = "Lower Right",
                                        checked = startingPosition == "LR",
                                        fn      = function(...)
                                            settings.set(obj.name .. "_position", "LR")
                                            startingPosition = "LR"
                                            alert("Location Saved")
                                        end,
                                    }
                                }
                            }, {
                                title    = "Clear Saved Start Position",
                                disabled = not settings.get(obj.name .. "_position"),
                                fn       = function(...)
                                    settings.clear(obj.name .. "_position")
                                    startingPosition = "LR"
                                    alert("Location Cleared")
                                end,
                            }
                        }
                        local frame = __internals._rCanvas[id].frame_raw
                        local topLeft = __internals._rCanvas:topLeft()
                        -- allow arrow keys to be used in the pop-up menu
                        if __spoonVariables.enableKeys and keysEnabled then __internals._modalKeys:exit() end
                        __internals.menus[id]:setMenu(popup):popupMenu({
                            x = frame.x + topLeft.x,
                            y = frame.y + topLeft.y + frame.h
                        }, true)
                        -- they should get restarted during update for mouseUp or upon re-entry if mouse outside
                        doDelayedUpdate(.1) -- in case they release outside of the menu
                    else
--                         __internals._mouseMoveTracker = eventtap.new(
--                             { events.leftMouseDragged, events.leftMouseUp },
--                             function(e)
--                                 if e:getType() == events.leftMouseUp then
--                                     __internals._mouseMoveTracker:stop()
--                                     __internals._mouseMoveTracker = nil
--                                 else
--                                     local mousePosition = mouse.absolutePosition()
--                                     __spoonVariables.position = {
--                                         x = mousePosition.x - x,
--                                         y = mousePosition.y - y,
--                                     }
--                                     __internals._rCanvas:topLeft(__spoonVariables.position)
--
--                                 end
--                             end
--                         ):start()
                        __internals._mouseMoveTracker = coroutine.wrap(function()
                            while __internals._mouseMoveTracker do
                                local pos = mouse.absolutePosition()
                                __spoonVariables.position = {
                                    x = pos.x - x,
                                    y = pos.y - y,
                                }
                                c:topLeft(__spoonVariables.position)
                                coroutine.applicationYield()
                            end
                        end)
                        __internals._mouseMoveTracker()
                    end
                elseif m == "mouseUp" then
                    __internals._mouseMoveTracker = nil
                end
--             elseif id == "_Keyboard" then
            else
                _log.wf("mousecallback for %s with %s not defined", id, m)
            end
        end
    end
end

local mimicCallback = function(id, m)
    if __internals._rCanvas then
        if __internals._rCanvas[id] then
            local frame = __internals._rCanvas[id].frame_raw
            local x, y = frame.x + frame.w / 2, frame.y + frame.h / 2
            if m == "mouseDown" then
                remoteMouseCallback(__internals._rCanvas, "mouseEnter", id, x, y)
            end
            remoteMouseCallback(__internals._rCanvas, m, id, x, y)
            if m == "mouseUp" then
                remoteMouseCallback(__internals._rCanvas, "mouseExit", id, x, y)
            end
        else
            _log.wf("unable to find %s in canvas buttons", id)
        end
    else
        _log.wf("mimicCallback invoked for %s before canvas has been created", id)
    end
end

local createRemoteCanvas = function()
    if not __internals._rCanvas then
        if type(__spoonVariables.position) == "string" then
            updateRealPosition()
        end
        local _rCanvas = canvas.new{
            x = __spoonVariables.position.x,
            y = __spoonVariables.position.y,
            w = (obj._layout.gridSize.w + 1) * obj._layout.buttonSize,
            h = (obj._layout.gridSize.h + 1.5) * obj._layout.buttonSize,
        }:level(canvas.windowLevels.popUpMenu)
         :behaviorAsLabels({"canJoinAllSpaces"})
         :mouseCallback(remoteMouseCallback)
         :clickActivating(false)

        __internals._modalKeys = hotkey.modal.new()
        __internals._modalKeys.entered = function(self)
            keysEnabled = true
        end
        __internals._modalKeys.exited = function(self)
            keysEnabled = false
        end

        _rCanvas[#_rCanvas + 1] = {
            id                  = "background",
            type                = "rectangle",
            action              = "fill",
            roundedRectRadii    = {
                xRadius = obj._layout.buttonSize / 2,
                yRadius = obj._layout.buttonSize / 2,
            },
            fillColor           = __spoonVariables.remoteColor,
            trackMouseEnterExit = true,
        }

        for k,v in pairs(obj._layout.buttons) do
            local theChar = type(v.char) == "function" and v.char() or v.char
            if v.enabled then
                local buttonFrame = v.pos and {
                    x = (v.pos.x + .5) * obj._layout.buttonSize,
                    y = (v.pos.y + 1) * obj._layout.buttonSize,
                    w = v.pos.w * obj._layout.buttonSize,
                    h = v.pos.h * obj._layout.buttonSize,
                } or {}

                if k == "_Close" then
                    local textFrame = _rCanvas:minimumTextSize(theChar)
                    local buttonFrame = {
                        x = obj._layout.buttonSize / 3,
                        y = obj._layout.buttonSize / 3,
                        w = textFrame.w + 2,
                        h = textFrame.w + 2,
                    }
                    _rCanvas[#_rCanvas + 1] = {
                        id                  = k,
                        type                = "rectangle",
                        frame               = buttonFrame,
                        strokeColor         = { alpha = 0 },
                        fillColor           = { alpha = 0 },
                        roundedRectRadii    = {
                            xRadius = buttonFrame.w / 4,
                            yRadius = buttonFrame.h / 4,
                        },
                        trackMouseDown      = true,
                        trackMouseEnterExit = true,
                        trackMouseUp        = true,
                    }

                    textFrame.x = buttonFrame.x + ((v.offset or {}).x or 0)
                    textFrame.y = buttonFrame.y + ((v.offset or {}).y or 0)
                    _rCanvas[#_rCanvas + 1] = {
                        id    = k .. "_text",
                        type  = "text",
                        frame = textFrame,
                        text  = theChar,
                    }
                elseif k == "_Move" then
                    local textFrame = _rCanvas:minimumTextSize(theChar)
                    local buttonFrame = {
                        x = (_rCanvas:frame().w - textFrame.w) / 2,
                        y = obj._layout.buttonSize / 3,
                        w = textFrame.w + 2,
                        h = textFrame.w + 2,
                    }
                    _rCanvas[#_rCanvas + 1] = {
                        id                  = k,
                        type                = "rectangle",
                        frame               = buttonFrame,
                        strokeColor         = { alpha = 0 },
                        fillColor           = { alpha = 0 },
                        roundedRectRadii    = {
                            xRadius = buttonFrame.w / 4,
                            yRadius = buttonFrame.h / 4,
                        },
                        trackMouseDown      = true,
                        trackMouseEnterExit = true,
                        trackMouseUp        = true,
                    }

                    textFrame.x = buttonFrame.x + ((v.offset or {}).x or 0)
                    textFrame.y = buttonFrame.y + ((v.offset or {}).y or 0)
                    _rCanvas[#_rCanvas + 1] = {
                        id    = k .. "_text",
                        type  = "text",
                        frame = textFrame,
                        text  = theChar,
                    }
                elseif k == "_Settings" then
                    local textFrame = _rCanvas:minimumTextSize(theChar)
                    local buttonFrame = {
                        x = _rCanvas:frame().w - (obj._layout.buttonSize / 3 + textFrame.w),
                        y = obj._layout.buttonSize / 3,
                        w = textFrame.w + 2,
                        h = textFrame.w + 2,
                    }
                    _rCanvas[#_rCanvas + 1] = {
                        id                  = k,
                        type                = "rectangle",
                        frame               = buttonFrame,
                        strokeColor         = { alpha = 0 },
                        fillColor           = { alpha = 0 },
                        roundedRectRadii    = {
                            xRadius = buttonFrame.w / 4,
                            yRadius = buttonFrame.h / 4,
                        },
                        trackMouseDown      = true,
                        trackMouseEnterExit = true,
                        trackMouseUp        = true,
                    }

                    textFrame.x = buttonFrame.x + ((v.offset or {}).x or 0)
                    textFrame.y = buttonFrame.y + ((v.offset or {}).y or 0)
                    _rCanvas[#_rCanvas + 1] = {
                        id    = k .. "_text",
                        type  = "text",
                        frame = textFrame,
                        text  = theChar,
                    }
                elseif k == "_Device" then
                    _rCanvas[#_rCanvas + 1] = {
                        id                  = k,
                        type                = "rectangle",
                        frame               = buttonFrame,
                        strokeColor         = __spoonVariables.buttonFrameColor,
                        fillColor           = { alpha = 0 },
                        roundedRectRadii    = {
                            xRadius = obj._layout.buttonSize / 4,
                            yRadius = obj._layout.buttonSize / 4,
                        },
                        trackMouseDown      = true,
                        trackMouseEnterExit = true,
                        trackMouseUp        = true,
                    }

                    local textFrame = {
                        w = buttonFrame.w,
                        h = buttonFrame.h,
                        x = buttonFrame.x + ((v.offset or {}).x or 0),
                        y = buttonFrame.y + ((v.offset or {}).y or 0),
                    }
                    _rCanvas[#_rCanvas + 1] = {
                        id     = k .. "_image",
                        action = "skip",
                        type   = "image",
                        frame  = buttonFrame,
                    }
                    _rCanvas[#_rCanvas + 1] = {
                        id    = k .. "_text",
                        type  = "text",
                        frame = textFrame,
                        text  = theChar,
                    }
                elseif k == "_Active" then
                    local imageFrame = {
                        x = buttonFrame.x +  5,
                        y = buttonFrame.y +  5,
                        w = buttonFrame.w - 10,
                        h = buttonFrame.h - 10,
                    }
                    _rCanvas[#_rCanvas + 1] = {
                        id                  = k,
                        type                = "rectangle",
                        frame               = buttonFrame,
                        strokeColor         = __spoonVariables.buttonFrameColor,
                        fillColor           = { alpha = 0 },
                        roundedRectRadii    = {
                            xRadius = obj._layout.buttonSize / 4,
                            yRadius = obj._layout.buttonSize / 4,
                        },
                    }

                    _rCanvas[#_rCanvas + 1] = {
                        id                  = k .. "_image",
                        type                = "image",
                        frame               = imageFrame,
                    }
                else
                    local textFrame = _rCanvas:minimumTextSize(theChar)
                    textFrame.x = buttonFrame.x + (buttonFrame.w - textFrame.w) / 2 + ((v.offset or {}).x or 0)
                    textFrame.y = buttonFrame.y + (buttonFrame.h - textFrame.h) / 2 + ((v.offset or {}).y or 0)

                    _rCanvas[#_rCanvas + 1] = {
                        id                  = k,
                        type                = "rectangle",
                        frame               = buttonFrame,
                        strokeColor         = __spoonVariables.buttonFrameColor,
                        fillColor           = { alpha = 0 },
                        roundedRectRadii    = {
                            xRadius = obj._layout.buttonSize / 4,
                            yRadius = obj._layout.buttonSize / 4,
                        },
                        trackMouseDown      = true,
                        trackMouseEnterExit = true,
                        trackMouseUp        = true,
                    }

                    if theChar then
                        _rCanvas[#_rCanvas + 1] = {
                            id    = k .. "_text",
                            type  = "text",
                            frame = textFrame,
                            text  = theChar,
                        }
                    end

                    if v.image then
                        _rCanvas[#_rCanvas + 1] = {
                            id    = k .. "_image",
                            type  = "image",
                            frame = buttonFrame,
                            image = type(v.image) ~= boolean and v.image or nil
                        }
                    end

                    local keyEquivalent = __spoonVariables.keyEquivalents[k]
                    if keyEquivalent then
                        local mods, key, repeats = keyEquivalent[1], keyEquivalent[2], keyEquivalent[3]

                        if repeats then
                            -- for repeaters (all non-special buttons?), it's the mouseUp action
                            -- that does the real work so that's what we repeat and then suppress
                            -- on mouseUp to prevent going too far
                            local isRepeating = nil
                            __internals._modalKeys:bind(mods, key,
                                        function() mimicCallback(k, "mouseDown") end,
                                        function()
                                            if not isRepeating then
                                                mimicCallback(k, "mouseUp")
                                            else
                                                isRepeating = nil
                                            end
                                        end,
                                        function()
                                            isRepeating = true
                                            mimicCallback(k, "mouseUp")
                                        end)
                        else
                            __internals._modalKeys:bind(mods, key,
                                        function() mimicCallback(k, "mouseDown") end,
                                        function() mimicCallback(k, "mouseUp") end)
                        end
                    end
                end
            end
        end

        __internals._rCanvas = _rCanvas
    end
    return __internals._rCanvas
end

---------- Spoon Methods ----------

obj.saveSettings = function(self, andPos)
    -- in case called as function
    if self ~= obj then self, andPos = obj, self end

    for k, v in pairs(__spoonVariables) do
        if andPos or not k:match("^" .. obj.name .. "_position$") then
            settings.set(obj.name .. "_" .. k, v)
        end
    end

    return self
end

obj.clearSavedSettings = function(self, andPos)
    -- in case called as function
    if self ~= obj then self, andPos = obj, self end

    for k, _ in pairs(__spoonVariables) do
        if andPos or not k:match("^" .. obj.name .. "_position$") then
            settings.clear(obj.name .. "_" .. k)
        end
    end

    return self
end

obj.selectDevice = function(self, dev)
    -- in case called as function
    if self ~= obj then self, dev = obj, self end

    if type(dev) == "boolean" and dev == false then
        __internals._rDevice = nil
    else
        local rDev = roku:device(dev)
        if rDev then
            roku:addDevice(rDev:host(), rDev:port()) -- mark it as manually added so it won't disappear on us if its slow to respond to a future discovery scan
            __internals._rDevice = rDev
            __internals._rDeviceImage = nil
-- app IDs are actually consistent across devices, so don't clear when switching to different device
--             for _, v in pairs(__internals.cachedImages) do
--                 __internals.cachedImages[k] = nil
--             end
        else
            _log.ef("%s device not found; current selected device unchanged", dev)
            return nil
        end
    end
    if __internals._rCanvas then
        updateRemoteCanvas()
    end
    return self
end

obj.show = function(self)
    -- in case called as function
    if self ~= obj then self = obj end
    if not __internals._rCanvas then
        obj:start()
    end
    if not __internals._rCanvas:isShowing() then
        __internals._rCanvas:show()
        updateRemoteCanvas()

        __internals._shouldHideWatcher = timer.doEvery(5, function()
            local mousePos = mouse.absolutePosition()
            if not geometry.inside(mousePos, __internals._rCanvas:frame()) then
                goDark()
            end
        end)

        __internals._sleepWatcher = caffeinate.watcher.new(function(state)
            if state == caffeinate.watcher.systemWillSleep then
                if keysEnabled then __internals._modalKeys:exit() end
            end
        end):start()
    end
    return self
end

obj.hide = function(self)
    -- in case called as function
    if self ~= obj then self = obj end

    if __internals._rCanvas then
        if __internals._rCanvas:isShowing() then
            __internals._rCanvas:hide()

            __internals._shouldHideWatcher:stop()
            __internals._shouldHideWatcher = nil

            __internals._sleepWatcher:stop()
            __internals._sleepWatcher = nil

            if __internals._mouseMoveTracker then
                __internals._mouseMoveTracker = nil
            end
        end
        if keysEnabled then __internals._modalKeys:exit() end
    end
    return self
end

obj.toggle = function(self)
    -- in case called as function
    if self ~= obj then self = obj end

    if not (__internals._rCanvas and __internals._rCanvas:isShowing()) then
        obj:show()
    else
        obj:hide()
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

--- RokuRemote:start() -> self
--- Method
--- Starts.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the RokuRemote spoon object
obj.start = function(self)
    -- in case called as function
    if self ~= obj then self = obj end

    if not __internals._rCanvas then
        roku:start()
        __internals._rCanvas = createRemoteCanvas()
    end

    return self
end

--- RokuRemote:stop() -> self
--- Method
--- Stops.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the RokuRemote spoon object
obj.stop = function(self)
    -- in case called as function
    if self ~= obj then self = obj end

    obj:hide()
    if __internals._rCanvas then
        __internals._rCanvas:delete()
        __internals._rCanvas = nil
    end
    if __internals._modalKeys then
        __internals._modalKeys:delete()
        __internals._modalKeys = nil
    end
    for _, v in pairs(__internals.cachedImages) do
        __internals.cachedImages[k] = nil
    end
    for k, v in pairs(__internals.timers) do
        v:stop() ; __internals.timers[k] = nil
    end
    roku:stop()
    return self
end

--- RokuRemote:bindHotkeys(mapping) -> self
--- Method
--- Binds hotkeys for the RokuRemote spoon
---
--- Parameters:
---  * `mapping` - A table containing hotkey modifier/key details for one or more of the following commands:
---    * "start"  - start
---    * "stop"   - stop
---    * "show"   -
---    * "hide"   -
---    * "toggle" -
---    * "save"   -
---
--- Returns:
---  * the RokuRemote spoon object
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
--         if key == "ssdpQueryTime" then
--             if type(value) == "number" and math.type(value) == "integer" and value > 0 then
--                 __spoonVariables[key] = value
--             else
--                 errMsg = "ssdpQueryTime must be an integer > 0"
--             end
--         elseif key == "rediscoveryInterval" then
--             if type(value) == "number" and math.type(value) == "integer" and value > __spoonVariables["ssdpQueryTime"] then
--                 __spoonVariables[key] = value
--                 if __internals.rediscoveryCheck then
--                     __internals.rediscoveryCheck:fire()
--                 end
--             else
--                 errMsg = "rediscoveryInterval must be an integer > ssdpQueryTime"
--             end
--
--         else
            errMsg = tostring(key) .. " is not a recognized paramter of RokuRemote"
--         end

        if errMsg then error(errMsg, 2) end
    end,

    -- for debugging purposes; users should never need to see these directly
    __internals = __internals,
    __spoonVariables = __spoonVariables,
})
