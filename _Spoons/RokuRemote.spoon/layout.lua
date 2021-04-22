local layout = {}

local stext = require("hs.styledtext")
local canvas = require("hs.canvas")

local buttonStyle = {
    font = { name = "Menlo", size = 18 },
    paragraphStyle = { alignment = "center" },
    color = { white = 1 },
}

layout.buttons = {
-- specially handled
    _Close = {
        enabled       = true,
        useInSizing   = false,
        alwaysDisplay = true,
        char          = stext.new(utf8.char(0x2612), {
            font           = { name = "Menlo", size = 14 },
            paragraphStyle = { alignment = "center" },
            color          = { white = 1 },
        }),
        offset        = { x = 1, y = -7.5 },
    },
    _Move = {
        enabled       = true,
        useInSizing   = false,
        alwaysDisplay = true,
        char = stext.new(utf8.char(0x29bf), {
            font           = { name = "Menlo", size = 14 },
            paragraphStyle = { alignment = "center" },
            color          = { white = 1 },
        }),
        offset        = { x = 1, y = -6 },
    },
    _Settings = {
        enabled       = true,
        useInSizing   = false,
        alwaysDisplay = true,
        char          = stext.new(utf8.char(0x25be), {
            font           = { name = "Menlo", size = 14 },
            paragraphStyle = { alignment = "center" },
            color          = { green = 1 },
        }),
        offset        = { x = 1, y = -6 },
        menu          = {
            { "Auto Dimming",       "autoDim",          "boolean" },
            { "Keyboard Shortcuts", "enableKeys",       "boolean" },
            { "-" },
            { "Remote Color",       "remoteColor",      "color" },
            { "Button Frame Color", "buttonFrameColor", "color" },
            { "Button Hover Color", "buttonHoverColor", "color" },
            { "Button Click Color", "buttonClickColor", "color" },
            { "-" },
            { "Active Alpha",       "activeAlpha",      "number", { 0.0, 1.0 }},
            { "Inactive Alpha",     "inactiveAlpha",    "number", { 0.0, 1.0 }},
        },
    },
    _Device = {
        enabled           = true,
        useInSizing       = false,
        alwaysDisplay     = true,
        pos               = { x = 0, y = 0, w = 5, h = 1 },
        triggerUpdate     = true,
        offset            = { x = 0, y = 2 }, -- some characters seem off, even using canvas:minimumTextSize
        image             = true,
        canvasFrameAction = "fill",
        char              = stext.new("Choose Device", {
            font           = { name = "Menlo", size = 14 },
            paragraphStyle = {
                alignment = "center",
                lineBreak = "truncateTail",
            },
            color          = { white = 1 },
        }),
    },

    _Active = {
        enabled     = true,
        useInSizing = true, -- include in grid size determination
        pos         = { x = 0, y = 8, w = 3, h = 2 },
        image       = true,
    },
    _Keyboard = {
        enabled     = true,
        useInSizing = true, -- include in grid size determination
        pos         = { x = 3, y = 8, w = 2, h = 1 },
        char        = stext.new(utf8.char(0x2328), {
            font           = { name = "Menlo", size = 28 },
            paragraphStyle = { alignment = "center" },
            color          = { white = 1 },
        }),
        offset      = { x = 0, y = -4 }, -- some characters seem off, even using canvas:minimumTextSize
    },
    _Launch = {
        enabled       = true,
        useInSizing   = true, -- include in grid size determination
        pos           = { x = 3, y = 9, w = 2, h = 1 },
        char          = stext.new(utf8.char(0x2630), buttonStyle),
        offset        = { x = 0, y = -2 }, -- some characters seem off, even using canvas:minimumTextSize
        triggerUpdate = true,
    },

-- keyboard related only; handled by _Keyboard handler, ignored by regular parser
    Enter = {
        enabled     = false,
        useInSizing = false,
        char        = stext.new(utf8.char(0x23ce), buttonStyle),
        parent      = "_Keyboard",
    },
    Backspace = {
        enabled     = false,
        useInSizing = false,
        char        = stext.new(utf8.char(0x232b), buttonStyle),
        parent      = "_Keyboard",
    },

-- regular remote buttons
    Home = {
        enabled       = true,
        useInSizing   = true,
        pos           = { x = 1.5, y = 1, w = 1.5, h = 1 },
        char          = stext.new(utf8.char(0x1f3da), buttonStyle),
        triggerUpdate = true,
        offset        = { x = 0, y = -2 }, -- some characters seem off, even using canvas:minimumTextSize
    },
    Back = {
        enabled     = true,
        useInSizing = true,
        pos         = { x = 0, y = 1, w = 1.5, h = 1 },
        char        = stext.new(utf8.char(0x2b05), buttonStyle),
        offset      = { x = 0, y = -1 }, -- some characters seem off, even using canvas:minimumTextSize
    },

    Rev = {
        enabled     = true,
        useInSizing = true,
        pos         = { x = 0, y = 7, w = 1, h = 1 },
        char        = stext.new(utf8.char(0x23ea), buttonStyle),
        offset      = { x = 0, y = -1.5 }, -- some characters seem off, even using canvas:minimumTextSize
    },
    Fwd = {
        enabled     = true,
        useInSizing = true,
        pos         = { x = 2, y = 7, w = 1, h = 1 },
        char        = stext.new(utf8.char(0x23e9), buttonStyle),
        offset      = { x = 0, y = -1.5 }, -- some characters seem off, even using canvas:minimumTextSize
    },
    Play = {
        enabled     = true,
        useInSizing = true,
        pos         = { x = 1, y = 7, w = 1, h = 1 },
        char        = stext.new(utf8.char(0x23ef), buttonStyle),
        offset      = { x = 0, y = -1.5 }, -- some characters seem off, even using canvas:minimumTextSize
    },

    Select = {
        enabled           = true,
        useInSizing       = true,
        pos               = { x = 1, y = 3.5, w = 1, h = 1 },
        char              = stext.new(utf8.char(0x26aa), buttonStyle),
        offset            = { x = 0, y = -1.5 }, -- some characters seem off, even using canvas:minimumTextSize
        triggerUpdate     = true,
        canvasFrameAction = "fill",
    },
    Left = {
        enabled           = true,
        useInSizing       = true,
        pos               = { x = 0, y = 3.5, w = 1, h = 1 },
        char              = stext.new(utf8.char(0x25c0), buttonStyle),
        offset            = { x = -1, y = -3 }, -- some characters seem off, even using canvas:minimumTextSize
        canvasFrameAction = "fill",
    },
    Right = {
        enabled           = true,
        useInSizing       = true,
        pos               = { x = 2, y = 3.5, w = 1, h = 1 },
        char              = stext.new(utf8.char(0x25b6), buttonStyle),
        offset            = { x = 1, y = -3 }, -- some characters seem off, even using canvas:minimumTextSize
        canvasFrameAction = "fill",
    },
    Down = {
        enabled           = true,
        useInSizing       = true,
        pos               = { x = 1, y = 4.5, w = 1, h = 1 },
        char              = stext.new(utf8.char(0x25bc), buttonStyle),
        offset            = { x = .5, y = -2 }, -- some characters seem off, even using canvas:minimumTextSize
        canvasFrameAction = "fill",
    },
    Up = {
        enabled           = true,
        useInSizing       = true,
        pos               = { x = 1, y = 2.5, w = 1, h = 1 },
        char              = stext.new(utf8.char(0x25b2), buttonStyle),
        offset            = { x = .5, y = -3 }, -- some characters seem off, even using canvas:minimumTextSize
        canvasFrameAction = "fill",
    },

    InstantReplay = {
        enabled     = true,
        useInSizing = true,
        pos         = { x = 0, y = 6, w = 1, h = 1 },
        char        = stext.new(utf8.char(0x21b6), {
            font           = { name = "Menlo", size = 24 },
            paragraphStyle = { alignment = "center" },
            color          = { white = 1 },
        }),
        offset      = { x = 0, y = -2 }, -- some characters seem off, even using canvas:minimumTextSize
    },
    Info = {
        enabled     = true,
        useInSizing = true,
        pos         = { x = 2, y = 6, w = 1, h = 1 },
        char        = stext.new(utf8.char(0x2731), buttonStyle),
        offset      = { x = 0, y = -2 }, -- some characters seem off, even using canvas:minimumTextSize
    },
    Search = {
        enabled     = true,
        useInSizing = true,
        pos         = { x = 1, y = 6, w = 1, h = 1 },
        char        = stext.new(utf8.char(0x1f50e), buttonStyle),
        sendUpDown  = true, -- sends "down"/"up" with mouseDown/Up rather then "pressed" with mouseUp
        offset      = { x = 0, y = -1 }, -- some characters seem off, even using canvas:minimumTextSize
    },

-- used when private listening supported or isTV
    VolumeDown = {
        enabled     = true,
        useInSizing = true,
        pos         = { x = 4, y = 2, w = 1, h = 1 },
        char        = stext.new(utf8.char(0x1f509), buttonStyle),
        active      = function(dev) return dev:isTV() or dev:headphonesConnected() end,
        offset      = { x = 1, y = -2 }, -- some characters seem off, even using canvas:minimumTextSize
    },
    VolumeUp = {
        enabled     = true,
        useInSizing = true,
        pos         = { x = 4, y = 1, w = 1, h = 1 },
        char        = stext.new(utf8.char(0x1f50a), buttonStyle),
        active      = function(dev) return dev:isTV() or dev:headphonesConnected() end,
        offset      = { x = 1, y = -2 }, -- some characters seem off, even using canvas:minimumTextSize
    },

-- not sure if useful in this context
    A = {
        enabled     = true,
        useInSizing = true,
        pos         = { x = 4, y = 3, w = 1, h = 1 },
        char        = stext.new("A", buttonStyle),
        offset      = { x = 0, y = -1 }, -- some characters seem off, even using canvas:minimumTextSize
    },
    B = {
        enabled     = true,
        useInSizing = true,
        pos         = { x = 4, y = 4, w = 1, h = 1 },
        char        = stext.new("B", buttonStyle),
        offset      = { x = 0, y = -1 }, -- some characters seem off, even using canvas:minimumTextSize
    },

    FindRemote = {
        enabled     = true,
        useInSizing = true,
        pos         = { x = 4, y = 5, w = 1, h = 1 },
        char        = stext.new(utf8.char(0x1f4f2), buttonStyle),
        active      = function(dev) return dev:supportsFindRemote() end,
        offset      = { x = 0, y = -2 }, -- some characters seem off, even using canvas:minimumTextSize
    },

    VolumeMute = {
        enabled     = true,
        useInSizing = true,
        pos         = { x = 3, y = 1, w = 1, h = 2 },
        char        = stext.new(utf8.char(0x1f507), buttonStyle),
        active      = function(dev) return dev:isTV() end,
        offset      = { x = 1, y = -2 }, -- some characters seem off, even using canvas:minimumTextSize
   },

    ChannelUp = {
        enabled     = true,
        useInSizing = true,
        pos         = { x = 3, y = 7, w = 1, h = 1 },
        char        = stext.new(utf8.char(0x2b06), buttonStyle),
        active      = function(dev) return dev:isTV() end,
        offset      = { x = 0, y = -1 }, -- some characters seem off, even using canvas:minimumTextSize
    },
    ChannelDown = {
        enabled     = true,
        useInSizing = true,
        pos         = { x = 4, y = 7, w = 1, h = 1 },
        char        = stext.new(utf8.char(0x2b07), buttonStyle),
        active      = function(dev) return dev:isTV() end,
        offset      = { x = 0, y = -1 }, -- some characters seem off, even using canvas:minimumTextSize
    },

-- ECP docs only mention "PowerOff", but a little googling found forum posts mentioning "PowerOn"
-- and "Power", so, maybe new additions? At any rate, it works for the one TV I have sporadic access to
--     Power = {
--         enabled     = true,
--         useInSizing = true,
--         pos         = { x = 3, y = 6, w = 2, h = 1 },
--         char        = stext.new(utf8.char(0x23FB), buttonStyle),
--         active      = function(dev) return dev:isTV() end,
--         offset      = { x = 0, y = -1 }, -- some characters seem off, even using canvas:minimumTextSize
--     },

    Power = {
        enabled           = true,
        useInSizing       = false,
        active            = function(dev) return dev:isTV() or dev:headphonesConnected() end,
        pos               = { x = 3, y = 6, w = 2, h = 1 },
        char              = function(dev)
            if not (dev and dev:tvPowerIsOn()) then
                return stext.new(utf8.char(0x26aa) .. " ", {
                    font           = { name = "Menlo", size = 14 },
                    paragraphStyle = { alignment = "center" },
                    color          = { white = 1 },
                }) .. stext.new(utf8.char(0x23FB), buttonStyle)
            else
                return stext.new(utf8.char(0x1f7e2) .. " ", {
                    font           = { name = "Menlo", size = 14 },
                    paragraphStyle = { alignment = "center" },
                    color          = { white = 1 },
                }) .. stext.new(utf8.char(0x23FB), buttonStyle)
            end
        end,
        offset            = { x = 0, y = -3 }, -- some characters seem off, even using canvas:minimumTextSize
        triggerUpdate     = true,
    },

-- I prefer a single button for toggling (above), but these work if you want them separate
    PowerOn = {
        enabled     = false,
        useInSizing = false,
        active      = function(dev) return dev:isTV() end,
    },
    PowerOff = {
        enabled     = false,
        useInSizing = false,
        active      = function(dev) return dev:isTV() end,
    },

-- These show up in the available apps intermixed with the installed apps, so no *need* to include
-- these unless you particularly want them...
    InputTuner = {
        enabled     = false,
        useInSizing = false,
        active      = function(dev) return dev:isTV() end,
    },
    InputHDMI1 = {
        enabled     = false,
        useInSizing = false,
        active      = function(dev) return dev:isTV() end,
    },
    InputHDMI2 = {
        enabled     = false,
        useInSizing = false,
        active      = function(dev) return dev:isTV() end,
    },
    InputHDMI3 = {
        enabled     = false,
        useInSizing = false,
        active      = function(dev) return dev:isTV() end,
    },
    InputHDMI4 = {
        enabled     = false,
        useInSizing = false,
        active      = function(dev) return dev:isTV() end,
    },
    InputAV1 = {
        enabled     = false,
        useInSizing = false,
        active      = function(dev) return dev:isTV() end,
    },
}

-- calculates button size based on largest icon, then adds .25 padding around it
-- calculates grid size by calculating max X and Y positions specified in layout

local maxW, maxH = 0, 0
local maxX, maxY = 0, 0
local _c = canvas.new{}
for k,v in pairs(layout.buttons) do
    if v.enabled and v.useInSizing then
        -- these throw the caculation off because it has a lot of whitespace around then
        -- that is considered part of the character
        if k ~= "_Keyboard" and k ~= "InstantReplay" then
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
