-- TODO:
--    document both spoons
--    implement keyboard support
--    add keyEquivelants toggle button?
--    display of device; smaller text, separate icon/text spaces?
--  + add save button (for position only; other settings require console since they're likely to be set either once or in code every time)
--  + add more keyboard equivalents?
--  +     editable through setting?

--- === RokuRemote ===
---
--- Provides an on screen remote control for controlling Roku devices.
---
--- Requires the RokuControl spoon.
---
--- Download: `svn export https://github.com/asmagill/hammerspoon-config/trunk/_Spoons/PwnedPasswords.spoon`

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

local events     = eventtap.event.types

local roku     = hs.loadSpoon("RokuControl")

local logger   = require("hs.logger")

local obj    = {
-- Metadata
    name      = "RokuRemote",
    version   = "0.1",
    author    = "A-Ron",
    homepage  = "https://github.com/asmagill/hammerspoon-config/tree/master/_Spoons/RokuRemote.spoon",
    license   = "MIT - https://opensource.org/licenses/MIT",
    spoonPath = debug.getinfo(1, "S").source:match("^@(.+/).+%.lua$"),
}
local metadataKeys = {} ; for k, v in require("hs.fnutils").sortByKeys(obj) do table.insert(metadataKeys, k) end

obj.__index = obj
local _log = logger.new(obj.name)
obj.logger = _log

obj._layout = dofile(obj.spoonPath .. "layout.lua")

-- for timers, etc so they don't get collected
local __internals = {
    timers       = {},
    cachedImages = {},
    keyRepeating = {},
    -- apparently there is a bug perhaps introduced in a new OS X release with the NSStatusBar approach
    -- used for menu items that means pop up menus aren't always deleted from the menubar correctly...
    -- its probably time to stop using the deprecated approach anyways and finish the more "Apple approved"
    -- version in hs._asm.guitk.menubar soon... until then, lets create them once to at least mitigate the
    -- issue
    menus        = {
        _Launch = menu.new():removeFromMenuBar(),
        _Device = menu.new():removeFromMenuBar(),
        _Move   = menu.new():removeFromMenuBar(),
    }
}

local sf = screen.mainScreen():fullFrame()

---------- Spoon Variables ----------

local startingPosition = settings.get(obj.name .. "_position") or {
    x = sf.x + sf.w - (obj._layout.gridSize.w + 2) * obj._layout.buttonSize,
    y = sf.y + sf.h - (obj._layout.gridSize.h + 3) * obj._layout.buttonSize,
}

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
    dimAlpha         = settings.get(obj.name .. "_dimAlpha")         or .25,
    visibleAlpha     = settings.get(obj.name .. "_visibleAlpha")     or .75,
    keyEquivalents   = settings.get(obj.name .. "_keyEquivalents")   or {
        Play   = { {},        "space",      },
        Select = { {},        "return",     },
        Left   = { {},        "left",  true },
        Right  = { {},        "right", true },
        Up     = { {},        "up",    true },
        Down   = { {},        "down",  true },
        Home   = { { "cmd" }, "h",          },
        Back   = { { "cmd" }, "b",          },
    }
}

---------- Local Functions ----------

local keysEnabled = false

local goDark = function()
    if __internals._rCanvas then
        if __spoonVariables.autoDim then
            for i = 2, #__internals._rCanvas,1  do
                __internals._rCanvas[i].action = "skip"
            end
            __internals._rCanvas["background"].fillColor.alpha = __spoonVariables.dimAlpha
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

local updateRemoteCanvas = function()
    if __internals._rCanvas then
        if __internals._rCanvas:isShowing() then
            local mousePos = mouse.getAbsolutePosition()
            if geometry.inside(mousePos, __internals._rCanvas:frame()) then
                __internals._rCanvas["background"].fillColor.alpha = __spoonVariables.visibleAlpha

                local availableButtons = __internals._rDevice and __internals._rDevice:remoteButtons() or {}
                for k,v in pairs(obj._layout.buttons) do
                    if k == "_Close" then
                        __internals._rCanvas[k].action = "strokeAndFill"
                        __internals._rCanvas[k .. "_text"].action = "strokeAndFill"
                    elseif k == "_Move" then
                        __internals._rCanvas[k].action = "strokeAndFill"
                        __internals._rCanvas[k .. "_text"].action = "strokeAndFill"
                    elseif k == "_Device" then
                        __internals._rCanvas[k].action = "strokeAndFill"
                        __internals._rCanvas[k .. "_text"].action = "strokeAndFill"

                        if __internals._rDevice then
                            __internals._rCanvas[k .. "_text"].text = stext.new(__internals._rDevice:name(), {
                                      font = { name = "Menlo", size = 14 },
                                      paragraphStyle = {
                                          alignment                     = "center",
                                          lineBreak                     = "truncateTail",
                                      },
                                      color = { white = 1 },
                                  })
                        else
                            __internals._rCanvas[k .. "_text"].text = v.char
                        end
                    elseif k == "_Active" then
                        if __internals._rDevice then
                            local appID = __internals._rDevice:currentAppID()
                            local icon = appID and __internals.cachedImages[appID]
                            if appID and not icon then
                                icon = __internals._rDevice:currentAppIcon()
                                if icon then
                                    __internals.cachedImages[appID] = icon:setSize{ h = 32, w = 64 }
                                end
                            end

                            if not icon then
                                icon = canvas.new(__internals._rCanvas[k].frame_raw)
                                local text = stext.new(__internals._rDevice:currentApp(), {
                                    font = { name = "Menlo", size = 18 },
                                    paragraphStyle = { alignment = "center", lineBreak = "truncateTail", allowsTighteningForTruncation = false },
                                    color = { white = 1 },
                                })
                                local textFrame = icon:minimumTextSize(text)
                                local iconFrame = icon:frame()
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

                                icon[1] = {
                                    type = "text",
                                    frame = textFrame,
                                    text = text,
                                }
                                icon = icon:imageFromCanvas()
                            end
                            __internals._rCanvas[k].action = "strokeAndFill"
                            __internals._rCanvas[k .. "_image"].action = "strokeAndFill"
                            __internals._rCanvas[k .. "_image"].image = icon
                        else
                            __internals._rCanvas[k].action = "skip"
                            __internals._rCanvas[k .. "_image"].action = "skip"
                        end
                    elseif v.enabled then
                        local action = (__internals._rDevice and (
                            k:match("^_") or fnutils.contains(availableButtons, k)
                        )) and "strokeAndFill" or "skip"
                        if __internals._rCanvas[k] then
                            __internals._rCanvas[k].action = action
                            __internals._rCanvas[k .. "_text"].action = action
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
                        table.insert(popup, {
                            title   = v:name(),
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
            elseif id == "_Close" then
                if m == "mouseUp" then obj:hide() end
            elseif id == "_Move" then
                if m == "mouseDown" then
                    if eventtap.checkMouseButtons().right or eventtap.checkKeyboardModifiers().ctrl then
                        local popup = {
                            {
                                title = "Save as start position",
                                fn    = function(...)
                                    local tl = __internals._rCanvas:topLeft()
                                    startingPosition.x = tl.x
                                    startingPosition.y = tl.y
                                    settings.set(obj.name .. "_position", startingPosition)
                                    doDelayedUpdate(.1)
                                end,
                            }, {
                                title = "-",
                            }, {
                                title = "Current start position:",
                                disabled = true,
                            }, {
                                title = "x = " .. tostring(startingPosition.x),
                                indent = 2,
                                disabled = true,
                            }, {
                                title = "y = " .. tostring(startingPosition.y),
                                indent = 2,
                                disabled = true,
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
                        __internals._mouseMoveTracker = eventtap.new(
                            { events.leftMouseDragged, events.leftMouseUp },
                            function(e)
                                if e:getType() == events.leftMouseUp then
                                    __internals._mouseMoveTracker:stop()
                                    __internals._mouseMoveTracker = nil
                                else
                                    local mousePosition = mouse.getAbsolutePosition()
                                    __spoonVariables.position = {
                                        x = mousePosition.x - x,
                                        y = mousePosition.y - y,
                                    }
                                    __internals._rCanvas:topLeft(__spoonVariables.position)

                                end
                            end
                        ):start()
                    end
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
            local buttonFrame = v.pos and {
                x = (v.pos.x + .5) * obj._layout.buttonSize,
                y = (v.pos.y + 1) * obj._layout.buttonSize,
                w = v.pos.w * obj._layout.buttonSize,
                h = v.pos.h * obj._layout.buttonSize,
            } or {}

            if k == "_Close" then
                local textFrame = _rCanvas:minimumTextSize(v.char)
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
                    text  = v.char,
                }
            elseif k == "_Move" then
                local textFrame = _rCanvas:minimumTextSize(v.char)
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
                    text  = v.char,
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
                _rCanvas[#_rCanvas + 1] = {
                    id    = k .. "_text",
                    type  = "text",
                    frame = buttonFrame,
                    text  = v.char,
                }
            elseif k == "_Active" then
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
                buttonFrame.x = buttonFrame.x +  5
                buttonFrame.y = buttonFrame.y +  5
                buttonFrame.w = buttonFrame.w - 10
                buttonFrame.h = buttonFrame.h - 10
                _rCanvas[#_rCanvas + 1] = {
                    id                  = k .. "_image",
                    type                = "image",
                    frame               = buttonFrame,
                }
--             elseif k == "_Keyboard" then
--             elseif k == "_Launch" then
            elseif v.enabled then
                local textFrame = _rCanvas:minimumTextSize(v.char)
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
                _rCanvas[#_rCanvas + 1] = {
                    id    = k .. "_text",
                    type  = "text",
                    frame = textFrame,
                    text  = v.char,
                }

                local keyEquivalent = __spoonVariables.keyEquivalents[k]
                if keyEquivalent then
                    local mods, key, repeats = keyEquivalent[1], keyEquivalent[2], keyEquivalent[3]

                    if repeats then
                        __internals._modalKeys:bind(mods, key,  function()
                                                                  __internals.keyRepeating[key] = false
                                                                  mimicCallback(k, "mouseDown")
                                                                end,
                                                                function()
                                                                    if not __internals.keyRepeating[key] then
                                                                        mimicCallback(k, "mouseUp")
                                                                    end
                                                                end,
                                                                function()
                                                                    __internals.keyRepeating[key] = true
                                                                    mimicCallback(k, "mouseUp")
                                                                end)
                    else
                        __internals._modalKeys:bind(mods, key, function() mimicCallback(k, "mouseDown") end,
                                                               function() mimicCallback(k, "mouseUp") end)
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

    for k,v in pairs(__spoonVariables) do
        if andPos or not k:match("^" .. obj.name .. "_position$") then
            settings.set(obj.name .. "_" .. k, v)
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
            __internals._rDevice = rDev
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
        __internals._rCanvas = createRemoteCanvas()
    end
    if not __internals._rCanvas:isShowing() then
        __internals._rCanvas:show()
        updateRemoteCanvas()

        __internals._shouldHideWatcher = timer.doEvery(5, function()
            local mousePos = mouse.getAbsolutePosition()
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
                __internals._mouseMoveTracker:stop()
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

    roku:start()
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
    for k,v in pairs(__internals.timers) do
        __internals.timers[k]:stop()
        __internals.timers[k] = nil
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
        save   = self.saveSettings,
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
