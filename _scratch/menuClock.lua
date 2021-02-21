local canvas     = require("hs.canvas")
local timer      = require("hs.timer")
local menubar    = require("hs.menubar")
local styledtext = require("hs.styledtext")

local module = {}

local updateMenuTitle = function()
    -- because of changes in macOS 11, two line menubar titles are no longer rendered with
    -- as tight of a linespacing as before... you get more control by making an image of the
    -- two lines and assigning an icon to the menu instead
    if module._menu then -- if the menu doesn't exist yet, skip this
        local titleText = styledtext.new(os.date("%R\n%D"), {
            font = { name = "Menlo", size = 9 },
            color = { blue = 1 },
            paragraphStyle = { alignment = "center" },
        })
        local tempCanvas = canvas.new{ x = 0, y = 0, h = 0, w = 0 }
        -- we can't determine the minimum size required for text until we have a canvas
        -- object, another possible addition/change to the module that should be considered
        tempCanvas:frame(tempCanvas:minimumTextSize(titleText))
        tempCanvas[1] = { type = "text", text = titleText }
        module._menu:setIcon(tempCanvas:imageFromCanvas())
        -- this is the important line:
        tempCanvas:delete() -- if you forget this, the canvas is *never* collected
    end
end

module._menu = menubar.new()
module._timer = timer.doEvery(5, updateMenuTitle) -- ok, a little fast for a clock, but this
                                                  -- is provided as an example
return module
