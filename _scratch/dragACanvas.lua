myCanvas = hs.canvas.new{ x = 100, y = 100, h = 200, w = 200 }:show()

myCanvas[#myCanvas + 1] = {
    id             = "primary", -- we check for this in the callback below (_i)
    type           = "circle",
    radius         = 100,
    center         = { x = 100, y = 100 },
    action         = "fill",
    fillColor      = { blue = .7, alpha = .7 },
    trackMouseDown = true,
    trackMouseUp   = true,
}

local _cMouseAction -- make local here so it's an upvalue in mouseCallback

-- This example only tracks movement when you click within the specified canvas object (i.e.
-- the blue circle). If you'd rather it move when they click within *any* portion of the
-- canvas, add `myCanvas:canvasMouseEvents(true, true)` and change `_i == "primary"` below to
-- `_i == "_canvas_"`.

myCanvas:clickActivating(false):mouseCallback(function(_c, _m, _i, _x, _y)
    print(_m, _i)
    if _i == "primary" then
        if _m == "mouseDown" then
            -- if you want to check other state to see if it should move, do it here
            -- e.g. *which* mouse button with `hs.eventtap.checkMouseButtons`,
            --      a modifier being held with `hs.eventtap.checkKeyboardModifiers`,
            --      etc.
            -- exit now if such conditions aren't met, otherwise:

            -- uses a coroutine so HS can update the canvas position and do other
            -- housekeeping while the mouse button is being held down
            _cMouseAction = coroutine.wrap(function()
                while _cMouseAction do
                    -- do the actual moving
                    local pos = hs.mouse.absolutePosition()
                    local frame = _c:frame()
                    frame.x = pos.x - _x
                    frame.y = pos.y - _y
                    _c:frame(frame)

                    -- "exits" so HS can do other things, but a timer resumes
                    -- the coroutine almost immediately if nothing else is
                    -- pending
                    coroutine.applicationYield()
                end
            end)
            _cMouseAction()
        elseif _m == "mouseUp" then
            -- next time the coroutine resumes, it will clear itself
            _cMouseAction = nil
        end
    end
end)
