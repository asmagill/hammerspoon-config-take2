local module = {}
local canvas = require("hs.canvas")

local boxSize   = 400
local dotRadius = boxSize / 50

local toXY = function(c)
    local h = 1 - c.hue - .25 -- modify hue to what I *think* is the orientation in FCP
    return c.saturation * math.cos(h * math.pi * 2), c.saturation * math.sin(h * math.pi * 2)
end

local fromXY = function(x, y)
    local hue, sat = math.atan(y, x) / ( math.pi * 2), math.sqrt(x * x + y * y)
    local h = 1 - (hue + .25) -- modify hue from what I *think* is the orientation in FCP
    return h, sat
end

function clamp(val, min, max)
    if val <= min then
        val = min
    elseif max <= val then
        val = max
    end
    return val
end

local _C = canvas.new{ x = 100, y = 100, h = boxSize, w = boxSize }:show()
_C[#_C + 1] = {
    type             = "rectangle",
    action           = "fill",
    fillColor        = { white = .75, alpha = .5 },
    roundedRectRadii = { xRadius = 10, yRadius = 10 },
    clipToPath       = true,
}

for hue = 0, 1, 1/180 do
    if hue ~= 1 then -- a hue of 0 and 1 are identical, so skip 1 if we actually land on it
        local hsb = { hue = hue, saturation = 1, brightness = 1 }
        local cX, cY = toXY(hsb)
        _C[#_C + 1] = {
            type      = "circle",
            action    = "fill",
            radius    = dotRadius,
            padding   = dotRadius,
            fillColor = hsb,
            center    = {
                x = tostring((cX + 1) / 2), -- shift from [-1, 1] to [0, 2]; half it and turn it into a percentage
                y = tostring((cY + 1) / 2), -- shift from [-1, 1] to [0, 2]; half it and turn it into a percentage
            }
        }
--         print(string.format("%.3f, %.3f --> %.3f, %.3f", hsb.hue, hsb.saturation, fromXY(cX, cY)))
    end
end

_C[#_C + 1] = {
    id            = "text",
    type          = "text",
    action        = "strokeAndFill",
    textSize      = 12,
    textFont      = "Menlo",
    textAlignment = "center",
    frame         = { x = ".1", y = ".1", h = 16, w = ".8" },
    text          = "filler",
}

_C[#_C + 1] = {
    id          = "knob",
    type        = "circle",
    action      = "strokeAndFill",
    clipToPath  = true,
    radius      = dotRadius,
    strokeWidth = dotRadius / 4,
    strokeColor = { white = 0 },
    fillColor   = { white = 1 },
    center      = { x = ".5", y = ".5" },
}

module.setXY = function(x, y)
    x, y = clamp(x or 0, -1, 1), clamp(y or 0, -1, 1)
    local h, s = fromXY(x, y)
    _C.knob.fillColor = { hue = h, saturation = s, brightness = 1 }
    _C.knob.center = { x = tostring((x + 1) / 2), y = tostring((y + 1) / 2) }
    _C.text.text = string.format("X, Y = %.3f, %.3f", x, y)
end

module.setXY(0,0)
module._C = _C

return module
