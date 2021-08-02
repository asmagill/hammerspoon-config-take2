-- Blank screen to solid color to make it easier to see streaks for cleaning


local screen = require("hs.screen")
local hotkey = require("hs.hotkey")
local canvas = require("hs.canvas")

local wall

hotkey.bind({"cmd","alt","ctrl"}, "k", nil, function()
    if wall then
        wall:hide()
        wall = nil
    else
        wall = canvas.new(screen.mainScreen():fullFrame()):show()
        wall[#wall + 1] = {
            type = "rectangle",
            action = "fill",
            fillColor = fc or { white = 1 }
        }
    end
end)

print("Set fc to fill color if you don't want to use white")
print("Toggle with Cmd-Alt-Ctrl K")
