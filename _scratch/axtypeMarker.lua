--
-- Tool for identifying elements in an application that might be of interest...
--
-- example use -- install this file in your ~/.hammerspoon directorym then, in the
-- Hammerspoon console type: dofile("axtypeMarker.lua").markApp("Finder", "AXButton")
--
-- The finder will be brought forward and a few seconds later red rectangles will be drawn
-- around all the identified elements of the type specified.
--
-- To clear the frames, tap the escape key.
--

local module = {}

local axuielement = require("hs.axuielement")
local application = require("hs.application")
local canvas      = require("hs.canvas")
local hotkey      = require("hs.hotkey")
local screen      = require("hs.screen")
local timer       = require("hs.timer")

local axmetatable = hs.getObjectMetatable("hs.axuielement")
local apmetatable = hs.getObjectMetatable("hs.application")

-- may look into alternative when coroutine friendly Hammerspoon lands
-- local useCoroutines = coroutine.applicationYield and true or false

module.markApp = function(app, axtype)
    local axapp
    if type(app) == "string" then
        axapp = axuielement.applicationElement(application(app))
    elseif getmetatable(app) == apmetatable then
        axapp = axuielement.applicationElement(app)
    elseif getmetatable(app) == axmetatable then
        axapp = app
    end
    hs.assert(axapp, "unable to identify application from '" .. tostring(app) .. "'")
    axtype = tostring(axtype)

    if axapp("role") == "AXApplication" then axapp:asHSApplication():activate(true) end
    if axapp("role") == "AXWindow"      then axapp:asHSWindow():focus() end

    local sframe  = screen.mainScreen():fullFrame()
    local markers = {}

    local pleaseWait = canvas.new{
        x = sframe.x + 100,
        y = sframe.y + 100,
        w = sframe.w - 200,
        h = 54
    }:appendElements{
        {
            type        = "rectangle",
            fillColor   = { red = 0.5, alpha = 0.5 },
            strokeColor = { white = 1.0, alpha = 0.5 }
        },
        {
            type          = "text",
            text          = "Please wait...",
            textColor     = { white = 1 },
            textSize      = 48,
            textAlignment = "center",
        }
    }:show()

    axapp:getAllChildElements(function(items)
        local elements = items:elementSearch({ role = axtype }, true)
        if #elements > 0 then
            local escapeClause
            escapeClause = hotkey.bind({}, "escape", nil, function()
                pleaseWait:show()[2].text = "Clearing frames..."
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
                local cf = v:attributeValue("AXFrame")
                hs.printf("%4d. %" .. tostring(#noFrameLabel) .. "s - %s", i, (cf and "" or noFrameLabel), tostring(v:attributeValue("AXTitle")))
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
                                textSize      = math.min(cf.h, cf.w) - 4,
                                textColor     = { white = 1.0 },
                                textAlignment = "center",
                            }
                        }:show()
                    )
                    -- no easy way to vertically align text, so move it's box instead
                    local mc = markers[#markers]
                    mc[2].frame.y = (cf.h - mc:minimumTextSize(2, tostring(i)).h) / 2
                end
            end
            pleaseWait:hide()
        else
            hs.printf("** no elements of type %s found for %s", axtype, tostring(app))
            pleaseWait:delete()
        end

    end)
end


return module
