local canvas = require("hs.canvas")
local screen = require("hs.screen")

local module = {}

local cos = {}
local sin = {}

for i = 0, 360, 0.5 do
    sin[i] = math.sin(math.rad(i))
    cos[i] = math.cos(math.rad(i))
end

local rehoboam = nil

module.undraw = function()
    if rehoboam then
        rehoboam:delete()
        rehoboam = nil
    end
end

module.draw = function(radius)
    local ff = screen.mainScreen():fullFrame()

    radius = radius or (ff.h / 2)
    local ss = radius * 0.15
    radius = radius - ss

    if not rehoboam then
        local side = 2 * (radius + ss)

        rehoboam = canvas.new{
            x = ff.x + (ff.w - side) / 2,
            y = ff.y + (ff.h - side) / 2,
            w = side,
            h = side,
        }:show()
        rehoboam[#rehoboam + 1] = {
            id        = "background",
            type      = "rectangle",
            action    = "fill",
            fillColor = { white = 1 },
        }

        local offset = side / 2

        local segments = {}
        for i = 0, 359, 1 do
            local len = radius + math.random() * ss
            table.insert(segments, { x = offset + sin[i] * radius, y = offset + cos[i] * radius })
            table.insert(segments, { x = offset + sin[i + 0.5] * len,    y = offset + cos[i + 0.5] * len    })
        end

        rehoboam[#rehoboam + 1] = {
            id          = "status",
            type        = "segments",
            action      = "strokeAndFill",
            strokeColor = { white = 0.25 },
            fillColor   = { white = 0.25 },
            coordinates = segments,
            closed      = true,
        }

        rehoboam[#rehoboam + 1] = {
            id        = "center",
            type      = "circle",
            action    = "fill",
            radius    = radius,
            fillColor = { white = 1 },
        }

        local routine
        routine = coroutine.wrap(function()
            while rehoboam do
                local segments = {}
                for i = 0, 359, 1 do
                    local len = radius + math.random() * ss
                    table.insert(segments, { x = offset + sin[i] * radius, y = offset + cos[i] * radius })
                    table.insert(segments, { x = offset + sin[i + 0.5] * len,    y = offset + cos[i + 0.5] * len    })
                end
                rehoboam["status"].coordinates = segments

                coroutine.applicationYield()
            end
            routine = nil
        end)
        routine()
    end
end

return module
