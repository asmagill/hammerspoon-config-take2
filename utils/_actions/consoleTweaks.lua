local console = require("hs.console")
local canvas  = require("hs.canvas")
local image   = require("hs.image")
local screen  = require("hs.screen")

local _c = canvas.new{ x = 0, y = 0, h = 200, w = 200 }
_c[1] = {
    type           = "image",
    image          = image.imageFromName("NSShareTemplate"):template(false),
    transformation = canvas.matrix.translate(100, 100):rotate(180):translate(-100, -100),
}
local _i_reseatConsole = _c:imageFromCanvas()
_c:delete()

local _i_darkModeToggle = image.imageFromASCII("2.........3\n" ..
                                               "...........\n" ..
                                               ".....g.....\n" ..
                                               "...........\n" ..
                                               "1...f.h...4\n" ..
                                               "6...b.c...9\n" ..
                                               "...........\n" ..
                                               "...a...d...\n" ..
                                               "...........\n" ..
                                               "7.........8", {
    { strokeColor = { white = .5 }, fillColor = { alpha = 0.0 }, shouldClose = false },
    { strokeColor = { white = .75 }, fillColor = { alpha = 0.5 }, shouldClose = false },
    { strokeColor = { white = .75 }, fillColor = { alpha = 0.0 }, shouldClose = false },
    { strokeColor = { white = .5 }, fillColor = { alpha = 0.0 }, shouldClose = true },
    {}
})

local colorizeConsolePerDarkMode = function()
    if console.darkMode() then
        console.outputBackgroundColor{ white = 0 }
        console.consoleCommandColor{ white = 1 }
        console.windowBackgroundColor{ list="System", name="windowBackgroundColor" }
        console.alpha(.9)
    else
        -- FYI these are the defaults
        console.outputBackgroundColor{ list="System", name="textBackgroundColor" }
        console.consoleCommandColor{ white = 0 }
        console.windowBackgroundColor{ list="System", name="windowBackgroundColor" }

    --     console.windowBackgroundColor({red=.6,blue=.7,green=.7})
    --     console.outputBackgroundColor({red=.8,blue=.8,green=.8})
        console.alpha(.9)
    end
end

console.behaviorAsLabels({"moveToActiveSpace"})
-- console.behaviorAsLabels({"canJoinAllSpaces"})

--console.titleVisibility("hidden")
console.toolbar():addItems{
    {
        id = "clear",
        image   = image.imageFromName("NSTrashFull"),
        fn      = function(...) console.clearConsole() end,
        label   = "Clear",
        tooltip = "Clear Console",
    }, {
        id      = "reseat",
        image   = _i_reseatConsole,
        fn      = function(...)
            local hammerspoon = application.applicationsForBundleID(hs.processInfo.bundleID)[1]
            local consoleWindow = hammerspoon:mainWindow()
            if consoleWindow then
                local consoleFrame = consoleWindow:frame()
                local screenFrame = screen.mainScreen():frame()
                local newConsoleFrame = {
                    x = screenFrame.x + (screenFrame.w - consoleFrame.w) / 2,
                    y = screenFrame.y + (screenFrame.h - consoleFrame.h),
                    w = consoleFrame.w,
                    h = consoleFrame.h,
                }
                consoleWindow:setFrame(newConsoleFrame)
            end
        end,
        label   = "Reseat",
        tooltip = "Reseat Console",
    }, {
        id      = "darkMode",
        image   = _i_darkModeToggle,
        fn      = function()
            console.darkMode(not console.darkMode())
            colorizeConsolePerDarkMode()
        end,
        label   = "Dark Mode",
        tooltip = "Toggle Dark Mode",
    }
}
-- since they don't exist when the toolbar is first attached, we have to re-insert them here
--   consider adding something in _coresetup to check users config dir for toolbar additions?
console.toolbar():insertItem("darkMode", #console.toolbar():visibleItems() + 1)
                 :insertItem("reseat", #console.toolbar():visibleItems() + 1)
                 :insertItem("clear", #console.toolbar():visibleItems() + 1)

console.smartInsertDeleteEnabled(false)

colorizeConsolePerDarkMode()

return true -- so require has something to save
