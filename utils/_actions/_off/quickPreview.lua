local image   = require("hs.image")
local screen  = require("hs.screen")
local canvas  = require("hs.canvas")
local webview = require("hs.webview")
local stext   = require("hs.styledtext")
local inspect = require("hs.inspect")
local hotkey  = require("hs.hotkey")

local module = {}


module.preview = function(item, textConversion)
    textConversion = textConversion or "raw"

    if module._canvas then -- we got called again; clear out previous display
        module._canvas:delete()
        module._canvas = nil
        module._escKey:disable()
        module._escKey = nil
    end

    if type(item) == "table" then item = inspect(item) end

    if getmetatable(item) ~= hs.getObjectMetatable("hs.image") and
       getmetatable(item) ~= hs.getObjectMetatable("hs.styledtext") then
        item = tostring(item) -- doesn't hurt if it's already a string
    end

    if type(item) == "string" and textConversion ~= "raw" then
        local s, r = pcall(stext.getStyledTextFromData, item, textConversion)
        if s then
            item = r
        else
            print("** invalid conversion type; see `hs.styledtext.getStyledTextFromData`; leaving unchanged")
        end
    end

    local sf = screen.mainScreen():fullFrame()

    module._canvas = canvas.new{
        x = sf.x + .1 * sf.w,
        y = sf.y + .1 * sf.h,
        h = .8 * sf.h,
        w = .8 * sf.w,
    }:appendElements{
        {
            type             = "rectangle",
            fillColor        = { white = .5,  alpha = .7 },
            strokeColor      = { white = .25, alpha = .7 },
            roundedRectRadii = { xRadius = 20, yRadius = 20 },
        }
    }:show()

    if type(item) == "string" or getmetatable(item) == hs.getObjectMetatable("hs.styledtext") then
        module._canvas:appendElements{
            {
                type      = "text",
                text      = item,
                textColor = { white = 1 },
                textFont  = ".AppleSystemUIFont",
                textSize  = 24,
                frame     = { x = ".05", y = ".05", h = ".9", w = ".9" },
            }
        }
    elseif getmetatable(item) == hs.getObjectMetatable("hs.image") then
        module._canvas:appendElements{
            {
                type          = "image",
                frame         = { x = ".05", y = ".05", h = ".9", w = ".9" },
                image         = item,
                imageAnimates = true, -- in case its an animated GIF
                imageScaling  = "scaleProportionally",
            }
        }
    else
        print("** how the h^$%^&#$%&^% did you get here? item should be text already... bailing")
        print(type(item), (getmetatable(item) or {}).__name, item)
        module._canvas:delete()
        module._canvas = nil
        return
    end

    module._escKey = hotkey.bind({}, "escape", nil, function()
        module._canvas:delete()
        module._canvas = nil
        module._escKey:disable()
        module._escKey = nil
    end)
end

return module
