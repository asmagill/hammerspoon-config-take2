-- an attempt to see if we can reduce the number of eventtaps required to create a dragging rect
-- behavior, inspired by https://groups.google.com/g/hammerspoon/c/0bDb78VrBAA

-- The answer is not really, but two of them are very narrowly targetted and only active for
-- a limited amount of time.

-- currently autostarts, but you can change this by changing the last line to just "return module"

local canvas   = require("hs.canvas")
local eventtap = require("hs.eventtap")
local mouse    = require("hs.mouse")

local module = {}

-- size and spacing for dashes in rectangle
module.phaseShift     = 10

-- how often the rectangle should be updated, both in size and dash offset
module.phaseCycle     = .05

 -- kbd mods that have to be held to allow a mouse down to initiate the dragging rect
 module.flagsToTrigger = { "cmd", "alt", "shift", "ctrl" }

-- build the rectangle object with dashed edges
local rect = canvas.new{ x = 0, y = 0, h = 1, w = 2}
rect[#rect + 1] = {
    type              = "rectangle",
    action            = "stroke",
    strokeWidth       = 4,
    strokeDashPattern = { module.phaseShift, module.phaseShift },
    strokeDashPhase   = 0,
}

local dashPhase          = 0
local engaged            = false
local regularTermination = false

-- predeclare primary function so an eventtap can trigger it
local enableRectangleDragger

---- eventtaps ----

-- when enabled, a mouse down will start the drag rect display and eats the event so it doesn't propagate
--  * turned on when flag condition met in flagChangeEventtap
--  * turned off upon entering drag rect update function
local mouseDownEventtap = eventtap.new(
  { eventtap.event.types.leftMouseDown },
  function(e)
      enableRectangleDragger(e:location())
      return true -- eats the event so nothing further sees it
  end
)

-- when enabled, ends drag rect display and eats the event so it doesn't propagate
--  * turned on when entering drag rect update function
--  * turned off when exiting drag rect update function
local mouseUpEventtap = eventtap.new(
  { eventtap.event.types.leftMouseUp },
  function(e)
      engaged            = false
      -- specify that this is the correct termination event, so we know that the
      -- selected rectangle is what we wanted
      regularTermination = true
      return true -- eats the event so nothing further sees it
  end
)

-- when enabled triggers drag rect display if flags condition met; otherwise stops drag rect display
--  * turned on when module.start invoked
--  * turned off when module.stop invoked
-- This is the only eventtap which is long running
local flagChangeEventtap = eventtap.new(
    { eventtap.event.types.flagsChanged },
    function(e)
      if e:getFlags():containExactly(module.flagsToTrigger) then
          if not engaged then mouseDownEventtap:start() end
      else
        engaged = false
        if mouseDownEventtap:isEnabled() then mouseDownEventtap:stop() end
      end
    end
)

-- does the actual drawing and updating of the drag rect display through use
-- of coroutine to keep Hammerspoon responsive and not require additional
-- eventtap for drag events
enableRectangleDragger = function(location)
    local actualDragger -- predeclare so we can use it within the function to make it an upvalue
    actualDragger = coroutine.wrap(function(startingLocation)
        engaged            = true
        regularTermination = false
        mouseDownEventtap:stop()
        mouseUpEventtap:start()
        rect:show()
        local phaseShift = module.phaseShift
        local phaseCycle = module.phaseCycle

        rect[1].strokeDashPattern = { phaseShift, phaseShift }

        local newFrame = {}
        -- engaged is updated by mouseUpEventtap and flagChangeEventtap to signal when to end
        while engaged do
            local mousePos = mouse.getAbsolutePosition()
            newFrame = {
                x = startingLocation.x,
                y = startingLocation.y,
                w = mousePos.x - startingLocation.x,
                h = mousePos.y - startingLocation.y
            }
            -- "wrap" around if mouse moved negative to initial x or y
            if newFrame.w < 0 then
                newFrame.w = math.abs(newFrame.w)
                newFrame.x = newFrame.x - newFrame.w
            end
            if newFrame.h < 0 then
                newFrame.h = math.abs(newFrame.h)
                newFrame.y = newFrame.y - newFrame.h
            end
            rect[1].strokeDashPhase = dashPhase -- update stroke dash position
            rect:frame(newFrame)                -- update rect frame
            dashPhase = (dashPhase + 1) % (phaseShift * 2)

            coroutine.applicationYield(phaseCycle) -- yield
        end
        mouseUpEventtap:stop()
        rect:hide()

        -- this makes actualDragger an upvalue so it can't be collected, though given
        -- the short time between yields (presumably less than a second, though this
        -- *is* adjustable with module.phaseCycle) collection is unlikely; still better
        -- safe than sorry
        actualDragger = nil

        if regularTermination then module.callback(newFrame) end
    end)
    actualDragger(location)
end

module.start = function()
    -- don't change anything if we're already running
    if not flagChangeEventtap:isEnabled() then
        engaged = false
        flagChangeEventtap:start()
    end
    return module
end

module.stop = function()
    engaged            = false
    regularTermination = false
    -- shutdown whatever taps may actually be running
    if flagChangeEventtap:isEnabled() then flagChangeEventtap:stop() end
    if mouseDownEventtap:isEnabled()  then mouseDownEventtap:stop()  end
    if mouseUpEventtap:isEnabled()    then mouseUpEventtap:stop()    end
    return module
end

-- called when drag rect is completed with the resulting frame
module.callback = function(rect)
    -- do what you need with the rect specified by newFrame as we exited normally
    hs.printf(
        "Regular termination with { x = %.2f, y = %.2f, w = %.2f, h = %.2f }",
        rect.x,
        rect.y,
        rect.w,
        rect.h
    )
end

return module.start()
