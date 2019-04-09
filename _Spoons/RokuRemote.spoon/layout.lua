-- TODO:
--    implement keyboard support
--    document both spoons
--    display of device; smaller text, separate icon/text spaces?
--    autosave position?
--    add save button?
--    add keyboard toggle button/
--    add more keyboard equivalents?
--        editable through setting?


local layout = {}

local stext = require("hs.styledtext")
local canvas = require("hs.canvas")

local buttonStyle = {
    font = { name = "Menlo", size = 18 },
    paragraphStyle = { alignment = "center" },
    color = { white = 0 },
}

layout.buttons = {
-- specially handled
    _Close = {
        enabled = false,
        char = stext.new(utf8.char(0x2612), {
            font = { name = "Menlo", size = 14 },
            paragraphStyle = { alignment = "center" },
            color = { white = 0 },
        }),
        offset = { x = 1, y = -7.5 },
    },
    _Move = {
        enabled = false,
        char = stext.new(utf8.char(0x29bf), {
            font = { name = "Menlo", size = 14 },
            paragraphStyle = { alignment = "center" },
            color = { white = 0 },
        }),
        offset = { x = 1, y = -6 },
    },
    _Device = {
        enabled = true, -- include in grid size determination
        pos = { x = 0, y = 0, w = 4, h = 1 },
        char = stext.new(utf8.char(0x1f4fa), {
            font = { name = "Menlo", size = 18 },
            paragraphStyle = {
                alignment                     = "center",
                lineBreak                     = "truncateTail",
--                 allowsTighteningForTruncation = false,
            },
            color = { white = 0 },
        }),
        triggerUpdate = true,
        offset = { x = 0, y = -1 }, -- some characters seem off, even using canvas:minimumTextSize
    },
    _Active = {
        enabled = true, -- include in grid size determination
        pos = { x = 0, y = 7, w = 3, h = 2 },
    },
    _Keyboard = {
        enabled = true, -- include in grid size determination
        pos = { x = 3, y = 7, w = 1, h = 1 },
        char = stext.new(utf8.char(0x2328), {
            font = { name = "Menlo", size = 28 },
            paragraphStyle = { alignment = "center" },
            color = { white = 0 },
        }),
        offset = { x = 0, y = -4 }, -- some characters seem off, even using canvas:minimumTextSize
    },
    _Launch = {
        enabled = true, -- include in grid size determination
        pos = { x = 3, y = 8, w = 1, h = 1 },
        char = stext.new(utf8.char(0x2630), buttonStyle),
        offset = { x = 0, y = -2 }, -- some characters seem off, even using canvas:minimumTextSize
        triggerUpdate = true,
    },
    -- keyboard related only; handled by _Keyboard handler, ignored by regular parser
    Enter = {
        enabled = false,
        char = stext.new(utf8.char(0x23ce), buttonStyle),
        parent = "_Keyboard",
    },
    Backspace = {
        enabled = false,
        char = stext.new(utf8.char(0x232b), buttonStyle),
        parent = "_Keyboard",
    },

-- regular remote buttons
    Home = {
        enabled = true,
        pos = { x = 1.5, y = 1, w = 1.5, h = 1 },
        char = stext.new(utf8.char(0x1f3da), buttonStyle),
    },
    Rev = {
        enabled = true,
        pos = { x = 0, y = 6, w = 1, h = 1 },
        char = stext.new(utf8.char(0x23ea), buttonStyle),
        offset = { x = 0, y = -.5 }, -- some characters seem off, even using canvas:minimumTextSize
    },
    Fwd = {
        enabled = true,
        pos = { x = 2, y = 6, w = 1, h = 1 },
        char = stext.new(utf8.char(0x23e9), buttonStyle),
        offset = { x = 0, y = -.5 }, -- some characters seem off, even using canvas:minimumTextSize
    },
    Play = {
        enabled = true,
        pos = { x = 1, y = 6, w = 1, h = 1 },
        char = stext.new(utf8.char(0x23ef), buttonStyle),
        offset = { x = 0, y = -.5 }, -- some characters seem off, even using canvas:minimumTextSize
        key = "space",
    },
    Select = {
        enabled = true,
        pos = { x = 1, y = 3, w = 1, h = 1 },
        char = stext.new(utf8.char(0x26aa), buttonStyle),
        key = "return",
        offset = { x = 0, y = -1 }, -- some characters seem off, even using canvas:minimumTextSize
        triggerUpdate = true,
    },
    Left = {
        enabled = true,
        pos = { x = 0, y = 3, w = 1, h = 1 },
        char = stext.new(utf8.char(0x25c0), buttonStyle),
        offset = { x = -1, y = -3 }, -- some characters seem off, even using canvas:minimumTextSize
        key = "left",
    },
    Right = {
        enabled = true,
        pos = { x = 2, y = 3, w = 1, h = 1 },
        char = stext.new(utf8.char(0x25b6), buttonStyle),
        offset = { x = 1, y = -3 }, -- some characters seem off, even using canvas:minimumTextSize
        key = "right",
    },
    Down = {
        enabled = true,
        pos = { x = 1, y = 4, w = 1, h = 1 },
        char = stext.new(utf8.char(0x25bc), buttonStyle),
        offset = { x = .5, y = -2 }, -- some characters seem off, even using canvas:minimumTextSize
        key = "down",
    },
    Up = {
        enabled = true,
        pos = { x = 1, y = 2, w = 1, h = 1 },
        char = stext.new(utf8.char(0x25b2), buttonStyle),
        offset = { x = .5, y = -3 }, -- some characters seem off, even using canvas:minimumTextSize
        key = "up",
    },
    Back = {
        enabled = true,
        pos = { x = 0, y = 1, w = 1.5, h = 1 },
        char = stext.new(utf8.char(0x2b05), buttonStyle),
        offset = { x = 0, y = -1 }, -- some characters seem off, even using canvas:minimumTextSize
    },
    InstantReplay = {
        enabled = true,
        pos = { x = 0, y = 5, w = 1, h = 1 },
        char = stext.new(utf8.char(0x21b6), buttonStyle),
        offset = { x = 0, y = -2 }, -- some characters seem off, even using canvas:minimumTextSize
    },
    Info = {
        enabled = true,
        pos = { x = 2, y = 5, w = 1, h = 1 },
        char = stext.new(utf8.char(0x2731), buttonStyle),
        offset = { x = 0, y = -2 }, -- some characters seem off, even using canvas:minimumTextSize
    },
    Search = {
        enabled = true,
        pos = { x = 1, y = 5, w = 1, h = 1 },
        char = stext.new(utf8.char(0x1f50e), buttonStyle),
        sendUpDown = true, -- sends "down"/"up" with mouseDown/Up rather then "pressed" with mouseUp
    },
-- used when private listening supported or isTV
    VolumeDown = {
        enabled = true,
        pos = { x = 3, y = 3, w = 1, h = 1 },
        char = stext.new(utf8.char(0x1f509), buttonStyle),
        active = function(dev) return dev:isTV() or dev:headphonesConnected() end,
    },
    VolumeUp = {
        enabled = true,
        pos = { x = 3, y = 1, w = 1, h = 1 },
        char = stext.new(utf8.char(0x1f50a), buttonStyle),
        active = function(dev) return dev:isTV() or dev:headphonesConnected() end,
    },
-- not sure if useful in this context
    A = {
        enabled = false,
    },
    B = {
        enabled = false,
    },
    FindRemote = {
        enabled = false,
    },
-- I don't have a RokuTV, so not sure the best way to represent these, but leaving
-- in place in case someone else wants to add them
    ChannelUp = {
        enabled = false,
    },
    ChannelDown = {
        enabled = false,
    },
    VolumeMute = {
        enabled = false,
    },
    PowerOff = {
        enabled = false,
    },
    InputTuner = {
        enabled = false,
    },
    InputHDMI1 = {
        enabled = false,
    },
    InputHDMI2 = {
        enabled = false,
    },
    InputHDMI3 = {
        enabled = false,
    },
    InputHDMI4 = {
        enabled = false,
    },
    InputAV1 = {
        enabled = false,
    },
}

-- calculates button size based on largest icon, then adds .25 padding around it
-- calculates grid size by calculating max X and Y positions specified in layout

local maxW, maxH = 0, 0
local maxX, maxY = 0, 0
local _c = canvas.new{}
for k,v in pairs(layout.buttons) do
    if v.enabled then
        if k ~= "_Keyboard" then -- throws the caculation off because it has a lot of whitespace around it that is considered part of the character for some reason
            if v.char then
                local box = _c:minimumTextSize(v.char)
-- print(v.char, box.w, box.h)
                maxW = math.max(maxW, box.w)
                maxH = math.max(maxH, box.h)
            end
        end
        if v.pos then
            maxX = math.max(maxX, v.pos.x + v.pos.w)
            maxY = math.max(maxY, v.pos.y + v.pos.h)
        end
    end
end
_c:delete()

layout.buttonSize = math.max(maxW, maxH) --  * 1.5
layout.gridSize   = { w = maxX,     h = maxY }

return layout
