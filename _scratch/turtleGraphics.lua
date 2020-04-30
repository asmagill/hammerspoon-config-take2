--
-- Turtle graphics wrapper for hs.canvas
--
-- Loosely based on Turtle Graphics primitives in BERKELEY LOGO 6.1
-- https://people.eecs.berkeley.edu/~bh/docs/html/usermanual_6.html#GRAPHICS
--
-- Some function names changed to better follow Hammerspoon method naming conventions and
-- others to make them more clear
--
-- This is *NOT* guaranteed to be functionally equivalent or identical to Berkeley Logo
-- nore is the logo specific syntax supported -- that would require writing an interpreter
-- which is beyond the scope of what I need at present.

-- see https://github.com/asmagill/hammerspoon/tree/canvasAdditions for current speed up attempts
--
--    SLOW
--    * Rewrite to avoid canvas metamethods
--    * add way to extend segments without passing array?
--      Still SLOW, but about 2/5 savings...
--          why is JS implementation at https://www.calormen.com/jslogo/ so much faster?
--          is JS graphics vector, bitmap, object?
--          would a bitmap creation module be better?
--          move entire thing into `hs.canvas.turtle` and impement specific optimizations?
--            I'm sure the validation code for canvas's attributes is at least partly to blame since I
--              can't do it per entry but have to do it for the whole coordinate list even though I just
--              changed one item

--    make yield parameters adjustable
--    figure out how to rotate turtle without having to invert image since canvas scale is invertts
--    add color methods
--    figure out how/if we're going to support fill and filled
--      will probably need better way to handle keeping segments from growing huge
--    label/text support
--    save as image
--    background images?
--    others?

local canvas   = require("hs.canvas")
local image    = require("hs.image")
local screen   = require("hs.screen")
local color    = require("hs.drawing.color")
local mouse    = require("hs.mouse")
local eventtap = require("hs.eventtap")

local USERDATA_TAG = "turtleGraphicsCanvas"

local individualCoordinateSupport = hs.getObjectMetatable("hs.canvas").coordinateForElement and true or false

local module = {}

-- to get rid of upvalue in mouse callbacks, store moving canvases here... see module.new below
local _movers = {}

local turtleSize = { h = 30, w = 30 }
local turtleBaseMatrix = canvas.matrix.translate(-turtleSize.w/2, -turtleSize.h/2)
local turtle = image.imageFromASCII([[
....V...........P....
..W.......S.......O..
.......U.T.R.Q.......
.....X.........N.....
.....................
.....................
.....................
.....................
....Y...........M....
c...................I
..b...............J..
d....Z.........L....H
....a...........K....
.e.................G.
.....................
......g.......E......
...f...h.....D...F...
........i...C........
.....................
.....................
.........j.B.........
..........A..........]], {
    {
        fillColor   = { green = 0.5, alpha = 0.5  },
        strokeColor = { green = 1,   alpha = 0.7 },
        lineWidth   = 1,
        shouldClose = true,
        antialias   = true,
    }
}):size{ h = turtleSize.h, w = turtleSize.w }

local penColors = {
    color.x11.blue,
    color.x11.green,
    color.x11.cyan,
    color.x11.red,
    color.x11.magenta,
    color.x11.yellow,
    color.x11.white,
    color.x11.brown,
    color.x11.tan,
    color.x11.forestgreen,
    color.x11.aqua,
    color.x11.salmon,
    color.x11.purple,
    color.x11.orange,
    color.x11.gray,
}
penColors[0] = color.x11.black -- lua starts arrays at 1, so will slip this in by hand

-- methods with visual impact can call this to allow for yields when we're running in a
-- coroutine
local coroutineFriendlyCheck = function(self)
    local thread, isMain = coroutine.running()
    if not isMain then
        self._primitivesCount = (self._primitivesCount + 1) % self._yieldAfter
        if self._primitivesCount == 0 then coroutine.applicationYield() end
    end
end

local turtleMT = {}
turtleMT.__index = turtleMT

-- 6.1 Turtle Motion

    turtleMT.forward = function(self, distance)
        local turtleFrame = self._c:elementAttribute(self._turtleIdx, "frame")
        local x, y = turtleFrame.x, turtleFrame.y
        local rad = math.rad(self._turtleHeading)
        x = x + distance * math.sin(rad)
        y = y + distance * math.cos(rad)
        return self:setXY(x, y)
    end

    turtleMT.back = function(self, distance)
        return self:forward(-distance)
    end

    turtleMT.left = function(self, amount)
        return self:setHeading(self._turtleHeading - amount)
    end

    turtleMT.right = function(self, amount)
        return self:setHeading(self._turtleHeading + amount)
    end

    turtleMT.setPos = function(self, list)
        return self:setXY(list[1], list[2])
    end

    turtleMT.setXY = function(self, x, y)
        local turtleFrame = self._c:elementAttribute(self._turtleIdx, "frame")
        x = x or turtleFrame.x
        y = y or turtleFrame.y

        if self._penMode.down then

            if self._coordinatesCacheCount > self._maxCoordinateCacheSize then
                -- keep coordinate list from growing too large since its being passed back and forth
                self:penUp():penDown()
            end
            self._coordinatesCacheCount = self._coordinatesCacheCount + 1

            if individualCoordinateSupport then
                self._c:coordinateForElement(self._turtleIdx - 1, { x = x, y = y })
            else
                table.insert(self._coordinatesCache, { x = x, y = y })
                self._c:elementAttribute(self._turtleIdx - 1, "coordinates", self._coordinatesCache)
            end
        end
        self._c:elementAttribute(self._turtleIdx, "frame", { x = x, y = y, h = turtleSize.h, w = turtleSize.w })
        self:setHeading()
        return self
    end

    turtleMT.setX = function(self, x)
        return self:setXY(x, nil)
    end

    turtleMT.setY = function(self, y)
        return self:setXY(nil, y)
    end

    turtleMT.setHeading = function(self, angle)
        angle = angle or self._turtleHeading
        self._turtleHeading = angle % 360

        local turtleFrame = self._c:elementAttribute(self._turtleIdx, "frame")
        local x, y = turtleFrame.x, turtleFrame.y
        self._c:elementAttribute(self._turtleIdx, "transformation", turtleBaseMatrix:append(
            canvas.matrix.translate(x, y):rotate(-self._turtleHeading):translate(-x, -y)
        ))

        -- (almost) all 6.1 Turtle Motion methods end up here, so try to be coroutine friendly here and
        -- the rest will follow...
        coroutineFriendlyCheck(self)

        return self
    end

    turtleMT.home = function(self)
        self._turtleHeading = 0
        return self:setXY(0, 0)
    end

    -- arc

-- 6.2 Turtle Motion Queries

    turtleMT.pos = function(self)
        local turtleFrame = self._c:elementAttribute(self._turtleIdx, "frame")
        return setmetatable({ turtleFrame.x, turtleFrame.y }, {
            __tostring = function(_) return string.format("{ %.2f, %.2f }", _[1], _[2]) end
        })
    end

    turtleMT.xCor = function(self)
        return self:pos()[1]
    end

    turtleMT.yCor = function(self)
        return self:pos()[2]
    end

    turtleMT.heading = function(self)
        return self._turtleHeading
    end

    -- towards
    -- scrunch

-- 6.3 Turtle and Window Control

    turtleMT.showTurtle = function(self)
        self._c:elementAttribute(self._turtleIdx, "action", "strokeAndFill")
        coroutineFriendlyCheck(self) -- has a visual effect, so check to see if we're in a coroutine
        return self
    end

    turtleMT.hideTurtle = function(self)
        self._c:elementAttribute(self._turtleIdx, "action", "skip")
        coroutineFriendlyCheck(self) -- has a visual effect, so check to see if we're in a coroutine
        return self
    end

    turtleMT.clean = function(self)
        while self._c:elementCount() > 2 do self._c:removeElement(2) end
        self._turtleIdx = 2

        -- forces creation of initial segment element with initial position
        if self._penMode.down then self:penUp():penDown() end

        coroutineFriendlyCheck(self) -- has a visual effect, so check to see if we're in a coroutine
        return self
    end

    turtleMT.clearScreen = function(self)
        return self:home():clean()
    end

    -- fill
    -- filled
    -- label
    -- setlabelheight
    -- setscrunch
    -- refresh
    -- norefresh

    -- skipping
        -- window      -- alternates not implemeneted
        -- fence       -- no current use case and implementation non-trivial without history
        -- wrap        -- no current use case and implementation non-trivial
        -- textscreen  -- irrelevant to this implementation
        -- fullscreen  -- irrelevant to this implementation
        -- splitscreen -- irrelevant to this implementation

-- 6.4 Turtle and Window Queries

    turtleMT.turtleVisible = function(self) -- shownp
        return self._c:elementAttribute(self._turtleIdx, "action") ~= "skip"
    end

    -- labelsize

    -- skipping
        -- turtlemode -- variants fence and wrap not implemenetd, so useless
        -- screenmode -- irrelevant to this implementation

-- 6.5 Pen and Background Control

    turtleMT.penDown = function(self)
        if not self._penMode.down then
            local turtleFrame = self._c:elementAttribute(self._turtleIdx, "frame")
            local size        = self._c:size()

            self._coordinatesCache = { { x = turtleFrame.x, y = turtleFrame.y } }
            self._coordinatesCacheCount = 1

            self._c:insertElement({
                type        = "segments",
                action      = "stroke",
                strokeColor = penColors[self._penMode.color],
                coordinates = self._coordinatesCache,
                frame       = { x = -size.w / 2, y = -size.h / 2, h = size.h, w = size.w },
            }, self._turtleIdx)
            self._turtleIdx = self._turtleIdx + 1
            self._penMode.down = true
        end
        return self
    end

    turtleMT.penUp = function(self)
        if self._penMode.down then
            self._penMode.down = false
        end
        return self
    end

    -- penpaint
    -- penerase
    -- penreverse
    -- setpencolor
    -- setpalette
    -- setpensize
    -- setpenpattern
    -- setpen
    -- setbackground

-- 6.6 Pen Queries

    -- pendownp
    -- penmode
    -- pencolor
    -- palette
    -- pensize
    -- penpattern
    -- pen
    -- background

-- 6.7 Saving and Loading Pictures

    -- savepict
    -- loadpict
    -- epspict

-- 8.1 Control

    turtleMT.bye = function(self)
        _movers[self._c] = nil
        self._c:delete()
        self._c = nil
        setmetatable(self, nil)
    end

-- Hammerspoon specific

    turtleMT._show = function(self)
        self._c:show()
        return self
    end

    turtleMT._hide = function(self)
        self._c:hide()
        return self
    end

    turtleMT._toggle = function(self)
        return self._c:isShowing() and self:_hide() or self:_show()
    end

    turtleMT._xRange = function(self)
        local canvasFrame = self._c:frame()
        local maxAbsX, maxAbsY = canvasFrame.w / 2, canvasFrame.h / 2
        return setmetatable({ -maxAbsX, maxAbsX }, {
            __tostring = function(_) return string.format("[%.2f, %.2f]", _[1], _[2]) end
        })
    end

    turtleMT._yRange = function(self)
        local canvasFrame = self._c:frame()
        local maxAbsX, maxAbsY = canvasFrame.w / 2, canvasFrame.h / 2
        return setmetatable({ -maxAbsY, maxAbsY }, {
            __tostring = function(_) return string.format("[%.2f, %.2f]", _[1], _[2]) end
        })
    end

-- lua specific

    turtleMT.__tostring = function(self)
        local xRange, yRange = self:_xRange(), self:_yRange()
        return string.format("%s: X %s %s, Y %s %s", USERDATA_TAG, utf8.char(0x2208), tostring(xRange), utf8.char(0x2208), tostring(yRange))
    end

    turtleMT.__gc = turtleMT.bye

-- constructor

module.new = function(size)
    local screenFrame = screen.mainScreen():fullFrame()
    size = size or { h = screenFrame.h / 2, w = screenFrame.w / 2 }
    local _display
    _display = {
        _c = canvas.new{
                x = screenFrame.x + (screenFrame.w - size.w) / 2,
                y = screenFrame.y + (screenFrame.h - size.h) / 2,
                h = size.h,
                w = size.w,
            }:transformation(canvas.matrix.translate(size.w / 2, size.h / 2):scale(1, -1))
            :appendElements(
                {
                    type      = "rectangle",
                    fillColor = { white = 1 },
                    action    = "fill",
                    frame     = { x = -size.w / 2, y = -size.h / 2, h = size.h, w = size.w },
                }, {
                    type           = "image",
                    image          = turtle,
                    imageAlignment = "center",
                    imageScaling   = "none",
                    transformation = turtleBaseMatrix,
                    frame          = { x = 0, y = 0, h = turtleSize.h, w = turtleSize.w },
                }
            ):canvasMouseEvents(true, true)
            :mouseCallback(function(_c, _m, _i, _x, _y)
                if _i == "_canvas_" then
                    local buttons = eventtap.checkMouseButtons()
                    if _m == "mouseDown" then
                        if buttons.left then
                            local mover = coroutine.wrap(function()
                                while _movers[_c] do
                                    local pos = mouse.getAbsolutePosition()
                                    local frame = _c:frame()
                                    frame.x = pos.x - _x
                                    frame.y = pos.y - _y
                                    _c:frame(frame)
                                    coroutine.applicationYield()
                                end
                            end)
                            _movers[_c] = true
                            mover()
                        elseif buttons.right then
                            _c:hide()
                        end
                    elseif _m == "mouseUp" then
                        _movers[_c] = nil
                    end
                end
            end):clickActivating(false)
            :show(),
        _turtleIdx = 2,
        _turtleHeading = 0,
        _penMode = { mode = "paint", down = false, size = 1, color = 0 },
        _primitivesCount = 0,
        _yieldAfter = 10,
        _coordinatesCache = {},
        _coordinatesCacheCount = 0,
        _maxCoordinateCacheSize = individualCoordinateSupport and 150 or 15,
    }

    setmetatable(_display, turtleMT)
    return _display:penDown()
end

return module
