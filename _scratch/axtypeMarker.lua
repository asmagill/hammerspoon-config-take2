--
-- Tool for identifying elements in an application that might be of interest...
--
-- example use -- install this file in your ~/.hammerspoon directorym then, in the
-- Hammerspoon console type: dofile("axtypeMarker.lua").markApplication("Finder", "AXButton")
--
-- The finder will be brought forward and a few seconds later red rectangles will be drawn
-- around all the identified elements of the type specified.
--
-- To clear the frames, tap the escape key.
--

local module = {}

local axuielement = require("hs.axuielement")
local canvas      = require("hs.canvas")
local hotkey      = require("hs.hotkey")
local screen      = require("hs.screen")
local timer       = require("hs.timer")

local axmetatable = hs.getObjectMetatable("hs.axuielement")

module.markWindow = function(win, axtype, pattern)
    local axwin
    if getmetatable(win) == axmetatable then
        if win.AXRole == "AXWindow" then
            axwin = win
        else
            axwin = win.AXWindow
        end
    else
        axwin = axuielement.windowElement(win)
    end

    assert(axwin, "unable to identify window from '" .. tostring(win) .. "'")
    return module.markElement(axwin, axtype, pattern)
end

module.markApplication = function(app, axtype, pattern)
    local axapp
    if getmetatable(app) == axmetatable then
        if app.AXRole == "AXApplication" then
            axapp = app
        else
            axapp = axuielement.applicationElementForPID(app:pid())
        end
    else
        axapp = axuielement.applicationElement(app)
    end

    hs.assert(axapp, "unable to identify application from '" .. tostring(app) .. "'")
    return module.markElement(axapp, axtype, pattern)
end

module.markElement = function(element, axtype, pattern)
    assert(getmetatable(element) == axmetatable, "element is not an hs.axuielement object")
    if type(pattern) == "nil" then pattern = true end
    pattern = pattern and true or false
    axtype = tostring(axtype)

    if element.AXRole == "AXApplication" then element:asHSApplication():activate(true) end
    if element.AXRole == "AXWindow"      then element:asHSWindow():focus() end

    local sframe  = screen.mainScreen():fullFrame()
    local markers = {}

    local pleaseWait = canvas.new{
        x = sframe.x + 100,
        y = sframe.y + 100,
        w = sframe.w - 200,
        h = 54
    }:appendElements{
        {
            id          = "box",
            type        = "rectangle",
            fillColor   = { red = 0.5, alpha = 0.5 },
            strokeColor = { white = 1.0, alpha = 0.5 }
        },
        {
            id            = "text",
            type          = "text",
            text          = "Please wait...",
            textColor     = { white = 1 },
            textSize      = 48,
            textAlignment = "center",
        }
    }:show()

    return element:elementSearch(function(msg, elements)
        if #elements > 0 then
            local escapeClause
            escapeClause = hotkey.bind({}, "escape", nil, function()
                pleaseWait["box"].fillColor = { red = 0.5, alpha = 0.5 }
                pleaseWait["text"].text = "Clearing frames..."
                local clearing
                clearing = timer.doAfter(0.001, function()
                    for i,v in ipairs(markers) do v:delete() end
                    escapeClause:disable()
                    clearing:stop() -- unnecessary, but makes it an upvalue so it won't be collected if we take too long
                    clearing = nil
                    pleaseWait:delete()
                end)
            end)

            local noFrameLabel = "~f"

            for i,v in ipairs(elements) do
                local cf = v.AXFrame
                hs.printf("%4d. %" .. tostring(#noFrameLabel) .. "s - %s", i, (cf and "" or noFrameLabel), tostring(v.AXTitle or v.AXValueDescription or v.AXDescription or v.AXRoleDescription))
                if (cf) then
                    table.insert(markers,
                        canvas.new(cf):appendElements{
                            {
                                type        = "rectangle",
                                action      = "stroke",
                                strokeColor = { red = 1 },
                                strokeWidth = 2,
                            }, {
                                type          = "text",
                                text          = tostring(i),
                                textSize      = math.min(cf.h, cf.w) - 8,
                                textColor     = { white = 1.0 },
                                textAlignment = "center",
                            }
                        }:show()
                    )
                    -- no easy way to vertically align text, so move its box instead
                    local mc = markers[#markers]
                    mc[2].frame.y = (cf.h - mc:minimumTextSize(2, tostring(i)).h) / 2
                end
            end
            pleaseWait["box"].fillColor = { green = 0.5, alpha = 0.5 }
            pleaseWait["text"].text = "Press ESC to clear."
        else
            hs.printf("** no elements of type %s found for %s", axtype, tostring(app))
            pleaseWait:delete()
        end

    end, axuielement.searchCriteriaFunction{ attribute = "AXRole", value = axtype, pattern = true })
end


return module
